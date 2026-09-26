#pragma once

#include <array>
#include <bit>
#include <cfenv>
#include <cmath>
#include <cstdint>
#include <limits>

#if defined(KARTPAD_ANDROID_COMBINED_FENV)
// Implemented in a separate translation unit: do not inline across the FP
// arithmetic whose exception flags are being captured.
extern "C" int KartPadAndroidCaptureScalarFlags() noexcept;
extern "C" void KartPadAndroidClearScalarFlags() noexcept;
#endif

namespace kartpad::semantics {

inline void ClearScalarFlags() noexcept {
#if defined(KARTPAD_ANDROID_COMBINED_FENV)
  KartPadAndroidClearScalarFlags();
#else
  std::feclearexcept(FE_ALL_EXCEPT);
#endif
}

inline int CaptureAndClearScalarFlags() noexcept {
#if defined(KARTPAD_ANDROID_COMBINED_FENV)
  return KartPadAndroidCaptureScalarFlags();
#else
  const int flags = std::fetestexcept(FE_OVERFLOW | FE_UNDERFLOW | FE_INEXACT);
  ClearScalarFlags();
  return flags;
#endif
}

struct PpcFlags {
  bool invalid{};
  bool overflow{};
  bool underflow{};
  bool divide_by_zero{};
  bool inexact{};

