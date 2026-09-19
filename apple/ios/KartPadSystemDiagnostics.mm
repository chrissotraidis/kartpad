#import "KartPadSystemDiagnostics.h"
#import <MetricKit/MetricKit.h>
#import <CommonCrypto/CommonDigest.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#include <unistd.h>

static const NSUInteger MaximumPayload = 1024 * 1024;
static const NSUInteger MaximumReports = 8;

static NSURL *DiagnosticDirectory(void) {
    NSURL *documents = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory
                                                           inDomains:NSUserDomainMask].firstObject;
    return [[documents.URLByResolvingSymlinksInPath URLByAppendingPathComponent:@"Diagnostics" isDirectory:YES]
            URLByAppendingPathComponent:@"System" isDirectory:YES];
}

static dispatch_queue_t DiagnosticQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ queue = dispatch_queue_create("dev.kartpad.system-diagnostics", DISPATCH_QUEUE_SERIAL); });
    return queue;
}

static NSArray<NSURL *> *DiagnosticFiles(void) {
    NSArray *files = [NSFileManager.defaultManager contentsOfDirectoryAtURL:DiagnosticDirectory()
        includingPropertiesForKeys:@[NSURLContentModificationDateKey, NSURLIsRegularFileKey, NSURLIsSymbolicLinkKey]
        options:NSDirectoryEnumerationSkipsHiddenFiles error:nil] ?: @[];
    NSMutableArray *accepted = [NSMutableArray new];
    for (NSURL *url in files) {
        NSNumber *regular = nil, *symlink = nil;
        [url getResourceValue:&regular forKey:NSURLIsRegularFileKey error:nil];
        [url getResourceValue:&symlink forKey:NSURLIsSymbolicLinkKey error:nil];
        if (regular.boolValue && !symlink.boolValue && [url.pathExtension isEqualToString:@"json"] &&
            [url.lastPathComponent hasPrefix:@"metrickit-"]) [accepted addObject:url];
    }
    return [accepted sortedArrayUsingComparator:^NSComparisonResult(NSURL *a, NSURL *b) {
        NSDate *ad = nil, *bd = nil;
        [a getResourceValue:&ad forKey:NSURLContentModificationDateKey error:nil];
        [b getResourceValue:&bd forKey:NSURLContentModificationDateKey error:nil];
        return [(bd ?: NSDate.distantPast) compare:(ad ?: NSDate.distantPast)];
    }];
}

@interface KartPadSystemDiagnosticSubscriber : NSObject <MXMetricManagerSubscriber>
@end

@implementation KartPadSystemDiagnosticSubscriber
- (void)didReceiveDiagnosticPayloads:(NSArray<MXDiagnosticPayload *> *)payloads {
    // MetricKit supplies system-collected crash/hang/CPU call stacks. Collection
    // may be unavailable on a particular install; absence is never a clean bill.
    for (MXDiagnosticPayload *payload in payloads) {
        NSData *data = [payload JSONRepresentation];
        if (!data || data.length > MaximumPayload) continue;
        dispatch_async(DiagnosticQueue(), ^{
            NSURL *directory = DiagnosticDirectory();
            if (!directory || ![directory.URLByResolvingSymlinksInPath.path isEqualToString:directory.path]) return;
            if (![NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:nil]) return;
            unsigned char digest[CC_SHA256_DIGEST_LENGTH];
            CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
            NSMutableString *hash = [NSMutableString new];
            for (unsigned char byte : digest) [hash appendFormat:@"%02x", byte];
            NSURL *file = [directory URLByAppendingPathComponent:[NSString stringWithFormat:@"metrickit-%@.json", hash]];
            if (![data writeToURL:file options:NSDataWritingAtomic error:nil]) return;
            NSArray *files = DiagnosticFiles();
            for (NSUInteger i = MaximumReports; i < files.count; ++i)
                [NSFileManager.defaultManager removeItemAtURL:files[i] error:nil];
        });
    }
}
@end

BOOL KartPadSystemDiagnosticsIsCandidate(void) {
    return [[NSBundle.mainBundle objectForInfoDictionaryKey:@"KartPadDiagnosticsCandidate"] boolValue];
}

__attribute__((noinline)) void KartPadDiagnosticCrashProbe(void) {
    if (!KartPadSystemDiagnosticsIsCandidate()) return;
    fprintf(stderr, "[KartPadDiagnosticTest] intentional_native_abort\n");
    fflush(stderr);
    abort();
}

