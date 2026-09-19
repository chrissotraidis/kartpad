"""Device-independent contracts, not claims of affected-device acceptance."""
from pathlib import Path
import importlib.util
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class NativeDiagnosticContracts(unittest.TestCase):
    def test_shared_wire_format_and_independent_budgets(self):
        import json
        canonical = ROOT / "runtime/include/kartpad/diagnostics/events.h"
        for platform in ("android", "ios"):
            self.assertEqual(canonical.read_bytes(), (ROOT/"vendor/runtimes"/platform/"aurora-main/include/aurora/kartpad_diagnostics.h").read_bytes())
        source = r'''#include "events.h"
#include <limits>
int main() {
 using namespace kartpad::diagnostics;
 event(Boundary::Adapter,"rejected",7,"quote\"slash\\newline\n");
 for(int i=0;i<100;i++) event(Boundary::Instance,"driver_message",i,std::string(600,'x'));
 event(Boundary::Device,"uncaptured_error",9,"later failure");
 frame(300,std::numeric_limits<double>::infinity(),2,3,4,5,1);
}'''
        source = '#include <string>\n' + source
        with tempfile.TemporaryDirectory() as tmp:
            cpp=Path(tmp)/"test.cpp"; exe=Path(tmp)/"test";cpp.write_text(source)
            subprocess.run(["clang++","-std=c++20","-Wall","-Wextra","-Werror","-I",str(canonical.parent),str(cpp),"-o",str(exe)],check=True)
            run=subprocess.run([str(exe)],capture_output=True,text=True,check=True)
        rows=[json.loads(line.split(" ",1)[1]) for line in run.stderr.splitlines()]
        self.assertEqual(len(rows),36)
        self.assertEqual(rows[0]["detail"], 'quote"slash\\newline ')
        self.assertEqual(rows[1]["detail"], 'x'*512)
        self.assertTrue(rows[1]["detail_truncated"])
        self.assertEqual(rows[-3]["status"],"budget_exhausted")
        self.assertEqual(rows[-2]["boundary"],"device")
        self.assertEqual(rows[-1]["fps"],-1)
        self.assertTrue(all(row["pid"]>0 and row["schema"]==2 for row in rows))

    def test_exact_build_id_symbolization(self):
        tools = Path.home()/"Library/Android/sdk/ndk/29.0.14206865/toolchains/llvm/prebuilt/darwin-x86_64/bin"
        spec = importlib.util.spec_from_file_location("symbolize", ROOT/"scripts/symbolize-android-frame.py")
        module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp)/"fixture.c"; binary=Path(tmp)/"fixture.so"
            source.write_text('int diagnostic_fixture(int x) { return x + 42; }\n')
            subprocess.run([str(tools/"clang"),"--target=aarch64-linux-android28","-shared","-nostdlib","-g","-Wl,--build-id=sha1",str(source),"-o",str(binary)],check=True)
            notes=subprocess.check_output([str(tools/"llvm-readelf"),"--notes",str(binary)],text=True)
            identity=re.search(r"Build ID:\s*([a-f0-9]+)",notes).group(1)
            symbols=subprocess.check_output([str(tools/"llvm-nm"),str(binary)],text=True)
            pc=re.search(r"([a-f0-9]+) T diagnostic_fixture",symbols).group(1)
            text=module.symbolize(binary,identity,pc,tools)
            self.assertIn("diagnostic_fixture",text);self.assertIn("fixture.c:1",text)
            with self.assertRaises(ValueError): module.symbolize(binary,"0"*40,pc,tools)

    def test_mobile_keeps_os_signal_and_terminate_handlers(self):
        for platform in ("android", "ios"):
            runtime=(ROOT/"vendor/runtimes"/platform/"runtime/src/main.cpp").read_text()
            start=runtime.index("    // Mobile OS crash collectors", runtime.index("int RuntimeMain"))
            end=runtime.index("    std::atexit(AtExitHandler);",start)+len("    std::atexit(AtExitHandler);")
            registration=runtime[start:end]
            define="#define __ANDROID__ 1" if platform=="android" else "#undef TARGET_OS_IOS\n#define TARGET_OS_IOS 1"
            source="""#include <csignal>
#include <cstdlib>
#include <exception>
#include <cassert>
void AbortSignalHandler(int) {}
void TerminateHandler() {}
void AtExitHandler() {}
"""+define+"\nint main() { auto original = std::get_terminate();\n"+registration+"""
assert(std::signal(SIGABRT,SIG_DFL)==SIG_DFL);
assert(std::get_terminate()==original);
}
"""
            with tempfile.TemporaryDirectory() as tmp:
                cpp=Path(tmp)/"test.cpp"; exe=Path(tmp)/"test";cpp.write_text(source)
                subprocess.run(["clang++","-std=c++20",str(cpp),"-o",str(exe)],check=True)
                subprocess.run([str(exe)],check=True)

    def test_thread_cpu_distinguishes_wait_and_work(self):
        source=r'''
#include "kartpad_function_timing.h"
#include <cassert>
#include <thread>
int main() {
 setenv("KARTPAD_FUNCTION_TIMING","1",1);
 kartpad::diagnostics::FunctionWindow wait{"fixture_wait"};
 { kartpad::diagnostics::FunctionScope s(wait); std::this_thread::sleep_for(std::chrono::milliseconds(40)); }
 assert(wait.calls==1 && wait.wall>=30000000 && wait.unavailable==0);
 assert(wait.cpu < wait.wall/2);
 kartpad::diagnostics::FunctionWindow busy{"fixture_busy"};
 { kartpad::diagnostics::FunctionScope s(busy); const auto end=std::chrono::steady_clock::now()+std::chrono::milliseconds(30); while(std::chrono::steady_clock::now()<end) {} }
 assert(busy.calls==1 && busy.cpu>1000000);
 busy.windows=120;
 { kartpad::diagnostics::FunctionScope s(busy); }
 assert(busy.calls==1);
 kartpad::diagnostics::FunctionWindow emitted{"fixture_emitted"};
 emitted.last -= std::chrono::seconds(6);
 { kartpad::diagnostics::FunctionScope s(emitted); }
 assert(emitted.windows==1 && emitted.calls==0);
}
'''
        with tempfile.TemporaryDirectory() as tmp:
            cpp=Path(tmp)/"test.cpp"; exe=Path(tmp)/"test";cpp.write_text(source)
            subprocess.run(["clang++","-std=c++20","-Wall","-Wextra","-Werror","-I",str(ROOT/"vendor/runtimes/android/runtime/include"),str(cpp),"-o",str(exe)],check=True)
            run=subprocess.run([str(exe)],capture_output=True,text=True,check=True)
            self.assertRegex(run.stderr, r"\[KartPadFunction\] pid=[1-9][0-9]* unix_ms=[1-9][0-9]* steady_ms=[1-9][0-9]* function=fixture_emitted window=1 calls=1")

if __name__ == "__main__": unittest.main()
