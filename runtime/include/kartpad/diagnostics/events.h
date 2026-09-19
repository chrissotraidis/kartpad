#pragma once
#include <array>
#include <atomic>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <string_view>
#if defined(_WIN32)
#include <process.h>
#else
#include <unistd.h>
#endif

namespace kartpad::diagnostics {
// Shared Android/iOS wire contract. Ordinary execution only, NEVER a signal handler.
// No user identifiers or memory payloads. Each boundary has its own budget, so
// noisy driver messages cannot consume the allowance for a later fatal stage.
enum class Boundary : unsigned {
  Runtime, Window, Backend, Instance, Adapter, Device, Surface, Guest, Lifecycle,
  Count
};
inline constexpr const char* boundary_names[] = {
  "runtime", "window", "backend", "instance", "adapter", "device", "surface", "guest", "lifecycle"
};
inline std::array<std::atomic<unsigned>, static_cast<unsigned>(Boundary::Count)> event_counts{};
inline std::atomic<unsigned long long> sequence{};
inline long long unix_ms() {
 return std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch()).count();
}
inline long long monotonic_ms() {
 return std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now().time_since_epoch()).count();
}
inline long long pid() {
#if defined(_WIN32)
 return _getpid();
#else
 return getpid();
#endif
}
inline const long long process_start_unix_ms = unix_ms();
inline void event(Boundary boundary, const char* status, long long code = -1,
                  std::string_view detail = {}) {
 const auto index = static_cast<unsigned>(boundary);
 if (index >= event_counts.size()) return;
 const auto count = event_counts[index].fetch_add(1, std::memory_order_relaxed);
 if (count > 32) return;
 if (count == 32) { status="budget_exhausted"; detail={}; code=32; }
 // Bounded ASCII projection: preserve message wording, escape JSON delimiters,
 // and prevent multiline log injection. Raw driver messages remain untrusted.
 char text[1025]{}; size_t length=0;
 const size_t take = detail.size() < 512 ? detail.size() : 512;
 for (size_t i=0; i<take; ++i) {
   const unsigned char c = detail[i];
   if (c == '"' || c == '\\') text[length++]='\\';
   text[length++]=(c>=32 && c<127) ? static_cast<char>(c) : ' ';
 }
 std::fprintf(stderr, "[KartPadDiagnostic] {\"schema\":2,\"kind\":\"boundary\",\"sequence\":%llu,\"pid\":%lld,\"process_start_unix_ms\":%lld,\"unix_ms\":%lld,\"monotonic_ms\":%lld,\"boundary\":\"%s\",\"status\":\"%s\",\"code\":%lld,\"detail\":\"%s\",\"detail_truncated\":%s}\n",
   sequence.fetch_add(1,std::memory_order_relaxed),pid(),process_start_unix_ms,unix_ms(),monotonic_ms(),boundary_names[index],status,code,text,detail.size()>take?"true":"false");
}
inline double finite(double value) { return std::isfinite(value) ? value : -1.0; }
inline void frame(unsigned long long presents, double fps, double p95, double p99,
                  double worst, unsigned pipelines, double resolution) {
 static std::atomic<unsigned> reports{};
 const unsigned count = reports.fetch_add(1,std::memory_order_relaxed);
 if (count>720) return;
 if (count==720) { event(Boundary::Runtime,"frame_budget_exhausted",720); return; }
 std::fprintf(stderr,"[KartPadDiagnostic] {\"schema\":2,\"kind\":\"frame\",\"pid\":%lld,\"process_start_unix_ms\":%lld,\"unix_ms\":%lld,\"monotonic_ms\":%lld,\"presents\":%llu,\"fps\":%.3f,\"p95_ms\":%.3f,\"p99_ms\":%.3f,\"worst_ms\":%.3f,\"pipelines_queued\":%u,\"resolution_scale\":%.3f}\n",pid(),process_start_unix_ms,unix_ms(),monotonic_ms(),presents,finite(fps),finite(p95),finite(p99),finite(worst),pipelines,finite(resolution));
}
}