void KartPadSystemDiagnosticsStart(void) {
    static KartPadSystemDiagnosticSubscriber *subscriber;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        if (KartPadSystemDiagnosticsIsCandidate()) {
        setenv("KARTPAD_RENDERER_VALIDATION", "1", 1);
        setenv("KARTPAD_FUNCTION_TIMING", "1", 1);
        }
        fprintf(stderr, "[KartPadSession] version=%s build=%s\n",
            [[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] UTF8String],
            [[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"] UTF8String]);
        subscriber = [KartPadSystemDiagnosticSubscriber new];
        [MXMetricManager.sharedManager addSubscriber:subscriber];
        // Independent of the UI/game thread: a stalled frame does not suppress
        // thermal/memory evidence. The native transcript retains this bounded rate.
        static dispatch_source_t healthTimer;
        healthTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, DiagnosticQueue());
        dispatch_source_set_timer(healthTimer, DISPATCH_TIME_NOW, 10*NSEC_PER_SEC, NSEC_PER_SEC);
        dispatch_source_set_event_handler(healthTimer, ^{
            static unsigned samples = 0;
            if (samples++ >= 720) { dispatch_source_cancel(healthTimer); return; }
            task_vm_info_data_t memory{};
            mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
            const bool available = task_info(mach_task_self(), TASK_VM_INFO,
                reinterpret_cast<task_info_t>(&memory), &count) == KERN_SUCCESS;
            char footprint[32]{};
            if (available) snprintf(footprint, sizeof(footprint), "%llu", (unsigned long long)memory.phys_footprint);
            else snprintf(footprint, sizeof(footprint), "null");
            fprintf(stderr, "[KartPadHealth] {\"schema\":2,\"pid\":%d,\"unix_ms\":%lld,\"elapsed_ms\":%lld,\"thermal_status\":%ld,\"thermal_scale\":\"apple_process_info\",\"power_save\":%s,\"pss_kib\":null,\"physical_footprint_bytes\":%s,\"final_sample\":%s}\n",
                getpid(), (long long)(NSDate.date.timeIntervalSince1970*1000),
                (long long)(NSProcessInfo.processInfo.systemUptime*1000),
                (long)NSProcessInfo.processInfo.thermalState,
                NSProcessInfo.processInfo.lowPowerModeEnabled ? "true" : "false", footprint,
                samples == 720 ? "true" : "false");
        });
        dispatch_resume(healthTimer);

        NSArray *past = MXMetricManager.sharedManager.pastDiagnosticPayloads;
        if (past.count) [subscriber didReceiveDiagnosticPayloads:past];
    });
}

// Only bounded text logs; never enumerate guest memory, saves or game assets.
static NSString *NativeRuntimeReport(void) {
    NSURL *home = [NSURL fileURLWithPath:NSHomeDirectory() isDirectory:YES].URLByResolvingSymlinksInPath;
    NSURL *root = [home URLByAppendingPathComponent:@"Library/Application Support/KartPad/Logs" isDirectory:YES];
    NSMutableString *out = [NSMutableString stringWithString:@"\n[Native runtime sessions]\nRecent sessions can include an earlier launch. Match session timestamp/PID and build. File tails are capped at 256 KiB.\n"];
    if (![root.URLByResolvingSymlinksInPath.path isEqualToString:root.path]) return [out stringByAppendingString:@"unavailable: redirected log directory\n"];
    NSArray *children = [NSFileManager.defaultManager contentsOfDirectoryAtURL:root includingPropertiesForKeys:@[NSURLContentModificationDateKey, NSURLIsDirectoryKey, NSURLIsSymbolicLinkKey] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil] ?: @[];
    NSMutableArray<NSURL *> *sessions = [NSMutableArray new];
    NSRegularExpression *pattern = [NSRegularExpression regularExpressionWithPattern:@"^(base|retro_rewind)_[0-9]+_pid[0-9]+$" options:0 error:nil];
    for (NSURL *url in children) {
        NSNumber *directory = nil, *link = nil;
        [url getResourceValue:&directory forKey:NSURLIsDirectoryKey error:nil];
        [url getResourceValue:&link forKey:NSURLIsSymbolicLinkKey error:nil];
        if (directory.boolValue && !link.boolValue && [pattern numberOfMatchesInString:url.lastPathComponent options:0 range:NSMakeRange(0,url.lastPathComponent.length)]) [sessions addObject:url];
    }
    [sessions sortUsingComparator:^NSComparisonResult(NSURL *a, NSURL *b) {
        NSDate *ad = nil, *bd = nil;
        [a getResourceValue:&ad forKey:NSURLContentModificationDateKey error:nil];
        [b getResourceValue:&bd forKey:NSURLContentModificationDateKey error:nil];
        return [(bd ?: NSDate.distantPast) compare:(ad ?: NSDate.distantPast)];
    }];
    NSUInteger exported = 0;
    for (NSURL *session in [sessions subarrayWithRange:NSMakeRange(0, MIN((NSUInteger)3, sessions.count))]) {
        NSArray<NSURL *> *files = [NSFileManager.defaultManager contentsOfDirectoryAtURL:session includingPropertiesForKeys:@[NSURLIsRegularFileKey, NSURLIsSymbolicLinkKey, NSURLFileSizeKey] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
        for (NSURL *file in [files sortedArrayUsingComparator:^NSComparisonResult(NSURL *a,NSURL *b){ return [a.lastPathComponent compare:b.lastPathComponent]; }]) {
            NSString *name = file.lastPathComponent;
            if (![name isEqualToString:@"console.log"] && !([name hasPrefix:@"crash_"] && [name hasSuffix:@".txt"])) continue;
            NSNumber *regular = nil, *link = nil, *size = nil;
            [file getResourceValue:&regular forKey:NSURLIsRegularFileKey error:nil];
            [file getResourceValue:&link forKey:NSURLIsSymbolicLinkKey error:nil];
            [file getResourceValue:&size forKey:NSURLFileSizeKey error:nil];
            if (!regular.boolValue || link.boolValue || exported >= 12) continue;
            NSFileHandle *handle = [NSFileHandle fileHandleForReadingFromURL:file error:nil];
            if (!handle) continue;
            const unsigned long long limit = 256 * 1024;
            const NSUInteger headerLimit = 16 * 1024;
            BOOL shortened = size.unsignedLongLongValue > limit;
            NSData *headerData = shortened ? [handle readDataUpToLength:headerLimit error:nil] : nil;
            unsigned long long offset = shortened ? size.unsignedLongLongValue - (limit - headerData.length) : 0;
            NSError *error = nil;
            if (![handle seekToOffset:offset error:&error]) { [handle closeAndReturnError:nil]; continue; }
            NSData *data = [handle readDataUpToLength:limit-headerData.length error:&error];
            [handle closeAndReturnError:nil];
            NSString *text = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
            // A tail may start inside one UTF-8 scalar. Recover only that prefix.
            for (NSUInteger skip=1; !text && skip <= 3 && skip < data.length; ++skip)
                text = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(skip,data.length-skip)] encoding:NSUTF8StringEncoding];
            NSString *headerText = headerData ? [[NSString alloc] initWithData:headerData encoding:NSUTF8StringEncoding] : nil;
            [out appendFormat:@"\n--- %@/%@ bytes_omitted=%llu ---\n", session.lastPathComponent,name,offset-headerData.length];
            if (shortened) [out appendFormat:@"%@\n[KartPad: middle omitted; recent tail follows]\n", headerText ?: @"header unavailable: UTF-8 boundary"];
            [out appendFormat:@"%@\n",text ?: @"unavailable: unreadable UTF-8 log"];
            ++exported;
        }
    }
    [out appendFormat:@"native_log_files=%lu\n", (unsigned long)exported];
    NSString *redacted = [out stringByReplacingOccurrencesOfString:NSHomeDirectory() withString:@"<app-container>"];
    return [redacted stringByReplacingOccurrencesOfString:home.path withString:@"<app-container>"];
}

