#include <kartpad/network/android_mbedtls.h>

#include <algorithm>
#include <array>
#include <cerrno>
#include <climits>
#include <cstring>
#include <fstream>
#include <string>
#include <vector>

#include <sys/socket.h>
#include <unistd.h>

#include <mbedtls/net_sockets.h>
#include <mbedtls/ssl.h>
#include <mbedtls/x509.h>
#include <mbedtls/x509_crt.h>
#include <psa/crypto.h>

namespace kartpad::network {
namespace {

constexpr std::int32_t Code(AndroidTlsResult result) {
  return static_cast<std::int32_t>(result);
}

constexpr std::array<std::uint8_t, 32> kWiiBuiltinRootCaSha256 = {
    0xc5, 0xb0, 0xf8, 0xdf, 0xce, 0xc6, 0xb9, 0xed,
    0x2a, 0xc3, 0x8b, 0x8b, 0xc6, 0x9a, 0x4d, 0xb7,
    0xc2, 0x09, 0xdc, 0x17, 0x7d, 0x24, 0x3c, 0x8d,
    0xf2, 0xbd, 0xdf, 0x9e, 0x39, 0x17, 0x1e, 0x5f,
};

int SocketSend(void* context, const unsigned char* data, std::size_t size) {
  const int socket = *static_cast<const int*>(context);
  const std::size_t bounded = std::min<std::size_t>(size, INT_MAX);
  for (;;) {
#ifdef MSG_NOSIGNAL
    constexpr int flags = MSG_NOSIGNAL;
#else
    constexpr int flags = 0;
#endif
    const ssize_t result = send(socket, data, bounded, flags);
    if (result >= 0) {
      return static_cast<int>(result);
    }
    if (errno == EINTR) {
      continue;
    }
    if (errno == EAGAIN || errno == EWOULDBLOCK) {
      return MBEDTLS_ERR_SSL_WANT_WRITE;
    }
    return MBEDTLS_ERR_NET_SEND_FAILED;
  }
}

int SocketReceive(void* context, unsigned char* data, std::size_t size) {
  const int socket = *static_cast<const int*>(context);
  const std::size_t bounded = std::min<std::size_t>(size, INT_MAX);
  for (;;) {
    const ssize_t result = recv(socket, data, bounded, 0);
    if (result > 0) {
      return static_cast<int>(result);
    }
    if (result == 0) {
      return MBEDTLS_ERR_SSL_CONN_EOF;
    }
    if (errno == EINTR) {
      continue;
    }
    if (errno == EAGAIN || errno == EWOULDBLOCK) {
      return MBEDTLS_ERR_SSL_WANT_READ;
    }
    return MBEDTLS_ERR_NET_RECV_FAILED;
  }
}

}  // namespace

struct AndroidMbedTlsSession::Impl {
  mbedtls_ssl_context ssl{};
  mbedtls_ssl_config config{};
  mbedtls_x509_crt roots{};
  std::string hostname;
  int socket = -1;
  bool config_ready = false;
  bool ssl_ready = false;
  bool handshaked = false;
  int last_native_error = 0;

  Impl() {
    mbedtls_ssl_init(&ssl);
    mbedtls_ssl_config_init(&config);
    mbedtls_x509_crt_init(&roots);
    if (psa_crypto_init() == PSA_SUCCESS &&
        mbedtls_ssl_config_defaults(
            &config, MBEDTLS_SSL_IS_CLIENT, MBEDTLS_SSL_TRANSPORT_STREAM,
            MBEDTLS_SSL_PRESET_DEFAULT) == 0) {
      mbedtls_ssl_conf_authmode(&config, MBEDTLS_SSL_VERIFY_REQUIRED);
      config_ready = true;
    }
  }

  ~Impl() {
    if (ssl_ready) {
      (void)mbedtls_ssl_close_notify(&ssl);
    }
    mbedtls_ssl_free(&ssl);
    mbedtls_ssl_config_free(&config);
    mbedtls_x509_crt_free(&roots);
  }

