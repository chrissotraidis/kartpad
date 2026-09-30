/* <fenv.h> for building KartPad iPhone game packs without Apple's SDK (see
 * builder/kartpad_builder/ios_sdk.py). Written for KartPad from the C standard.
 * The values are the arm64 architecture's own: exception flags are the FPSR
 * cumulative bits and rounding modes the FPCR RMode field, which is what the
 * iPhone's libSystem reads and writes. */
#ifndef __FENV_H__
#define __FENV_H__

#include <sys/cdefs.h>

#if !defined(__arm64__) && !defined(__aarch64__)
#error "KartPad's iOS <fenv.h> is for arm64 only"
#endif

__BEGIN_DECLS

typedef struct {
    unsigned long long __fpsr;
    unsigned long long __fpcr;
} fenv_t;

typedef unsigned short fexcept_t;

#define FE_INVALID      0x0001
#define FE_DIVBYZERO    0x0002
#define FE_OVERFLOW     0x0004
#define FE_UNDERFLOW    0x0008
#define FE_INEXACT      0x0010
#define FE_FLUSHTOZERO  0x0080 /* input denormal flushed to zero (FPSR.IDC) */
#define FE_ALL_EXCEPT   0x009f

#define FE_TONEAREST    0x00000000
#define FE_UPWARD       0x00400000
#define FE_DOWNWARD     0x00800000
#define FE_TOWARDZERO   0x00C00000

extern const fenv_t _FE_DFL_ENV;
#define FE_DFL_ENV (&_FE_DFL_ENV)
extern const fenv_t _FE_DFL_DISABLE_DENORMS_ENV;
#define FE_DFL_DISABLE_DENORMS_ENV (&_FE_DFL_DISABLE_DENORMS_ENV)

extern int feclearexcept(int);
extern int fegetexceptflag(fexcept_t *, int);
extern int feraiseexcept(int);
extern int fesetexceptflag(const fexcept_t *, int);
extern int fetestexcept(int);
extern int fegetround(void);
extern int fesetround(int);
extern int fegetenv(fenv_t *);
extern int feholdexcept(fenv_t *);
extern int fesetenv(const fenv_t *);
extern int feupdateenv(const fenv_t *);

__END_DECLS

#endif /* __FENV_H__ */
