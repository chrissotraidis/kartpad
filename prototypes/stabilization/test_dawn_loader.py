#!/usr/bin/env python3
"""Execute pinned/backported production loader methods with a controlled proc resolver.

This is a host test of Dawn's optional-extension failure handling, not Vulkan,
Android startup, GPU rendering, or a packaged KartPad build.
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import sys

if len(sys.argv) != 4:
    raise SystemExit("usage: test_dawn_loader.py BASELINE_SOURCE PATCHED_SOURCE OUTPUT_DIRECTORY")
ROOT = Path(sys.argv[3]).resolve()
ROOT.mkdir(parents=True, exist_ok=True)
SOURCES = {"before": Path(sys.argv[1]).resolve(), "backport": Path(sys.argv[2]).resolve()}
RESULTS = []

for variant in ("before", "backport"):
    source_path = SOURCES[variant] / "src/dawn/native/vulkan/VulkanFunctions.cpp"
    text = source_path.read_text()
    begin = text.index("#define GET_INSTANCE_PROC_NO_ERROR_BASE")
    end = text.index("#define GET_DEVICE_PROC", begin)
    methods = text[begin:end]
    procs = sorted(set(re.findall(r"GET_INSTANCE_PROC(?:_NO_ERROR)?\((\w+)\)", methods)) - {"name"})
    extensions = sorted(set(re.findall(r"InstanceExt::(\w+)", methods)) | {"DebugUtils"})
    debug_procs = [name for name in procs if "DebugUtils" in name]
    assert len(debug_procs) == 11
    preamble = r'''
#include <cassert>
#include <iostream>
#include <string>
#include <set>
using Fn = void(*)();
using VkInstance = void*;
static std::string missing;
static void present() {}
static Fn lookup(VkInstance, const char* name) {
    return missing == name ? nullptr : &present;
}
template<class F> F AsVkFn(Fn f) { return reinterpret_cast<F>(f); }
struct MaybeError { std::string message; bool ok() const { return message.empty(); } };
#define DAWN_INTERNAL_ERROR(x) MaybeError{x}
#define DAWN_ASSERT(x) assert(x)
#define DAWN_PLATFORM_IS(x) DAWN_PLATFORM_##x
#define DAWN_PLATFORM_ANDROID 1
#define DAWN_PLATFORM_WINDOWS 0
#define VK_API_VERSION_1_1 11
'''
    preamble += "enum class InstanceExt {" + ",".join(extensions) + "};\n"
    preamble += "struct VulkanGlobalInfo {int apiVersion=11; std::set<InstanceExt> extensions; bool HasExt(InstanceExt e) const {return extensions.count(e)!=0;}};\n"
    preamble += "\n".join(f"using PFN_vk{p} = Fn;" for p in procs)
    preamble += "\nstruct VulkanFunctions { Fn(*GetInstanceProcAddr)(VkInstance,const char*)=&lookup;\n"
    preamble += "\n".join(f"Fn {p}=nullptr;" for p in procs)
    preamble += "\nMaybeError LoadInstanceProcs(VkInstance,const VulkanGlobalInfo&);\n"
    if variant == "backport":
        preamble += "bool TryLoadEXTDebugUtils(VkInstance);\n"
    preamble += "};\n"
    test = r'''
int main() {
    VulkanGlobalInfo info;
    info.extensions.insert(InstanceExt::DebugUtils);
    info.extensions.insert(InstanceExt::Surface);
    info.extensions.insert(InstanceExt::AndroidSurface);
    VulkanFunctions funcs;
    assert(funcs.LoadInstanceProcs(nullptr, info).ok());
'''
    if variant == "backport":
        test += "assert(funcs.TryLoadEXTDebugUtils(nullptr));\n"
    test += "int cases=1;\n"
    for name in debug_procs:
        test += f'missing="vk{name}"; funcs=VulkanFunctions{{}};\n'
        if variant == "before":
            test += f'assert(funcs.LoadInstanceProcs(nullptr,info).message=="Couldn\'t get proc vk{name}");\n'
        else:
            test += "assert(funcs.LoadInstanceProcs(nullptr,info).ok());\n"
            test += "assert(!funcs.TryLoadEXTDebugUtils(nullptr));\n"
            test += "\n".join(f"assert(funcs.{p}==nullptr);" for p in debug_procs)
            test += "\nassert(funcs.CreateDevice!=nullptr); assert(funcs.CreateAndroidSurfaceKHR!=nullptr);\n"
        test += "++cases;\n"
    test += r'''
    missing="vkCreateDevice"; funcs=VulkanFunctions{};
    assert(!funcs.LoadInstanceProcs(nullptr,info).ok()); ++cases;
    missing="vkCreateAndroidSurfaceKHR"; funcs=VulkanFunctions{};
    assert(!funcs.LoadInstanceProcs(nullptr,info).ok()); ++cases;
    missing="vkCmdBeginDebugUtilsLabelEXT"; funcs=VulkanFunctions{};
    info.extensions.erase(InstanceExt::DebugUtils);
    assert(funcs.LoadInstanceProcs(nullptr,info).ok()); ++cases;
    std::cout << cases << " controlled loader cases passed\n";
}
'''
    cpp = ROOT / f"dawn-loader-{variant}.cpp"
    exe = ROOT / f"dawn-loader-{variant}"
    cpp.write_text(preamble + methods + test)
    command = ["/Library/Developer/CommandLineTools/usr/bin/clang++", "-isysroot", "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk", "-std=c++20", "-O2", "-Wall", "-Wextra", "-Werror", str(cpp), "-o", str(exe)]
    subprocess.run(command, check=True)
    output = subprocess.check_output([str(exe)], text=True).strip()
    RESULTS.append({"variant": variant, "production_source_sha256": hashlib.sha256(source_path.read_bytes()).hexdigest(), "result": output})
    print(variant + ": " + output)

(ROOT / "dawn-loader-results.json").write_text(json.dumps(RESULTS, indent=2) + "\n")
