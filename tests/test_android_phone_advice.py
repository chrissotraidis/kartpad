"""Run KartPad's per-phone graphics advice rules on the host with realistic GPU strings."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PhoneAdviceTests(unittest.TestCase):
    def test_recommendations_match_known_drivers(self):
        cache = Path.home() / ".gradle/caches/modules-2/files-2.1"

        def jar(relative):
            return next((p for p in (cache / relative).glob("*/*.jar")
                         if not p.name.endswith(("-sources.jar", "-javadoc.jar"))), None)

        compiler, stdlib, annotations, reflect, coroutines = [jar(p) for p in (
            "org.jetbrains.kotlin/kotlin-compiler-embeddable/2.2.21",
            "org.jetbrains.kotlin/kotlin-stdlib/2.2.21",
            "org.jetbrains/annotations/13.0",
            "org.jetbrains.kotlin/kotlin-reflect/2.2.0",
            "org.jetbrains.kotlinx/kotlinx-coroutines-core-jvm/1.8.0",
        )]
        java = shutil.which("java")
        if not java or not all((compiler, stdlib, annotations, reflect, coroutines)):
            self.skipTest("Requires Java and the project's cached Kotlin compiler")
        with tempfile.TemporaryDirectory(prefix="kartpad-phone-advice-") as temporary:
            out = Path(temporary) / "tests.jar"
            subprocess.run([java, "-cp", ":".join(map(str, (compiler, stdlib, annotations, coroutines, reflect))),
                            "org.jetbrains.kotlin.cli.jvm.K2JVMCompiler", "-no-stdlib", "-no-reflect",
                            "-jvm-target", "17", "-classpath", str(stdlib), "-d", str(out),
                            str(ROOT / "android/app/src/main/java/dev/kartpad/android/KartPadPhoneAdvice.kt"),
                            str(ROOT / "tests/android_phone_advice/PhoneAdviceTests.kt")], check=True)
            result = subprocess.run([java, "-cp", f"{out}:{stdlib}", "dev.kartpad.android.PhoneAdviceTestsKt"],
                                    check=True, capture_output=True, text=True)
            self.assertIn("PASS", result.stdout)


if __name__ == "__main__":
    unittest.main()
