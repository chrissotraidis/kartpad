#include <aurora/render_size_limits.hpp>
#include <cassert>
#include <cmath>
#include <cstdio>

int main() {
    using namespace aurora::render_size_limits;
    // Exercise the renderer's actual sizing code at the new UI choices, including
    // fractional rounding and wide/portrait canvases used by Fill Screen.
    for (const float scale : {0.5f, 0.75f, 1.f, 1.5f, 2.f, 3.f, 4.f}) {
        const auto native = scale_framebuffer_to_aspect(640, 480, scale, 4.f / 3.f);
        assert(native.width == std::lround(640 * scale));
        assert(native.height == std::lround(480 * scale));
        for (const float aspect : {4.f / 3.f, 16.f / 9.f, 20.f / 9.f, 9.f / 20.f}) {
            const auto size = scale_framebuffer_to_aspect(640, 480, scale, aspect);
            assert(size.width > 0 && size.height > 0);
            const auto budget = fit_framebuffer_to_budget(size.width, size.height, 4096);
            assert(budget.width <= size.width && budget.height <= size.height);
            assert(budget.width <= 4096 && budget.height <= 4096);
            assert(std::abs(float(size.width) / size.height - clamp_dynamic_aspect(aspect)) < 0.01f);
        }
    }
    const auto halfWide = scale_framebuffer_to_aspect(640, 480, .5f, 16.f / 9.f);
    assert(halfWide.width == 427 && halfWide.height == 240);
    const auto threeQuarter = scale_framebuffer_to_aspect(640, 480, .75f, 16.f / 9.f);
    assert(threeQuarter.width == 640 && threeQuarter.height == 360);
    const auto tiny = scale_framebuffer_to_aspect(1, 1, .5f, 1.f);
    assert(tiny.width == 1 && tiny.height == 1);
    std::puts("PASS subnative framebuffer sizing and allocation bounds");
}
