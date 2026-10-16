#pragma once
// Bounded big-endian guest memory for checking the actual KPAD ABI writes.
#include <cstdint>
#include <cstddef>
#include <stdexcept>
#include <string_view>
class Memory {
public:
 class AccessViolation : public std::runtime_error {
 public: AccessViolation(uint32_t,size_t,std::string_view);
 private: uint32_t address_; size_t length_; std::string reason_;
 };
 static uint8_t* GetPointer(uint32_t,size_t);
 static uint8_t Read8(uint32_t);
 static uint16_t Read16(uint32_t);
 static uint32_t Read32(uint32_t);
 static float ReadFloat32(uint32_t);
 static void Write8(uint32_t,uint8_t);
 static void Write16(uint32_t,uint16_t);
 static void Write32(uint32_t,uint32_t);
 static void WriteFloat32(uint32_t,double);
};
