"""Compile the actual SC override with bounded guest memory; no game data/network."""
from pathlib import Path
import os
import re
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]

HARNESS = r'''
#include <array>
#include <cstdint>
#include <cstring>
#include <stdexcept>
#include <string>
#include <iostream>
#if __has_include("sc_serial_contract.h")
#include "sc_serial_contract.h"
#endif
namespace RuntimeConsoleIdentity {
struct Identity { std::string serial; } identity;
const Identity& Current() { return identity; }
}
namespace Memory {
std::array<unsigned char, 32> bytes;
size_t available = 4;
bool Contains(uint32_t address, size_t size) { return address == 8 && size <= available; }
void* GetPointer(uint32_t address, size_t) { return bytes.data() + address; }
void Write32(uint32_t address, uint32_t value) {
    for (unsigned i = 0; i < 4; ++i) bytes[address+i] = value >> (24-8*i);
}
uint32_t Read32(uint32_t address) {
    uint32_t value = 0;
    for (unsigned i = 0; i < 4; ++i) value = (value << 8) | bytes[address+i];
    return value;
}
}
@OVERRIDE@
void require(bool value, const char* message) { if (!value) throw std::runtime_error(message); }
int main(int argc, char**) {
 try {
    if (argc > 1) {
        Memory::available = 10;
        for (const char* serial : {"788600001", "788699999"}) {
            RuntimeConsoleIdentity::identity.serial = serial;
            require(SCGetProductSN_HLE(8) == 1, "serial probe succeeds");
            std::cout << Memory::Read32(8) << '\n';
        }
        return 0;
    }
    // The old override reduces both 7886xxxxx values to ASCII "7886".
    require(0x37383836u == 926431286u, "reproduce old colliding csnum");
    for (const char* serial : {"788600001", "788699999", "761800001", "761899999",
                              "012345678", "000000001", "999999999"}) {
        RuntimeConsoleIdentity::identity.serial = serial;
        Memory::bytes.fill(0xa5);
        require(SCGetProductSN_HLE(8) == 1, "accept exactly four-byte output");
        require(Memory::Read32(8) == std::stoul(serial), "preserve full numeric serial in guest byte order");
        for (size_t i = 0; i < Memory::bytes.size(); ++i)
            if (i < 8 || i >= 12) require(Memory::bytes[i] == 0xa5, "preserve adjacent guest memory");
    }
    for (const char* serial : {"", "1234567890", "7886x1234", "-12345678", "+12345678"}) {
        RuntimeConsoleIdentity::identity.serial = serial;
        Memory::bytes.fill(0xa5);
        require(SCGetProductSN_HLE(8) == 0, "reject malformed serial");
        for (auto byte : Memory::bytes) require(byte == 0xa5, "invalid serial must not write");
    }
    RuntimeConsoleIdentity::identity.serial = "788600001";
    require(SCGetProductSN_HLE(0) == 0, "reject null output");
    Memory::available = 3;
    require(SCGetProductSN_HLE(8) == 0, "reject undersized output");
    for (auto byte : Memory::bytes) require(byte == 0xa5, "invalid address must not write");
    std::cout << "SC override: numeric serial, collision, byte order and memory boundary checks passed\n";
    return 0;
 } catch (const std::exception& error) { std::cerr << error.what() << '\n'; return 1; }
}
'''


class ScSerialTests(unittest.TestCase):
    def test_preparation_covers_all_platforms(self):
        for script in ('prepare-ios-game-runtime.sh', 'prepare-g7-game-runtime.sh'):
            self.assertIn('wiicompiled-sc-serial.patch', (REPO / 'scripts' / script).read_text())
        # Android's common preparation and tvOS both inherit the iOS patch stack.
        android = REPO / 'scripts/prepare-android-game-runtime.sh'
        if android.exists():
            self.assertIn('prepare-ios-game-runtime.sh', android.read_text())
        self.assertIn('prepare-ios-game-runtime.sh', (REPO / 'scripts/prepare-tvos-game-runtime.sh').read_text())

    def test_actual_override_before_and_after_backport(self):
        upstream = REPO / 'ref/upstream/Wiicompiled/runtime/src/hle/sc.cpp'
        if not upstream.exists():
            self.skipTest('pinned WiiCompiled reference required for compiled regression')
        with tempfile.TemporaryDirectory() as directory:
            stage = Path(directory)
            (stage / 'src/hle').mkdir(parents=True)
            shutil.copyfile(upstream, stage / 'src/hle/sc.cpp')

            def run_override():
                source = (stage / 'src/hle/sc.cpp').read_text()
                override = re.search(r'extern "C" uint32_t SCGetProductSN_HLE\(uint32_t serialAddress\)\n\{.*?\n\}', source, re.S)
                self.assertIsNotNone(override)
                (stage / 'test.cpp').write_text(HARNESS.replace('@OVERRIDE@', override.group()))
                subprocess.run([os.environ.get('CXX', 'c++'), '-std=c++17', '-Wall', '-Wextra', '-Werror',
                                '-fsanitize=address,undefined', '-I', str(stage / 'include'),
                                str(stage / 'test.cpp'), '-o', str(stage / 'test')], check=True, capture_output=True)
                return subprocess.run([str(stage / 'test')], capture_output=True, text=True)

            before = run_override()
            self.assertNotEqual(before.returncode, 0, 'old override must fail regression')
            self.assertIn('accept exactly four-byte output', before.stderr)
            legacy = subprocess.check_output([str(stage / 'test'), '--probe'], text=True)
            self.assertEqual(legacy.splitlines(), ['926431286', '926431286'])
            subprocess.run(['patch', '--batch', '--fuzz=0', '-p1', '-d', str(stage),
                            '-i', str(REPO / 'patches/wiicompiled-sc-serial.patch')], check=True, capture_output=True)
            after = run_override()
            self.assertEqual(after.returncode, 0, after.stdout + after.stderr)
            fixed = subprocess.check_output([str(stage / 'test'), '--probe'], text=True)
            self.assertEqual(fixed.splitlines(), ['788600001', '788699999'])


if __name__ == '__main__':
    unittest.main()
