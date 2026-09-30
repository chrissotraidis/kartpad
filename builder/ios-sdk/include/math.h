/* <math.h> for building KartPad iPhone game packs without Apple's SDK (see
 * builder/kartpad_builder/ios_sdk.py). Written for KartPad from the C standard
 * (C11 7.12) plus the POSIX constants; the functions are the iPhone libSystem's.
 * On arm64 Apple platforms float_t is float, double_t is double and long double
 * is double. Classification uses the compiler's builtins with libSystem's
 * FP_* values, so fpclassify() agrees with the library's __fpclassify. */
#ifndef __MATH_H__
#define __MATH_H__

#include <sys/cdefs.h>

#if !defined(__arm64__) && !defined(__aarch64__)
#error "KartPad's iOS <math.h> is for arm64 only"
#endif

__BEGIN_DECLS

typedef float float_t;
typedef double double_t;

#define HUGE_VAL  __builtin_huge_val()
#define HUGE_VALF __builtin_huge_valf()
#define HUGE_VALL __builtin_huge_vall()
#define INFINITY  __builtin_inff()
#define NAN       __builtin_nanf("0x7fc00000")

#define FP_NAN          1
#define FP_INFINITE     2
#define FP_ZERO         3
#define FP_NORMAL       4
#define FP_SUBNORMAL    5
#define FP_SUPERNORMAL  6

#define FP_FAST_FMA  1
#define FP_FAST_FMAF 1
#define FP_FAST_FMAL 1

#define FP_ILOGB0   (-2147483647 - 1)
#define FP_ILOGBNAN (-2147483647 - 1)

#define MATH_ERRNO     1
#define MATH_ERREXCEPT 2
extern int __math_errhandling(void);
#define math_errhandling (__math_errhandling())

#define fpclassify(x) __builtin_fpclassify(FP_NAN, FP_INFINITE, FP_NORMAL, FP_SUBNORMAL, FP_ZERO, (x))
#define isfinite(x)   __builtin_isfinite(x)
#define isinf(x)      __builtin_isinf(x)
#define isnan(x)      __builtin_isnan(x)
#define isnormal(x)   __builtin_isnormal(x)
#define signbit(x)    __builtin_signbit(x)
#define isgreater(x, y)      __builtin_isgreater((x), (y))
#define isgreaterequal(x, y) __builtin_isgreaterequal((x), (y))
#define isless(x, y)         __builtin_isless((x), (y))
#define islessequal(x, y)    __builtin_islessequal((x), (y))
#define islessgreater(x, y)  __builtin_islessgreater((x), (y))
#define isunordered(x, y)    __builtin_isunordered((x), (y))

/* Each function in its float, double and long double form. */
#define __KARTPAD_MATH_1(name) \
    extern float name##f(float); extern double name(double); extern long double name##l(long double);
#define __KARTPAD_MATH_2(name) \
    extern float name##f(float, float); extern double name(double, double); \
    extern long double name##l(long double, long double);

__KARTPAD_MATH_1(acos) __KARTPAD_MATH_1(asin) __KARTPAD_MATH_1(atan) __KARTPAD_MATH_2(atan2)
__KARTPAD_MATH_1(cos) __KARTPAD_MATH_1(sin) __KARTPAD_MATH_1(tan)
__KARTPAD_MATH_1(acosh) __KARTPAD_MATH_1(asinh) __KARTPAD_MATH_1(atanh)
__KARTPAD_MATH_1(cosh) __KARTPAD_MATH_1(sinh) __KARTPAD_MATH_1(tanh)
__KARTPAD_MATH_1(exp) __KARTPAD_MATH_1(exp2) __KARTPAD_MATH_1(expm1)
__KARTPAD_MATH_1(log) __KARTPAD_MATH_1(log10) __KARTPAD_MATH_1(log2) __KARTPAD_MATH_1(log1p)
__KARTPAD_MATH_1(logb) __KARTPAD_MATH_1(fabs) __KARTPAD_MATH_1(cbrt) __KARTPAD_MATH_2(hypot)
__KARTPAD_MATH_2(pow) __KARTPAD_MATH_1(sqrt) __KARTPAD_MATH_1(erf) __KARTPAD_MATH_1(erfc)
__KARTPAD_MATH_1(lgamma) __KARTPAD_MATH_1(tgamma) __KARTPAD_MATH_1(ceil) __KARTPAD_MATH_1(floor)
__KARTPAD_MATH_1(nearbyint) __KARTPAD_MATH_1(rint) __KARTPAD_MATH_1(round) __KARTPAD_MATH_1(trunc)
__KARTPAD_MATH_2(fmod) __KARTPAD_MATH_2(remainder) __KARTPAD_MATH_2(copysign)
__KARTPAD_MATH_2(nextafter) __KARTPAD_MATH_2(fdim) __KARTPAD_MATH_2(fmax) __KARTPAD_MATH_2(fmin)

#undef __KARTPAD_MATH_1
#undef __KARTPAD_MATH_2

extern float modff(float, float *);
extern double modf(double, double *);
extern long double modfl(long double, long double *);
extern float ldexpf(float, int);
extern double ldexp(double, int);
extern long double ldexpl(long double, int);
extern float frexpf(float, int *);
extern double frexp(double, int *);
extern long double frexpl(long double, int *);
extern int ilogbf(float);
extern int ilogb(double);
extern int ilogbl(long double);
extern float scalbnf(float, int);
extern double scalbn(double, int);
extern long double scalbnl(long double, int);
extern float scalblnf(float, long int);
extern double scalbln(double, long int);
extern long double scalblnl(long double, long int);
extern long int lrintf(float);
extern long int lrint(double);
extern long int lrintl(long double);
extern long long int llrintf(float);
extern long long int llrint(double);
extern long long int llrintl(long double);
extern long int lroundf(float);
extern long int lround(double);
extern long int lroundl(long double);
extern long long int llroundf(float);
extern long long int llround(double);
extern long long int llroundl(long double);
extern float remquof(float, float, int *);
extern double remquo(double, double, int *);
extern long double remquol(long double, long double, int *);
extern float nanf(const char *);
extern double nan(const char *);
extern long double nanl(const char *);
extern float nexttowardf(float, long double);
extern double nexttoward(double, long double);
extern long double nexttowardl(long double, long double);
extern float fmaf(float, float, float);
extern double fma(double, double, double);
extern long double fmal(long double, long double, long double);

#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
#define M_E        2.71828182845904523536028747135266250
#define M_LOG2E    1.44269504088896340735992468100189214
#define M_LOG10E   0.434294481903251827651128918916605082
#define M_LN2      0.693147180559945309417232121458176568
#define M_LN10     2.30258509299404568401799145468436421
#define M_PI       3.14159265358979323846264338327950288
#define M_PI_2     1.57079632679489661923132169163975144
#define M_PI_4     0.785398163397448309615660845819875721
#define M_1_PI     0.318309886183790671537767526745028724
#define M_2_PI     0.636619772367581343075535053490057448
#define M_2_SQRTPI 1.12837916709551257389615890312154517
#define M_SQRT2    1.41421356237309504880168872420969808
#define M_SQRT1_2  0.707106781186547524400844362104849039
#define MAXFLOAT   0x1.fffffep+127f
#define HUGE       MAXFLOAT
#endif

__END_DECLS

#endif /* __MATH_H__ */
