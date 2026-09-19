"""Execute the actual ghost JNI boundary: invalid records must reach the shell."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
JDK=Path(os.environ.get('KARTPAD_TEST_JDK',str(ROOT/'.android-bootstrap/jdk-17.0.20.1+1/Contents/Home')))
class GhostExportErrors(unittest.TestCase):
 def test_jni_preserves_validation_reason_and_save(self):
  text=(ROOT/'android/app/src/main/cpp/kartpad_runtime_settings_jni.cpp').read_text()
  function=text[text.index('#include "kartpad/ghost/rkg.h"'):]
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);cpp=root/'bridge.cpp';cpp.write_text('#include <jni.h>\n'+function);lib=root/'libghost.dylib'
   result=subprocess.run(['clang++','-std=c++20','-dynamiclib','-I'+str(JDK/'include'),'-I'+str(JDK/'include/darwin'),'-I'+str(ROOT/'runtime/include'),str(cpp),'-o',str(lib)],text=True,capture_output=True)
   self.assertEqual(result.returncode,0,result.stderr)
   java=root/'KartPadActivity.java';java.write_text(r'''
package dev.kartpad.android;
import java.nio.ByteBuffer;
import java.util.Arrays;
import java.util.zip.CRC32;
public class KartPadActivity {
 private native byte[] nativeGhostTransfer(byte[] save, byte[] ghost, int license, int slot, boolean downloaded);
 public static void main(String[] args) {
  System.load(args[0]);KartPadActivity activity=new KartPadActivity();
  byte[] save=new byte[0x2bc000];ByteBuffer b=ByteBuffer.wrap(save);
  b.putInt(0,0x524b5344);b.putInt(4,0x30303036);b.putInt(8,0x524b5044);
  for(boolean listed:new boolean[]{false,true}) {
   b.putInt(12,listed?1:0);CRC32 crc=new CRC32();crc.update(save,0,0x27ffc);b.putInt(0x27ffc,(int)crc.getValue());
   byte[] before=save.clone();boolean rejected=false;
   try {activity.nativeGhostTransfer(save,null,0,0,false);}
   catch(IllegalArgumentException failure){
    String expected=listed?"Not an RKG ghost":"No saved ghost for that course";
    if(!expected.equals(failure.getMessage()))throw new AssertionError(failure);
    rejected=true;
   }
   if(!rejected||!Arrays.equals(before,save))throw new AssertionError("error suppressed or save modified");
  }
 }
}
''')
   subprocess.run([str(JDK/'bin/javac'),'-d',d,str(java)],check=True,capture_output=True)
   run=subprocess.run([str(JDK/'bin/java'),'-cp',d,'dev.kartpad.android.KartPadActivity',str(lib)],text=True,capture_output=True)
   self.assertEqual(run.returncode,0,run.stderr)
if __name__=='__main__':unittest.main()
