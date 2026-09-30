/* TargetConditionals.h for building KartPad iPhone game packs without Apple's
 * SDK (see builder/kartpad_builder/ios_sdk.py). Written for KartPad: it names
 * the one target a pack is built for, an arm64 iPhone or iPad. */
#ifndef __TARGETCONDITIONALS__
#define __TARGETCONDITIONALS__

#if !defined(__APPLE__) || !(defined(__arm64__) || defined(__aarch64__)) || \
    !defined(__ENVIRONMENT_IPHONE_OS_VERSION_MIN_REQUIRED__)
#error "KartPad's iOS headers only build for arm64 iPhone and iPad (arm64-apple-ios)"
#endif

#define TARGET_OS_MAC 1
#define TARGET_OS_IPHONE 1
#define TARGET_OS_IOS 1
#define TARGET_OS_EMBEDDED 1
#define TARGET_OS_UNIX 0
#define TARGET_OS_OSX 0
#define TARGET_OS_MACCATALYST 0
#define TARGET_OS_UIKITFORMAC 0
#define TARGET_OS_TV 0
#define TARGET_OS_WATCH 0
#define TARGET_OS_VISION 0
#define TARGET_OS_XR 0
#define TARGET_OS_BRIDGE 0
#define TARGET_OS_DRIVERKIT 0
#define TARGET_OS_SIMULATOR 0
#define TARGET_OS_NANO 0
#define TARGET_OS_WIN32 0
#define TARGET_OS_WINDOWS 0
#define TARGET_OS_LINUX 0
#define TARGET_IPHONE_SIMULATOR 0

#define TARGET_CPU_ARM64 1
#define TARGET_CPU_ARM 0
#define TARGET_CPU_X86 0
#define TARGET_CPU_X86_64 0
#define TARGET_CPU_PPC 0
#define TARGET_CPU_PPC64 0
#define TARGET_CPU_68K 0
#define TARGET_CPU_ALPHA 0
#define TARGET_CPU_MIPS 0
#define TARGET_CPU_SPARC 0

#define TARGET_RT_LITTLE_ENDIAN 1
#define TARGET_RT_BIG_ENDIAN 0
#define TARGET_RT_64_BIT 1
#define TARGET_RT_MAC_CFM 0
#define TARGET_RT_MAC_MACHO 1
#define TARGET_ABI_USES_IOS_VALUES 1

#endif /* __TARGETCONDITIONALS__ */
