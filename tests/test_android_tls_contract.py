from __future__ import annotations

import json
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]


class AndroidTlsContractTests(unittest.TestCase):
    def test_android_apk_packages_mbed_tls_license(self) -> None:
        license_path = (
            REPO
            / "android/app/src/main/assets/ThirdPartyLicenses/Mbed-TLS.txt"
        )
        license_text = license_path.read_text(encoding="utf-8")
        self.assertIn("Apache License", license_text)
        self.assertIn("GNU GENERAL PUBLIC LICENSE", license_text)

    def test_mbedtls_release_is_hash_locked_and_prepared(self) -> None:
        dependencies = json.loads((REPO / "dependencies.lock.json").read_text())["dependencies"]
        dependency = next(item for item in dependencies if item["name"] == "Mbed TLS Android")
        self.assertEqual(dependency["version"], "4.1.1")
        self.assertEqual(dependency["bytes"], 7_099_934)
        self.assertEqual(
            dependency["sha256"],
            "3359a349e23db3d5536fcee032ae7b2ecbfc08972fab643089b5cbf2a375c98c",
        )
        prepare = (REPO / "scripts/prepare-android-dependencies.sh").read_text()
        self.assertIn('mbedtls_version="4.1.1"', prepare)
        self.assertIn('echo "MBEDTLS_ANDROID_ROOT=$mbedtls_root"', prepare)

    def test_source_fixture_requires_entropy_and_peer_verification(self) -> None:
        fixture = (REPO / "android/app/src/main/cpp/android_tls_fixture.cpp").read_text()
        main = (REPO / "android/app/src/main/cpp/fixture_main.cpp").read_text()
        cmake = (REPO / "android/app/src/main/cpp/CMakeLists.txt").read_text()
        self.assertIn("psa_crypto_init()", fixture)
        self.assertIn("psa_generate_random", fixture)
        self.assertIn("MBEDTLS_SSL_VERIFY_REQUIRED", fixture)
        self.assertIn('mbedtls_ssl_set_hostname(&ssl, "kartpad.invalid")', fixture)
        self.assertIn("RunAndroidTlsFixture()", main)
        self.assertIn("mbedtls android log dl", cmake)

    def test_guest_tls_backend_is_patched_into_android_product(self) -> None:
        header = (
            REPO / "runtime/include/kartpad/network/android_mbedtls.h"
        ).read_text()
        source = (
            REPO / "runtime/src/hle/net/android_mbedtls.cpp"
        ).read_text()
        patch = (
            REPO / "patches/wiicompiled-android-network-tls.patch"
        ).read_text()
        prepare = (REPO / "scripts/prepare-android-game-runtime.sh").read_text()
        cmake = (REPO / "android/app/src/main/cpp/CMakeLists.txt").read_text()

        self.assertIn("class AndroidMbedTlsSession final", header)
        self.assertIn("MBEDTLS_SSL_VERIFY_REQUIRED", source)
        self.assertIn("mbedtls_x509_crt_parse_der", source)
        self.assertIn("SetBuiltinRootCaFile", source)
        self.assertIn("kWiiBuiltinRootCaSha256", source)
        self.assertIn("kMaximumCertificateBytes", source)
        self.assertIn("psa_hash_compute(PSA_ALG_SHA_256", source)
        self.assertIn("mbedtls_ssl_set_hostname", source)
        self.assertIn("AndroidMbedTlsSession", patch)
        self.assertIn("SetRootCaDer", patch)
        self.assertIn("SetBuiltinRootCaFile", patch)
        self.assertIn("AttachSocket", patch)
        self.assertIn("wiicompiled-android-network-tls.patch", prepare)
        self.assertIn('runtime/src/hle/net/android_mbedtls.cpp"', cmake)
        self.assertIn("MINIZIP::minizip mbedtls", cmake)

    def test_guest_ioctlv_fixture_exercises_the_product_handler(self) -> None:
        fixture_patch = (
            REPO / "patches/wiicompiled-android-tls-ioctlv-fixture.patch"
        ).read_text()
        prepare = (REPO / "scripts/prepare-android-game-runtime.sh").read_text()

        self.assertIn("wiicompiled-android-tls-ioctlv-fixture.patch", prepare)
        self.assertIn("RunAndroidTlsIoctlvFixture()", fixture_patch)
        self.assertIn("std::memcpy(saved.data(), scratch, saved.size())", fixture_patch)
        self.assertIn("std::memcpy(scratch, saved.data(), saved.size())", fixture_patch)
        self.assertIn('root + "/port"', fixture_patch)
        self.assertIn('root + "/recovery_port"', fixture_patch)
        self.assertIn("static thread_local bool useRecoveryPort", fixture_patch)
        self.assertIn("same-process recovery passed", fixture_patch)
        self.assertIn("terminalRead != SSL_ERR_ZERO", fixture_patch)
        self.assertIn("peer_close=%d", fixture_patch)
        self.assertIn("IOCTLV_NET_SSL_SETBUILTINROOTCA", fixture_patch)
        self.assertIn("missing built-in root rejection passed", fixture_patch)
        for command in (
            "IOCTLV_NET_SSL_NEW",
            "IOCTLV_NET_SSL_SETROOTCA",
            "IOCTLV_NET_SSL_CONNECT",
            "IOCTLV_NET_SSL_DOHANDSHAKE",
            "IOCTLV_NET_SSL_WRITE",
            "IOCTLV_NET_SSL_READ",
            "IOCTLV_NET_SSL_SHUTDOWN",
        ):
            self.assertIn(f"HandleSslIoctlv({command}", fixture_patch)

    def test_product_ioctlv_emulator_runner_preserves_private_state(self) -> None:
        runner = (
            REPO / "scripts/test-android-tls-ioctlv-emulator.sh"
        ).read_text()

        self.assertIn("mktemp -d", runner)
        self.assertIn("trap cleanup EXIT", runner)
        self.assertIn('install -r "$apk"', runner)
        self.assertNotIn("pm clear", runner)
        self.assertIn("files/KartPad/GameData/sys/main.dol", runner)
        self.assertIn("KartPadTlsIoctlvFixture", runner)
        self.assertIn("files/KartPad/NAND/rootca.pem", runner)
        self.assertIn('"$fixture_root/ca.der"', runner)
        self.assertNotIn('"$fixture_root/ca.key"', runner)
        self.assertNotIn('"$fixture_root/server.key"', runner)
        self.assertIn("SO_LINGER", runner)
        self.assertIn('listener.bind(("0.0.0.0", 0))', runner)
        self.assertIn("interrupt_port_file", runner)
        self.assertIn("time.sleep(0.5)", runner)
        self.assertIn("A5 guest TLS IOCTLV fixture handshake=", runner)
        self.assertIn("before_size", runner)
        self.assertIn("tail -c", runner)
        self.assertIn("same_process_handshake_recovered=yes", runner)
        self.assertIn(".KartPadLaunchActivity", runner)

    def test_guest_dns_ioctl_fixture_uses_product_deferred_path(self) -> None:
        fixture_patch = (
            REPO / "patches/wiicompiled-android-dns-ioctl-fixture.patch"
        ).read_text()
        prepare = (REPO / "scripts/prepare-android-game-runtime.sh").read_text()
        runner = (
            REPO / "scripts/test-android-dns-ioctl-emulator.sh"
        ).read_text()

        self.assertIn("wiicompiled-android-dns-ioctl-fixture.patch", prepare)
        self.assertIn("StartScalarDeferredIoctl", fixture_patch)
        self.assertIn("IOCTL_SO_GETHOSTBYNAME", fixture_patch)
        self.assertIn("ApplyDeferredDnsCompletion", fixture_patch)
        self.assertIn("AndroidFixtureRoute", fixture_patch)
        self.assertIn("TakeAndroidFixtureCompletion", fixture_patch)
        self.assertIn("CancelAndroidFixtureCompletion", fixture_patch)
        self.assertNotIn("getaddrinfo(", fixture_patch)
        self.assertIn("request_marshaled=yes", fixture_patch)
        self.assertIn("worker_resolved=yes", fixture_patch)
        self.assertIn("guest_hostent=yes", fixture_patch)
        self.assertIn("KartPadDnsIoctlFixture", runner)
        self.assertIn("localhost", runner)
        self.assertIn("127.0.0.1", runner)
        self.assertIn("before_size", runner)
        self.assertNotIn("pm clear", runner)

    def test_tls_fixtures_use_only_ephemeral_private_keys(self) -> None:
        script = (REPO / "scripts/test-android-tls-local.sh").read_text()
        emulator_script = (
            REPO / "scripts/test-android-tls-emulator.sh"
        ).read_text()
        loopback = (
            REPO / "android/app/src/main/cpp/android_tls_loopback_fixture.cpp"
        ).read_text()
        main = (REPO / "android/app/src/main/cpp/fixture_main.cpp").read_text()
        private_key_marker = "BEGIN " + "PRIVATE" + " KEY"

        self.assertIn("mktemp -d", script)
        self.assertIn("trap cleanup EXIT", script)
        self.assertIn('rm -rf "$temporary_root"', script)
        self.assertNotIn(private_key_marker, script)
        self.assertIn("mktemp -d", emulator_script)
        self.assertIn("trap cleanup EXIT", emulator_script)
        self.assertNotIn(private_key_marker, emulator_script)
        self.assertIn('"10.0.2.2"', loopback)
        self.assertIn("RunAndroidTlsLoopbackFixture()", main)


if __name__ == "__main__":
    unittest.main()
