"""Run the beta's production resize queue without SDL or a GPU."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "vendor/runtimes/android/aurora-wiicompiled/lib/window.cpp"


def block(source, signature):
    start = source.index(signature)
    opening = source.index("{", start)
    end, depth = opening + 1, 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start:end], source[opening + 1:end - 1]


class BetaResolutionTests(unittest.TestCase):
    def test_setting_resize_is_deferred_applied_and_coalesced(self):
        source = SOURCE.read_text()
        functions = "\n".join(block(source, signature)[0] for signature in (
            "void resize_swapchain() noexcept",
            "void apply_pending_surface_changes() noexcept",
            "void request_frame_buffer_resize()",
            "void set_frame_buffer_scale(float scale)",
        ))
        handler = block(source,
            "if (event.type == g_sdlCustomEventsStart + CustomEvent::FutureResize)")[1]
        code = r'''
#include <atomic>
#include <mutex>
#include <optional>
#include <vector>
#include <cassert>
#include <cstdint>
#define AURORA_ENABLE_GX
struct AuroraWindowSize {
    uint32_t width=640, height=480, fb_width=640, fb_height=480;
    uint32_t native_fb_width=640, native_fb_height=480;
    float scale=1;
    bool operator==(const AuroraWindowSize&) const = default;
};
struct AuroraEvent { int type; AuroraWindowSize windowSize; };
constexpr int AURORA_WINDOW_RESIZED=1, SDL_LOGICAL_PRESENTATION_DISABLED=0;
struct Logger { template<class... T> void info(T...) {} } Log;
int window;
void* g_window=&window;
void* g_renderer=nullptr;
float g_frameBufferScale=1;
std::atomic_bool g_nativeResizePending=false, g_pendingSurfaceRefresh=false;
std::mutex g_pendingSurfaceMutex;
std::optional<AuroraWindowSize> g_pendingSwapchainSize;
AuroraWindowSize g_windowSize;
std::vector<AuroraEvent> g_events;
int queued=0, resizes=0;
uint32_t actualWidth=640, actualHeight=480;
void update_refresh_period() {}
void SDL_SetRenderLogicalPresentation(void*, int, int, int) {}
void SDL_SetRenderScale(void*, float, float) {}
void push_future_resize_event() { ++queued; }
// SDL/native dimensions stay constant; only the requested render size changes.
AuroraWindowSize get_window_size() {
    auto size=g_windowSize;
    size.fb_width=uint32_t(640*g_frameBufferScale);
    size.fb_height=uint32_t(480*g_frameBufferScale);
    return size;
}
namespace webgpu {
void resize_swapchain(uint32_t w, uint32_t h, uint32_t nw, uint32_t nh) {
    assert(nw==640 && nh==480);
    ++resizes; actualWidth=w; actualHeight=h;
}
void refresh_surface(bool) {}
}
''' + functions + "\nvoid future_resize() {" + handler + r'''
}
int main() {
    set_frame_buffer_scale(2.f);
    assert(queued==1 && resizes==0);
    future_resize();
    assert(g_events.back().windowSize.fb_width==1280);
    assert(resizes==0); // SDL event handling must not recreate GPU resources.
    apply_pending_surface_changes();
    assert(actualWidth==1280 && actualHeight==960 && resizes==1);
    apply_pending_surface_changes();
    assert(resizes==1); // One request is applied only once.
    set_frame_buffer_scale(2.f);
    assert(queued==1); // An unchanged setting does not enqueue work.
    future_resize(); apply_pending_surface_changes();
    assert(resizes==1); // Duplicate wakeups do not recreate targets either.
    set_frame_buffer_scale(.5f); future_resize();
    set_frame_buffer_scale(1.5f); future_resize();
    assert(resizes==1);
    apply_pending_surface_changes();
    assert(actualWidth==960 && actualHeight==720 && resizes==2);
    // Multiple changes before frame begin use the latest size.
    for (float scale : {.5f, .75f, 1.f, 1.5f, 2.f, 3.f, 4.f}) {
        set_frame_buffer_scale(scale); future_resize();
        apply_pending_surface_changes();
        assert(actualWidth==uint32_t(640*scale));
        assert(actualHeight==uint32_t(480*scale));
    }
}
'''
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.cpp").write_text(code)
            build = subprocess.run([
                os.environ.get("CXX", "clang++"), "-std=c++20", "-Wall", "-Wextra",
                "-Werror", "-fsanitize=address,undefined", str(path / "test.cpp"),
                "-o", str(path / "test"),
            ], capture_output=True, text=True)
            self.assertEqual(build.returncode, 0, build.stderr)
            result = subprocess.run([str(path / "test")], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
