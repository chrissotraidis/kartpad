#include "android_tls_fixture.h"

#include <android/log.h>

#include <algorithm>
#include <array>

#include <mbedtls/build_info.h>
#include <mbedtls/ssl.h>
#include <psa/crypto.h>

namespace {

constexpr char kLogTag[] = "KartPadFixture";

}  // namespace

bool RunAndroidTlsFixture() {
  mbedtls_ssl_config config;
  mbedtls_ssl_context ssl;
  mbedtls_ssl_config_init(&config);
  mbedtls_ssl_init(&ssl);

  std::array<unsigned char, 32> sample{};
  const psa_status_t cryptoResult = psa_crypto_init();
  int result = cryptoResult == PSA_SUCCESS ? 0 : static_cast<int>(cryptoResult);
  if (result == 0 &&
      psa_generate_random(sample.data(), sample.size()) != PSA_SUCCESS) {
    result = -1;
  }
  if (result == 0) {
    result = mbedtls_ssl_config_defaults(
        &config, MBEDTLS_SSL_IS_CLIENT, MBEDTLS_SSL_TRANSPORT_STREAM,
        MBEDTLS_SSL_PRESET_DEFAULT);
  }
  if (result == 0) {
    mbedtls_ssl_conf_authmode(&config, MBEDTLS_SSL_VERIFY_REQUIRED);
    result = mbedtls_ssl_setup(&ssl, &config);
  }
  if (result == 0) {
    result = mbedtls_ssl_set_hostname(&ssl, "kartpad.invalid");
  }
  const bool entropyVaries = std::any_of(
      sample.begin(), sample.end(),
      [first = sample.front()](unsigned char value) { return value != first; });
  const bool passed = result == 0 && entropyVaries;
  if (passed) {
    __android_log_print(
        ANDROID_LOG_INFO, kLogTag,
        "A5 native TLS primitive passed version=%s entropy_bytes=%zu verify=required",
        MBEDTLS_VERSION_STRING_FULL, sample.size());
  } else {
    __android_log_print(
        ANDROID_LOG_ERROR, kLogTag,
        "A5 native TLS primitive failed result=%d entropy_varies=%s", result,
        entropyVaries ? "true" : "false");
  }

  mbedtls_ssl_free(&ssl);
  mbedtls_ssl_config_free(&config);
  return passed;
}
