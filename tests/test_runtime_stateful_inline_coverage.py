"""Every stateful FP helper the translator can emit must exist in every runtime.

Retro Rewind 6.13.3 was the first translated code to call PpcFmaddStateInline,
which the runtimes had never defined, so its game pack failed to compile.
"""

import re
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
TRANSLATOR = REPO / "vendor/wiicompiled/translator/src/Translator.Core/CodeGen/CxxLinearCodeGenerator.Inlines.cs"
PLATFORMS = ("android", "ios", "macos", "tvos")
# Emittable but not yet implemented in the runtimes, and unused by current
# translations (they need EvaluatePpcSqrt / an RN-aware fctiw). Remove an entry
# when its helper is added.
KNOWN_MISSING = {"PpcFsqrtStateInline", "PpcFsqrtsStateInline", "PpcFctiwStateInline"}


class RuntimeStatefulInlineCoverageTests(unittest.TestCase):
    def test_runtimes_define_every_emittable_stateful_helper(self) -> None:
        if not TRANSLATOR.is_file():
            self.skipTest("translator submodule is not initialized")
        emitted = set(re.findall(r"\"(Ppc\w+StateInline)\"", TRANSLATOR.read_text()))
        self.assertIn("PpcFmaddStateInline", emitted)
        for platform in PLATFORMS:
            header = REPO / f"vendor/runtimes/{platform}/runtime/include/ppc_runtime.h"
            if not header.is_file():
                self.skipTest(f"{platform} runtime submodule is not initialized")
            defined = set(re.findall(r"^inline \w+ (Ppc\w+StateInline)\(", header.read_text(), re.M))
            with self.subTest(platform=platform):
                self.assertEqual(emitted - defined, KNOWN_MISSING)


if __name__ == "__main__":
    unittest.main()

