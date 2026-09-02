from __future__ import annotations

import subprocess
import unittest
from pathlib import Path

from kartpad_builder.profiles import ProfileError, load_profiles, select_profile


REPO = Path(__file__).resolve().parents[1]
PROFILES = REPO / "builder/profiles"
PROFILE_ID = "mkwii-rmcp01-rev0"
PREPARE_DISC = REPO / "scripts/prepare-disc.sh"
WBFS_SHA256 = "fc035e60610842da6860d23d4a30c1f1c0f019d492469deb8a2ac25ef5822331"
ISO_SHA256 = "2fc548bad45f373bad953d410a32e042e7efeef86a90f9ff63ddc5b62f9e6971"


class RMCP01PrivateInputContractTests(unittest.TestCase):
    def test_verified_wbfs_and_iso_hashes_are_accepted(self) -> None:
        profiles = load_profiles(PROFILES)
        for digest in (WBFS_SHA256, ISO_SHA256):
            with self.subTest(digest=digest):
                self.assertEqual(
                    select_profile(profiles, digest, PROFILE_ID).id,
                    PROFILE_ID,
                )

        accepted = {
            image["sha256"]: image
            for image in select_profile(profiles, ISO_SHA256, PROFILE_ID).accepted_images
        }
        self.assertEqual(accepted[ISO_SHA256]["format"], "iso")
        self.assertIn("lossless", accepted[ISO_SHA256]["note"].lower())
        self.assertIn("decrypted", accepted[ISO_SHA256]["note"].lower())

    def test_unknown_hash_is_rejected(self) -> None:
        with self.assertRaisesRegex(ProfileError, "does not match profile"):
            select_profile(load_profiles(PROFILES), "0" * 64, PROFILE_ID)

    def test_prepare_disc_uses_profile_without_duplicate_image_hashes(self) -> None:
        source = PREPARE_DISC.read_text()
        self.assertIn("builder/profiles/mkwii-rmcp01-rev0.json", source)
        self.assertIn("load_profiles", source)
        self.assertIn("select_profile", source)
        self.assertNotIn("expected_image_sha256", source)
        self.assertNotIn(WBFS_SHA256, source)
        self.assertNotIn(ISO_SHA256, source)
        self.assertIn('"${image_sha256}"', source)
        self.assertIn('"imageSHA256": "%s"', source)

    def test_prepare_disc_has_valid_bash_syntax(self) -> None:
        subprocess.run(["bash", "-n", PREPARE_DISC], check=True)


if __name__ == "__main__":
    unittest.main()
