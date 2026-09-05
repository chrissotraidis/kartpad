#pragma once

#include <cstddef>
#include <cstdint>
#include <memory>
#include <string_view>

namespace kartpad::network {

// Guest-visible /dev/net/ssl result values used by the Wii SSL service.
enum class AndroidTlsResult : std::int32_t {
  kSuccess = 0,
  kFailed = -1,
  kReadAgain = -2,
  kWriteAgain = -3,
  kSyscall = -5,
  kClosed = -6,
  kCommonName = -9,
  kRootCa = -10,
  kChain = -11,
  kDate = -12,
  kServerCertificate = -13,
};

class AndroidMbedTlsSession final {
 public:
  AndroidMbedTlsSession();
  ~AndroidMbedTlsSession();

  AndroidMbedTlsSession(const AndroidMbedTlsSession&) = delete;
  AndroidMbedTlsSession& operator=(const AndroidMbedTlsSession&) = delete;

  std::int32_t SetHostname(std::string_view hostname);
  std::int32_t SetRootCaDer(const std::uint8_t* data, std::size_t size);
  std::int32_t SetBuiltinRootCaFile(std::string_view path);
  std::int32_t AttachSocket(int native_socket);
  std::int32_t Handshake();
  std::int32_t Read(std::uint8_t* data, std::size_t size);
  std::int32_t Write(const std::uint8_t* data, std::size_t size);
  int LastNativeError() const;
  void Close();

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};

}  // namespace kartpad::network
