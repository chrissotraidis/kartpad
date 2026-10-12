#include "logging.hpp"
#include <cstdio>
#include <cstdlib>
namespace aurora {
AuroraConfig g_config{};
void log_internal(AuroraLogLevel, const char* module, const char* message, unsigned int len) noexcept {
  std::fprintf(stderr, "[%s] %.*s\n", module, static_cast<int>(len), message);
}
void Module::show_fatal_dialog(const char*, std::string_view message) noexcept {
  std::fprintf(stderr, "fatal: %.*s\n", static_cast<int>(message.size()), message.data());
  std::abort();
}
}