  std::int32_t Classify(int result, bool writing) const {
    if (result >= 0) {
      return result;
    }
    if (result == MBEDTLS_ERR_SSL_WANT_READ ||
        result == MBEDTLS_ERR_SSL_RECEIVED_NEW_SESSION_TICKET) {
      return Code(AndroidTlsResult::kReadAgain);
    }
    if (result == MBEDTLS_ERR_SSL_WANT_WRITE) {
      return Code(AndroidTlsResult::kWriteAgain);
    }
    if (result == MBEDTLS_ERR_SSL_PEER_CLOSE_NOTIFY ||
        result == MBEDTLS_ERR_SSL_CONN_EOF) {
      return Code(AndroidTlsResult::kClosed);
    }
    if (result == MBEDTLS_ERR_NET_SEND_FAILED ||
        result == MBEDTLS_ERR_NET_RECV_FAILED) {
      return Code(AndroidTlsResult::kSyscall);
    }

    const std::uint32_t verify = mbedtls_ssl_get_verify_result(&ssl);
    if ((verify & MBEDTLS_X509_BADCERT_CN_MISMATCH) != 0) {
      return Code(AndroidTlsResult::kCommonName);
    }
    if ((verify & (MBEDTLS_X509_BADCERT_EXPIRED |
                   MBEDTLS_X509_BADCERT_FUTURE)) != 0) {
      return Code(AndroidTlsResult::kDate);
    }
    if ((verify & MBEDTLS_X509_BADCERT_NOT_TRUSTED) != 0) {
      return Code(AndroidTlsResult::kRootCa);
    }
    if (verify != 0) {
      return Code(AndroidTlsResult::kChain);
    }
    (void)writing;
    return Code(AndroidTlsResult::kFailed);
  }
};

AndroidMbedTlsSession::AndroidMbedTlsSession()
    : impl_(std::make_unique<Impl>()) {}

AndroidMbedTlsSession::~AndroidMbedTlsSession() = default;

std::int32_t AndroidMbedTlsSession::SetHostname(std::string_view hostname) {
  if (!impl_->config_ready || impl_->ssl_ready || hostname.empty() ||
      hostname.find('\0') != std::string_view::npos) {
    return Code(AndroidTlsResult::kFailed);
  }
  impl_->hostname.assign(hostname);
  return Code(AndroidTlsResult::kSuccess);
}

std::int32_t AndroidMbedTlsSession::SetRootCaDer(const std::uint8_t* data,
                                                 std::size_t size) {
  if (!impl_->config_ready || impl_->ssl_ready || data == nullptr || size == 0) {
    return Code(AndroidTlsResult::kFailed);
  }
  mbedtls_x509_crt_free(&impl_->roots);
  mbedtls_x509_crt_init(&impl_->roots);
  const int result = mbedtls_x509_crt_parse_der(&impl_->roots, data, size);
  if (result != 0) {
    return Code(AndroidTlsResult::kServerCertificate);
  }
  mbedtls_ssl_conf_ca_chain(&impl_->config, &impl_->roots, nullptr);
  return Code(AndroidTlsResult::kSuccess);
}

std::int32_t AndroidMbedTlsSession::SetBuiltinRootCaFile(
    std::string_view path) {
  if (!impl_->config_ready || impl_->ssl_ready || path.empty() ||
      path.find('\0') != std::string_view::npos) {
    return Code(AndroidTlsResult::kFailed);
  }
  std::ifstream input(std::string(path), std::ios::binary);
  input.seekg(0, std::ios::end);
  const std::streamoff file_size = input.tellg();
  constexpr std::streamoff kMaximumCertificateBytes = 64 * 1024;
  if (file_size <= 0 || file_size > kMaximumCertificateBytes) {
    return Code(AndroidTlsResult::kFailed);
  }
  input.seekg(0, std::ios::beg);
  std::vector<std::uint8_t> certificate(static_cast<std::size_t>(file_size));
  input.read(reinterpret_cast<char*>(certificate.data()),
             static_cast<std::streamsize>(certificate.size()));
  if (!input) {
    return Code(AndroidTlsResult::kFailed);
  }
  std::array<std::uint8_t, 32> digest{};
  std::size_t digest_size = 0;
  if (psa_hash_compute(PSA_ALG_SHA_256, certificate.data(), certificate.size(),
                       digest.data(), digest.size(), &digest_size) != PSA_SUCCESS ||
      digest_size != digest.size()) {
    return Code(AndroidTlsResult::kFailed);
  }
  std::uint8_t difference = 0;
  for (std::size_t index = 0; index < digest.size(); ++index) {
    difference |= digest[index] ^ kWiiBuiltinRootCaSha256[index];
  }
  if (difference != 0) {
    return Code(AndroidTlsResult::kFailed);
  }

  mbedtls_x509_crt_free(&impl_->roots);
  mbedtls_x509_crt_init(&impl_->roots);
  if (mbedtls_x509_crt_parse(&impl_->roots, certificate.data(),
                             certificate.size()) != 0) {
    return Code(AndroidTlsResult::kServerCertificate);
  }
  mbedtls_ssl_conf_ca_chain(&impl_->config, &impl_->roots, nullptr);
  return Code(AndroidTlsResult::kSuccess);
}

std::int32_t AndroidMbedTlsSession::AttachSocket(int native_socket) {
  if (!impl_->config_ready || impl_->ssl_ready || native_socket < 0 ||
      impl_->hostname.empty()) {
    return Code(AndroidTlsResult::kFailed);
  }
  const int setup = mbedtls_ssl_setup(&impl_->ssl, &impl_->config);
  if (setup != 0) {
    return impl_->Classify(setup, false);
  }
  impl_->ssl_ready = true;
  const int hostname = mbedtls_ssl_set_hostname(&impl_->ssl,
                                                impl_->hostname.c_str());
  if (hostname != 0) {
    return impl_->Classify(hostname, false);
  }
  impl_->socket = native_socket;
  mbedtls_ssl_set_bio(&impl_->ssl, &impl_->socket, SocketSend, SocketReceive,
                      nullptr);
  return Code(AndroidTlsResult::kSuccess);
}

std::int32_t AndroidMbedTlsSession::Handshake() {
  if (!impl_->ssl_ready) {
    return Code(AndroidTlsResult::kFailed);
  }
  if (impl_->handshaked) {
    return Code(AndroidTlsResult::kSuccess);
  }
  const int result = mbedtls_ssl_handshake(&impl_->ssl);
  impl_->last_native_error = result;
  if (result == 0) {
    impl_->handshaked = true;
    return Code(AndroidTlsResult::kSuccess);
  }
  return impl_->Classify(result, false);
}

std::int32_t AndroidMbedTlsSession::Read(std::uint8_t* data, std::size_t size) {
  if (!impl_->ssl_ready || data == nullptr || size == 0) {
    return Code(AndroidTlsResult::kClosed);
  }
  const int result = mbedtls_ssl_read(
      &impl_->ssl, data, std::min<std::size_t>(size, INT_MAX));
  impl_->last_native_error = result;
  return impl_->Classify(result, false);
}

std::int32_t AndroidMbedTlsSession::Write(const std::uint8_t* data,
                                          std::size_t size) {
  if (!impl_->ssl_ready || data == nullptr || size == 0) {
    return Code(AndroidTlsResult::kClosed);
  }
  const int result = mbedtls_ssl_write(
      &impl_->ssl, data, std::min<std::size_t>(size, INT_MAX));
  impl_->last_native_error = result;
  return impl_->Classify(result, true);
}

int AndroidMbedTlsSession::LastNativeError() const {
  return impl_->last_native_error;
}

void AndroidMbedTlsSession::Close() {
  if (impl_->ssl_ready) {
    (void)mbedtls_ssl_close_notify(&impl_->ssl);
    impl_->ssl_ready = false;
  }
}

}  // namespace kartpad::network
