#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
prepare_output="$("$repo_root/scripts/prepare-android-dependencies.sh")"
mbedtls_root="$(printf '%s\n' "$prepare_output" |
  sed -n 's/^MBEDTLS_ANDROID_ROOT=//p')"
[[ -n "$mbedtls_root" ]] || {
  echo "ERROR: dependency preparation did not report Mbed TLS" >&2
  exit 1
}

host_build="$repo_root/build/mbedtls-host-tls-fixture"
cmake -S "$mbedtls_root" -B "$host_build" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DENABLE_PROGRAMS=OFF \
  -DENABLE_TESTING=OFF \
  -DUSE_SHARED_MBEDTLS_LIBRARY=OFF \
  -DUSE_STATIC_MBEDTLS_LIBRARY=ON >/dev/null
cmake --build "$host_build" --target mbedtls -j 2 >/dev/null

cxx="${CXX:-clang++}"
fixture="$host_build/kartpad-android-tls-local-fixture"
"$cxx" -std=c++20 -Wall -Wextra -Werror \
  -I"$repo_root/runtime/include" \
  -I"$mbedtls_root/include" \
  -I"$mbedtls_root/tf-psa-crypto/include" \
  -I"$mbedtls_root/tf-psa-crypto/drivers/builtin/include" \
  "$repo_root/runtime/src/hle/net/android_mbedtls.cpp" \
  "$repo_root/tests/android_tls_local_fixture.cpp" \
  "$host_build/library/libmbedtls.a" \
  "$host_build/library/libmbedx509.a" \
  "$host_build/tf-psa-crypto/core/libtfpsacrypto.a" \
  -o "$fixture"

temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/kartpad-tls.XXXXXX")"
server_pid=""
cleanup() {
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" >/dev/null 2>&1 || true
    wait "$server_pid" 2>/dev/null || true
  fi
  rm -rf "$temporary_root"
}
trap cleanup EXIT

openssl req -x509 -newkey rsa:2048 -nodes -days 1 \
  -keyout "$temporary_root/ca.key" -out "$temporary_root/ca.pem" \
  -subj /CN=KartPad-Test-CA >/dev/null 2>&1
openssl req -newkey rsa:2048 -nodes \
  -keyout "$temporary_root/server.key" -out "$temporary_root/server.csr" \
  -subj /CN=kartpad.test -addext subjectAltName=DNS:kartpad.test \
  >/dev/null 2>&1
openssl x509 -req -days 1 -set_serial 1 \
  -in "$temporary_root/server.csr" \
  -CA "$temporary_root/ca.pem" -CAkey "$temporary_root/ca.key" \
  -copy_extensions copy -out "$temporary_root/server.pem" >/dev/null 2>&1
openssl x509 -in "$temporary_root/ca.pem" -outform DER \
  -out "$temporary_root/ca.der"

port="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')"
openssl s_server -accept "127.0.0.1:$port" \
  -cert "$temporary_root/server.pem" -key "$temporary_root/server.key" \
  -www -quiet >"$temporary_root/server.log" 2>&1 &
server_pid="$!"
for _ in {1..50}; do
  if kill -0 "$server_pid" 2>/dev/null; then
    break
  fi
  sleep 0.05
done
kill -0 "$server_pid" 2>/dev/null || {
  echo "ERROR: local TLS server did not start" >&2
  exit 1
}

"$fixture" "$port" "$temporary_root/ca.der" kartpad.test 0
"$fixture" "$port" "$temporary_root/ca.der" wrong.kartpad.test -9
echo "Android Mbed TLS local fixture passed."
