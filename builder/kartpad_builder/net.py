"""Downloads that ride out a dropped connection, and say plainly when they can't.

A server or network that drops one request ("Remote end closed connection
without response") used to stop a build with that bare message, which players
read as a problem with their game file or Git. Each download is now tried a few
times; if it still fails, the message names the server."""
from __future__ import annotations

import http.client
import socket
import time
import urllib.error
import urllib.parse
from typing import Callable, TypeVar

from .errors import BuildError

T = TypeVar("T")
ATTEMPTS = 4
# Seconds without any data before a request counts as stalled.
TIMEOUT = 60
TRANSIENT = (http.client.RemoteDisconnected, http.client.IncompleteRead, ConnectionError,
             TimeoutError, socket.timeout, urllib.error.URLError)


def _reason(error: BaseException) -> str:
    reason = getattr(error, "reason", None) or error
    return str(reason) or type(error).__name__


def problem(url: str, label: str, error: BaseException) -> str:
    host = urllib.parse.urlsplit(url).hostname or url
    return (f"Could not download {label} from {host} ({_reason(error)}). This is a network "
            f"problem, not a problem with your game file. Check your internet connection, and "
            f"whether a VPN, a firewall or an ad blocker blocks {host}, then run the build "
            "again; finished downloads are kept.")


def retrying(url: str, label: str, attempt: Callable[[], T]) -> T:
    """Run one complete download attempt, again after a dropped or stalled connection
    or a server error. A refused request (4xx) or a certificate failure is not retried.
    BuildError (a wrong size, hash or redirect) is never retried."""
    host = urllib.parse.urlsplit(url).hostname or url
    for number in range(1, ATTEMPTS + 1):
        try:
            return attempt()
        except urllib.error.HTTPError as error:
            if error.code < 500 or number == ATTEMPTS:
                raise BuildError(problem(url, label, error)) from error
            failure: BaseException = error
        except TRANSIENT as error:
            if "CERTIFICATE_VERIFY_FAILED" in str(error) or number == ATTEMPTS:
                raise BuildError(problem(url, label, error)) from error
            failure = error
        wait = 5 * number
        print(f"The connection to {host} dropped while downloading {label} ({_reason(failure)}). "
              f"Trying again in {wait} seconds ({number} of {ATTEMPTS - 1}).", flush=True)
        time.sleep(wait)
    raise AssertionError("unreachable")
