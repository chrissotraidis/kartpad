#include "ppc_runtime.h"
extern "C" bool baseline(unsigned op, double& d, double a, double b, double c) {
    switch (op) {
    case 0: return PpcFaddsStateInline(d, a, b);
    case 1: return PpcFsubsStateInline(d, a, b);
    case 2: return PpcFmulsStateInline(d, a, b);
    case 3: return PpcFdivsStateInline(d, a, b);
    case 4: return PpcFaddStateInline(d, a, b);
    case 5: return PpcFsubStateInline(d, a, b);
    case 6: return PpcFmulStateInline(d, a, b);
    case 7: return PpcFdivStateInline(d, a, b);
    case 8: return PpcFctiwzStateInline(d, a);
    case 9: return PpcFmaddsStateInline(d, a, c, b);
    case 10: return PpcFmsubsStateInline(d, a, c, b);
    case 11: return PpcFnmsubStateInline(d, a, c, b);
    case 12: return PpcFnmsubsStateInline(d, a, c, b);
    case 13: return PpcFrsqrteStateInline(d, a);
    default: std::abort();
    }
}
