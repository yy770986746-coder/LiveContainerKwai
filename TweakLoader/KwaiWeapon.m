// ============================================================
//  KwaiWeapon.m  v2  ——  延迟安装 + 重试
//  问题：Weapon* 类在 tweak 加载时可能还没注册
//  修复：延迟到 App 启动完成后重试
// ============================================================
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <string.h>

static void WLog(NSString *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    NSString *m = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], m];
    NSString *doc = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *p = [doc stringByAppendingPathComponent:@"kwlogin.log"];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:p];
    if (!fh) { [[NSFileManager defaultManager] createFileAtPath:p contents:nil attributes:nil];
               fh = [NSFileHandle fileHandleForWritingAtPath:p]; }
    if (fh) { [fh seekToEndOfFile]; [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]]; [fh closeFile]; }
}

// ---------- 伪装值 ----------
static NSString *gWModel = nil, *gWName = nil, *gWSerial = nil, *gWUUID = nil;
static NSString *gWIDFV = nil, *gWIDFA = nil;
static NSNumber *gWMemBytes = nil, *gWCPUCores = nil;

void KwaiWeaponSetValues(NSString *model, NSString *name, NSString *serial,
                          NSString *uuid, NSString *idfv, NSString *idfa,
                          NSNumber *mem, NSNumber *cores) {
    gWModel = model; gWName = name; gWSerial = serial; gWUUID = uuid;
    gWIDFV = idfv; gWIDFA = idfa; gWMemBytes = mem; gWCPUCores = cores;
    WLog(@"values: model=%@ serial=%@ idfv=%@ uuid=%@", model, serial, idfv, uuid);
}

// ---------- 字段替换 ----------
static id WReplace(NSString *key, id orig) {
    if (!key || ![key isKindOfClass:[NSString class]]) return orig;
    NSString *k = [key lowercaseString];
    if (gWModel && ([k containsString:@"model"] || [k containsString:@"machine"] ||
                    [k containsString:@"hardware"] || [k containsString:@"product"]))
        return gWModel;
    if (gWSerial && ([k containsString:@"serial"] || [k containsString:@"_sn"] || [k hasSuffix:@"sn"]))
        return gWSerial;
    if (gWUUID && ([k containsString:@"uuid"] || [k containsString:@"udid"]))
        return gWUUID;
    if (gWIDFV && [k containsString:@"idfv"]) return gWIDFV;
    if (gWIDFA && [k containsString:@"idfa"]) return gWIDFA;
    if (gWName && [k containsString:@"name"]) return gWName;
    if (gWMemBytes && ([k containsString:@"mem"] || [k containsString:@"ram"])) return gWMemBytes;
    if (gWCPUCores && ([k containsString:@"cpu"] || [k containsString:@"core"])) return gWCPUCores;
    return orig;
}

static id WProcess(id obj, int depth) {
    if (depth > 6 || !obj) return obj;
    if ([obj isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *out = [NSMutableDictionary dictionary];
        [(NSDictionary *)obj enumerateKeysAndObjectsUsingBlock:^(id k, id v, BOOL *stop){
            out[k] = WProcess(WReplace([k isKindOfClass:[NSString class]] ? k : nil, v), depth + 1);
        }];
        return out;
    }
    if ([obj isKindOfClass:[NSArray class]]) {
        NSMutableArray *out = [NSMutableArray array];
        for (id v in (NSArray *)obj) [out addObject:WProcess(v, depth + 1)];
        return out;
    }
    return obj;
}

// ---------- hook ----------
static id (*orig_sigDict)(id, SEL) = NULL;
static id (*orig_sig)(id, SEL) = NULL;
static int gWeaponHooked = 0;

static id kw_sigDict(id self, SEL _cmd) {
    id r = orig_sigDict ? orig_sigDict(self, _cmd) : nil;
    if (r) { WLog(@"[hook] %@ sigDict", NSStringFromClass([self class])); return WProcess(r, 0); }
    return r;
}
static id kw_sig(id self, SEL _cmd) {
    id r = orig_sig ? orig_sig(self, _cmd) : nil;
    if (r) return WProcess(r, 0);
    return r;
}

// 用类名列表精确 hook（不依赖类已注册）
static void WTryInstall(void) {
    static const char *names[] = {
        "WeaponDeviceInfoCollector", "WeaponDeviceNameCollector", "WeaponDeviceCpuCollector",
        "WeaponDeviceStartCollector", "WeaponBatteryCollector", "WeaponDiskCollector",
        "WeaponProcessCollector", "WeaponNetworkCollector", "WeaponSimCardCollector",
        "WeaponScreenCollector", "WeaponCameraCollector", "WeaponVolumeCollector",
        "WeaponAirPlaneCollector", "WeaponFingerprintCollector", "WeaponRealFingerComponent",
        "WeaponIDFVCollector", "WeaponIDFACollector", "WeaponUmidCollector",
        "WeaponTdidCollector", "WeaponSessionUUIDCollector", "WeaponAppInfoCollector",
        "WeaponAppStoreCollector", "WeaponAppPrimaryKeyCollector", "WeaponLangCollector",
        "WeaponUerAgentCollector", "WeaponImageDyldCollector",
        "WeaponDataCollector", "WeaponDataProcessComponent",
        NULL
    };

    int hooked = 0;
    for (int i = 0; names[i]; i++) {
        Class c = NSClassFromString(@(names[i]));
        if (!c) continue;

        SEL s1 = NSSelectorFromString(@"collectInfoSigDict");
        Method m1 = class_getInstanceMethod(c, s1);
        if (m1 && !orig_sigDict) {
            orig_sigDict = (void *)method_getImplementation(m1);
            method_setImplementation(m1, (IMP)kw_sigDict);
            hooked++; gWeaponHooked++;
            WLog(@"[hook] %s sigDict OK", names[i]);
        }
        SEL s2 = NSSelectorFromString(@"collectInfoSig");
        Method m2 = class_getInstanceMethod(c, s2);
        if (m2 && !orig_sig) {
            orig_sig = (void *)method_getImplementation(m2);
            method_setImplementation(m2, (IMP)kw_sig);
            hooked++; gWeaponHooked++;
            WLog(@"[hook] %s sig OK", names[i]);
        }
    }
    WLog(@"try install: %d hooked (total %d)", hooked, gWeaponHooked);
}

void KwaiWeaponInstall(void) {
    static BOOL started = NO;
    if (started) return;
    started = YES;

    // ① 立即尝试
    WTryInstall();

    // ② 多次重试（Weapon 类可能延迟加载）
    for (int i = 1; i <= 10; i++) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 1.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            WTryInstall();
        });
    }

    // ③ App 启动完成后也试
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
        object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n){
        WTryInstall();
    }];

    WLog(@"Weapon install scheduled");
}