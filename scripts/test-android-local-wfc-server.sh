#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
server_source="$repo_root/ref/upstream/wfc-server"
config_template="$repo_root/scripts/fixtures/android-local-wfc-config.xml.in"
postgres_image="postgres@sha256:742f40ea20b9ff2ff31db5458d127452988a2164df9e17441e191f3b72252193"
expected_server_commit="fbd30fa41a35fe8a407e3a49bc83fe4ff91fd35b"
sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
adb="${KARTPAD_ADB:-$sdk_root/platform-tools/adb}"
container_name="kartpad-local-wfc-postgres-$$"
temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/kartpad-android-local-wfc.XXXXXX")"
server_pid=""
hold_fixture="${KARTPAD_LOCAL_WFC_HOLD:-0}"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

# Invoked through the EXIT trap below.
# shellcheck disable=SC2329
cleanup() {
  if [[ -n "$server_pid" ]] && kill -0 "$server_pid" >/dev/null 2>&1; then
    kill -INT "$server_pid" >/dev/null 2>&1 || true
    for _ in {1..100}; do
      kill -0 "$server_pid" >/dev/null 2>&1 || break
      sleep 0.1
    done
    if kill -0 "$server_pid" >/dev/null 2>&1; then
      kill -TERM "$server_pid" >/dev/null 2>&1 || true
    fi
    wait "$server_pid" 2>/dev/null || true
  fi
  docker stop -t 5 "$container_name" >/dev/null 2>&1 || true
  find "$temporary_root" -depth -delete >/dev/null 2>&1 || true
}
trap cleanup EXIT

command -v docker >/dev/null || fail "Docker is unavailable"
command -v go >/dev/null || fail "Go is unavailable"
command -v curl >/dev/null || fail "curl is unavailable"
command -v nc >/dev/null || fail "netcat is unavailable"
command -v lsof >/dev/null || fail "lsof is unavailable"
[[ -x "$adb" ]] || fail "adb is unavailable at $adb"
[[ -f "$config_template" ]] || fail "local WFC config template is unavailable"
[[ "$hold_fixture" == 0 || "$hold_fixture" == 1 ]] ||
  fail "KARTPAD_LOCAL_WFC_HOLD must be 0 or 1"
[[ "$(git -C "$server_source" rev-parse HEAD)" == "$expected_server_commit" ]] ||
  fail "pinned local WFC server commit changed"
[[ -z "$(git -C "$server_source" status --porcelain)" ]] ||
  fail "pinned local WFC server checkout is dirty"
docker info >/dev/null 2>&1 || fail "Docker Desktop is not running"

for required_port in 27900 27901 28910 29900 29901 29920 29980 29998 29999; do
  if lsof -nP -iTCP:"$required_port" -sTCP:LISTEN >/dev/null 2>&1 ||
      lsof -nP -iUDP:"$required_port" >/dev/null 2>&1; then
    fail "local WFC port $required_port is already in use"
  fi
done

devices="$($adb devices -l)"
ready_count="$(printf '%s\n' "$devices" |
  awk 'NR > 1 && $2 == "device" { count++ } END { print count + 0 }')"
[[ "$ready_count" == 1 ]] || fail "expected exactly one ready Android target"
serial="$(printf '%s\n' "$devices" |
  awk 'NR > 1 && $2 == "device" { print $1; exit }')"
adb_target=("$adb" -s "$serial")
[[ "$("${adb_target[@]}" shell getprop ro.kernel.qemu | tr -d '\r')" == 1 ]] ||
  fail "the connected target is not an Android emulator"

if ! docker image inspect "$postgres_image" >/dev/null 2>&1; then
  docker pull "$postgres_image" >/dev/null
fi
docker run --rm -d --name "$container_name" \
  --tmpfs /var/lib/postgresql/data:rw,noexec,nosuid,size=512m \
  -e POSTGRES_USER=kartpad \
  -e POSTGRES_PASSWORD=kartpad-local-only \
  -e POSTGRES_DB=wwfc \
  -p 127.0.0.1::5432 "$postgres_image" >/dev/null

for _ in {1..120}; do
  if docker logs "$container_name" 2>&1 |
      grep -Fq "PostgreSQL init process complete; ready for start up." &&
      docker exec "$container_name" pg_isready -U kartpad -d wwfc \
        >/dev/null 2>&1; then
    break
  fi
  sleep 0.25
done
docker exec "$container_name" pg_isready -U kartpad -d wwfc >/dev/null ||
  fail "disposable PostgreSQL did not become ready"
database_port="$(docker port "$container_name" 5432/tcp | sed -n 's/^127\.0\.0\.1://p')"
[[ "$database_port" =~ ^[0-9]+$ ]] || fail "Docker did not publish a database port"

