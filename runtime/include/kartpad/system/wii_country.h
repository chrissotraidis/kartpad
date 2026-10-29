#pragma once

// The Wii console country setting (SYSCONF IPL.SADR), #511.
//
// Mario Kart Wii reads the player's country and globe position through
// SCGetSimpleAddressData. KartPad has no SYSCONF, so that call failed and the
// game showed no flag and placed the Mii at the wrong spot. The app sets
// KARTPAD_COUNTRY (ISO 3166-1 alpha-2, from the device's region or the player's
// choice) before the runtime starts; this header turns it into the same
// structure a real Wii returns. Codes are Nintendo's (wiibrew Country_Codes);
// coordinates are each country's capital, in the SDK's 45/8192-degree units.

#include <cctype>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string_view>

namespace KartPad::System {

inline constexpr char kCountryEnvironment[] = "KARTPAD_COUNTRY";

struct WiiCountry {
    const char* iso;
    uint8_t code;
    int16_t latitude;
    int16_t longitude;
    const char* englishName;
};

inline constexpr WiiCountry kWiiCountries[] = {
    {"JP", 1, 6495, 25430, "Japan"},
    {"AI", 8, 3317, -11478, "Anguilla"},
    {"AG", 9, 3117, -11259, "Antigua and Barbuda"},
    {"AR", 10, -6299, -10628, "Argentina"},
    {"AW", 11, 2279, -12749, "Aruba"},
    {"BS", 12, 4560, -14081, "Bahamas"},
    {"BB", 13, 2385, -10853, "Barbados"},
    {"BZ", 14, 3140, -16160, "Belize"},
    {"BO", 15, -3004, -12406, "Bolivia"},
    {"BR", 16, -2874, -8716, "Brazil"},
    {"VG", 17, 3355, -11764, "British Virgin Islands"},
    {"CA", 18, 8268, -13781, "Canada"},
    {"KY", 19, 3512, -14815, "Cayman Islands"},
    {"CL", 20, -6089, -12865, "Chile"},
    {"CO", 21, 857, -13484, "Colombia"},
    {"CR", 22, 1808, -15308, "Costa Rica"},
    {"DM", 23, 2785, -11176, "Dominica"},
    {"DO", 24, 3366, -12730, "Dominican Republic"},
    {"EC", 25, -33, -14285, "Ecuador"},
    {"SV", 26, 2492, -16242, "El Salvador"},
    {"GF", 27, 896, -9526, "French Guiana"},
    {"GD", 28, 2195, -11241, "Grenada"},
    {"GP", 29, 2913, -11238, "Guadeloupe"},
    {"GT", 30, 2663, -16477, "Guatemala"},
    {"GY", 31, 1238, -10588, "Guyana"},
    {"HT", 32, 3375, -13169, "Haiti"},
    {"HN", 33, 2561, -15872, "Honduras"},
    {"JM", 34, 3280, -13981, "Jamaica"},
    {"MQ", 35, 2661, -11116, "Martinique"},
    {"MX", 36, 3537, -18046, "Mexico"},
    {"MS", 37, 3057, -11325, "Montserrat"},
    {"AN", 38, 2205, -12548, "Netherlands Antilles"},
    {"CW", 38, 2205, -12548, "Netherlands Antilles"},
    {"SX", 38, 3282, -11478, "Netherlands Antilles"},
    {"BQ", 38, 2212, -12428, "Netherlands Antilles"},
    {"NI", 39, 2205, -15700, "Nicaragua"},
    {"PA", 40, 1635, -14476, "Panama"},
    {"PY", 41, -4598, -10482, "Paraguay"},
    {"PE", 42, -2194, -14025, "Peru"},
    {"KN", 43, 3149, -11418, "St. Kitts and Nevis"},
    {"LC", 44, 2550, -11103, "St. Lucia"},
    {"VC", 45, 2396, -11147, "St. Vincent and the Grenadines"},
    {"SR", 46, 1065, -10049, "Suriname"},
    {"TT", 47, 1939, -11198, "Trinidad and Tobago"},
    {"TC", 48, 3907, -12951, "Turks and Caicos Islands"},
    {"US", 49, 7083, -14025, "United States"},
    {"UY", 50, -6353, -10224, "Uruguay"},
    {"VI", 51, 3339, -11820, "US Virgin Islands"},
    {"VE", 52, 1908, -12179, "Venezuela"},
    {"AL", 64, 7524, 3608, "Albania"},
    {"AU", 65, -6423, 27148, "Australia"},
    {"AT", 66, 8776, 2980, "Austria"},
    {"BE", 67, 9257, 792, "Belgium"},
    {"BA", 68, 7984, 3351, "Bosnia and Herzegovina"},
    {"BW", 69, -4484, 4719, "Botswana"},
    {"BG", 70, 7773, 4245, "Bulgaria"},
    {"HR", 71, 8339, 2909, "Croatia"},
    {"CY", 72, 6406, 6077, "Cyprus"},
    {"CZ", 73, 9117, 2629, "Czech Republic"},
    {"DK", 74, 10136, 2288, "Denmark"},
    {"EE", 75, 10821, 4506, "Estonia"},
    {"FI", 76, 10954, 4540, "Finland"},
    {"FR", 77, 8895, 428, "France"},
    {"DE", 78, 9561, 2439, "Germany"},
    {"GR", 79, 6914, 4320, "Greece"},
    {"HU", 80, 8647, 3466, "Hungary"},
    {"IS", 81, 11678, -3994, "Iceland"},
    {"IE", 82, 9712, -1140, "Ireland"},
    {"IT", 83, 7628, 2276, "Italy"},
    {"LV", 84, 10367, 4389, "Latvia"},
    {"LS", 85, -5336, 5003, "Lesotho"},
    {"LI", 86, 8582, 1733, "Liechtenstein"},
    {"LT", 87, 9956, 4602, "Lithuania"},
    {"LU", 88, 9031, 1116, "Luxembourg"},
    {"MK", 89, 7646, 3901, "North Macedonia"},
    {"MT", 90, 6535, 2641, "Malta"},
    {"ME", 91, 7726, 3506, "Montenegro"},
    {"MZ", 92, -4728, 5929, "Mozambique"},
    {"NA", 93, -4107, 3109, "Namibia"},
    {"NL", 94, 9534, 892, "Netherlands"},
    {"NZ", 95, -7517, 31818, "New Zealand"},
    {"NO", 96, 10906, 1957, "Norway"},
    {"PL", 97, 9508, 3825, "Poland"},
    {"PT", 98, 7049, -1664, "Portugal"},
    {"RO", 99, 8088, 4751, "Romania"},
    {"RU", 100, 10151, 6849, "Russia"},
    {"RS", 101, 8154, 3723, "Serbia"},
    {"SK", 102, 8765, 3115, "Slovakia"},
    {"SI", 103, 8385, 2641, "Slovenia"},
    {"ZA", 104, -4688, 5132, "South Africa"},
    {"ES", 105, 7358, -674, "Spain"},
    {"SZ", 106, -4790, 5669, "Eswatini"},
    {"SE", 107, 10801, 3290, "Sweden"},
    {"CH", 108, 8547, 1356, "Switzerland"},
    {"TR", 109, 7269, 5982, "Turkey"},
    {"GB", 110, 9377, -24, "United Kingdom"},
    {"ZM", 111, -2802, 5155, "Zambia"},
    {"ZW", 112, -3246, 5652, "Zimbabwe"},
    {"AZ", 113, 7356, 9079, "Azerbaijan"},
    {"MR", 114, 3293, -2909, "Mauritania"},
    {"ML", 115, 2301, -1456, "Mali"},
    {"NE", 116, 2459, 384, "Niger"},
    {"TD", 117, 2208, 2742, "Chad"},
    {"SD", 118, 2822, 5927, "Sudan"},
    {"ER", 119, 2789, 7087, "Eritrea"},
    {"DJ", 120, 2110, 7855, "Djibouti"},
    {"SO", 121, 373, 8250, "Somalia"},
    {"TW", 128, 4557, 22131, "Taiwan"},
    {"KR", 136, 6839, 23116, "South Korea"},
    {"HK", 144, 4063, 20784, "Hong Kong"},
    {"MO", 145, 4041, 20669, "Macao"},
    {"ID", 152, -1130, 19451, "Indonesia"},
    {"SG", 153, 246, 18900, "Singapore"},
    {"TH", 154, 2505, 18295, "Thailand"},
    {"PH", 155, 2658, 22024, "Philippines"},
    {"MY", 156, 572, 18512, "Malaysia"},
    {"CN", 160, 7264, 21192, "China"},
    {"AE", 168, 4451, 9900, "U.A.E."},
    {"IN", 169, 5208, 14056, "India"},
    {"EG", 170, 5469, 5687, "Egypt"},
    {"OM", 171, 4294, 10633, "Oman"},
    {"QA", 172, 4604, 9381, "Qatar"},
    {"KW", 173, 5348, 8736, "Kuwait"},
    {"SA", 174, 4498, 8498, "Saudi Arabia"},
    {"SY", 175, 6100, 6606, "Syria"},
    {"BH", 176, 4775, 9210, "Bahrain"},
    {"JO", 177, 5816, 6541, "Jordan"},
};

inline const WiiCountry* FindWiiCountry(std::string_view iso) {
    if (iso.size() != 2) return nullptr;
    const char a = static_cast<char>(std::toupper(static_cast<unsigned char>(iso[0])));
    const char b = static_cast<char>(std::toupper(static_cast<unsigned char>(iso[1])));
    for (const WiiCountry& country : kWiiCountries) {
        if (country.iso[0] == a && country.iso[1] == b) return &country;
    }
    return nullptr;
}

inline const WiiCountry* CountryFromEnvironment() {
    const char* value = std::getenv(kCountryEnvironment);
    return value ? FindWiiCountry(value) : nullptr;
}

// SCSimpleAddressData as the SDK returns it (wiibrew IPL.SADR without its
// two-byte length): country, region, city, 16 country names, 16 region names,
// latitude, longitude. A region of 0 makes the SDK clear the coordinates, so
// KartPad reports region 1 with no region name.
inline constexpr uint32_t kSimpleAddressSize = 0x1008;
inline constexpr uint32_t kSimpleAddressEnglishName = 0x0004 + 0x80;
inline constexpr uint32_t kSimpleAddressLatitude = 0x1004;
inline constexpr uint32_t kSimpleAddressLongitude = 0x1006;

inline void FillSimpleAddress(const WiiCountry& country, uint8_t* out) {
    std::memset(out, 0, kSimpleAddressSize);
    out[0] = country.code;
    out[1] = 1;
    uint8_t* name = out + kSimpleAddressEnglishName;
    for (size_t index = 0; country.englishName[index] != 0 && index < 0x3F; ++index) {
        name[index * 2] = 0;
        name[index * 2 + 1] = static_cast<uint8_t>(country.englishName[index]);
    }
    const auto latitude = static_cast<uint16_t>(country.latitude);
    const auto longitude = static_cast<uint16_t>(country.longitude);
    out[kSimpleAddressLatitude] = static_cast<uint8_t>(latitude >> 8);
    out[kSimpleAddressLatitude + 1] = static_cast<uint8_t>(latitude);
    out[kSimpleAddressLongitude] = static_cast<uint8_t>(longitude >> 8);
    out[kSimpleAddressLongitude + 1] = static_cast<uint8_t>(longitude);
}

} // namespace KartPad::System

