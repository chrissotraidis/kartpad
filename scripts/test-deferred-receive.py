#!/usr/bin/env python3
"""Exercise the deferred blocking-receive park/probe/complete/expire path.

Extracts the receive functions and the receive pump loop from a runtime's
network_deferred.cpp, compiles them against small guest-memory stubs, and drives
them with real loopback TCP sockets.
"""
import argparse
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("runtime", type=Path)
args = parser.parse_args()
repo = Path(__file__).resolve().parents[1]
source = (args.runtime / "src/hle/net/network_deferred.cpp").read_text()


def between(start, end, include_end=False):
    begin = source.index(start)
    stop = source.index(end, begin)
    return source[begin:stop + (len(end) if include_end else 0)]


work_struct = between("struct DeferredReceiveWork {", "\n};", include_end=True)
prepare = between("static bool ReceiveIsReady(", "NetworkDeferredContract::StartOutcome Network_HLE_StartIoctlSync(")
complete = between("static int32_t CompleteDeferredReceive(", "bool Network_HLE_ProcessCompletions(")
pump_loop = between("    for (auto it = store.pendingReceives.begin();", "    return handledAny;\n}")

prefix = r'''
#include <kartpad/network/blocking_stream_wait.h>
#include <hle/network_deferred_contract.h>
#include <hle/network_poll_contract.h>
#include <arpa/inet.h>
#include <array>
#include <cassert>
#include <cerrno>
#include <chrono>
#include <climits>
#include <cstdarg>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <fcntl.h>
#include <optional>
#include <poll.h>
#include <stdexcept>
#include <string_view>
#include <sys/socket.h>
#include <unistd.h>
#include <vector>

using NativeSocket = int;
constexpr NativeSocket kInvalidSocket = -1;
constexpr uint64_t kMaxIoVectors = 32;
enum { SO_EAGAIN = 6, SO_EINVAL = 28, SO_ENOTCONN = 56 };
struct IoVector { uint32_t address = 0; uint32_t size = 0; };
struct CpuContext {};

namespace Memory {
constexpr uint32_t kBase = 0x80000000u;
std::array<uint8_t, 0x10000> ram{};
struct AccessViolation : std::runtime_error {
  AccessViolation() : std::runtime_error("fault") {}
  std::string_view reason() const { return "fault"; }
};
bool Contains(uint32_t address, size_t size) {
  return address >= kBase && size <= ram.size() && address - kBase <= ram.size() - size;
}
uint8_t* GetPointer(uint32_t address, uint32_t size) {
  return Contains(address, size) ? ram.data() + (address - kBase) : nullptr;
}
uint32_t Read32(uint32_t address) {
  if (!Contains(address, 4)) throw AccessViolation();
  const uint8_t* p = GetPointer(address, 4);
  return uint32_t(p[0]) << 24 | uint32_t(p[1]) << 16 | uint32_t(p[2]) << 8 | p[3];
}
void Write32(uint32_t address, uint32_t value) {
  uint8_t* p = GetPointer(address, 4);
  p[0] = value >> 24; p[1] = value >> 16; p[2] = value >> 8; p[3] = value;
}
}  // namespace Memory

std::vector<IoVector> ReadVectors(uint32_t pointer, uint32_t count) {
  std::vector<IoVector> vectors(count);
  for (uint32_t i = 0; i < count; ++i) {
    vectors[i] = {Memory::Read32(pointer + i * 8), Memory::Read32(pointer + i * 8 + 4)};
  }
  return vectors;
}

struct WiiSocket {
  NativeSocket native = kInvalidSocket;
  int type = SOCK_STREAM;
  bool nonblocking = false;
  uint64_t generation = 0;
  int32_t lastLoggedRecvError = 0;
};
std::array<WiiSocket, 24> g_sockets;
WiiSocket* GetWiiSocket(uint32_t fd) {
  return fd < g_sockets.size() && g_sockets[fd].native != kInvalidSocket ? &g_sockets[fd] : nullptr;
}
bool SocketIdentityIsCurrent(uint32_t fd, NativeSocket native, uint64_t generation) {
  return fd < g_sockets.size() && g_sockets[fd].native != kInvalidSocket &&
         g_sockets[fd].native == native && g_sockets[fd].generation == generation;
}
void TraceWfcTcp(const char*, uint32_t, WiiSocket*, const char*, int, int) {}
int NativeLastError() { return errno; }
int32_t SocketResult(int ret) { return ret; }
int32_t SocketErrorResult(int error) { return error == EAGAIN ? -SO_EAGAIN : -1000 - error; }
int failures = 0;
void NetFail(const char*, ...) { ++failures; }

enum class DeferredNetworkCompletionKind { SyncWaitQueue, AsyncCallback, AndroidFixture };
struct DeferredNetworkRoute {
  DeferredNetworkCompletionKind kind = DeferredNetworkCompletionKind::SyncWaitQueue;
  uint64_t token = 0;
  uint32_t waitQueue = 0;
  uint32_t expectedThread = 0;
  uint32_t callback = 0;
  uint32_t callbackArg = 0;
};
using DeferredStartOutcome = NetworkDeferredContract::StartOutcome;
'''