docker exec "$container_name" psql -v ON_ERROR_STOP=1 -U kartpad -d wwfc \
  -c "CREATE ROLE wiilink NOLOGIN;" >/dev/null
docker exec -i "$container_name" psql -v ON_ERROR_STOP=1 -U kartpad -d wwfc \
  < "$server_source/schema.sql" >/dev/null
table_count="$(docker exec "$container_name" psql -At -U kartpad -d wwfc \
  -c "select count(*) from information_schema.tables where table_schema='public';")"
[[ "$table_count" == 4 ]] || fail "pinned WFC schema did not create four tables"

(cd "$server_source" && go test -vet=off ./... >/dev/null)
(cd "$server_source" && go build -trimpath \
  -ldflags "-X main.version=kartpad-local-$expected_server_commit" \
  -o "$temporary_root/wwfc" .)
install -m 600 "$server_source/game_list.tsv" "$temporary_root/game_list.tsv"
install -m 600 /dev/null "$temporary_root/profanity.txt"
sed "s/@POSTGRES_PORT@/$database_port/g" "$config_template" \
  > "$temporary_root/config.xml"

(cd "$temporary_root" && exec ./wwfc) >"$temporary_root/server.log" 2>&1 &
server_pid="$!"
for _ in {1..200}; do
  kill -0 "$server_pid" >/dev/null 2>&1 ||
    fail "local WFC server exited during startup"
  all_tcp_ready=1
  for required_port in 28910 29900 29901 29920 29980 29998 29999; do
    if ! nc -z 127.0.0.1 "$required_port" >/dev/null 2>&1; then
      all_tcp_ready=0
      break
    fi
  done
  if [[ "$all_tcp_ready" == 1 ]] &&
      lsof -nP -iUDP:27900 >/dev/null 2>&1 &&
      lsof -nP -iUDP:27901 >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done

grep -Fq "Connected to backend" "$temporary_root/server.log" ||
  fail "local WFC frontend did not connect to its backend"
for required_port in 28910 29900 29901 29920 29980 29998 29999; do
  nc -z 127.0.0.1 "$required_port" >/dev/null 2>&1 ||
    fail "local WFC TCP port $required_port is not listening"
done
lsof -nP -iUDP:27900 >/dev/null 2>&1 || fail "QR2 UDP is not listening"
lsof -nP -iUDP:27901 >/dev/null 2>&1 || fail "NATNEG UDP is not listening"

host_headers="$temporary_root/host-headers"
host_body="$temporary_root/host-body"
curl --silent --show-error --max-time 5 \
  -D "$host_headers" -o "$host_body" \
  -H "Host: naswii.nintendowifi.net" "http://127.0.0.1:29980/"
grep -Fq "Server: Nintendo" "$host_headers" ||
  fail "host NAS response did not identify the pinned server"
grep -Fq "KartPad Local WFC" "$host_body" ||
  fail "host NAS response did not use the isolated server name"

emulator_response="$("${adb_target[@]}" shell \
  "printf 'GET / HTTP/1.1\r\nHost: naswii.nintendowifi.net\r\nConnection: close\r\n\r\n' | nc -w 5 10.0.2.2 29980" | tr -d '\r')"
grep -Fq "Server: Nintendo" <<<"$emulator_response" ||
  fail "Android emulator could not reach the local NAS server"
grep -Fq "KartPad Local WFC" <<<"$emulator_response" ||
  fail "Android emulator reached an unexpected NAS server"

server_sha256="$(shasum -a 256 "$temporary_root/wwfc" | awk '{ print $1 }')"
echo "Android local WFC server boundary passed: server_commit=$expected_server_commit postgres_digest=${postgres_image#postgres@} server_sha256=$server_sha256 schema_tables=$table_count emulator_nas_reachable=yes public_service_used=no"

if [[ "$hold_fixture" == 1 ]]; then
  echo "Android local WFC server ready for translated guest traffic: host=10.0.2.2 nas_port=29980 public_service_used=no"
  guest_request_reported=0
  while kill -0 "$server_pid" >/dev/null 2>&1; do
    if [[ "$guest_request_reported" == 0 ]] &&
        grep -Fq "Command:" "$temporary_root/server.log" &&
        grep -Fq "AVAILABLE" "$temporary_root/server.log" &&
        grep -Fq "/payload?g=RMCPD00" "$temporary_root/server.log"; then
      echo "Android translated Retro guest reached local WFC: qr2_available=yes nas_payload_request=yes public_service_used=no"
      guest_request_reported=1
    fi
    sleep 0.5
  done
  fail "local WFC server exited while held for translated guest traffic"
fi
