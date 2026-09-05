#include "android_tls_loopback_fixture.h"

#include <android/log.h>

#include <arpa/inet.h>
#include <fcntl.h>
#include <poll.h>
#include <sys/socket.h>
#include <unistd.h>

#include <array>
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iterator>
#include <string>
#include <vector>

#include <kartpad/network/android_mbedtls.h>

namespace {

using kartpad::network::AndroidMbedTlsSession;
using kartpad::network::AndroidTlsResult;

constexpr char kLogTag[] = "KartPadFixture";

constexpr std::int32_t Code(AndroidTlsResult result) {
  return static_cast<std::int32_t>(result);
}

std::string ReadText(const std::string& path) {
  std::ifstream input(path);
  return {std::istreambuf_iterator<char>(input),
          std::istreambuf_iterator<char>()};
}

std::vector<std::uint8_t> ReadBytes(const std::string& path) {
  std::ifstream input(path, std::ios::binary);
  return {std::istreambuf_iterator<char>(input),
          std::istreambuf_iterator<char>()};
}

bool WaitFor(int socket_fd, std::int32_t result) {
  const short events = result == Code(AndroidTlsResult::kReadAgain)
                           ? POLLIN
                           : (result == Code(AndroidTlsResult::kWriteAgain)
                                  ? POLLOUT
                                  : 0);
  if (events == 0) {
    return false;
  }
  pollfd descriptor{socket_fd, events, 0};
  return poll(&descriptor, 1, 1000) > 0;
}

}  // namespace

bool RunAndroidTlsLoopbackFixture() {
  const char* files_dir = std::getenv("KARTPAD_ANDROID_FILES_DIR");
  if (files_dir == nullptr || *files_dir == '\0') {
    return true;
  }
  const std::string root = std::string(files_dir) + "/KartPadTlsFixture";
  const std::string port_text = ReadText(root + "/port");
  if (port_text.empty()) {
    return true;
  }
  const int port = std::atoi(port_text.c_str());
  const std::string hostname = ReadText(root + "/hostname");
  const std::string expected_text = ReadText(root + "/expected");
  const std::vector<std::uint8_t> ca = ReadBytes(root + "/ca.der");
  if (port <= 0 || port > 65535 || hostname.empty() ||
      expected_text.empty() || ca.empty()) {
    __android_log_print(ANDROID_LOG_ERROR, kLogTag,
                        "A5 TLS loopback fixture invalid configuration");
    return false;
  }
  const std::int32_t expected = std::atoi(expected_text.c_str());

  const int socket_fd = socket(AF_INET, SOCK_STREAM, 0);
  sockaddr_in address{};
  address.sin_family = AF_INET;
  address.sin_port = htons(static_cast<std::uint16_t>(port));
  inet_pton(AF_INET, "10.0.2.2", &address.sin_addr);
  if (socket_fd < 0 ||
      connect(socket_fd, reinterpret_cast<const sockaddr*>(&address),
              sizeof(address)) != 0) {
    if (socket_fd >= 0) {
      close(socket_fd);
    }
    __android_log_print(ANDROID_LOG_ERROR, kLogTag,
                        "A5 TLS loopback fixture connect failed");
    return false;
  }
  const int flags = fcntl(socket_fd, F_GETFL, 0);
  if (flags < 0 || fcntl(socket_fd, F_SETFL, flags | O_NONBLOCK) != 0) {
    close(socket_fd);
    return false;
  }

  AndroidMbedTlsSession tls;
  if (tls.SetHostname(hostname) != 0 ||
      tls.SetRootCaDer(ca.data(), ca.size()) != 0 ||
      tls.AttachSocket(socket_fd) != 0) {
    close(socket_fd);
    return false;
  }
  std::int32_t result = Code(AndroidTlsResult::kFailed);
  for (int attempt = 0; attempt < 100; ++attempt) {
    result = tls.Handshake();
    if (result != Code(AndroidTlsResult::kReadAgain) &&
        result != Code(AndroidTlsResult::kWriteAgain)) {
      break;
    }
    if (!WaitFor(socket_fd, result)) {
      close(socket_fd);
      return false;
    }
  }
  if (result != expected) {
    __android_log_print(
        ANDROID_LOG_ERROR, kLogTag,
        "A5 TLS loopback fixture unexpected handshake=%d expected=%d native=%d",
        result, expected, tls.LastNativeError());
    close(socket_fd);
    return false;
  }
  if (expected != 0) {
    close(socket_fd);
    __android_log_print(
        ANDROID_LOG_INFO, kLogTag,
        "A5 TLS loopback hostname rejection passed result=%d", result);
    return true;
  }

  constexpr char request[] =
      "GET / HTTP/1.1\r\nHost: kartpad.test\r\nConnection: close\r\n\r\n";
  std::size_t written = 0;
  for (int attempt = 0; written < sizeof(request) - 1 && attempt < 100;
       ++attempt) {
    result = tls.Write(reinterpret_cast<const std::uint8_t*>(request) + written,
                       sizeof(request) - 1 - written);
    if (result > 0) {
      written += static_cast<std::size_t>(result);
    } else if (!WaitFor(socket_fd, result)) {
      close(socket_fd);
      return false;
    }
  }

  std::string response;
  std::array<std::uint8_t, 4096> buffer{};
  for (int attempt = 0; attempt < 100; ++attempt) {
    result = tls.Read(buffer.data(), buffer.size());
    if (result > 0) {
      response.append(reinterpret_cast<const char*>(buffer.data()), result);
      if (response.find("200 ok") != std::string::npos ||
          response.find("200 OK") != std::string::npos) {
        break;
      }
    } else if (result == Code(AndroidTlsResult::kClosed)) {
      break;
    } else if (!WaitFor(socket_fd, result)) {
      close(socket_fd);
      return false;
    }
  }
  tls.Close();
  close(socket_fd);
  if (response.find("200 ok") == std::string::npos &&
      response.find("200 OK") == std::string::npos) {
    return false;
  }
  __android_log_print(
      ANDROID_LOG_INFO, kLogTag,
      "A5 TLS loopback trusted handshake passed response_bytes=%zu",
      response.size());
  return true;
}
