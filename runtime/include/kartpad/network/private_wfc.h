#pragma once

#include <algorithm>
#include <cctype>
#include <cstdint>
#include <cstdlib>
#include <string>
#include <string_view>

namespace KartPad::Network {

// Set only before the runtime starts. UI edits are persisted for next launch.
inline constexpr char kPrivateWfcHostEnvironment[] = "KARTPAD_PRIVATE_WFC_HOST";

// The public services' own names (#520). Routing their game services to one
// of these names sends every service to a single host and breaks login, and
// Retro Rewind already reaches Retro WFC without this setting.
inline bool IsPublicWfcDomain(std::string_view host) {
    std::string lowered(host);
    std::transform(lowered.begin(), lowered.end(), lowered.begin(),
                   [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    if (!lowered.empty() && lowered.back() == '.') lowered.pop_back();
    for (const std::string_view domain : {"nintendowifi.net", "rwfc.net"}) {
        if (lowered == domain) return true;
        if (lowered.size() > domain.size() && lowered.ends_with(domain) &&
            lowered[lowered.size() - domain.size() - 1] == '.') return true;
    }
    return false;
}

inline bool ValidPrivateWfcHost(std::string_view host) {
    if (host.empty() || host.size() > 253 || IsPublicWfcDomain(host)) return false;
    size_t labelLength = 0;
    char previous = '.';
    for (unsigned char c : host) {
        if (c == '.') {
            if (labelLength == 0 || labelLength > 63 || previous == '-') return false;
            labelLength = 0;
        } else {
            if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
                  (c >= '0' && c <= '9') || (c == '-' && labelLength != 0))) return false;
            ++labelLength;
        }
        previous = static_cast<char>(c);
    }
    return labelLength != 0 && labelLength <= 63 && previous != '-';
}

inline std::string PrivateWfcHost() {
    const char *host = std::getenv(kPrivateWfcHostEnvironment);
    return host && ValidPrivateWfcHost(host) ? std::string(host) : std::string();
}

inline bool IsWfcServiceHost(std::string_view host) {
    std::string lowered(host);
    std::transform(lowered.begin(), lowered.end(), lowered.begin(),
                   [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    if (!lowered.empty() && lowered.back() == '.') lowered.pop_back();
    // Route only game services. Pack downloads, arbitrary DNS, and peer
    // addresses must keep their original destination.
    for (const std::string_view suffix : {".nintendowifi.net", ".play.rwfc.net"}) {
        if (lowered.size() > suffix.size() && lowered.ends_with(suffix)) return true;
    }
    return false;
}

inline bool PrivateWfcRoutesHost(std::string_view host) {
    return !PrivateWfcHost().empty() && IsWfcServiceHost(host);
}

inline std::string RoutePrivateWfcHost(std::string_view host) {
    return PrivateWfcRoutesHost(host) ? PrivateWfcHost() : std::string(host);
}

} // namespace KartPad::Network
