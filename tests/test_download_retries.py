"""A dropped connection is retried; a lasting one names the server (Discord report, Linux,
KartPad 0.8.3: bare "ERROR: Remote end closed connection without response")."""
import hashlib
import http.client
import io
import ssl
import sys
import tempfile
import unittest
import urllib.error
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "builder"))
from kartpad_builder import net, retro_rewind, runtime_stage  # noqa: E402
from kartpad_builder.errors import BuildError  # noqa: E402

URL = "https://cdn.update.rwfc.net/RetroRewind/zip/6.13.3-full.zip"
DATA = b"synthetic pinned pack"


def response(body=DATA, url=URL):
    stream = io.BytesIO(body)
    stream.geturl = lambda: url
    return stream


class DownloadRetryTests(unittest.TestCase):
    def download(self, outcomes):
        with tempfile.TemporaryDirectory() as temp, \
                mock.patch("urllib.request.urlopen", side_effect=outcomes) as opened, \
                mock.patch("time.sleep") as slept, mock.patch("builtins.print"):
            output = Path(temp) / "pack.zip"
            try:
                retro_rewind._download(URL, output, len(DATA), hashlib.sha256(DATA).hexdigest())
                return output.read_bytes(), opened.call_count, slept.call_count, list(Path(temp).iterdir())
            finally:
                self.leftovers = list(Path(temp).iterdir())

    def test_a_dropped_connection_is_tried_again(self):
        dropped = http.client.RemoteDisconnected("Remote end closed connection without response")
        body, opened, slept, files = self.download([dropped, ConnectionResetError(), response()])
        self.assertEqual((body, opened, slept), (DATA, 3, 2))
        self.assertEqual([path.name for path in files], ["pack.zip"])

    def test_a_lasting_failure_names_the_server(self):
        dropped = http.client.RemoteDisconnected("Remote end closed connection without response")
        with self.assertRaisesRegex(BuildError, r"Retro Rewind from cdn\.update\.rwfc\.net .*network problem"):
            self.download([dropped] * net.ATTEMPTS)
        self.assertEqual(self.leftovers, [])

    def test_a_refused_request_or_a_wrong_file_is_not_retried(self):
        missing = urllib.error.HTTPError(URL, 404, "Not Found", {}, None)
        with self.assertRaisesRegex(BuildError, "404|Not Found"):
            self.download([missing, response()])
        with self.assertRaisesRegex(BuildError, "identity does not match"):
            self.download([response(b"x" * len(DATA)), response()])

    def test_certificate_failure_explains_recovery_without_retrying(self):
        certificate = ssl.SSLCertVerificationError(1, "unable to get local issuer certificate")
        failures = (certificate, urllib.error.URLError(certificate),
                    urllib.error.URLError("[SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed"))
        for failure in failures:
            with self.subTest(failure=failure), \
                    mock.patch("time.sleep") as slept, mock.patch("builtins.print"):
                attempt = mock.Mock(side_effect=failure)
                with self.assertRaises(BuildError) as raised:
                    net.retrying(runtime_stage.SSE2NEON_URL, "sse2neon.h", attempt)
                message = str(raised.exception)
                self.assertIn("sse2neon.h from raw.githubusercontent.com", message)
                self.assertIn("PadMint.command", message)
                self.assertIn("Install Certificates.command", message)
                self.assertIn("Keep certificate verification enabled", message)
                self.assertNotIn("firewall or an ad blocker", message)
                attempt.assert_called_once_with()
                slept.assert_not_called()

    def test_runtime_stage_prints_actionable_error_without_a_traceback(self):
        failure = BuildError("Python could not verify the server's HTTPS certificate")
        with mock.patch.object(sys, "argv", ["runtime_stage", "extras", "/unused"]), \
                mock.patch.object(runtime_stage, "stage_extras", side_effect=failure), \
                mock.patch("sys.stderr", new_callable=io.StringIO) as stderr:
            self.assertEqual(runtime_stage.main(), 1)
        self.assertEqual(stderr.getvalue(), f"ERROR: {failure}\n")


if __name__ == "__main__":
    unittest.main()