  [[nodiscard]] constexpr std::uint32_t bits() const noexcept {
    return (invalid ? 1u << 0 : 0u) | (overflow ? 1u << 1 : 0u) |
           (underflow ? 1u << 2 : 0u) | (divide_by_zero ? 1u << 3 : 0u) |
           (inexact ? 1u << 4 : 0u);
  }
};

namespace fpscr {
inline constexpr std::uint32_t FX = 0x80000000u;
inline constexpr std::uint32_t FEX = 0x40000000u;
inline constexpr std::uint32_t VX = 0x20000000u;
inline constexpr std::uint32_t OX = 0x10000000u;
inline constexpr std::uint32_t UX = 0x08000000u;
inline constexpr std::uint32_t ZX = 0x04000000u;
inline constexpr std::uint32_t XX = 0x02000000u;
inline constexpr std::uint32_t VXSNAN = 0x01000000u;
inline constexpr std::uint32_t VXISI = 0x00800000u;
inline constexpr std::uint32_t VXIDI = 0x00400000u;
inline constexpr std::uint32_t VXZDZ = 0x00200000u;
inline constexpr std::uint32_t VXIMZ = 0x00100000u;
inline constexpr std::uint32_t VXVC = 0x00080000u;
inline constexpr std::uint32_t FR = 0x00040000u;
inline constexpr std::uint32_t FI = 0x00020000u;
inline constexpr std::uint32_t FPRF = 0x0001f000u;
inline constexpr std::uint32_t VXSOFT = 0x00000400u;
inline constexpr std::uint32_t VXSQRT = 0x00000200u;
inline constexpr std::uint32_t VXCVI = 0x00000100u;
inline constexpr std::uint32_t VE = 0x00000080u;
inline constexpr std::uint32_t OE = 0x00000040u;
inline constexpr std::uint32_t UE = 0x00000020u;
inline constexpr std::uint32_t ZE = 0x00000010u;
inline constexpr std::uint32_t XE = 0x00000008u;
inline constexpr std::uint32_t NI = 0x00000004u;
inline constexpr std::uint32_t RN = 0x00000003u;
inline constexpr std::uint32_t VX_ANY = VXSNAN | VXISI | VXIDI | VXZDZ |
                                                VXIMZ | VXVC | VXSOFT |
                                                VXSQRT | VXCVI;
inline constexpr std::uint32_t ANY_X = OX | UX | ZX | XX | VX_ANY;
inline constexpr std::uint32_t ANY_E = VE | OE | UE | ZE | XE;
}  // namespace fpscr

// Host overflow/underflow/inexact flags only set the guest's sticky OX/UX/XX
// status bits, unless the matching FPSCR enable could suppress the register
// write. The translated game reads FPSCR (mffs) solely in OS context
// save/restore, FP-exception and crash-dump paths, so on Android the status
// capture is skipped while those enables are clear. Results, register writes,
// VX/ZX, FR/FI and FPRF are unchanged. Skipping also avoids reading and writing
// the host FPSR around every operation.
inline constexpr bool TrackHostFpStatus(std::uint32_t fpscr_value) noexcept {
#if (defined(KARTPAD_ANDROID_COMBINED_FENV) && defined(KARTPAD_ANDROID_UNOBSERVED_FP_STATUS)) || \
    defined(KARTPAD_UNOBSERVED_FP_STATUS)
  return (fpscr_value & (fpscr::OE | fpscr::UE | fpscr::XE)) != 0;
#else
  (void)fpscr_value;
  return true;
#endif
}

inline constexpr std::uint32_t UpdateFpscrSummaries(
    std::uint32_t value) noexcept {
  value = (value & ~fpscr::VX) |
          ((value & fpscr::VX_ANY) != 0 ? fpscr::VX : 0u);
  const bool enabled = (((value >> 22) & (value & fpscr::ANY_E)) != 0);
  return (value & ~fpscr::FEX) | (enabled ? fpscr::FEX : 0u);
}

inline constexpr std::uint32_t SetFpscrException(
    std::uint32_t value, std::uint32_t exception) noexcept {
  if ((value & exception) != exception)
    value |= fpscr::FX;
  value |= exception;
  return UpdateFpscrSummaries(value);
}

inline constexpr bool FpscrExceptionEnabled(
    std::uint32_t value, std::uint32_t exception) noexcept {
  return (((exception & fpscr::VX_ANY) != 0) && (value & fpscr::VE) != 0) ||
         (((exception & fpscr::OX) != 0) && (value & fpscr::OE) != 0) ||
         (((exception & fpscr::UX) != 0) && (value & fpscr::UE) != 0) ||
         (((exception & fpscr::ZX) != 0) && (value & fpscr::ZE) != 0) ||
         (((exception & fpscr::XX) != 0) && (value & fpscr::XE) != 0);
}

inline constexpr bool IsSignalingNan(double value) noexcept {
  const auto bits = std::bit_cast<std::uint64_t>(value);
  return (bits & 0x7ff0000000000000ULL) == 0x7ff0000000000000ULL &&
         (bits & 0x000fffffffffffffULL) != 0 &&
         (bits & 0x0008000000000000ULL) == 0;
}

inline constexpr bool IsSignalingNan(float value) noexcept {
  const auto bits = std::bit_cast<std::uint32_t>(value);
  return (bits & 0x7f800000u) == 0x7f800000u &&
         (bits & 0x007fffffu) != 0 && (bits & 0x00400000u) == 0;
}

inline constexpr double QuietNan(double value) noexcept {
  return std::bit_cast<double>(std::bit_cast<std::uint64_t>(value) |
                               0x0008000000000000ULL);
}

inline constexpr std::uint32_t ClassifyDouble(double value) noexcept {
  const auto bits = std::bit_cast<std::uint64_t>(value);
  const auto sign = bits & 0x8000000000000000ULL;
  const auto exponent = bits & 0x7ff0000000000000ULL;
  const auto fraction = bits & 0x000fffffffffffffULL;
  if (exponent != 0 && exponent != 0x7ff0000000000000ULL)
    return sign != 0 ? 0x08u : 0x04u;
  if (fraction != 0)
    return exponent != 0 ? 0x11u : (sign != 0 ? 0x18u : 0x14u);
  if (exponent != 0)
    return sign != 0 ? 0x09u : 0x05u;
  return sign != 0 ? 0x12u : 0x02u;
}

inline constexpr std::uint32_t ClassifyFloat(float value) noexcept {
  const auto bits = std::bit_cast<std::uint32_t>(value);
  const auto sign = bits & 0x80000000u;
  const auto exponent = bits & 0x7f800000u;
  const auto fraction = bits & 0x007fffffu;
  if (exponent != 0 && exponent != 0x7f800000u)
    return sign != 0 ? 0x08u : 0x04u;
  if (fraction != 0)
    return exponent != 0 ? 0x11u : (sign != 0 ? 0x18u : 0x14u);
  if (exponent != 0)
    return sign != 0 ? 0x09u : 0x05u;
  return sign != 0 ? 0x12u : 0x02u;
}

inline constexpr std::uint32_t SetFprf(std::uint32_t fpscr_value,
                                       std::uint32_t classification) noexcept {
  return (fpscr_value & ~fpscr::FPRF) |
         ((classification & 0x1fu) << 12);
}

inline float ForceSingle(double value, bool non_ieee) noexcept;
inline double Force25Bit(double value) noexcept;
inline double ApproximateReciprocal(double value) noexcept;
inline double ApproximateReciprocalSquareRoot(double value) noexcept;

struct ScalarFpResult {
  double value{};
  std::uint32_t fpscr{};
  std::uint32_t exception{};
  bool write_destination{true};
};

inline double RoundToIntegerMode(double value, int rounding_mode) noexcept {
  switch (rounding_mode) {
  case FE_TOWARDZERO:
    return std::trunc(value);
  case FE_UPWARD:
    return std::ceil(value);
  case FE_DOWNWARD:
    return std::floor(value);
  default:
    return std::rint(value);
  }
}

inline ScalarFpResult FinishScalarFp(std::uint32_t fpscr_value, double value,
                                     std::uint32_t exception,
                                     bool single_precision) noexcept {
  if (exception != 0)
    fpscr_value = SetFpscrException(fpscr_value, exception);

  // Invalid and divide-by-zero enables suppress the architectural register
  // write. The exception and summary bits remain sticky either way.
  const bool write_destination =
      !FpscrExceptionEnabled(fpscr_value, exception);
  if (!write_destination)
    return {value, fpscr_value, exception, false};

  if (single_precision) {
    volatile float rounded = ForceSingle(
        value, (fpscr_value & fpscr::NI) != 0);
    value = static_cast<double>(rounded);
    fpscr_value = SetFprf(fpscr_value, ClassifyFloat(rounded));
  } else {
    fpscr_value = SetFprf(fpscr_value, ClassifyDouble(value));
  }
  return {value, fpscr_value, exception, true};
}

enum class ScalarFpBinaryOperation { Add, Subtract, Multiply, Divide };

inline ScalarFpResult EvaluatePpcScalarBinary(
    std::uint32_t fpscr_value, ScalarFpBinaryOperation operation, double a,
    double b, bool single_precision) noexcept {
  const bool track_status = TrackHostFpStatus(fpscr_value);
  if (track_status)
    ClearScalarFlags();
  volatile double computed = 0.0;
  switch (operation) {
  case ScalarFpBinaryOperation::Add:
    computed = a + b;
    break;
  case ScalarFpBinaryOperation::Subtract:
    computed = a - b;
    break;
  case ScalarFpBinaryOperation::Multiply:
    computed = a * b;
    break;
  case ScalarFpBinaryOperation::Divide:
    computed = a / b;
    break;
  }

  double value = computed;
  std::uint32_t exception = 0;
  const bool a_snan = IsSignalingNan(a);
  const bool b_snan = IsSignalingNan(b);
  if (a_snan || b_snan)
    exception |= fpscr::VXSNAN;

  if (std::isnan(value)) {
    fpscr_value &= ~(fpscr::FR | fpscr::FI);
    if (std::isnan(a))
      value = QuietNan(a);
    else if (std::isnan(b))
      value = QuietNan(b);
    else {
      value = std::bit_cast<double>(0x7ff8000000000000ULL);
      switch (operation) {
      case ScalarFpBinaryOperation::Add:
      case ScalarFpBinaryOperation::Subtract:
        exception |= fpscr::VXISI;
        break;
      case ScalarFpBinaryOperation::Multiply:
        exception |= fpscr::VXIMZ;
        break;
      case ScalarFpBinaryOperation::Divide:
        exception |= b == 0.0 ? fpscr::VXZDZ : fpscr::VXIDI;
        break;
      }
    }
  } else if (operation == ScalarFpBinaryOperation::Divide && b == 0.0) {
    exception |= fpscr::ZX;
  }

  const int host_flags = track_status ? CaptureAndClearScalarFlags() : 0;
  if ((host_flags & FE_OVERFLOW) != 0)
    exception |= fpscr::OX;
  if ((host_flags & FE_UNDERFLOW) != 0)
    exception |= fpscr::UX;
  if ((host_flags & FE_INEXACT) != 0)
    exception |= fpscr::XX;
  return FinishScalarFp(fpscr_value, value, exception, single_precision);
}

inline ScalarFpResult EvaluatePpcSqrt(std::uint32_t fpscr_value, double input,
                                      bool single_precision = false) noexcept {
  std::uint32_t exception = 0;
  double value;
  if (std::isnan(input)) {
    if (IsSignalingNan(input))
      exception |= fpscr::VXSNAN;
    fpscr_value &= ~(fpscr::FR | fpscr::FI);
    value = QuietNan(input);
  } else if (input < 0.0) {
    exception |= fpscr::VXSQRT;
    fpscr_value &= ~(fpscr::FR | fpscr::FI);
    value = std::bit_cast<double>(0x7ff8000000000000ULL);
  } else {
    const bool track_status = TrackHostFpStatus(fpscr_value);
    if (track_status)
      ClearScalarFlags();
    volatile double computed = std::sqrt(input);
    value = computed;
    const int flags = track_status ? CaptureAndClearScalarFlags() : 0;
    if ((flags & FE_OVERFLOW) != 0)
      exception |= fpscr::OX;
    if ((flags & FE_UNDERFLOW) != 0)
      exception |= fpscr::UX;
    if ((flags & FE_INEXACT) != 0)
      exception |= fpscr::XX;
  }
  return FinishScalarFp(fpscr_value, value, exception, single_precision);
}

inline ScalarFpResult EvaluatePpcConvertToInteger(
    std::uint32_t fpscr_value, double input, int rounding_mode) noexcept {
  const double rounded = RoundToIntegerMode(input, rounding_mode);

  std::uint32_t word = 0;
  std::uint32_t exception = 0;
  bool invalid = false;
  if (std::isnan(input)) {
    if (IsSignalingNan(input))
      exception |= fpscr::VXSNAN;
    word = 0x80000000u;
    invalid = true;
  } else if (rounded >= 2147483648.0) {
    word = 0x7fffffffu;
    invalid = true;
  } else if (rounded < -2147483648.0) {
    word = 0x80000000u;
    invalid = true;
  } else {
    const auto signed_word = static_cast<std::int32_t>(rounded);
    word = static_cast<std::uint32_t>(signed_word);
    if (rounded == input) {
      fpscr_value &= ~(fpscr::FR | fpscr::FI);
    } else {
      exception |= fpscr::XX;
      fpscr_value |= fpscr::FI;
      if (std::abs(rounded) > std::abs(input))
        fpscr_value |= fpscr::FR;
      else
        fpscr_value &= ~fpscr::FR;
    }
  }

  if (invalid) {
    exception |= fpscr::VXCVI;
    fpscr_value &= ~(fpscr::FR | fpscr::FI);
  }
  if (exception != 0)
    fpscr_value = SetFpscrException(fpscr_value, exception);

  std::uint64_t result_bits = 0xfff8000000000000ULL | word;
  if (word == 0 && std::signbit(input))
    result_bits |= 0x0000000100000000ULL;
  return {std::bit_cast<double>(result_bits), fpscr_value, exception,
          !invalid || (fpscr_value & fpscr::VE) == 0};
}

inline ScalarFpResult EvaluatePpcFused(std::uint32_t fpscr_value, double a,
                                       double c, double b, bool subtract,
                                       bool single_precision,
                                       bool negate_result) noexcept {
  const double effective_c = single_precision ? Force25Bit(c) : c;
  const bool track_status = TrackHostFpStatus(fpscr_value);
  if (track_status)
    ClearScalarFlags();
  volatile double computed = std::fma(a, effective_c, subtract ? -b : b);
  double value = computed;
  std::uint32_t exception = 0;
  if (IsSignalingNan(a) || IsSignalingNan(b) || IsSignalingNan(c))
    exception |= fpscr::VXSNAN;

  if (std::isnan(value)) {
    fpscr_value &= ~(fpscr::FR | fpscr::FI);
    if (std::isnan(a))
      value = QuietNan(a);
    else if (std::isnan(b))
      value = QuietNan(b);
    else if (std::isnan(c))
      value = QuietNan(c);
    else {
      const bool invalid_product =
          (std::isinf(a) && effective_c == 0.0) ||
          (a == 0.0 && std::isinf(effective_c));
      exception |= invalid_product ? fpscr::VXIMZ : fpscr::VXISI;
      value = std::bit_cast<double>(0x7ff8000000000000ULL);
    }
  } else if (negate_result) {
    value = -value;
  }

  const int flags = track_status ? CaptureAndClearScalarFlags() : 0;
  if ((flags & FE_OVERFLOW) != 0)
    exception |= fpscr::OX;
  if ((flags & FE_UNDERFLOW) != 0)
    exception |= fpscr::UX;
  if ((flags & FE_INEXACT) != 0)
    exception |= fpscr::XX;
  return FinishScalarFp(fpscr_value, value, exception, single_precision);
}

inline ScalarFpResult EvaluatePpcEstimate(std::uint32_t fpscr_value,
                                          double input,
                                          bool reciprocal_sqrt) noexcept {
  std::uint32_t exception = 0;
  if (reciprocal_sqrt && input < 0.0)
    exception |= fpscr::VXSQRT;
  else if (input == 0.0)
    exception |= fpscr::ZX;
  else if (IsSignalingNan(input))
    exception |= fpscr::VXSNAN;

  if (exception != 0 || std::isnan(input) || std::isinf(input))
    fpscr_value &= ~(fpscr::FR | fpscr::FI);
  const double value = reciprocal_sqrt
      ? ApproximateReciprocalSquareRoot(input)
      : ApproximateReciprocal(input);
  return FinishScalarFp(fpscr_value, value, exception, !reciprocal_sqrt);
}

template <typename T> struct Result {
  T value{};
  PpcFlags flags{};
};

inline PpcFlags CaptureFlags() noexcept {
  const int flags = std::fetestexcept(FE_ALL_EXCEPT);
  return {.invalid = (flags & FE_INVALID) != 0,
          .overflow = (flags & FE_OVERFLOW) != 0,
          .underflow = (flags & FE_UNDERFLOW) != 0,
          .divide_by_zero = (flags & FE_DIVBYZERO) != 0,
          .inexact = (flags & FE_INEXACT) != 0};
}

template <typename Operation>
inline Result<double> EvaluateScalar(Operation operation) noexcept {
  ClearScalarFlags();
  volatile double value = operation();
  return {value, CaptureFlags()};
}

inline constexpr std::uint32_t RotateLeft32(std::uint32_t value,
                                            std::uint32_t shift) noexcept {
  return std::rotl(value, static_cast<int>(shift & 31u));
}

inline constexpr std::uint32_t Mask32(std::uint32_t mb,
                                      std::uint32_t me) noexcept {
  const std::uint32_t left = 0xffffffffu >> (mb & 31u);
  const std::uint32_t right = 0xffffffffu << (31u - (me & 31u));
  return mb <= me ? left & right : left | right;
}

inline constexpr std::uint32_t ShiftLeftWord(std::uint32_t value,
                                             std::uint32_t shift) noexcept {
  return (shift & 0x20u) != 0 ? 0u : value << (shift & 31u);
}

inline constexpr std::uint32_t ShiftRightWord(std::uint32_t value,
                                              std::uint32_t shift) noexcept {
  return (shift & 0x20u) != 0 ? 0u : value >> (shift & 31u);
}

inline constexpr std::uint32_t ShiftRightAlgebraic(std::uint32_t value,
                                                   std::uint32_t shift) noexcept {
  if ((shift & 0x20u) != 0)
    return (value & 0x80000000u) != 0 ? 0xffffffffu : 0u;
  return static_cast<std::uint32_t>(
      static_cast<std::int32_t>(value) >> (shift & 31u));
}

inline constexpr std::uint32_t DivideWordUnsigned(std::uint32_t dividend,
                                                  std::uint32_t divisor) noexcept {
  return divisor == 0 ? 0u : dividend / divisor;
}

inline constexpr std::int32_t DivideWord(std::int32_t dividend,
                                         std::int32_t divisor) noexcept {
  if (divisor == 0 ||
      (dividend == std::numeric_limits<std::int32_t>::min() && divisor == -1))
    return dividend < 0 ? -1 : 0;
  return dividend / divisor;
}

inline constexpr std::uint32_t CountLeadingZero(std::uint32_t value) noexcept {
  return static_cast<std::uint32_t>(std::countl_zero(value));
}

struct IntegerResult32 {
  std::uint32_t value{};
  bool carry{};
  bool overflow{};
};

inline constexpr IntegerResult32 AddWord(std::uint32_t lhs, std::uint32_t rhs,
                                         bool carry_in = false) noexcept {
  const std::uint64_t wide = static_cast<std::uint64_t>(lhs) + rhs +
                             static_cast<std::uint32_t>(carry_in);
  const auto value = static_cast<std::uint32_t>(wide);
  const bool overflow = ((~(lhs ^ rhs) & (lhs ^ value)) & 0x80000000u) != 0;
  return {value, (wide >> 32) != 0, overflow};
}

inline constexpr IntegerResult32 SubtractWord(std::uint32_t subtrahend,
                                              std::uint32_t minuend,
                                              bool carry_in = true) noexcept {
  const std::uint64_t wide = static_cast<std::uint64_t>(minuend) +
      static_cast<std::uint32_t>(~subtrahend) +
      static_cast<std::uint32_t>(carry_in);
  const auto value = static_cast<std::uint32_t>(wide);
  const bool overflow = (((minuend ^ subtrahend) & (minuend ^ value)) &
                         0x80000000u) != 0;
  return {value, (wide >> 32) != 0, overflow};
}

inline constexpr std::uint32_t ConditionFieldSigned(std::int32_t lhs,
                                                    std::int32_t rhs,
                                                    std::uint32_t xer) noexcept {
  return (lhs < rhs ? 8u : 0u) | (lhs > rhs ? 4u : 0u) |
         (lhs == rhs ? 2u : 0u) | ((xer >> 31) & 1u);
}

inline constexpr std::uint32_t ConditionFieldFloat(double lhs,
                                                   double rhs) noexcept {
  if (std::isnan(lhs) || std::isnan(rhs))
    return 1u;
  return (lhs < rhs ? 8u : 0u) | (lhs > rhs ? 4u : 0u) |
         (lhs == rhs ? 2u : 0u);
}

struct FloatCompareResult {
  std::uint32_t condition{};
  std::uint32_t fpscr{};
  std::uint32_t exception{};
};

inline constexpr FloatCompareResult EvaluatePpcFloatCompare(
    std::uint32_t fpscr_value, double lhs, double rhs,
    bool ordered) noexcept {
  const std::uint32_t condition = ConditionFieldFloat(lhs, rhs);
  std::uint32_t exception = 0;
  if (std::isnan(lhs) || std::isnan(rhs)) {
    if (IsSignalingNan(lhs) || IsSignalingNan(rhs)) {
      exception |= fpscr::VXSNAN;
      if (ordered && (fpscr_value & fpscr::VE) == 0)
        exception |= fpscr::VXVC;
    } else if (ordered) {
      exception |= fpscr::VXVC;
    }
  }
  if (exception != 0)
    fpscr_value = SetFpscrException(fpscr_value, exception);
  fpscr_value = (fpscr_value & ~0x0000f000u) |
                ((condition & 0xfu) << 12);
  return {condition, fpscr_value, exception};
}

inline double Force25Bit(double value) noexcept {
  constexpr std::uint64_t exponent_mask = 0x7ff0000000000000ULL;
  constexpr std::uint64_t fraction_mask = 0x000fffffffffffffULL;
  std::uint64_t bits = std::bit_cast<std::uint64_t>(value);
  const std::uint64_t exponent = bits & exponent_mask;
  const std::uint64_t fraction = bits & fraction_mask;
  if (exponent == 0 && fraction != 0) {
    std::int64_t keep_mask = 0xfffffffff8000000LL;
    std::uint64_t round = 0x8000000ULL;
    std::uint32_t leading = 0;
    std::uint64_t normalized = fraction;
    while ((normalized & (1ULL << 63)) == 0) {
      normalized <<= 1;
      ++leading;
    }
    const std::uint32_t shift = leading - 11u;
    keep_mask >>= shift;
    round >>= shift;
    bits = (bits & static_cast<std::uint64_t>(keep_mask)) + (bits & round);
  } else {
    bits = (bits & 0xfffffffff8000000ULL) + (bits & 0x8000000ULL);
  }
  return std::bit_cast<double>(bits);
}

inline float ForceSingle(double value, bool non_ieee = false) noexcept {
  if (non_ieee && std::abs(value) < 0x1p-126)
    return std::copysign(0.0f, static_cast<float>(value));
  return static_cast<float>(value);
}

inline std::int32_t ConvertToIntegerWord(double value, int rounding_mode) noexcept {
  if (std::isnan(value))
    return std::numeric_limits<std::int32_t>::min();
  if (value >= 2147483647.0)
    return std::numeric_limits<std::int32_t>::max();
  if (value <= -2147483648.0)
    return std::numeric_limits<std::int32_t>::min();
  const double rounded = RoundToIntegerMode(value, rounding_mode);
  return static_cast<std::int32_t>(rounded);
}

struct EstimateEntry { std::int32_t base; std::int32_t decrement; };

inline constexpr std::array<EstimateEntry, 32> kFres = {{
    {0x7ff800,0x3e1},{0x783800,0x3a7},{0x70ea00,0x371},{0x6a0800,0x340},
    {0x638800,0x313},{0x5d6200,0x2ea},{0x579000,0x2c4},{0x520800,0x2a0},
    {0x4cc800,0x27f},{0x47ca00,0x261},{0x430800,0x245},{0x3e8000,0x22a},
    {0x3a2c00,0x212},{0x360800,0x1fb},{0x321400,0x1e5},{0x2e4a00,0x1d1},
    {0x2aa800,0x1be},{0x272c00,0x1ac},{0x23d600,0x19b},{0x209e00,0x18b},
    {0x1d8800,0x17c},{0x1a9000,0x16e},{0x17ae00,0x15b},{0x14f800,0x15b},
    {0x124400,0x143},{0x0fbe00,0x143},{0x0d3800,0x12d},{0x0ade00,0x12d},
    {0x088400,0x11a},{0x065000,0x11a},{0x041c00,0x108},{0x020c00,0x106}}};

inline constexpr std::array<EstimateEntry, 32> kFrsqrte = {{
    {0x1a7e800,-0x568},{0x17cb800,-0x4f3},{0x1552800,-0x48d},{0x130c000,-0x435},
    {0x10f2000,-0x3e7},{0x0eff000,-0x3a2},{0x0d2e000,-0x365},{0x0b7c000,-0x32e},
    {0x09e5000,-0x2fc},{0x0867000,-0x2d0},{0x06ff000,-0x2a8},{0x05ab800,-0x283},
    {0x046a000,-0x261},{0x0339800,-0x243},{0x0218800,-0x226},{0x0105800,-0x20b},
    {0x3ffa000,-0x7a4},{0x3c29000,-0x700},{0x38aa000,-0x670},{0x3572000,-0x5f2},
    {0x3279000,-0x584},{0x2fb7000,-0x524},{0x2d26000,-0x4cc},{0x2ac0000,-0x47e},
    {0x2881000,-0x43a},{0x2665000,-0x3fa},{0x2468000,-0x3c2},{0x2287000,-0x38e},
    {0x20c1000,-0x35e},{0x1f12000,-0x332},{0x1d79000,-0x30a},{0x1bf4000,-0x2e6}}};

inline double ApproximateReciprocal(double value) noexcept {
  constexpr std::uint64_t sign_mask = 1ULL << 63;
  constexpr std::uint64_t exponent_mask = 0x7ffULL << 52;
  constexpr std::uint64_t fraction_mask = (1ULL << 52) - 1;
  constexpr std::uint64_t quiet = 1ULL << 51;
  const auto input = std::bit_cast<std::uint64_t>(value);
  const auto mantissa = input & fraction_mask;
  const auto sign = input & sign_mask;
  auto exponent = input & exponent_mask;
  if (mantissa == 0 && exponent == 0)
    return std::bit_cast<double>(sign | exponent_mask);
  if (exponent == exponent_mask)
    return mantissa == 0 ? std::bit_cast<double>(sign)
                         : std::bit_cast<double>(input | quiet);
  if (exponent < (895ULL << 52))
    return std::copysign(static_cast<double>(std::numeric_limits<float>::max()), value);
  if (exponent >= (1149ULL << 52))
    return std::copysign(0.0, value);
  exponent = (0x7fdULL << 52) - exponent;
  const int index = static_cast<int>(mantissa >> 37);
  const auto &entry = kFres[static_cast<std::size_t>(index / 1024)];
  const std::int64_t estimate = entry.base -
      (static_cast<std::int64_t>(entry.decrement) * (index % 1024) + 1) / 2;
  return std::bit_cast<double>(sign | exponent |
                               (static_cast<std::uint64_t>(estimate) << 29));
}

inline double ApproximateReciprocalSquareRoot(double value) noexcept {
  constexpr std::uint64_t sign_mask = 1ULL << 63;
  constexpr std::uint64_t exponent_mask = 0x7ffULL << 52;
  constexpr std::uint64_t fraction_mask = (1ULL << 52) - 1;
  constexpr std::uint64_t quiet = 1ULL << 51;
  const auto input = std::bit_cast<std::uint64_t>(value);
  auto mantissa = input & fraction_mask;
  const auto sign = input & sign_mask;
  std::int64_t exponent = static_cast<std::int64_t>(input & exponent_mask);
  if (mantissa == 0 && exponent == 0)
    return std::bit_cast<double>(sign | exponent_mask);
  if (static_cast<std::uint64_t>(exponent) == exponent_mask) {
    if (mantissa == 0)
      return sign ? std::bit_cast<double>(exponent_mask | quiet) : 0.0;
    return std::bit_cast<double>(input | quiet);
  }
  if (sign)
    return std::bit_cast<double>(exponent_mask | quiet);
  if (exponent == 0) {
    do {
      exponent -= std::int64_t{1} << 52;
      mantissa <<= 1;
    } while ((mantissa & (1ULL << 52)) == 0);
    mantissa &= fraction_mask;
    exponent += std::int64_t{1} << 52;
  }
  const auto exponent_lsb = exponent & (std::int64_t{1} << 52);
  exponent = (((std::int64_t{0x3ff} << 52) -
               ((exponent - (std::int64_t{0x3fe} << 52)) / 2)) &
              static_cast<std::int64_t>(exponent_mask));
  const int index = static_cast<int>(
      (static_cast<std::uint64_t>(exponent_lsb) | mantissa) >> 37);
  const auto &entry = kFrsqrte[static_cast<std::size_t>(index / 2048)];
  const std::int64_t estimate = entry.base +
      static_cast<std::int64_t>(entry.decrement) * (index % 2048);
  return std::bit_cast<double>(static_cast<std::uint64_t>(exponent) |
                               (static_cast<std::uint64_t>(estimate) << 26));
}

struct PairedSingle { float ps0{}; float ps1{}; };

inline PairedSingle PsAdd(PairedSingle a, PairedSingle b) noexcept {
  return {a.ps0 + b.ps0, a.ps1 + b.ps1};
}
inline PairedSingle PsSub(PairedSingle a, PairedSingle b) noexcept {
  return {a.ps0 - b.ps0, a.ps1 - b.ps1};
}
inline PairedSingle PsMul(PairedSingle a, PairedSingle b) noexcept {
  return {a.ps0 * b.ps0, a.ps1 * b.ps1};
}
inline PairedSingle PsDiv(PairedSingle a, PairedSingle b) noexcept {
  return {a.ps0 / b.ps0, a.ps1 / b.ps1};
}
inline PairedSingle PsMadd(PairedSingle a, PairedSingle c,
                           PairedSingle b) noexcept {
  return {std::fma(a.ps0, c.ps0, b.ps0), std::fma(a.ps1, c.ps1, b.ps1)};
}
inline PairedSingle PsMsub(PairedSingle a, PairedSingle c,
                           PairedSingle b) noexcept {
  return {std::fma(a.ps0, c.ps0, -b.ps0), std::fma(a.ps1, c.ps1, -b.ps1)};
}
inline PairedSingle PsNmadd(PairedSingle a, PairedSingle c,
                            PairedSingle b) noexcept {
  const auto value=PsMadd(a,c,b);
  return {std::isnan(value.ps0)?value.ps0:-value.ps0,
          std::isnan(value.ps1)?value.ps1:-value.ps1};
}
inline PairedSingle PsNmsub(PairedSingle a, PairedSingle c,
                            PairedSingle b) noexcept {
  const auto value=PsMsub(a,c,b);
  return {std::isnan(value.ps0)?value.ps0:-value.ps0,
          std::isnan(value.ps1)?value.ps1:-value.ps1};
}
inline PairedSingle PsMadds0(PairedSingle a, PairedSingle c,
                             PairedSingle b) noexcept {
  return {std::fma(a.ps0,c.ps0,b.ps0),std::fma(a.ps1,c.ps0,b.ps1)};
}
inline PairedSingle PsMadds1(PairedSingle a, PairedSingle c,
                             PairedSingle b) noexcept {
  return {std::fma(a.ps0,c.ps1,b.ps0),std::fma(a.ps1,c.ps1,b.ps1)};
}
inline PairedSingle PsMuls0(PairedSingle a, PairedSingle c) noexcept {
  return {a.ps0*c.ps0,a.ps1*c.ps0};
}
inline PairedSingle PsMuls1(PairedSingle a, PairedSingle c) noexcept {
  return {a.ps0*c.ps1,a.ps1*c.ps1};
}
inline PairedSingle PsNeg(PairedSingle value) noexcept {
  return {-value.ps0,-value.ps1};
}
inline PairedSingle PsAbs(PairedSingle value) noexcept {
  return {std::abs(value.ps0),std::abs(value.ps1)};
}
inline PairedSingle PsNabs(PairedSingle value) noexcept {
  return {-std::abs(value.ps0),-std::abs(value.ps1)};
}
inline PairedSingle PsSum0(PairedSingle a,PairedSingle b,
                           PairedSingle c) noexcept {
  return {static_cast<float>(static_cast<double>(a.ps0)+b.ps1),c.ps1};
}
inline PairedSingle PsSum1(PairedSingle a,PairedSingle b,
                           PairedSingle c) noexcept {
  return {c.ps0,static_cast<float>(static_cast<double>(a.ps0)+b.ps1)};
}
inline PairedSingle PsMerge00(PairedSingle a,PairedSingle b) noexcept {
  return {a.ps0,b.ps0};
}
inline PairedSingle PsMerge01(PairedSingle a, PairedSingle b) noexcept {
  return {a.ps0, b.ps1};
}
inline PairedSingle PsMerge10(PairedSingle a,PairedSingle b) noexcept {
  return {a.ps1,b.ps0};
}
inline PairedSingle PsMerge11(PairedSingle a,PairedSingle b) noexcept {
  return {a.ps1,b.ps1};
}
inline PairedSingle PsSelect(PairedSingle positive, PairedSingle control,
                             PairedSingle negative) noexcept {
  return {control.ps0 >= -0.0f ? positive.ps0 : negative.ps0,
          control.ps1 >= -0.0f ? positive.ps1 : negative.ps1};
}

inline PairedSingle PsReciprocal(PairedSingle value) noexcept {
  return {static_cast<float>(ApproximateReciprocal(value.ps0)),
          static_cast<float>(ApproximateReciprocal(value.ps1))};
}
inline PairedSingle PsReciprocalSquareRoot(PairedSingle value) noexcept {
  return {static_cast<float>(ApproximateReciprocalSquareRoot(value.ps0)),
          static_cast<float>(ApproximateReciprocalSquareRoot(value.ps1))};
}

struct PairedFpResult {
  PairedSingle value{};
  std::uint32_t fpscr{};
  std::uint32_t exception{};
};

inline PairedFpResult FinishPpcPairedArithmetic(
    std::uint32_t original_fpscr, ScalarFpResult lane0,
    ScalarFpResult lane1) noexcept {
  const bool non_ieee = (original_fpscr & fpscr::NI) != 0;
  const PairedSingle value{ForceSingle(lane0.value, non_ieee),
                           ForceSingle(lane1.value, non_ieee)};
  auto final_fpscr = (lane1.fpscr & ~fpscr::ANY_E) |
                     (original_fpscr & fpscr::ANY_E);
  final_fpscr = SetFprf(final_fpscr, ClassifyFloat(value.ps0));
  final_fpscr = UpdateFpscrSummaries(final_fpscr);
  return {value, final_fpscr, lane0.exception | lane1.exception};
}

inline PairedFpResult EvaluatePpcPairedBinary(
    std::uint32_t fpscr_value, ScalarFpBinaryOperation operation,
    PairedSingle a, PairedSingle b) noexcept {
  const auto original_fpscr = fpscr_value;
  fpscr_value &= ~fpscr::ANY_E;
  if (operation == ScalarFpBinaryOperation::Multiply) {
    b.ps0 = static_cast<float>(Force25Bit(b.ps0));
    b.ps1 = static_cast<float>(Force25Bit(b.ps1));
  }
  const auto lane0 = EvaluatePpcScalarBinary(
      fpscr_value, operation, a.ps0, b.ps0, true);
  const auto lane1 = EvaluatePpcScalarBinary(
      lane0.fpscr, operation, a.ps1, b.ps1, true);
  return FinishPpcPairedArithmetic(original_fpscr, lane0, lane1);
}

inline PairedFpResult EvaluatePpcPairedFused(
    std::uint32_t fpscr_value, PairedSingle a, PairedSingle c,
    PairedSingle b, bool subtract, bool negative) noexcept {
  const auto original_fpscr = fpscr_value;
  fpscr_value &= ~fpscr::ANY_E;
  const auto lane0 = EvaluatePpcFused(fpscr_value, a.ps0, c.ps0, b.ps0,
                                      subtract, true, negative);
  const auto lane1 = EvaluatePpcFused(lane0.fpscr, a.ps1, c.ps1, b.ps1,
                                      subtract, true, negative);
  return FinishPpcPairedArithmetic(original_fpscr, lane0, lane1);
}

inline PairedFpResult EvaluatePpcPairedSum(
    std::uint32_t fpscr_value, PairedSingle a, PairedSingle b,
    PairedSingle c, bool sum1) noexcept {
  const auto original_fpscr = fpscr_value;
  const auto arithmetic = EvaluatePpcScalarBinary(
      fpscr_value & ~fpscr::ANY_E, ScalarFpBinaryOperation::Add,
      a.ps0, b.ps1, true);
  const bool non_ieee = (original_fpscr & fpscr::NI) != 0;
  const float sum = ForceSingle(arithmetic.value, non_ieee);
  const PairedSingle value = sum1
      ? PairedSingle{ForceSingle(c.ps0, non_ieee), sum}
      : PairedSingle{sum, ForceSingle(c.ps1, non_ieee)};
  auto final_fpscr = (arithmetic.fpscr & ~fpscr::ANY_E) |
                     (original_fpscr & fpscr::ANY_E);
  final_fpscr = SetFprf(final_fpscr, ClassifyFloat(sum));
  final_fpscr = UpdateFpscrSummaries(final_fpscr);
  return {value, final_fpscr, arithmetic.exception};
}

inline PairedFpResult EvaluatePpcPairedEstimate(
    std::uint32_t fpscr_value, PairedSingle input,
    bool reciprocal_sqrt) noexcept {
  std::uint32_t exception = 0;
  const auto classify_lane = [&](float lane) {
    if (reciprocal_sqrt && lane < 0.0f)
      exception |= fpscr::VXSQRT;
    else if (lane == 0.0f)
      exception |= fpscr::ZX;
    if (IsSignalingNan(lane))
      exception |= fpscr::VXSNAN;
  };
  classify_lane(input.ps0);
  classify_lane(input.ps1);
  if (exception != 0 || std::isnan(input.ps0) || std::isinf(input.ps0) ||
      std::isnan(input.ps1) || std::isinf(input.ps1))
    fpscr_value &= ~(fpscr::FR | fpscr::FI);
  if (exception != 0)
    fpscr_value = SetFpscrException(fpscr_value, exception);
  const bool non_ieee = (fpscr_value & fpscr::NI) != 0;
  const PairedSingle value = reciprocal_sqrt
      ? PairedSingle{
            ForceSingle(ApproximateReciprocalSquareRoot(input.ps0), non_ieee),
            ForceSingle(ApproximateReciprocalSquareRoot(input.ps1), non_ieee)}
      : PairedSingle{ForceSingle(ApproximateReciprocal(input.ps0), non_ieee),
                     ForceSingle(ApproximateReciprocal(input.ps1), non_ieee)};
  fpscr_value = SetFprf(fpscr_value, ClassifyFloat(value.ps0));
  return {value, fpscr_value, exception};
}

inline std::uint32_t ComparePairedLane(float lhs,float rhs) noexcept {
  if(std::isnan(lhs)||std::isnan(rhs)) return 1u;
  return (lhs<rhs?8u:0u)|(lhs>rhs?4u:0u)|(lhs==rhs?2u:0u);
}

enum class QuantizedType : std::uint32_t {
  Float = 0, Unsigned8 = 4, Unsigned16 = 5, Signed8 = 6, Signed16 = 7
};
struct Gqr { QuantizedType type{QuantizedType::Float}; std::uint32_t scale{}; };

inline float Dequantize(std::int32_t value, std::uint32_t scale) noexcept {
  const int exponent = scale < 32 ? -static_cast<int>(scale)
                                  : static_cast<int>(64u - scale);
  return std::ldexp(static_cast<float>(value), exponent);
}

template <typename T> inline T Quantize(float value, std::uint32_t scale) noexcept {
  const int exponent = scale < 32 ? static_cast<int>(scale)
                                  : -static_cast<int>(64u - scale);
  const float scaled = std::ldexp(value, exponent);
  const float low = static_cast<float>(std::numeric_limits<T>::min());
  const float high = static_cast<float>(std::numeric_limits<T>::max());
  return static_cast<T>(std::fmin(std::fmax(scaled, low), high));
}

inline std::uint32_t QuietFloatBits(std::uint32_t value) noexcept {
  return (value&0x7fffffffu)>0x7f800000u ? value|0x00400000u:value;
}
inline std::uint32_t StoreFloatBits(std::uint32_t value) noexcept {
  const auto magnitude=value&0x7fffffffu;
  if(magnitude<0x00800000u) return value&0x80000000u;
  return QuietFloatBits(value);
}

inline std::uint32_t ReadBigEndian32(const std::uint8_t* source) noexcept {
  return (static_cast<std::uint32_t>(source[0])<<24)|
         (static_cast<std::uint32_t>(source[1])<<16)|
         (static_cast<std::uint32_t>(source[2])<<8)|source[3];
}
inline std::uint16_t ReadBigEndian16(const std::uint8_t* source) noexcept {
  return static_cast<std::uint16_t>((source[0]<<8)|source[1]);
}
inline void WriteBigEndian16(std::uint8_t* destination,std::uint16_t value) noexcept {
  destination[0]=static_cast<std::uint8_t>(value>>8); destination[1]=static_cast<std::uint8_t>(value);
}
inline void WriteBigEndian32(std::uint8_t* destination,std::uint32_t value) noexcept {
  destination[0]=static_cast<std::uint8_t>(value>>24); destination[1]=static_cast<std::uint8_t>(value>>16);
  destination[2]=static_cast<std::uint8_t>(value>>8); destination[3]=static_cast<std::uint8_t>(value);
}

inline PairedSingle LoadQuantizedPair(const std::uint8_t* source,Gqr gqr,
                                      bool one) noexcept {
  switch(gqr.type) {
    case QuantizedType::Float: {
      const float first=std::bit_cast<float>(QuietFloatBits(ReadBigEndian32(source)));
      const float second=one?1.0f:std::bit_cast<float>(QuietFloatBits(ReadBigEndian32(source+4)));
      return {first,second};
    }
    case QuantizedType::Unsigned8:
      return {Dequantize(source[0],gqr.scale),one?1.0f:Dequantize(source[1],gqr.scale)};
    case QuantizedType::Unsigned16:
      return {Dequantize(ReadBigEndian16(source),gqr.scale),one?1.0f:Dequantize(ReadBigEndian16(source+2),gqr.scale)};
    case QuantizedType::Signed8:
      return {Dequantize(static_cast<std::int8_t>(source[0]),gqr.scale),one?1.0f:Dequantize(static_cast<std::int8_t>(source[1]),gqr.scale)};
    case QuantizedType::Signed16:
      return {Dequantize(static_cast<std::int16_t>(ReadBigEndian16(source)),gqr.scale),one?1.0f:Dequantize(static_cast<std::int16_t>(ReadBigEndian16(source+2)),gqr.scale)};
  }
  return {};
}

inline void StoreQuantizedPair(std::uint8_t* destination,Gqr gqr,bool one,
                               PairedSingle value) noexcept {
  switch(gqr.type) {
    case QuantizedType::Float:
      WriteBigEndian32(destination,StoreFloatBits(std::bit_cast<std::uint32_t>(value.ps0)));
      if(!one) WriteBigEndian32(destination+4,StoreFloatBits(std::bit_cast<std::uint32_t>(value.ps1)));
      break;
    case QuantizedType::Unsigned8:
      destination[0]=Quantize<std::uint8_t>(value.ps0,gqr.scale);
      if(!one) destination[1]=Quantize<std::uint8_t>(value.ps1,gqr.scale);
      break;
    case QuantizedType::Unsigned16:
      WriteBigEndian16(destination,Quantize<std::uint16_t>(value.ps0,gqr.scale));
      if(!one) WriteBigEndian16(destination+2,Quantize<std::uint16_t>(value.ps1,gqr.scale));
      break;
    case QuantizedType::Signed8:
      destination[0]=static_cast<std::uint8_t>(Quantize<std::int8_t>(value.ps0,gqr.scale));
      if(!one) destination[1]=static_cast<std::uint8_t>(Quantize<std::int8_t>(value.ps1,gqr.scale));
      break;
    case QuantizedType::Signed16:
      WriteBigEndian16(destination,static_cast<std::uint16_t>(Quantize<std::int16_t>(value.ps0,gqr.scale)));
      if(!one) WriteBigEndian16(destination+2,static_cast<std::uint16_t>(Quantize<std::int16_t>(value.ps1,gqr.scale)));
      break;
  }
}

}  // namespace kartpad::semantics
