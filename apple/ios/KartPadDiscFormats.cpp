#include <algorithm>
#include <array>
#include <cstddef>
#include <cstring>
#include <string>
#include <utility>
#include <vector>

#include "Common/Crypto/AES.h"
#include "Common/Swap.h"
#include "Core/IOS/ES/Formats.h"

namespace IOS::ES {

namespace {

// KartPad does not ship console keys. The user's own Wii common key is loaded
// at import time by KartPadDiscExtractor and handed in here.
std::array<u8, 16> g_userCommonKey{};
bool g_hasUserCommonKey = false;

size_t SignatureSize(SignatureType type) {
  switch (type) {
    case SignatureType::RSA4096: return sizeof(SignatureRSA4096);
    case SignatureType::RSA2048: return sizeof(SignatureRSA2048);
    case SignatureType::ECC: return sizeof(SignatureECC);
    default: return 0;
  }
}

}  // namespace

SignedBlobReader::SignedBlobReader(std::vector<u8> bytes)
    : m_bytes(std::move(bytes)) {}

const std::vector<u8>& SignedBlobReader::GetBytes() const { return m_bytes; }

SignatureType SignedBlobReader::GetSignatureType() const {
  if (m_bytes.size() < sizeof(SignatureType)) return static_cast<SignatureType>(0);
  return static_cast<SignatureType>(Common::swap32(m_bytes.data()));
}

size_t SignedBlobReader::GetSignatureSize() const {
  return SignatureSize(GetSignatureType());
}

bool SignedBlobReader::IsSignatureValid() const {
  const size_t size = GetSignatureSize();
  return size != 0 && m_bytes.size() >= size;
}

bool IsValidTMDSize(size_t size) {
  return size >= sizeof(TMDHeader) && size <= MAX_TMD_SIZE;
}

TMDReader::TMDReader(std::vector<u8> bytes)
    : SignedBlobReader(std::move(bytes)) {}

u16 TMDReader::GetBootIndex() const {
  return Common::swap16(m_bytes.data() + offsetof(TMDHeader, boot_index));
}

u64 TMDReader::GetIOSId() const {
  return Common::swap64(m_bytes.data() + offsetof(TMDHeader, ios_id));
}

u64 TMDReader::GetTitleId() const {
  return Common::swap64(m_bytes.data() + offsetof(TMDHeader, title_id));
}

u32 TMDReader::GetTitleFlags() const {
  return Common::swap32(m_bytes.data() + offsetof(TMDHeader, title_flags));
}

u16 TMDReader::GetTitleVersion() const {
  return Common::swap16(m_bytes.data() + offsetof(TMDHeader, title_version));
}

u16 TMDReader::GetGroupId() const {
  return Common::swap16(m_bytes.data() + offsetof(TMDHeader, group_id));
}

DiscIO::Region TMDReader::GetRegion() const {
  return DiscIO::Region::Unknown;
}

u16 TMDReader::GetNumContents() const {
  return Common::swap16(m_bytes.data() + offsetof(TMDHeader, num_contents));
}

bool TMDReader::IsValid() const {
  if (!IsSignatureValid() || m_bytes.size() < sizeof(TMDHeader)) return false;
  return m_bytes.size() >=
      sizeof(TMDHeader) + static_cast<size_t>(GetNumContents()) * sizeof(Content);
}

bool TMDReader::GetContent(u16 index, Content* content) const {
  if (content == nullptr || !IsValid() || index >= GetNumContents()) return false;
  const u8* base = m_bytes.data() + sizeof(TMDHeader) + index * sizeof(Content);
  content->id = Common::swap32(base + offsetof(Content, id));
  content->index = Common::swap16(base + offsetof(Content, index));
  content->type = Common::swap16(base + offsetof(Content, type));
  content->size = Common::swap64(base + offsetof(Content, size));
  std::copy_n(base + offsetof(Content, sha1), content->sha1.size(),
              content->sha1.begin());
  return true;
}

std::vector<Content> TMDReader::GetContents() const {
  std::vector<Content> contents(IsValid() ? GetNumContents() : 0);
  for (size_t i = 0; i < contents.size(); ++i)
    GetContent(static_cast<u16>(i), &contents[i]);
  return contents;
}

TicketReader::TicketReader(std::vector<u8> bytes)
    : SignedBlobReader(std::move(bytes)) {}

u8 TicketReader::GetVersion() const {
  return m_bytes.size() > offsetof(Ticket, version)
             ? m_bytes[offsetof(Ticket, version)]
             : 0xff;
}

bool TicketReader::IsV1Ticket() const { return GetVersion() == 1; }

u32 TicketReader::GetTicketSize() const {
  if (!IsV1Ticket()) return sizeof(Ticket);
  const size_t offset = sizeof(Ticket) + offsetof(V1TicketHeader, v1_ticket_size);
  if (m_bytes.size() < offset + sizeof(u32)) return 0;
  return Common::swap32(m_bytes.data() + offset) + sizeof(Ticket);
}

size_t TicketReader::GetNumberOfTickets() const {
  const u32 size = GetTicketSize();
  return IsV1Ticket() ? 1 : (size == 0 ? 0 : m_bytes.size() / size);
}

bool TicketReader::IsValid() const {
  if (!IsSignatureValid() || m_bytes.empty()) return false;
  const u32 size = GetTicketSize();
  return size != 0 && (IsV1Ticket() ? m_bytes.size() == size
                                    : m_bytes.size() % size == 0);
}

u64 TicketReader::GetTitleId() const {
  return Common::swap64(m_bytes.data() + offsetof(Ticket, title_id));
}

u8 TicketReader::GetCommonKeyIndex() const {
  return m_bytes[offsetof(Ticket, common_key_index)];
}

std::array<u8, 16> TicketReader::GetTitleKey() const {
  // Only the retail common key (index 0) is supported; KartPad accepts PAL
  // RMCP01 discs only.
  if (!g_hasUserCommonKey || GetCommonKeyIndex() != 0) return {};
  const std::array<u8, 16>& commonKey = g_userCommonKey;
  std::array<u8, 16> iv{};
  std::copy_n(m_bytes.data() + offsetof(Ticket, title_id), sizeof(Ticket::title_id),
              iv.begin());
  std::array<u8, 16> titleKey{};
  auto aes = Common::AES::CreateContextDecrypt(commonKey.data());
  if (aes != nullptr) {
    aes->Crypt(iv.data(), m_bytes.data() + offsetof(Ticket, title_key),
               titleKey.data(), titleKey.size());
  }
  return titleKey;
}

void KartPadSetUserCommonKey(const std::array<u8, 16>& key) {
  g_userCommonKey = key;
  g_hasUserCommonKey = true;
}

}  // namespace IOS::ES
