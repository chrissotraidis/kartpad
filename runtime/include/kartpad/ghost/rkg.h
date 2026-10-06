#pragma once
#include <algorithm>
#include <array>
#include <cstdint>
#include <span>
#include <stdexcept>
#include <utility>
#include <vector>

namespace kartpad::ghost {
inline constexpr size_t SaveBytes=0x2bc000, GhostBytes=0x2800;
inline constexpr std::array<unsigned,32> CourseIds{8,1,2,4,0,5,6,7,9,15,3,11,10,14,12,13,31,25,24,30,27,26,29,28,16,17,18,19,20,21,22,23};
inline constexpr std::array<const char*,32> CourseNames{"Luigi Circuit","Moo Moo Meadows","Mushroom Gorge","Toad's Factory","Mario Circuit","Coconut Mall","DK Summit","Wario's Gold Mine","Daisy Circuit","Koopa Cape","Grumble Volcano","Maple Treeway","Moonview Highway","Dry Dry Ruins","Bowser's Castle","Rainbow Road","GBA Shy Guy Beach","SNES Ghost Valley 2","SNES Mario Circuit 3","GBA Bowser Castle 3","N64 Sherbet Land","N64 Mario Raceway","N64 DK's Jungle Parkway","N64 Bowser's Castle","GCN Peach Beach","GCN Mario Circuit","GCN Waluigi Stadium","GCN DK Mountain","DS Yoshi Falls","DS Desert Hills","DS Peach Gardens","DS Delfino Square"};
inline void Require(bool value,const char* why){if(!value)throw std::runtime_error(why);}
inline uint32_t Read32(std::span<const uint8_t> b,size_t p){Require(p<=b.size()&&b.size()-p>=4,"Truncated data");return uint32_t(b[p])<<24|uint32_t(b[p+1])<<16|uint32_t(b[p+2])<<8|b[p+3];}
inline void Write32(std::span<uint8_t>b,size_t p,uint32_t v){for(int i=0;i<4;++i)b[p+i]=uint8_t(v>>(24-8*i));}
inline uint32_t Crc(std::span<const uint8_t>b){uint32_t c=~0u;for(auto v:b){c^=v;for(int i=0;i<8;++i)c=(c>>1)^(0xedb88320u&uint32_t(-int(c&1)));}return ~c;}
struct Info {unsigned course;size_t bytes;};
inline Info Validate(std::span<const uint8_t>b,std::vector<uint8_t>*expandedInputs=nullptr){
 Require(b.size()>=0x90&&b.size()<=GhostBytes,"Unsupported ghost size");
 Require(Read32(b,0)==0x524b4744,"Not an RKG ghost");
 const uint32_t race=Read32(b,4),who=Read32(b,8);
 Require(((race>>18)&127)<60&&((race>>8)&1023)<1000,"Invalid ghost time");
 Require((who>>26)<36&&((who>>20)&63)<48,"Unsupported ghost character or vehicle");
 const unsigned course=(race>>2)&63;Require(course<32,"Only Original race courses are supported");
 const size_t length=(size_t(b[14])<<8)|b[15];Require(length>=8&&length<=0x2774,"Invalid input length");
 std::vector<uint8_t> input;
 size_t crcOffset=GhostBytes-4;
 if(b[12]&8){
  const size_t packed=Read32(b,0x88);Require(packed>=16&&packed<=GhostBytes-0x90,"Invalid compressed length");
  crcOffset=0x8c+packed;Require(crcOffset+4<=b.size(),"Truncated compressed ghost");
  auto yaz=b.subspan(0x8c,packed);Require(Read32(yaz,0)==0x59617a31||Read32(yaz,0)==0x59617a30,"Invalid Yaz header");
  Require(Read32(yaz,4)==length,"Expanded size mismatch");input.reserve(length);size_t p=16;
  while(input.size()<length){Require(p<yaz.size(),"Truncated Yaz flags");unsigned flags=yaz[p++];for(unsigned bit=128;bit&&input.size()<length;bit>>=1){
   if(flags&bit){Require(p<yaz.size(),"Truncated Yaz literal");input.push_back(yaz[p++]);}
   else{Require(p+2<=yaz.size(),"Truncated Yaz match");unsigned a=yaz[p++],v=yaz[p++];size_t distance=((a&15)<<8|v)+1,count=a>>4;
    if(count==0){Require(p<yaz.size(),"Truncated Yaz run");count=yaz[p++]+18;}else count+=2;
    Require(distance<=input.size()&&count<=length-input.size(),"Invalid Yaz match");while(count--)input.push_back(input[input.size()-distance]);}
  }}
 }else{Require(b.size()==GhostBytes,"Uncompressed ghosts must be 10240 bytes");input.assign(b.begin()+0x88,b.begin()+0x88+length);}
 Require(Read32(b,crcOffset)==Crc(b.first(crcOffset)),"Ghost checksum mismatch");
 size_t expected=8;for(size_t p:{0u,2u,4u})expected+=2*((unsigned(input[p])<<8)|input[p+1]);Require(expected==input.size(),"Invalid input stream table");
 if(expandedInputs)*expandedInputs=std::move(input);
 return {course,crcOffset+4};
}
inline void ValidateSave(std::span<const uint8_t>b,unsigned license){
 Require(b.size()==SaveBytes&&Read32(b,0)==0x524b5344&&Read32(b,4)==0x30303036,"Unsupported save");
 Require(Read32(b,0x27ffc)==Crc(b.first(0x27ffc)),"Save checksum mismatch");
 Require(license<4&&Read32(b,8+license*0x8cc0)==0x524b5044,"Choose an initialized license");
}
inline std::vector<uint8_t> Export(std::span<const uint8_t>save,unsigned license,unsigned slot,bool downloaded){
 ValidateSave(save,license);Require(slot<32,"Invalid course");
 const auto bits=Read32(save,8+license*0x8cc0+(downloaded?8:4));Require(bits&(1u<<slot),"No saved ghost for that course");
 const size_t p=0x28000+license*0xa5000+(downloaded?0x50000:0)+slot*GhostBytes;
 auto data=save.subspan(p,GhostBytes);auto info=Validate(data);Require(info.course==CourseIds[slot],"Ghost/course mismatch");return {data.begin(),data.begin()+info.bytes};
}
inline std::vector<uint8_t> Import(std::span<const uint8_t>save,std::span<const uint8_t>ghost,unsigned license){
 ValidateSave(save,license);std::vector<uint8_t>inputs;auto info=Validate(ghost,&inputs);unsigned slot=unsigned(std::find(CourseIds.begin(),CourseIds.end(),info.course)-CourseIds.begin());Require(slot<32,"Unknown course");
 std::vector<uint8_t> result(save.begin(),save.end());size_t p=0x28000+license*0xa5000+0x50000+slot*GhostBytes;
 std::fill_n(result.begin()+p,GhostBytes,0);
 // Original's downloaded replay consumes a native input table at 0x88;
 // unlike staff/Retro replay, it does not decompress the saved container.
 if(ghost[12]&8){std::copy_n(ghost.begin(),0x88,result.begin()+p);std::copy(inputs.begin(),inputs.end(),result.begin()+p+0x88);result[p+12]&=0xf7;}
 else std::copy_n(ghost.begin(),info.bytes,result.begin()+p);
 // Imported comparison ghost: leave personal records and their ghost slots intact.
 result[p+12]=uint8_t((result[p+12]&0xfeu)|((7u>>6)&1u));result[p+13]=uint8_t((result[p+13]&3u)|((7u&63u)<<2));
 Write32(result,p+GhostBytes-4,Crc(std::span<const uint8_t>(result).subspan(p,GhostBytes-4)));
 const size_t bits=8+license*0x8cc0+8;Write32(result,bits,Read32(result,bits)|(1u<<slot));Write32(result,0x27ffc,Crc(std::span<const uint8_t>(result).first(0x27ffc)));return result;
}
}