NSString *KartPadSystemDiagnosticsReport(void) {
    NSMutableString *report = [NSMutableString stringWithString:
        @"\n[Apple system diagnostics]\nMetricKit reports are system-delivered and may describe an earlier session/build. Match their timestamps, app version and binary UUIDs. No report means unavailable, not no crash.\n"];
    // Identify the installed Mach-O for exact dSYM matching; no container path.
    const struct mach_header *header = _dyld_get_image_header(0);
    if (header && header->magic == MH_MAGIC_64) {
        const char *cursor = (const char *)header + sizeof(struct mach_header_64);
        const char *end = cursor + header->sizeofcmds;
        for (uint32_t i = 0; i < header->ncmds && cursor + sizeof(struct load_command) <= end; ++i) {
            const struct load_command *command = (const struct load_command *)cursor;
            if (command->cmdsize < sizeof(*command) || command->cmdsize > (size_t)(end - cursor)) break;
            if (command->cmd == LC_UUID && command->cmdsize >= sizeof(struct uuid_command)) {
                const struct uuid_command *uuid = (const struct uuid_command *)command;
                NSUUID *value = [[NSUUID alloc] initWithUUIDBytes:uuid->uuid];
                [report appendFormat:@"export_time_executable_uuid=%@\n", value.UUIDString];
            }
            cursor += command->cmdsize;
        }
    }
    dispatch_sync(DiagnosticQueue(), ^{
        NSArray *files = DiagnosticFiles();
        [report appendFormat:@"retained_diagnostic_payloads=%lu\n", (unsigned long)files.count];
        for (NSURL *file in [files subarrayWithRange:NSMakeRange(0, MIN(MaximumReports, files.count))]) {
            NSNumber *size = nil;
            [file getResourceValue:&size forKey:NSURLFileSizeKey error:nil];
            if (!size || size.unsignedLongLongValue > MaximumPayload) continue;
            NSData *data = [NSData dataWithContentsOfURL:file options:0 error:nil];
            if (data.length > MaximumPayload) continue;
            NSString *text = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
            if (text) [report appendFormat:@"\n--- %@ ---\n%@\n", file.lastPathComponent, text];
        }
    });
    [report appendString:@"\nIf the matching crash is absent, iOS Settings > Privacy & Security > Analytics & Improvements > Analytics Data may contain a KartPad .ips or JetsamEvent report. Memory-pressure kills may have no crash stack. Review system reports before sharing. No automatic upload occurs.\n"];
    [report appendString:NativeRuntimeReport()];
    return report;
}
