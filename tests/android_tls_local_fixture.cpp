#include <kartpad/network/android_mbedtls.h>

#include <arpa/inet.h>
#include <fcntl.h>
#include <poll.h>
#include <sys/socket.h>
#include <unistd.h>

#include <cerrno>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iterator>
#include <string>
#include <vector>

namespace {

using kartpad::network::AndroidMbedTlsSession;
using kartpad::network::AndroidTlsResult;

constexpr std::int32_t Code(AndroidTlsResult result) {
  return static_cast<std::int32_t>(result);
}

bool WaitFor(int socket, std::int32_t result) {
  short events = 0;
  if (result == Code(AndroidTlsResult::kReadAgain)) {
    events = POLLIN;
  } else if (result == Code(AndroidTlsResult::kWriteAgain)) {
    events = POLLOUT;
  } else {
    return false;
  }
  pollfd descriptor{socket, events, 0};
  return poll(&descriptor, 1, 1000) > 0;
}

std::vector<std::uint8_t> ReadFile(const char* path) {
  std::ifstream input(path, std::ios::binary);
  return {std::istreambuf_iterator<char>(input),
          std::istreambuf_iterator<char>()};
}

}  // namespace

int main(int argc, char** argv) {
  if (argc != 5) {
    std::fprintf(stderr, "usage: fixture PORT CA_DER HOST EXPECTED_RESULT\n");
    return 64;
  }
  const int port = std::atoi(argv[1]);
  const std::vector<std::uint8_t> root = ReadFile(argv[2]);
  const std::string hostname = argv[3];
  const std::int32_t expected = std::atoi(argv[4]);
  if (port <= 0 || port > 65535 || root.empty() || hostname.empty()) {
    return 65;
  }

  const int socket_fd = socket(AF_INET, SOCK_STREAM, 0);
  if (socket_fd < 0) {
    return 66;
  }
  sockaddr_in address{};
  address.sin_family = AF_INET;
  address.sin_port = htons(static_cast<std::uint16_t>(port));
  address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  if (connect(socket_fd, reinterpret_cast<const sockaddr*>(&address),
              sizeof(address)) != 0) {
    close(socket_fd);
    return 67;
  }
  const int flags = fcntl(socket_fd, F_GETFL, 0);
  if (flags < 0 || fcntl(socket_fd, F_SETFL, flags | O_NONBLOCK) != 0) {
    close(socket_fd);
    return 68;
  }

  AndroidMbedTlsSession tls;
  if (tls.SetHostname(hostname) != 0 ||
      tls.SetBuiltinRootCaFile(argv[2]) != Code(AndroidTlsResult::kFailed) ||
      tls.SetRootCaDer(root.data(), root.size()) != 0 ||
      tls.AttachSocket(socket_fd) != 0) {
    close(socket_fd);
    return 69;
  }

  std::int32_t handshake = Code(AndroidTlsResult::kFailed);
  for (int attempt = 0; attempt < 100; ++attempt) {
    handshake = tls.Handshake();
    if (handshake != Code(AndroidTlsResult::kReadAgain) &&
        handshake != Code(AndroidTlsResult::kWriteAgain)) {
      break;
    }
    if (!WaitFor(socket_fd, handshake)) {
      close(socket_fd);
      return 70;
    }
  }
  if (handshake != expected) {
    std::fprintf(stderr, "unexpected handshake result: %d expected %d\n",
                 handshake, expected);
    close(socket_fd);
    return 71;
  }
  if (expected != 0) {
    close(socket_fd);
    std::printf("PASS hostname rejection result=%d\n", handshake);
    return 0;
  }

  const std::string request =
      "GET / HTTP/1.1\r\nHost: kartpad.test\r\nConnection: close\r\n\r\n";
  std::size_t written = 0;
  for (int attempt = 0; written < request.size() && attempt < 100; ++attempt) {
    const std::int32_t result = tls.Write(
        reinterpret_cast<const std::uint8_t*>(request.data() + written),
        request.size() - written);
    if (result > 0) {
      written += static_cast<std::size_t>(result);
    } else if (!WaitFor(socket_fd, result)) {
      close(socket_fd);
      return 72;
    }
  }

  std::string response;
  std::uint8_t buffer[4096]{};
  for (int attempt = 0; attempt < 100; ++attempt) {
    const std::int32_t result = tls.Read(buffer, sizeof(buffer));
    if (result > 0) {
      response.append(reinterpret_cast<const char*>(buffer), result);
      if (response.find("200 ok") != std::string::npos ||
          response.find("200 OK") != std::string::npos) {
        break;
      }
    } else if (result == Code(AndroidTlsResult::kClosed)) {
      break;
    } else if (!WaitFor(socket_fd, result)) {
      std::fprintf(stderr,
                   "TLS read failed result=%d native=%d response_bytes=%zu\n",
                   result, tls.LastNativeError(), response.size());
      close(socket_fd);
      return 73;
    }
  }
  tls.Close();
  close(socket_fd);
  if (response.find("200 ok") == std::string::npos &&
      response.find("200 OK") == std::string::npos) {
    return 74;
  }
  std::printf("PASS trusted handshake and encrypted HTTP bytes=%zu\n",
              response.size());
  return 0;
}
