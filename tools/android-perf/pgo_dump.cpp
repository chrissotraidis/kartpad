// PGO experiment only: Android kills app processes without running atexit, so
// write the instrumented pack's counters from a timer thread. Counters reset
// 75 s after load (inside the first race) and are written 90 s later.
#include <chrono>
#include <thread>
extern "C" int __llvm_profile_write_file(void);
extern "C" void __llvm_profile_set_filename(const char*);
extern "C" void __llvm_profile_reset_counters(void);
namespace {
struct KartPadPgoDump {
    KartPadPgoDump() {
        std::thread([] {
            std::this_thread::sleep_for(std::chrono::seconds(75));
            __llvm_profile_reset_counters();
            std::this_thread::sleep_for(std::chrono::seconds(90));
            __llvm_profile_set_filename("/data/data/dev.kartpad.android/files/kp-pgo.profraw");
            __llvm_profile_write_file();
        }).detach();
    }
} g_kartPadPgoDump;
}

