"""Run the production shake detector and Android sensor lifecycle on the JVM."""
from pathlib import Path
import os
import subprocess
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
JAVA = (str(Path(os.environ['JAVA_HOME']) / 'bin/java') if os.environ.get('JAVA_HOME')
        else next((str(p) for p in (ROOT / '.android-bootstrap').glob('jdk-*/Contents/Home/bin/java')),
                  shutil.which('java')))
CACHE = Path(os.environ.get('GRADLE_USER_HOME', str(Path.home() / '.gradle'))) / 'caches/modules-2/files-2.1'


def jar(path):
    found = next((p for p in (CACHE / path).rglob('*.jar')
                  if not p.name.endswith(('-sources.jar', '-javadoc.jar'))), None)
    if found is None:
        raise unittest.SkipTest('Run the Android Gradle build first to cache the pinned Kotlin compiler')
    return found


class ShakeTricksBehavior(unittest.TestCase):
    def test_gesture_and_independent_sensor_lifecycle(self):
        stubs = {
            'Context.kt': '''package android.content
import android.hardware.SensorManager
class Context(val manager: SensorManager) {
 val applicationContext get() = this
 fun <T> getSystemService(type: Class<T>): T = type.cast(manager)
}
''',
            'Sensor.kt': '''package android.hardware
class Sensor(val type: Int) { companion object {
 const val TYPE_GRAVITY=9; const val TYPE_ACCELEROMETER=1; const val TYPE_LINEAR_ACCELERATION=10
}}
class SensorEvent(val sensor: Sensor, val values: FloatArray, val timestamp: Long)
interface SensorEventListener {
 fun onSensorChanged(event: SensorEvent)
 fun onAccuracyChanged(sensor: Sensor?, accuracy: Int)
}
class SensorManager(var supportsShake: Boolean=true) {
 val registered=mutableSetOf<Int>()
 fun getDefaultSensor(type: Int): Sensor? = if(type==10&&!supportsShake) null else Sensor(type)
 fun registerListener(listener: SensorEventListener, sensor: Sensor, delay: Int): Boolean {
  registered.add(sensor.type);return true
 }
 fun unregisterListener(listener: SensorEventListener) { registered.clear() }
 companion object { const val GRAVITY_EARTH=9.80665f; const val SENSOR_DELAY_GAME=1 }
}
''',
            'Log.kt': '''package android.util
object Log { fun i(tag: String, msg: String)=0; fun d(tag: String, msg: String)=0 }
''',
            'Settings.kt': '''package dev.kartpad.android
import android.content.Context
object BuildConfig { const val DEBUG=true }
object KartPadTouchSettings {
 var tilt=false;var shake=false;var invert=false;var scale=1f
 fun motionEnabled(c: Context)=tilt
 fun shakeTricksEnabled(c: Context)=shake
 fun motionInverted(c: Context)=invert
 fun motionSensitivity(c: Context)=scale
 fun setMotionEnabled(c: Context,v: Boolean){tilt=v}
 fun setShakeTricksEnabled(c: Context,v: Boolean){shake=v}
 fun setMotionInverted(c: Context,v: Boolean){invert=v}
 fun setMotionSensitivity(c: Context,v: Float){scale=v}
}
''',
            'Probe.kt': '''package dev.kartpad.android
import android.content.Context
import android.hardware.*
fun main() {
 val d=KartPadShakeDetector()
 check(!d.sample(2.0,0.0)) // opening a menu/re-enabling in motion must not trigger
 check(!d.sample(0.1,0.1));check(!d.sample(0.9,0.2))
 check(d.sample(1.5,1.0));check(!d.sample(2.0,1.6)) // held impulse never repeats
 check(!d.sample(0.1,1.7));check(d.sample(1.5,1.8))
 check(!d.sample(0.1,1.9));check(!d.sample(1.5,2.0)) // cooldown consumes early impulse
 check(!d.sample(1.5,2.5));check(!d.sample(0.1,2.6));check(d.sample(1.5,2.7))
 d.reset();check(!d.sample(Double.NaN,3.0));check(!d.sample(2.0,3.1))
 check(!d.sample(0.0,3.2));check(!d.sample(2.0,Double.POSITIVE_INFINITY))
 check(d.sample(2.0,3.3))
 val manager=SensorManager();val context=Context(manager)
 var tricks=0;var steering=0f
 val motion=KartPadMotionSteering(context,{tricks++},{steering=it})
 fun acceleration(g: Float,seconds: Double) { motion.onSensorChanged(SensorEvent(
  Sensor(10),floatArrayOf(0f,0f,g*SensorManager.GRAVITY_EARTH),(seconds*1e9).toLong())) }
 motion.start();check(manager.registered.isEmpty()) // both options default off
 motion.setShakeTricksEnabled(true);check(manager.registered==setOf(10))
 acceleration(0f,4.0);acceleration(1.5f,4.1);check(tricks==1&&steering==0f)
 motion.setEnabled(true);check(manager.registered==setOf(9,10))
 motion.onSensorChanged(SensorEvent(Sensor(9),floatArrayOf(0f,9.8f,0f),5_000_000_000))
 motion.onSensorChanged(SensorEvent(Sensor(9),floatArrayOf(-4f,9f,0f),5_100_000_000))
 check(steering>0.3f)
 motion.setEnabled(false);check(manager.registered==setOf(10)&&steering==0f)
 acceleration(0f,6.0);acceleration(1.5f,6.1);check(tricks==2)
 motion.stop();acceleration(0f,7.0);acceleration(1.5f,7.1)
 check(tricks==2&&manager.registered.isEmpty()) // late callbacks after background ignored
 motion.start();acceleration(1.5f,8.0);check(tricks==2) // must settle on resume
 acceleration(0f,8.1);acceleration(1.5f,8.2);check(tricks==3)
 motion.setShakeTricksEnabled(false);acceleration(0f,9.0);acceleration(2f,9.1)
 check(tricks==3&&manager.registered.isEmpty())
 motion.setEnabled(true);motion.setShakeTricksEnabled(false);check(manager.registered==setOf(9))
 val absent=KartPadMotionSteering(Context(SensorManager(false)),{error("unavailable sensor")},{})
 check(!absent.shakeSensorAvailable);absent.setShakeTricksEnabled(true);absent.stop()
 println("Shake thresholds, flat z-axis input, cooldown, tilt independence, resume and disable passed")
}
''',
        }
        if not JAVA or not Path(JAVA).is_file():
            self.skipTest('Android JDK is not installed')
        paths = [jar(p) for p in (
            'org.jetbrains.kotlin/kotlin-compiler-embeddable/2.2.21',
            'org.jetbrains.kotlin/kotlin-stdlib/2.2.21', 'org.jetbrains/annotations/13.0',
            'org.jetbrains.kotlin/kotlin-reflect/2.2.0',
            'org.jetbrains.kotlinx/kotlinx-coroutines-core-jvm/1.8.0')]
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            for name, body in stubs.items():
                (tmp / name).write_text(body)
            source = ROOT / 'android/app/src/main/java/dev/kartpad/android'
            args = [str(tmp / n) for n in stubs] + [str(source / n) for n in
                    ('KartPadShakeDetector.kt', 'KartPadMotionSteering.kt')]
            output = tmp / 'tests.jar'
            build = subprocess.run([str(JAVA), '-cp', os.pathsep.join(map(str, paths)),
                'org.jetbrains.kotlin.cli.jvm.K2JVMCompiler', '-no-stdlib', '-no-reflect',
                '-classpath', str(paths[1]), '-d', str(output), *args], capture_output=True, text=True)
            self.assertEqual(build.returncode, 0, build.stderr)
            run = subprocess.run([str(JAVA), '-cp', f'{output}{os.pathsep}{paths[1]}',
                'dev.kartpad.android.ProbeKt'], capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, run.stderr)
