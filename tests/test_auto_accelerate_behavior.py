"""Execute production Android latch methods with a deterministic UI scheduler."""
from pathlib import Path
import os
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
JAVA = Path(os.environ.get('KARTPAD_TEST_JDK', str(ROOT / '.android-bootstrap/jdk-17.0.20.1+1/Contents/Home'))) / 'bin/java'
CACHE = Path.home() / '.gradle/caches/modules-2/files-2.1'

def jar(path):
    return next(p for p in (CACHE/path).rglob('*.jar') if not p.name.endswith(('-sources.jar','-javadoc.jar')))

def method(source, name):
    match = re.search(r'(?:private )?fun '+name+r'\([^\n]*\) \{',source)
    start=match.start(); pos=match.end(); level=1
    while level:
        if source[pos]=='{': level+=1
        if source[pos]=='}': level-=1
        pos+=1
    return source[start:pos].replace('private fun ', 'fun ',1)

class AutoAccelerateBehavior(unittest.TestCase):
    def test_timer_disable_hold_release_and_accessibility(self):
        source=(ROOT/'android/app/src/main/java/dev/kartpad/android/KartPadOverlayView.kt').read_text()
        methods='\n'.join(method(source,n) for n in ('beginGasPress','toggleAccessibilityGasLock','reloadPresentationSettings'))
        kotlin=r'''
class Scheduler {
 val work=mutableListOf<()->Unit>()
 fun postDelayed(action:()->Unit, delay:Long) { work.add(action) }
 fun drain() { val pending=work.toList();work.clear();pending.forEach { it() } }
}
object KartPadTouchSettings {
 var enabled=true
 fun autoAccelerate(context:Int)=enabled
 fun opacity(context:Int)=0.82f
 fun size(context:Int)=1f
 fun modernCStickHorizontal(context:Int)=false
}
class Overlay {
 val context=0
 var autoAccelerate=KartPadTouchSettings.autoAccelerate(context)
 var gasLocked=false
 var gasHoldGeneration=0
 var hiddenForController=false
 var controlOpacity=0.82f
 var controlSizeScale=1f
 var modernCStickHorizontal=false
 val pointerOwners=mutableMapOf<Int,String>()
 val mainHandler=Scheduler()
 val GAS_LOCK_DELAY_MS=1000L
 var published=false
 fun updateGasAccessibility() {}
 fun performVirtualKeyHaptic() {}
 fun publishState(connected:Boolean) { published=gasLocked||pointerOwners.containsValue("A") }
 fun invalidate() {}
 fun reloadCustomSettings() {}
 fun requestLayout() {}
 fun sendAccessibilityTreeChanged() {}
 fun down() { pointerOwners[0]="A";beginGasPress();publishState(true) }
 fun up() { pointerOwners.clear();gasHoldGeneration++;publishState(true) }
''' + methods + r'''
}
fun main() {
 val v=Overlay()
 v.down();check(v.published&&!v.gasLocked);v.mainHandler.drain();v.up();check(v.published&&v.gasLocked)
 // Disabling a latched accelerator releases it immediately.
 KartPadTouchSettings.enabled=false;v.reloadPresentationSettings();check(!v.published&&!v.gasLocked)
 v.down();v.mainHandler.drain();check(v.published&&!v.gasLocked);v.up();check(!v.published)
 v.toggleAccessibilityGasLock();check(!v.gasLocked)
 // A queued callback cannot relock after a disable/re-enable cycle.
 KartPadTouchSettings.enabled=true;v.reloadPresentationSettings();v.down()
 KartPadTouchSettings.enabled=false;v.reloadPresentationSettings();check(v.published)
 KartPadTouchSettings.enabled=true;v.reloadPresentationSettings();v.mainHandler.drain();check(!v.gasLocked)
 v.up();check(!v.published)
 v.down();v.up();v.mainHandler.drain();check(!v.gasLocked&&!v.published)
 v.toggleAccessibilityGasLock();check(v.gasLocked);v.toggleAccessibilityGasLock();check(!v.gasLocked)
 KartPadTouchSettings.enabled=false
 val recreated=Overlay();recreated.down();recreated.mainHandler.drain();recreated.up();check(!recreated.published)
 println("Production accelerator timer, hold, disable and accessibility checks passed")
}
'''
        paths=[jar(p) for p in ('org.jetbrains.kotlin/kotlin-compiler-embeddable/2.2.21','org.jetbrains.kotlin/kotlin-stdlib/2.2.21','org.jetbrains/annotations/13.0','org.jetbrains.kotlin/kotlin-reflect/2.2.0','org.jetbrains.kotlinx/kotlinx-coroutines-core-jvm/1.8.0')]
        with tempfile.TemporaryDirectory() as tmp:
            src=Path(tmp)/'Probe.kt';src.write_text(kotlin);out=Path(tmp)/'tests.jar'
            compiled=subprocess.run([str(JAVA),'-cp',':'.join(map(str,paths)),'org.jetbrains.kotlin.cli.jvm.K2JVMCompiler','-no-stdlib','-no-reflect','-classpath',str(paths[1]),'-d',str(out),str(src)],text=True,capture_output=True)
            self.assertEqual(compiled.returncode,0,compiled.stderr)
            run=subprocess.run([str(JAVA),'-cp',f'{out}:{paths[1]}','ProbeKt'],text=True,capture_output=True)
            self.assertEqual(run.returncode,0,run.stderr)

    def test_saved_option_and_both_accessibility_routes(self):
        folder=ROOT/'android/app/src/main/java/dev/kartpad/android'
        settings=(folder/'KartPadTouchSettings.kt').read_text()
        self.assertIn('.getBoolean(AUTO_ACCELERATE, true)',settings)
        self.assertIn('putBoolean(AUTO_ACCELERATE, value)',settings)
        source=(folder/'KartPadOverlayView.kt').read_text()
        self.assertIn('ACTION_TOGGLE_GAS_LOCK -> if (control.id == "A" && autoAccelerate)',source)
        self.assertIn('if (control.id == "A" && autoAccelerate)',source)
        ios=(ROOT/'apple/ios/KartPadRuntimeOverlayHost.mm').read_text()
        self.assertIn('setBool:sender.on forKey:kKartPadAutoAccelerateKey',ios)
        self.assertIn('!strongSelf.kartPadGasPressed || !KartPadAutoAccelerateEnabled()',ios)
        self.assertIn('if (!self.kartPadGasPressed) [super buttonUp:self.kartPadGasButton]',ios)

if __name__=='__main__': unittest.main()
