"""Exercise the production JNI with exact file IO, SAF state inputs and UTF-8."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
JDK = Path(os.environ.get("KARTPAD_TEST_JDK", str(ROOT / ".android-bootstrap/jdk-17.0.20.1+1/Contents/Home")))


class RetroGhostJNI(unittest.TestCase):
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
 public static void main(String[] args) throws Exception {
  System.load(args[0]);String root=args[1];KartPadActivity a=new KartPadActivity();
  String catalog=a.nativeRetroGhostCatalog(root);
  if(!catalog.contains("😀tro Course")||!catalog.contains("\"tracks\""))throw new AssertionError("catalog encoding");
  String prefix="\"identity\":\"";int start=catalog.indexOf(prefix)+prefix.length();
  String identity=catalog.substring(start,catalog.indexOf('"',start));
  byte[] ghost=Files.readAllBytes(Path.of(root,"incoming.rkg"));
  String[] names=a.nativeRetroGhostFiles(root,0x100,0,0,identity);
  if(names.length!=1||!names[0].equals("x😀.rkg"))throw new AssertionError("filename encoding");
  if(!Arrays.equals(ghost,a.nativeRetroGhostTransfer(root,0x100,0,0,identity,names[0],null)))throw new AssertionError("UTF8 export mismatch");
  rejects(()->a.nativeRetroGhostTransfer(root,0x100,0,1,identity,null,new byte[10]));
  rejects(()->a.nativeRetroGhostTransfer(root,0x100,0,1,"stale",null,ghost));
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
 }
}
''')
            subprocess.run([str(JDK / "bin/javac"), "-encoding", "UTF-8", "-d", temporary, str(java)], check=True, capture_output=True)
            run = subprocess.run([str(JDK / "bin/java"), "-cp", temporary, "dev.kartpad.android.KartPadActivity", str(library), str(root)], capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, run.stderr)


if __name__ == "__main__":
    unittest.main()
