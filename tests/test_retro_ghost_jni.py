"""Exercise the production JNI with exact file IO, SAF state inputs and UTF-8."""
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
JDK = Path(os.environ.get("KARTPAD_TEST_JDK", str(ROOT / ".android-bootstrap/jdk-17.0.20.1+1/Contents/Home")))


class RetroGhostJNI(unittest.TestCase):
    def test_android_document_request_codes_do_not_overlap(self):
        # Music and Retro ghost export both originally used 4322. Duplicate
        # request codes route a picker result to the wrong transfer operation.
        activity = (ROOT / "android/app/src/main/java/dev/kartpad/android/KartPadActivity.kt").read_text()
        declarations = re.findall(r"private const val (REQUEST_\w+) = ([\d_]+)", activity)
        codes = {}
        for name, value in declarations:
            code = int(value.replace("_", ""))
            self.assertNotIn(code, codes, f"{name} and {codes.get(code)} share picker request {code}")
            codes[code] = name
        self.assertTrue({"REQUEST_IMPORT_MUSIC", "REQUEST_EXPORT_RETRO_GHOST", "REQUEST_IMPORT_RETRO_GHOST"}.issubset(codes.values()))

    def test_catalog_import_export_pending_and_unicode(self):
        with tempfile.TemporaryDirectory(prefix="kartpad-retro-jni-") as temporary:
            task = Path(temporary)
            fixture = task / "fixture.cpp"
            fixture.write_text(r'''
#include "kartpad/ghost/retro_transfer.h"
#include "retro_catalog_fixture.h"
#include "retro_ghost_fixture.h"
#include <fstream>
void Write(const std::filesystem::path& p, const std::vector<uint8_t>& b) {
 std::filesystem::create_directories(p.parent_path());std::ofstream f(p,std::ios::binary);
 f.write(reinterpret_cast<const char*>(b.data()),b.size());
 if(!f)throw std::runtime_error("fixture IO failed");
}
int main(int argc,char** argv) {
 if(argc!=2)return 1;std::filesystem::path root(argv[1]);auto [rt,ct]=retro_fixture::Fixtures();
 const std::vector<uint8_t> text{0,'R',0,'e',0,'t',0,'r',0,'o',0,' '};
 auto p=std::search(rt.begin(),rt.end(),text.begin(),text.end());
 if(p==rt.end())return 2;size_t offset=p-rt.begin();
 retro_fixture::U16(rt,offset,0xd83d);retro_fixture::U16(rt,offset+2,0xde00);
 Write(root/"RetroRewind/RetroRewind6/Binaries/ConfigRT.pul",rt);
 Write(root/"RetroRewind/RetroRewind6/Binaries/ConfigCT.pul",ct);
 auto g=retro_fixture::Ghost(true);Write(root/"incoming.rkg",g);
 Write(root/"uncompressed.rkg",retro_fixture::Ghost(false,1));
 Write(root/"NAND/title/00010004/524d4350/data/rksys.dat",{1,2,3,4});
 Write(root/"RetroRewind/riivolution/save/RetroWFC/RMCP/rksys.dat",{5,6,7,8});
 Write(root/"NAND/shared2/Pulsar/RetroRewind6/ldb.pul",{9,10,11,12});
 auto c=kartpad::ghost::retro::ParseCatalog(rt,ct);
 Write(root/"NAND"/c.Select(0x100,0,0).directory/"x😀.rkg",g);
}
''')
            includes = ["-I" + str(ROOT / "runtime/include"), "-I" + str(ROOT / "runtime/tests")]
            compile_args = ["clang++", "-std=c++20", "-Wall", "-Wextra", "-Werror"]
            subprocess.run(compile_args + includes + [str(fixture), "-o", str(task / "fixture")], check=True, capture_output=True)
            root = task / "player-😀"
            subprocess.run([str(task / "fixture"), str(root)], check=True)
            library = task / "libretro.dylib"
            subprocess.run(compile_args + includes + [
                "-dynamiclib", "-I" + str(JDK / "include"), "-I" + str(JDK / "include/darwin"),
                str(ROOT / "android/app/src/main/cpp/kartpad_retro_ghost_jni.cpp"), "-o", str(library),
            ], check=True, capture_output=True)
            java = task / "KartPadActivity.java"
            java.write_text(r'''
package dev.kartpad.android;
import java.nio.file.*;
import java.util.*;
public class KartPadActivity {
 private native String nativeRetroGhostCatalog(String root);
 private native String[] nativeRetroGhostFiles(String root,int track,int variant,int mode,String identity);
 private native byte[] nativeRetroGhostTransfer(String root,int track,int variant,int mode,String identity,String filename,byte[] ghost);
 private native void nativeRetroGhostPending(String root,boolean apply);
 interface Operation {void run();}
 private static void rejects(Operation operation) {
  try {operation.run();}catch(IllegalArgumentException failure){return;}
  throw new AssertionError("invalid operation accepted");
 }
 private static Map<String,String> snapshot(Path root) throws Exception {
  Map<String,String> files=new TreeMap<>();
  try(var paths=Files.walk(root)) {
   for(Path path:paths.filter(Files::isRegularFile).toList())
    files.put(root.relativize(path).toString(),Base64.getEncoder().encodeToString(Files.readAllBytes(path)));
  }
  return files;
 }
 public static void main(String[] args) throws Exception {
  System.load(args[0]);String root=args[1];KartPadActivity a=new KartPadActivity();
  String catalog=a.nativeRetroGhostCatalog(root);
  if(!catalog.contains("😀tro Course")||!catalog.contains("\"tracks\""))throw new AssertionError("catalog encoding");
  String prefix="\"identity\":\"";int start=catalog.indexOf(prefix)+prefix.length();
  String identity=catalog.substring(start,catalog.indexOf('"',start));
  byte[] ghost=Files.readAllBytes(Path.of(root,"incoming.rkg"));
  byte[] uncompressed=Files.readAllBytes(Path.of(root,"uncompressed.rkg"));
  Map<String,String> original=snapshot(Path.of(root));
  String[] names=a.nativeRetroGhostFiles(root,0x100,0,0,identity);
  if(names.length!=1||!names[0].equals("x😀.rkg"))throw new AssertionError("filename encoding");
  if(!Arrays.equals(ghost,a.nativeRetroGhostTransfer(root,0x100,0,0,identity,names[0],null)))throw new AssertionError("UTF8 export mismatch");
  rejects(()->a.nativeRetroGhostTransfer(root,0x100,0,1,identity,null,new byte[10]));
  rejects(()->a.nativeRetroGhostTransfer(root,0x100,0,1,identity,null,new byte[0x2801]));
  rejects(()->a.nativeRetroGhostTransfer(root,0x100,0,1,"stale",null,ghost));
  rejects(()->a.nativeRetroGhostTransfer(root,-1,0,0,identity,null,ghost));
  rejects(()->a.nativeRetroGhostTransfer(root,0x100,-1,0,identity,null,ghost));
  rejects(()->a.nativeRetroGhostTransfer(root,0x100,0,4,identity,null,ghost));
  rejects(()->a.nativeRetroGhostTransfer(root,0x100,0,0,null,null,ghost));
  rejects(()->a.nativeRetroGhostTransfer(root,0x100,0,0,identity,null,null));
  rejects(()->a.nativeRetroGhostCatalog(null));
  if(!original.equals(snapshot(Path.of(root))))throw new AssertionError("rejected JNI request changed files");
  a.nativeRetroGhostTransfer(root,0x100,1,3,identity,null,ghost);
  if(a.nativeRetroGhostFiles(root,0x100,1,3,identity).length!=0)throw new AssertionError("live mutation during staging");
  if(!Files.exists(Path.of(root,"PendingRetroGhost.bin")))throw new AssertionError("pending missing");
  a.nativeRetroGhostPending(root,true);
  names=a.nativeRetroGhostFiles(root,0x100,1,3,identity);
  if(names.length!=1||!Arrays.equals(ghost,a.nativeRetroGhostTransfer(root,0x100,1,3,identity,names[0],null)))throw new AssertionError("roundtrip");
  if(Files.exists(Path.of(root,"PendingRetroGhost.bin")))throw new AssertionError("pending not finalized");
  a.nativeRetroGhostTransfer(root,0x100,1,2,identity,null,ghost);
  a.nativeRetroGhostPending(root,false);
  if(a.nativeRetroGhostFiles(root,0x100,1,2,identity).length!=0)throw new AssertionError("cancel applied");
  rejects(()->a.nativeRetroGhostFiles(root,0x100,1,2,"stale"));
  // Exercise all four modes across a nonbase Retro variant and a custom course.
  for(int track:new int[]{0x100,0x104}) for(int mode=0;mode<4;mode++) {
   int variant=track==0x100?2:0;
   byte[] input=(mode%2==0)?ghost:uncompressed;
   Map<String,String> before=snapshot(Path.of(root,"NAND"));
   a.nativeRetroGhostTransfer(root,track,variant,mode,identity,null,input);
   if(!before.equals(snapshot(Path.of(root,"NAND"))))throw new AssertionError("staging changed live NAND");
   a.nativeRetroGhostPending(root,true);
   String[] exported=a.nativeRetroGhostFiles(root,track,variant,mode,identity);
   if(exported.length!=1||!Arrays.equals(input,a.nativeRetroGhostTransfer(root,track,variant,mode,identity,exported[0],null)))
    throw new AssertionError("mode/variant JNI roundtrip mismatch");
  }
  // Config replacement between selection and cold application must retain the request.
  Map<String,String> before=snapshot(Path.of(root,"NAND"));
  a.nativeRetroGhostTransfer(root,0x101,0,0,identity,null,ghost);
  Path config=Path.of(root,"RetroRewind/RetroRewind6/Binaries/ConfigRT.pul");
  byte[] savedConfig=Files.readAllBytes(config),changedConfig=savedConfig.clone();
  changedConfig[changedConfig.length-1]^=1;Files.write(config,changedConfig);
  rejects(()->a.nativeRetroGhostPending(root,true));
  if(!Files.exists(Path.of(root,"PendingRetroGhost.bin"))||!before.equals(snapshot(Path.of(root,"NAND"))))
   throw new AssertionError("stale config consumed request or changed NAND");
  Files.write(config,savedConfig);
  a.nativeRetroGhostPending(root,false);
  if(!before.equals(snapshot(Path.of(root,"NAND"))))throw new AssertionError("cancel changed NAND");
  for(String path:new String[]{"NAND/title/00010004/524d4350/data/rksys.dat","RetroRewind/riivolution/save/RetroWFC/RMCP/rksys.dat","NAND/shared2/Pulsar/RetroRewind6/ldb.pul"})
   if(!original.get(path).equals(Base64.getEncoder().encodeToString(Files.readAllBytes(Path.of(root,path)))))
    throw new AssertionError("JNI transfer changed save or leaderboard");
 }
}
''')
            subprocess.run([str(JDK / "bin/javac"), "-encoding", "UTF-8", "-d", temporary, str(java)], check=True, capture_output=True)
            run = subprocess.run([str(JDK / "bin/java"), "-cp", temporary, "dev.kartpad.android.KartPadActivity", str(library), str(root)], capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, run.stderr)


if __name__ == "__main__":
    unittest.main()
