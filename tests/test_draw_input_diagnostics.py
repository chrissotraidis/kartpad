"""Actual-draw input checker boundaries and bounded reporting, using synthetic geometry."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
ROOT = Path(__file__).resolve().parents[1]

class DrawInputDiagnosticsTests(unittest.TestCase):
    def test_mobile_headers_match(self):
        for platform in ("android", "ios"):
            self.assertEqual((ROOT/"runtime/include/kartpad/diagnostics/draw_inputs.h").read_bytes(),
                (ROOT/"vendor/runtimes"/platform/"aurora-main/lib/gx/kartpad_draw_inputs.hpp").read_bytes())

    def test_matrix_indices_and_nonfinite_data(self):
        compiler = shutil.which("clang++") or shutil.which("g++")
        self.assertIsNotNone(compiler)
        source = r'''
#include <kartpad/diagnostics/draw_inputs.h>
#include <cassert>
#include <limits>
#include <vector>
using namespace kartpad::diagnostics;
int main() {
  for (unsigned raw = 0; raw <= 255; ++raw) {
    uint8_t bytes[4] = {static_cast<uint8_t>(raw), 255, 255, 255};
    const auto result = inspect_matrix_selection(bytes, sizeof(bytes), 1, 4);
    assert(result.complete && result.sampled == 1 && result.max_raw == raw);
    assert(result.outside_palette == (raw >= 30 ? 1u : 0u));
    assert(result.non_row_multiple == (raw % 3 != 0 ? 1u : 0u));
    assert(result.used_mask == (raw < 30 ? uint16_t(1u << (raw / 3)) : 0));
  }
  uint8_t values[] = {0, 99, 27, 99, 30, 99};
  const auto all = inspect_matrix_selection(values, sizeof(values), 3, 2);
  assert(all.complete && all.used_mask == 0x201 && all.outside_palette == 1);
  assert(!inspect_matrix_selection(values, 5, 3, 2).complete);
  assert(!inspect_matrix_selection(nullptr, 6, 3, 2).complete);
  assert(!inspect_matrix_selection(values, 6, 3, 0).complete);
  assert(!inspect_matrix_selection(values, 6, UINT32_MAX, UINT32_MAX).complete);
  assert(inspect_matrix_selection(values, 6, 0, 2).complete);
  float matrix[12] = {};
  assert(count_nonfinite(matrix, sizeof(matrix)) == 0);
  matrix[0] = std::numeric_limits<float>::quiet_NaN();
  matrix[4] = std::numeric_limits<float>::infinity();
  matrix[11] = -std::numeric_limits<float>::infinity();
  assert(count_nonfinite(matrix, sizeof(matrix)) == 3);
  std::vector<uint8_t> unaligned(sizeof(matrix)+1);
  std::memcpy(unaligned.data()+1, matrix, sizeof(matrix));
  assert(count_nonfinite(unaligned.data()+1, sizeof(matrix)) == 3);
  DrawSamplingBudget sampling;
  for (unsigned slice=0;slice<32;++slice) {
    const uint64_t ms=(uint64_t(slice)*30000+31)/32;
    for(unsigned i=0;i<64;++i) assert(sampling.take(ms));
    assert(!sampling.take(ms));
  }
  assert(!sampling.take(30000));
  assert(!sampling.take(UINT64_MAX));
  sampling={}; assert(sampling.take(29999));
  DrawOutcomeWindow outcome;
  assert(outcome.record(false, 100)); // missing pipeline first observed
  assert(outcome.skipped==1 && outcome.encoded==0);
  outcome.clearCounts();
  assert(!outcome.record(false, 101));
  assert(outcome.record(true, 102)); // readiness transition must not be hidden
  assert(outcome.skipped==1 && outcome.encoded==1);
  outcome.clearCounts();
  assert(!outcome.record(true, 5101));
  assert(outcome.record(true, 5102));
  assert(outcome.encoded==2);
  outcome.clearCounts();
  assert(!outcome.record(false, 1)); // backward clock cannot underflow
  for(unsigned i=3;i<120;++i) assert(outcome.record(true, 5102+uint64_t(i)*5000));
  assert(outcome.reports==120);
  assert(!outcome.record(false, UINT64_MAX));
  DrawReportBudget budget;
  for (uint64_t i=0;i<32;++i) {
    assert(budget.take(i,false));
    assert(!budget.take(i,false));
  }
  assert(!budget.take(32,false));
  for(int i=0;i<64;++i) assert(budget.take(0,true));
  assert(!budget.take(0,true));
}
'''
        with tempfile.TemporaryDirectory() as tmp:
            cpp, exe = Path(tmp)/"test.cpp",Path(tmp)/"test"
            cpp.write_text(source)
            subprocess.run([compiler,"-std=c++17","-Wall","-Wextra","-Werror","-fsanitize=address,undefined",
                            "-I",str(ROOT/"runtime/include"),str(cpp),"-o",str(exe)],check=True)
            subprocess.run([str(exe)],check=True)

if __name__ == '__main__': unittest.main()
