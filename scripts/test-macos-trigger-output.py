#!/usr/bin/env python3
"""Compile the prepared PADRead trigger block and check its final output."""
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'build/self-build-macos-source')
source = (root / 'aurora-main/lib/dolphin/pad/pad.cpp').read_text()
start = source.index('      Sint16 tl = std::max')
end = source.index('      if (controller->m_hasRumble)', start)
code = r'''
#include <algorithm>
#include <cassert>
#include <cstdint>
using Sint16 = int16_t;
constexpr int PAD_AXIS_TRIGGER_L=0, PAD_AXIS_TRIGGER_R=1;
constexpr int PAD_TRIGGER_L=64, PAD_TRIGGER_R=32;
struct Controller {
  struct { bool emulateTriggers; int leftTriggerActivationZone=8000;
           int rightTriggerActivationZone=8000; } m_deadZones;
};
struct Status { int button=0; uint8_t triggerLeft=0, triggerRight=0; };
Sint16 axes[2];
Sint16 _get_axis_value(Controller*, int axis) { return axes[axis]; }
int main() {
  for (bool emulate : {false, true})
  for (bool leftTriggerSet : {false, true})
  for (bool rightTriggerSet : {false, true})
  for (Sint16 left : {-32768, 0, 7999, 8001, 32767})
  for (Sint16 right : {-32768, 0, 7999, 8001, 32767}) {
    Controller device{{emulate}};
    Controller* controller = &device;
    Status status[1]; int i = 0;
    axes[0] = left; axes[1] = right;
''' + source[start:end] + r'''
    assert(status[0].triggerLeft == (leftTriggerSet ? 0 : std::max(0, int(left))/128));
    assert(status[0].triggerRight == (rightTriggerSet ? 0 : std::max(0, int(right))/128));
    assert(bool(status[0].button & PAD_TRIGGER_L) == (emulate && !leftTriggerSet && left > 8000));
    assert(bool(status[0].button & PAD_TRIGGER_R) == (emulate && !rightTriggerSet && right > 8000));
  }
}
'''
with tempfile.TemporaryDirectory() as directory:
    cpp = Path(directory) / 'trigger-output.cpp'
    executable = Path(directory) / 'trigger-output'
    cpp.write_text(code)
    subprocess.run(['clang++', '-std=c++20', '-Wall', '-Wextra', '-Werror',
                    str(cpp), '-o', str(executable)], check=True)
    subprocess.run([str(executable)], check=True)
print('PASS: 200 final PADStatus cases; both mapped triggers and analogue fallback')
