from __future__ import annotations

import json
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]


class AndroidLocalWfcServerContractTests(unittest.TestCase):
    def test_fixture_is_pinned_isolated_and_disposable(self) -> None:
        script = (REPO / "scripts/test-android-local-wfc-server.sh").read_text()
        template = (
            REPO / "scripts/fixtures/android-local-wfc-config.xml.in"
        ).read_text()
        dependencies = json.loads(
            (REPO / "dependencies.lock.json").read_text()
        )["dependencies"]
        postgres = next(
            item
            for item in dependencies
            if item["name"] == "PostgreSQL local WFC fixture"
        )

        digest = "742f40ea20b9ff2ff31db5458d127452988a2164df9e17441e191f3b72252193"
        self.assertEqual(postgres["version"], "17-alpine")
        self.assertEqual(postgres["image"], f"postgres@sha256:{digest}")
        self.assertIn(f'postgres_image="postgres@sha256:{digest}"', script)
        self.assertIn("--tmpfs /var/lib/postgresql/data", script)
        self.assertIn("docker stop -t 5", script)
        self.assertIn('find "$temporary_root" -depth -delete', script)
        self.assertIn("CREATE ROLE wiilink NOLOGIN", script)
        self.assertIn("PostgreSQL init process complete; ready for start up.", script)
        self.assertIn("go test -vet=off ./...", script)
        self.assertIn("10.0.2.2 29980", script)
        self.assertIn("public_service_used=no", script)
        self.assertIn("<gsAddress>0.0.0.0</gsAddress>", template)
        self.assertIn("<nasAddress>0.0.0.0</nasAddress>", template)
        self.assertIn("<enableHttps>false</enableHttps>", template)
        self.assertIn("<enableHashCheck>false</enableHashCheck>", template)
        self.assertIn("127.0.0.1:@POSTGRES_PORT@", template)
        self.assertNotIn("play.rwfc.net", template)
        self.assertNotIn("wiimmfi", template.lower())


if __name__ == "__main__":
    unittest.main()
