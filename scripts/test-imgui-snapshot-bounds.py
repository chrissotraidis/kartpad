#!/usr/bin/env python3
"""Exercise the prepared render boundary with an attachment-validating backend.

The backend stub checks the maximum scissor extent used by ImGui's WGPU
backend. This does not replace an actual Dawn resize/recovery run.
"""
from pathlib import Path
import subprocess
import sys
import tempfile

source = (Path(sys.argv[1]) / "aurora-main/lib/imgui.cpp").read_text()
start = source.index("void render(const wgpu::RenderPassEncoder& pass")
end = source.index("\nImTextureID add_texture", start)
render = source[start:end]
# Also exercise the old implementation to demonstrate the failing invariant.
old_signature = "void render(const wgpu::RenderPassEncoder& pass) noexcept"
if old_signature in render:
    render = render.replace(old_signature, "void render(const wgpu::RenderPassEncoder& pass, uint32_t, uint32_t) noexcept")
code = r'''
#include <cassert>
#include <cstdint>
#define ZoneScoped
struct Vec { float x, y; };
struct DrawData { Vec DisplaySize, FramebufferScale; } data;
int draws = 0, invalid = 0, sdlDraws = 0;
uint32_t attachmentWidth, attachmentHeight;
bool g_useSdlRenderer = false;
namespace wgpu {
struct RenderPassEncoder {
  int Get() const { return 0; }
  void PushDebugGroup(const char*) const {}
  void PopDebugGroup() const {}
};
}
struct SDL_Renderer {};
namespace window { SDL_Renderer* get_sdl_renderer() { return nullptr; } }
namespace ImGui { DrawData* GetDrawData() { return &data; } }
void render_frame_data() {}
void SDL_RenderClear(SDL_Renderer*) {}
void SDL_RenderPresent(SDL_Renderer*) {}
void ImGui_ImplSDLRenderer3_RenderDrawData(DrawData*, SDL_Renderer*) { ++sdlDraws; }
void ImGui_ImplWGPU_RenderDrawData(DrawData* d, int) {
  const int width = static_cast<int>(d->DisplaySize.x * d->FramebufferScale.x);
  const int height = static_cast<int>(d->DisplaySize.y * d->FramebufferScale.y);
  if (width <= 0 || height <= 0) return;
  ++draws;
  if (width > static_cast<int>(attachmentWidth) || height > static_cast<int>(attachmentHeight)) ++invalid;
}
''' + render + r'''
void frame(float w, float h, float sx, float sy, uint32_t tw, uint32_t th, bool expected) {
  data = {{w, h}, {sx, sy}};
  attachmentWidth = tw; attachmentHeight = th;
  draws = invalid = 0;
  render({}, tw, th);
  assert(invalid == 0);
  assert(draws == int(expected));
  // The persistent draw data must remain reusable by later snapshots.
  assert(data.DisplaySize.x == w && data.DisplaySize.y == h);
  assert(data.FramebufferScale.x == sx && data.FramebufferScale.y == sy);
}
int main() {
  frame(2400, 1080, 1, 1, 2400, 1080, true);
  frame(2400, 1080, 1, 1, 720, 1280, false); // observed fatal
  frame(720, 1280, 1, 1, 720, 1280, true); // next new_frame recovers
  frame(720, 1280, 1, 1, 1280, 720, false); // rotation back
  frame(1280, 720, 1, 1, 1280, 720, true);
  frame(1280, 720, 1, 1, 2400, 1080, true); // smaller draw data is safe
  frame(1200, 540, 2, 2, 720, 1280, false); // Retina/high-DPI scale
  frame(360, 640, 2, 2, 720, 1280, true);
  frame(640, 360, 1.5f, 1.5f, 960, 540, true);
  frame(960, 540, 1, 1, 959, 540, false); // single pixel overflow
  frame(960, 540, 1, 1, 960, 539, false);
  frame(0, 0, 1, 1, 0, 0, false);
  g_useSdlRenderer = true;
  frame(2400, 1080, 1, 1, 720, 1280, false);
  assert(sdlDraws == 1); // SDL owns its separate target
}
'''
with tempfile.TemporaryDirectory() as directory:
    cpp = Path(directory) / "test.cpp"
    exe = Path(directory) / "test"
    cpp.write_text(code)
    subprocess.run(["clang++", "-std=c++20", "-Wall", "-Wextra", "-Werror",
                    "-fsanitize=address,undefined", str(cpp), "-o", str(exe)], check=True)
    subprocess.run([str(exe)], check=True)
print("PASS: prepared overlay resize/rotation/DPI bounds, recovery, replay and SDL path")
