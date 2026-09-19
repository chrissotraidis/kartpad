#pragma once
#import <Foundation/Foundation.h>

// Local system diagnostics only. Never uploads or installs a signal handler.
FOUNDATION_EXPORT void KartPadSystemDiagnosticsStart(void);
FOUNDATION_EXPORT NSString *KartPadSystemDiagnosticsReport(void);

FOUNDATION_EXPORT BOOL KartPadSystemDiagnosticsIsCandidate(void);
FOUNDATION_EXPORT void KartPadDiagnosticCrashProbe(void);