middle = r'''
struct Store { std::vector<DeferredReceiveWork> pendingReceives; };
Store storeInstance;
Store& GetDeferredNetworkStore() { return storeInstance; }
bool waiterValid = true;
struct Delivery { uint64_t token; int32_t result; };
std::vector<Delivery> deliveries;
bool DeferredNetworkWaiterIsValid(const DeferredNetworkRoute&) { return waiterValid; }
void DeliverDeferredNetworkResult(CpuContext*, Store&, const DeferredNetworkRoute& route, int32_t result) {
  deliveries.push_back({route.token, result});
}
'''

suffix = r'''
bool Pump() {
  CpuContext context;
  CpuContext* cpu = &context;
  Store& store = GetDeferredNetworkStore();
  const auto now = NetworkPollContract::Timeout::Clock::now();
  bool handledAny = false;
''' + pump_loop + r'''
  return handledAny;
}

constexpr uint32_t kVectors = Memory::kBase + 0x100;
constexpr uint32_t kControl = Memory::kBase + 0x200;
constexpr uint32_t kData = Memory::kBase + 0x300;
constexpr uint32_t kFrom = Memory::kBase + 0x400;
uint64_t nextToken = 1;
bool routeOk = true;
auto Route() {
  return [](DeferredNetworkRoute& route) {
    if (!routeOk) return false;
    route.token = nextToken++;
    return true;
  };
}

DeferredStartOutcome Submit(uint32_t fd, uint32_t flags, uint32_t fromSize = 0) {
  Memory::Write32(kControl, fd);
  Memory::Write32(kControl + 4, flags);
  Memory::Write32(kVectors, kControl); Memory::Write32(kVectors + 4, 8);
  Memory::Write32(kVectors + 8, kData); Memory::Write32(kVectors + 12, 64);
  Memory::Write32(kVectors + 16, fromSize ? kFrom : 0); Memory::Write32(kVectors + 20, fromSize);
  return StartDeferredReceive(1, 2, kVectors, Route());
}

struct Pair { int client, server; };
Pair Connect() {
  int listener = ::socket(AF_INET, SOCK_STREAM, 0);
  sockaddr_in address{}; address.sin_family = AF_INET;
  address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  assert(::bind(listener, reinterpret_cast<sockaddr*>(&address), sizeof(address)) == 0);
  socklen_t length = sizeof(address);
  assert(::getsockname(listener, reinterpret_cast<sockaddr*>(&address), &length) == 0);
  assert(::listen(listener, 1) == 0);
  int client = ::socket(AF_INET, SOCK_STREAM, 0);
  assert(::connect(client, reinterpret_cast<sockaddr*>(&address), sizeof(address)) == 0);
  int server = ::accept(listener, nullptr, nullptr);
  ::close(listener);
  // Host sockets stay nonblocking even when the Wii socket is logically blocking.
  assert(::fcntl(client, F_SETFL, O_NONBLOCK) == 0);
  return {client, server};
}

void Install(uint32_t fd, int native, uint64_t generation) {
  g_sockets[fd] = WiiSocket{native, SOCK_STREAM, false, generation, 0};
}

double PumpMilliseconds() {
  const auto start = std::chrono::steady_clock::now();
  Pump();
  return std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - start).count();
}

using Disposition = NetworkDeferredContract::StartDisposition;

int main() {
  Pair pair = Connect();
  Install(3, pair.client, 7);

  // Nothing readable on a blocking stream: parked, and the pump never waits.
  DeferredStartOutcome started = Submit(3, 0);
  assert(started.disposition == Disposition::Started && started.token != 0);
  assert(PumpMilliseconds() < 50.0 && deliveries.empty());
  assert(storeInstance.pendingReceives.size() == 1);

  // Data arrives: the next pump performs the receive into guest memory.
  assert(::send(pair.server, "hello", 5, 0) == 5);
  for (int i = 0; i < 100 && deliveries.empty(); ++i) { Pump(); usleep(1000); }
  assert(deliveries.size() == 1 && deliveries[0].token == started.token && deliveries[0].result == 5);
  assert(std::memcmp(Memory::GetPointer(kData, 5), "hello", 5) == 0);
  assert(storeInstance.pendingReceives.empty());
  deliveries.clear();

  // Readable at submission, nonblocking, forced nonblocking, source address,
  // datagram and unknown fd all stay on the direct handler.
  assert(::send(pair.server, "x", 1, 0) == 1);
  usleep(10000);
  assert(Submit(3, 0).disposition == Disposition::NotApplicable);
  char drain[8]; assert(::recv(pair.client, drain, sizeof(drain), 0) == 1);
  g_sockets[3].nonblocking = true;
  assert(Submit(3, 0).disposition == Disposition::NotApplicable);
  g_sockets[3].nonblocking = false;
  assert(Submit(3, 0x04).disposition == Disposition::NotApplicable);
  assert(Submit(3, 0, 8).disposition == Disposition::NotApplicable);
  g_sockets[3].type = SOCK_DGRAM;
  assert(Submit(3, 0).disposition == Disposition::NotApplicable);
  g_sockets[3].type = SOCK_STREAM;
  assert(Submit(9, 0).disposition == Disposition::NotApplicable);
  routeOk = false;
  assert(Submit(3, 0).disposition == Disposition::NotApplicable);
  routeOk = true;
  assert(storeInstance.pendingReceives.empty());

  // A short source-address vector (< 8 bytes) is ignored by the direct handler too.
  assert(Submit(3, 0, 4).disposition == Disposition::Started);
  storeInstance.pendingReceives.clear();

  // Deadline: the receive runs once and reports the direct handler's would-block result.
  started = Submit(3, 0);
  assert(started.disposition == Disposition::Started);
  storeInstance.pendingReceives[0].timeout = NetworkPollContract::Timeout::FromMilliseconds(0);
  Pump();
  assert(deliveries.size() == 1 && deliveries[0].result == -SO_EAGAIN);
  deliveries.clear();

  // Data present at the deadline still wins.
  started = Submit(3, 0);
  assert(::send(pair.server, "late", 4, 0) == 4);
  usleep(10000);
  storeInstance.pendingReceives[0].timeout = NetworkPollContract::Timeout::FromMilliseconds(0);
  Pump();
  assert(deliveries.size() == 1 && deliveries[0].result == 4);
  deliveries.clear();

  // The default deadline is the direct handler's five seconds.
  started = Submit(3, 0);
  const auto remaining = storeInstance.pendingReceives[0].timeout.Deadline() -
                         NetworkPollContract::Timeout::Clock::now();
  assert(remaining > std::chrono::milliseconds(4900) && remaining <= std::chrono::milliseconds(5000));

  // Closing the Wii socket (slot reused with a new generation) fails the parked receive.
  g_sockets[3].generation = 8;
  Pump();
  assert(deliveries.size() == 1 && deliveries[0].result == -SO_ENOTCONN);
  deliveries.clear();
  g_sockets[3].generation = 7;

  // A cancelled synchronous waiter is dropped without a delivery.
  started = Submit(3, 0);
  waiterValid = false;
  Pump();
  assert(deliveries.empty() && storeInstance.pendingReceives.empty());
  waiterValid = true;

  // Peer close makes the socket readable and reports end of stream.
  started = Submit(3, 0);
  ::close(pair.server);
  for (int i = 0; i < 100 && deliveries.empty(); ++i) { Pump(); usleep(1000); }
  assert(deliveries.size() == 1 && deliveries[0].result == 0);
  ::close(pair.client);
  std::puts("ok");
}
'''

with tempfile.TemporaryDirectory(prefix="kartpad-deferred-recv-") as temp:
    path = Path(temp)
    cpp = path / "deferred_receive.cpp"
    cpp.write_text(prefix + work_struct + "\n" + middle + prepare + complete + suffix)
    binary = path / "deferred_receive"
    subprocess.run(["clang++", "-std=c++20", "-Wall", "-Wextra", "-Werror", "-Wno-unused-function",
                    "-I", str(repo / "runtime/include"), "-I", str(args.runtime / "include"),
                    str(cpp), "-o", str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
print("PASS: deferred receive park/probe/complete/expire/close/cancel over loopback TCP")

