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

FAKES=r'''
class Scheduler {
 val work=mutableListOf<()->Unit>()
 fun postDelayed(action:()->Unit, delay:Long) { work.add(action) }
 fun drain() { val pending=work.toList();work.clear();pending.forEach { it() } }
}
object KartPadTouchSettings {
 var enabled=true
 var itemEnabled=false
 fun autoAccelerate(context:Int)=enabled
 fun itemHold(context:Int)=itemEnabled
 fun opacity(context:Int)=0.82f
 fun size(context:Int)=1f
 fun modernCStickHorizontal(context:Int)=false
}
class Overlay {
 val context=0
 var autoAccelerate=KartPadTouchSettings.autoAccelerate(context)
 var gasLocked=false
 var gasHoldGeneration=0
 var itemHold=KartPadTouchSettings.itemHold(context)
 var itemLocked=false
 var itemHoldGeneration=0
 var hiddenForController=false
 var controlOpacity=0.82f
 var controlSizeScale=1f
 var modernCStickHorizontal=false
 val pointerOwners=mutableMapOf<Int,String>()
 val mainHandler=Scheduler()
 val GAS_LOCK_DELAY_MS=1000L
 val ITEM_LOCK_DELAY_MS=670L
 var published=false
 var itemPublished=false
 fun updateGasAccessibility() {}
 fun updateItemAccessibility() {}
 fun performVirtualKeyHaptic() {}
 fun publishState(connected:Boolean) {
  published=gasLocked||pointerOwners.containsValue("A")
  itemPublished=itemLocked||pointerOwners.containsValue("L")
 }
 fun invalidate() {}
 fun reloadCustomSettings() {}
 fun requestLayout() {}
 fun sendAccessibilityTreeChanged() {}
 fun down() { pointerOwners[0]="A";beginGasPress();publishState(true) }
 fun up() { pointerOwners.clear();gasHoldGeneration++;publishState(true) }
 fun itemDown() { pointerOwners[1]="L";beginItemPress();publishState(true) }
 fun itemUp() { pointerOwners.remove(1);itemHoldGeneration++;publishState(true) }
'''

def run_probe(test, source, names, main):
    methods='\n'.join(method(source,n) for n in names)
    kotlin=FAKES + methods + '\n}\n' + main
    paths=[jar(p) for p in ('org.jetbrains.kotlin/kotlin-compiler-embeddable/2.2.21','org.jetbrains.kotlin/kotlin-stdlib/2.2.21','org.jetbrains/annotations/13.0','org.jetbrains.kotlin/kotlin-reflect/2.2.0','org.jetbrains.kotlinx/kotlinx-coroutines-core-jvm/1.8.0')]
    with tempfile.TemporaryDirectory() as tmp:
        src=Path(tmp)/'Probe.kt';src.write_text(kotlin);out=Path(tmp)/'tests.jar'
        compiled=subprocess.run([str(JAVA),'-cp',':'.join(map(str,paths)),'org.jetbrains.kotlin.cli.jvm.K2JVMCompiler','-no-stdlib','-no-reflect','-classpath',str(paths[1]),'-d',str(out),str(src)],text=True,capture_output=True)
        test.assertEqual(compiled.returncode,0,compiled.stderr)
        run=subprocess.run([str(JAVA),'-cp',f'{out}:{paths[1]}','ProbeKt'],text=True,capture_output=True)
        test.assertEqual(run.returncode,0,run.stderr)

class AutoAccelerateBehavior(unittest.TestCase):
    def test_timer_disable_hold_release_and_accessibility(self):
        source=(ROOT/'android/app/src/main/java/dev/kartpad/android/KartPadOverlayView.kt').read_text()
        run_probe(self, source, ('beginGasPress','beginItemPress','toggleAccessibilityGasLock','reloadPresentationSettings'), r'''
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
''')

    def test_item_hold_latch_release_disable_and_accessibility(self):
        source=(ROOT/'android/app/src/main/java/dev/kartpad/android/KartPadOverlayView.kt').read_text()
        run_probe(self, source, ('beginGasPress','beginItemPress','toggleAccessibilityItemLock','reloadPresentationSettings'), r'''
fun main() {
 // Off by default: holding L is an ordinary hold.
 val off=Overlay();off.itemDown();off.mainHandler.drain();off.itemUp();check(!off.itemPublished&&!off.itemLocked)
 KartPadTouchSettings.itemEnabled=true
 val v=Overlay()
 // A short tap never latches.
 v.itemDown();v.itemUp();v.mainHandler.drain();check(!v.itemLocked&&!v.itemPublished)
 // Holding for the delay keeps L held after release; the next press lets go.
 v.itemDown();v.mainHandler.drain();v.itemUp();check(v.itemLocked&&v.itemPublished)
 v.itemDown();check(!v.itemLocked);v.itemUp();check(!v.itemPublished)
 // The A latch and the item latch are independent.
 v.down();v.mainHandler.drain();v.up();v.itemDown();v.mainHandler.drain();v.itemUp()
 check(v.gasLocked&&v.itemLocked)
 // Turning the option off releases a held item at once.
 KartPadTouchSettings.itemEnabled=false;v.reloadPresentationSettings();check(!v.itemLocked&&!v.itemPublished&&v.gasLocked)
 v.toggleAccessibilityItemLock();check(!v.itemLocked)
 KartPadTouchSettings.itemEnabled=true;v.reloadPresentationSettings()
 v.toggleAccessibilityItemLock();check(v.itemLocked);v.toggleAccessibilityItemLock();check(!v.itemLocked)
 KartPadTouchSettings.itemEnabled=false
 println("Production item hold latch, release, disable and accessibility checks passed")
}
''')

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
