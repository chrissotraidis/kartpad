#include "kartpad/system/wii_country.h"
#include <array>
#include <iostream>
#include <set>

int main() {
    using namespace KartPad::System;
    unsigned failures = 0;
    auto check = [&](bool value, const char *message) {
        if (!value) { std::cerr << message << '\n'; ++failures; }
    };
    const WiiCountry* mexico = FindWiiCountry("mx");
    check(mexico && mexico->code == 36, "Mexico is Wii country 36");
    check(FindWiiCountry("US") && FindWiiCountry("US")->code == 49, "United States is 49");
    check(FindWiiCountry("GB") && FindWiiCountry("GB")->code == 110, "United Kingdom is 110");
    check(FindWiiCountry("JP") && FindWiiCountry("JP")->code == 1, "Japan is 1");
    check(!FindWiiCountry("XX") && !FindWiiCountry("") && !FindWiiCountry("USA"), "unknown codes rejected");
    std::set<std::string_view> seen;
    for (const WiiCountry& country : kWiiCountries) {
        check(seen.insert(country.iso).second, "duplicate ISO code");
        check(country.code != 0 && country.code != 0xFF, "reserved Wii code used");
        check(country.latitude >= -16384 && country.latitude <= 16384, "latitude past 90 degrees");
    }
    std::array<uint8_t, kSimpleAddressSize> data{};
    data.fill(0xAA);
    FillSimpleAddress(*mexico, data.data());
    check(data[0] == 36 && data[1] == 1 && data[2] == 0 && data[3] == 0, "country, region and city bytes");
    // 19.43 N, 99.13 W in 45/8192-degree steps, big-endian.
    const int16_t latitude = static_cast<int16_t>((data[0x1004] << 8) | data[0x1005]);
    const int16_t longitude = static_cast<int16_t>((data[0x1006] << 8) | data[0x1007]);
    check(latitude == 3537 && longitude == -18046, "Mexico City coordinates");
    check(data[0x84] == 0 && data[0x85] == 'M' && data[0x87] == 'e' && data[0x8F] == 'o', "English country name");
    check(data[0x804] == 0 && data[0xFFF] == 0, "other fields cleared");
    setenv(kCountryEnvironment, "de", 1);
    check(CountryFromEnvironment() && CountryFromEnvironment()->code == 78, "environment selects Germany");
    unsetenv(kCountryEnvironment);
    check(CountryFromEnvironment() == nullptr, "no country without the setting");
    return failures ? 1 : 0;
}

