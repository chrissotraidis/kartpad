"""Exercise maintained production timer pumps with reentrant scheduler callbacks."""
from pathlib import Path
import os
import shlex
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
class SleepTimerReentry(unittest.TestCase):
 def test_reentry_and_timer_boundaries_on_every_platform(self):
  for platform in ("android", "ios", "macos", "tvos"):
   with self.subTest(platform=platform):
    source = ROOT / "vendor/runtimes" / platform / "runtime/src/hle/os/os_sleep.cpp"
    text = source.read_text()
    start = text.index("bool ProcessSleepTimers(CpuContext* cpu)")
    end = text.index("\n} // namespace OsHleInternal", start)
    function = text[start:end]
    preamble = r'''
#include <algorithm>
#include <atomic>
#include <cassert>
#include <chrono>
#include <cstdint>
#include <iostream>
#include <mutex>
#include <unordered_map>
#include <unordered_set>
#include <vector>
struct CpuContext {uint32_t gpr[32]{};};
constexpr uint32_t kThreadSuspendOffset=4, kThreadStateOffset=0;
constexpr uint16_t kThreadStateReady=1, kThreadStateRunning=2;
struct SleepTimerEntry {uint32_t threadPtr; std::chrono::steady_clock::time_point deadline;};
std::mutex gSleepTimerMutex, gOutstandingParkMutex;
std::vector<SleepTimerEntry> gSleepTimers;
std::unordered_set<uint32_t> gOutstandingParks;
std::unordered_map<uint32_t,uint32_t> memory;
namespace Memory {
bool Contains(uint32_t address, size_t) {return address>4;}
uint16_t Read16(uint32_t address) {return memory.at(address);}
uint32_t Read32(uint32_t address) {return memory.at(address);}
}
namespace Fiber { struct GuestFiberManager {static bool IsTerminated(uint32_t) {return false;}}; }
void ClearOutstandingPark(uint32_t t) {gOutstandingParks.erase(t);}
bool SleepTimerIsPending(uint32_t t) {
    return std::any_of(gSleepTimers.begin(),gSleepTimers.end(),[t](auto e){return e.threadPtr==t;});
}
#define RT_LOG(x) std::cerr
bool ProcessSleepTimers(CpuContext*);
std::vector<uint32_t> resumed;
bool reenter=false, secondVisible=false, nestedProcessed=false;
void OSResumeThread_HLE_801aa58c(CpuContext* cpu) {
    const auto id=cpu->gpr[3]; resumed.push_back(id);
    if (reenter && id==0x100) {
        reenter=false;
        secondVisible=SleepTimerIsPending(0x200);
        nestedProcessed=ProcessSleepTimers(cpu);
    }
}
'''
    test = r'''
int main() {
    CpuContext cpu;
    using Clock=std::chrono::steady_clock;
    const auto past=Clock::now()-std::chrono::seconds(1);
    const auto future=Clock::now()+std::chrono::hours(1);
    memory[0x100]=memory[0x200]=kThreadStateReady;
    memory[0x104]=memory[0x204]=1;
    assert(!ProcessSleepTimers(&cpu));
    gSleepTimers={{0x100,future}};
    assert(!ProcessSleepTimers(&cpu)); assert(gSleepTimers.size()==1);
    gSleepTimers={{0x100,past},{0x200,past}};
    reenter=true;
    assert(ProcessSleepTimers(&cpu));
    assert(resumed==std::vector<uint32_t>({0x100,0x200}));
    assert(gSleepTimers.empty());
'''
    expect = "true"
    test += f"assert(secondVisible=={expect}); assert(nestedProcessed=={expect});\n"
    test += r'''
    resumed.clear(); memory[0x100]=kThreadStateRunning;
    gSleepTimers={{0x100,past}};
    assert(ProcessSleepTimers(&cpu)); assert(resumed.empty());
    assert(gSleepTimers.size()==1 && gSleepTimers.front().deadline>Clock::now());
    memory[0x100]=kThreadStateReady; memory[0x104]=0;
    gSleepTimers={{0x100,past}};
    assert(ProcessSleepTimers(&cpu)); assert(resumed.empty()); assert(gSleepTimers.empty());
    resumed.clear();
    for (unsigned i=0;i<65;++i) {
      const uint32_t id=0x1000+i*8;
      memory[id]=kThreadStateReady;memory[id+4]=1;
      gSleepTimers.push_back({id,past});
    }
    assert(ProcessSleepTimers(&cpu));assert(resumed.size()==64);assert(gSleepTimers.size()==1);
    assert(ProcessSleepTimers(&cpu));assert(resumed.size()==65);assert(gSleepTimers.empty());
    gSleepTimers={{0,past}};assert(ProcessSleepTimers(&cpu));assert(resumed.size()==65);
    assert(gSleepTimers.empty());
    std::cout << "timer cases passed; second due timer visible during reentry="
              << secondVisible << "; nested pump processed it=" << nestedProcessed << "\n";
}
'''
    with tempfile.TemporaryDirectory() as tmp:
     cpp=Path(tmp)/"timer.cpp";exe=Path(tmp)/"timer"
     cpp.write_text(preamble+function+test)
     subprocess.run([*shlex.split(os.environ.get("CXX","clang++")),"-std=c++20","-fsanitize=address,undefined","-Wall","-Wextra","-Werror",str(cpp),"-o",str(exe)],check=True)
     subprocess.run([str(exe)],check=True,timeout=15)
if __name__ == "__main__": unittest.main()
