#pragma once
#include "kartpad/ghost/rkg.h"

namespace retro_fixture {
using namespace kartpad::ghost;
inline std::vector<uint8_t> Ghost(bool compressed, uint8_t marker = 0) {
  std::vector<uint8_t> bytes(GhostBytes);
  Write32(bytes, 0, 0x524b4744); Write32(bytes, 4, (8u << 2) | (30u << 18));
  Write32(bytes, 8, 0x00035410); // Year 26, October 1; kart/character/controller 0.
  bytes[15] = 14; bytes[0x89] = 1; bytes[0x8b] = 1; bytes[0x8d] = 1;
  bytes[0x90] = 1; bytes[0x91] = 60; bytes[0x92] = 0x77; bytes[0x93] = 60;
  bytes[0x95] = 60; bytes[30] = marker;
  if (compressed) {
    auto input = bytes;
    bytes.resize(0x8c + 16); bytes[12] |= 8;
    Write32(bytes, 0x8c, 0x59617a31); Write32(bytes, 0x90, 14);
    bytes.push_back(0xff); bytes.insert(bytes.end(), input.begin() + 0x88, input.begin() + 0x90);
    bytes.push_back(0xfc); bytes.insert(bytes.end(), input.begin() + 0x90, input.begin() + 0x96);
    Write32(bytes, 0x88, uint32_t(bytes.size() - 0x8c)); bytes.resize(bytes.size() + 4);
  }
  Write32(bytes, bytes.size() - 4, Crc(std::span<const uint8_t>(bytes).first(bytes.size() - 4)));
  Validate(bytes);
  return bytes;
}

}
