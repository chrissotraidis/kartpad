#include "kartpad/ghost/rkg.h"
#include <iostream>
using namespace kartpad::ghost;
int main(){
 std::vector<uint8_t>s(SaveBytes),g(GhostBytes);Write32(s,0,0x524b5344);Write32(s,4,0x30303036);Write32(s,8,0x524b5044);Write32(s,0x27ffc,Crc(std::span<const uint8_t>(s).first(0x27ffc)));
 Write32(g,0,0x524b4744);Write32(g,4,(8u<<2)|(30u<<18));Write32(g,8,0);g[15]=14;g[0x89]=1;g[0x8b]=1;g[0x8d]=1;g[0x90]=1;g[0x91]=60;g[0x92]=0x77;g[0x93]=60;g[0x94]=0;g[0x95]=60;
 Write32(g,GhostBytes-4,Crc(std::span<const uint8_t>(g).first(GhostBytes-4)));
 Require(Validate(g).course==8,"course decode");auto imported=Import(s,g,0);auto out=Export(imported,0,0,true);Require(Validate(out).course==8,"roundtrip");
 Require(Read32(imported,12)==0,"personal ghost presence changed");
 for(size_t i=0;i<s.size();++i){bool allowed=(i>=16&&i<20)||(i>=0x27ffc&&i<0x28000)||(i>=0x78000&&i<0x7a800);Require(allowed||s[i]==imported[i],"unrelated save data changed");}
 for(int mode=0;mode<4;++mode){auto bad=g;if(mode==0)bad[0]^=1;if(mode==1)bad[14]=0xff;if(mode==2)bad[30]^=1;if(mode==3)bad.resize(100);bool rejected=false;try{(void)Validate(bad);}catch(...){rejected=true;}Require(rejected,"invalid ghost accepted");}
 bool missing=false;try{(void)Export(s,0,0,false);}catch(...){missing=true;}Require(missing,"missing ghost accepted");
 // Minimal compressed fixture with literal-only Yaz1 data and exact CRC.
 std::vector<uint8_t>c(g.begin(),g.begin()+0x88);c[12]|=8;c.resize(0x8c+16);Write32(c,0x8c,0x59617a31);Write32(c,0x90,14);
 c.push_back(0xff);c.insert(c.end(),g.begin()+0x88,g.begin()+0x90);c.push_back(0xfc);c.insert(c.end(),g.begin()+0x90,g.begin()+0x96);Write32(c,0x88,uint32_t(c.size()-0x8c));auto end=c.size();c.resize(end+4);Write32(c,end,Crc(std::span<const uint8_t>(c).first(end)));Require(Validate(c).bytes==c.size(),"compressed ghost rejected");
 Require(Validate(Export(Import(s,c,0),0,0,true)).course==8,"compressed save roundtrip");
 auto expandedSave=Import(s,c,0);auto expanded=Export(expandedSave,0,0,true);
 // Original's downloaded replay copies the slot directly and treats 0x88 as
 // the native stream table. Compressed length/Yaz bytes are not replay inputs.
 Require(expanded.size()==GhostBytes&&!(expanded[12]&8),"Original slot must contain an uncompressed ghost");
 Require(std::equal(g.begin()+0x88,g.begin()+0x96,expanded.begin()+0x88),"expanded native stream table and input records differ");
 Require(expanded[0x89]==1&&expanded[0x90]==1&&expanded[0x91]==60,"native loader lost recorded acceleration");
 auto expectedHeader=std::vector<uint8_t>(c.begin(),c.begin()+0x88);expectedHeader[12]&=0xf6;expectedHeader[13]=uint8_t((expectedHeader[13]&3u)|(7u<<2));
 Require(std::equal(expectedHeader.begin(),expectedHeader.end(),expanded.begin()),"ghost metadata changed beyond container and comparison type");
 for(size_t i=0;i<s.size();++i){bool allowed=(i>=16&&i<20)||(i>=0x27ffc&&i<0x28000)||(i>=0x78000&&i<0x7a800);Require(allowed||s[i]==expandedSave[i],"compressed import changed unrelated save data");}
 // Match the native header predicate: zero dates are accepted; year >99 or
 // month >12 must not be advertised as replayable merely because CRC is valid.
 for(uint32_t date:{0u,99u<<13|12u<<9,100u<<13,13u<<9}){
  auto dated=g;Write32(dated,8,date);Write32(dated,GhostBytes-4,Crc(std::span<const uint8_t>(dated).first(GhostBytes-4)));
  bool accepted=true;try{(void)Validate(dated);}catch(...){accepted=false;}
  Require(accepted==(date==0u||date==(99u<<13|12u<<9)),"native ghost date bounds differ");
 }
 std::cout<<"Ghost checksums, bounds, compressed roundtrip and unrelated save preservation passed\n";
}
