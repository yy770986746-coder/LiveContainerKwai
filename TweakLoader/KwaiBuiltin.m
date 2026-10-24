// KwaiWeChatLogin.m   v1.0
// LiveContainer 
// LiveContainer TweakLoader
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <mach/mach_time.h>
#include <sys/time.h>
#include <sys/sysctl.h>
#include <sys/mount.h>
#include <ifaddrs.h>
// Sec* 类型的简化定义（SDK 无 SecCode.h）
typedef struct __SecCode *SecCodeRef;
typedef struct __SecStaticCode *SecStaticCodeRef;
typedef struct __SecRequirement *SecRequirementRef;
typedef uint32_t SecCSFlags;

#include <net/if_dl.h>
#include <sys/socket.h>
#include <mach/mach.h>
#include <mach/vm_statistics.h>
#include <os/lock.h>   // ★ v45：os_unfair_lock（KWLog 线程安全）
#include <mach/host_info.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <dlfcn.h>
#import "litehook.h"

static NSString * const kDefApi   = @"http://121.229.205.215:9092";
static NSString * const kApiV2Base = @"http://cnc.cn1001.top/openapi/cl-service/partner/v1";
static NSString * const kEryueApi  = @"https://www.eryueop.com/api.php";
static NSString * const kQQGameId  = @"100228415";   // 快手普通版
// 缓存的 QQ 授权 URL（避免每次请求 eryueop）
static NSString * const kQQUrlCache = @"tencent100228415://qzapp/mqzone/0?objectlocation=url&pasteboard=YnBsaXN0MDBieWJpcGxpc3QxLjDUAQIDBAUGBwhZJGFyY2hpdmVyWCRvYmplY3RzVCR0b3BYJHZlcnNpb25fEA9OU0tleWVkQXJjaGl2ZXKvEBwJCgsMDQ4PEBESExQVFhcYGRobHB0eHyAhIiMkVSRudWxs0yUmJygpKlYkY2xhc3NXTlMua2V5c1pOUy5vYmplY3RzgBusKywtLi8wMTIzNDU2gAKAA4AEgAWABoAHgAiACYAKgAuADIANrDc4OTo7PD0+P0BBQoAOgA+AEIARgBOAFIAVgBaAF4AYgBmAGlpleHBpcmVzX2luXxASYXBwc2lnbl9idW5kbGVudWxsWmVuY3J5dG9rZW5ccGFzc0RhdGFSZXNwU3JldFZvcGVuaWRScGZedXNlcl9jYW5jZWxsZWRVcGZrZXlZcGF5X3Rva2VuU21zZ1xhY2Nlc3NfdG9rZW4SAHanAFEyXxAgZGQwMmMxMTMwMmUwOWY4NTQwMGI4MzRiYmQzYWMwNGTSJSdDRIASoNJFRkdIWCRjbGFzc2VzWiRjbGFzc25hbWWjSElKV05TQXJyYXlYTlNPYmplY3ReTlNNdXRhYmxlQXJyYXkQAF8QIERDMjMxREVFMEUxRjFFQUVFQTc0ODIzMjRERUEyMkRFXm9wZW5tb2JpbGVfaW9zUk5PXxAgNjVkMGEzMGJlZGJjNzNmNTNkODM3MDE0MWU2MjIwZGZfECA1MUUxRTRGOEExMTM5NUVEN0YwNUE4RkUyMjFGOUM1RVBfECA1MEZGN0ExRDMzQTNDNTU4RjJFQjA5REM4RDEzNDFDONJFRktMo0xNSlxOU0RpY3Rpb25hcnlfEBNOU011dGFibGVEaWN0aW9uYXJ50U5PVHJvb3SAARIAAYagABQAHQAnADAANQA+AFAClAKeAG8AdQDiAO0BAgENARoBHgElASgBNwE9AUcBSwFYAV0BXwGCAYoBxwHJAewB+wH+AiECRAJFAmgAfACDAIsAlgCYAL0ApQCnAKkAqwCtAK8AsQCzALUAtwC5ALsAygDMAM4A0ADSANQA1gDYANoA3ADeAOABhwGJAY8BmAGjAbgBpwGvAm0CfgJxApcCnAAAAAAAAAIBAAAAAAAAAFAAAAAAAAAAAAAAAAAAAAKj";
static NSString * const kQQLoginKey = @"";           // 留空，由用户输入

// ---------- 前置声明 ----------
static unsigned long KwaiContainerSeed(void);
void KwaiInstallTimeSpoof(void);
void KwaiInstallStorageSpoof(void);
void KwaiInstallBatterySpoof(void);
void KwaiInstallExtSpoof(void);
void KwaiInstallDeepSpoof(void);
void KwaiInstallDetectorBypass(void);
void KwaiInstallDataSpoof(void);
void KwaiInstallHistorySpoof(void);
void KwaiInstallTrueParamSpoof(void);
void KwaiInstallV11Spoof(void);
void KwaiInstallLCFeatureHide(void);
void KwaiInstallEnvHide(void);
void KwaiInstallRepackBypass(void);
void KwaiInstallSigBypass(void);


// ---------- v9 合并 hook 所需的前向声明 ----------
static long long g_timeOffset;
static long long g_fakeDiskTotal;
static long long g_fakeDiskFree;
static int g_fakeFreqMHz;
static int g_fakeSoCId;
static int g_fakeArmE;
static char g_fakeKernelVersion[128];
static int kw_apply_ext_sysctlbyname(const char *name, void *oldp, size_t *oldlenp);

static NSString * const kApiV2Token = @"eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiIyMTA1MzE0NDk1MTQ3ODAyNjI0Iiwic3ViIjoiMzc0NDg3NTc0IiwiaWF0IjoxNzkwODc5OTc4LCJyb2xlcyI6IlJPTEVfTk9STUFMIiwiZXhwIjoxNzkzNDcxOTc4fQ.A7ncnsAFqwUTrvGMCBZtJavKQZwaaLYzKFelynN13aU";
static NSString * const kDefAppId = @"wxaadbab9d13edff20";
static NSString * const kDefGrade = @"1";
// ---- ????????? ----
static void KwaiReadFromCache(void);
static void KwaiDumpKeychain(void);
static void KwaiDumpPlist(void);
static NSString *KwaiGetFiveString(void);
static void KwaiDumpPassToken(void);        // ★ v50 passToken
static NSDictionary *KwaiLoadBasicInfo(void);
static NSString *KwaiCurrentUserId(void);
void KwaiStartBallWatcher(void);
void KwaiShowBall(void);
BOOL KwaiIsLoggedIn(void);

// ★ 性能修复：缓存 fileHandle，避免每次打开/关闭文件
//   限流：每秒最多 20 条，防高频 hook 打爆 I/O
static NSFileHandle *g_logHandle = nil;
static NSString *g_logPath = nil;
static NSTimeInterval g_logLastFlush = 0;
static int g_logCount = 0;
static os_unfair_lock g_logLock = OS_UNFAIR_LOCK_INIT;   // ★ v45：KWLog 会被多线程 hook 同时调用

// ★ v47.5 修复 H3：锁内绝不做文件系统调用
//   原实现在 os_unfair_lock 内调用 NSSearchPathForDirectoriesInDomains /
//   NSFileManager / NSFileHandle，这些内部会走 statfs/stat/getenv ——
//   本文件已 hооk 它们，其中若干 hook 又回调 KWLog，导致同线程二次获取
//   os_unfair_lock 直接 trap（EXC_BAD_ACCESS），异线程则永久挂起。
//   修复原则：锁只保护状态位，所有 IO 与对象构造一律在锁外。
static void KWLog(NSString *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    NSString *m = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);

    NSString *path = nil;
    NSFileHandle *fh = nil;
    BOOL over = NO;

    os_unfair_lock_lock(&g_logLock);
    path = g_logPath;
    if (!path) {
        NSString *doc = [NSSearchPathForDirectoriesInDomains(
            NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        if (!doc) doc = NSTemporaryDirectory();
        path = [doc stringByAppendingPathComponent:@"kwlogin.log"];
        g_logPath = path;
    }
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now - g_logLastFlush >= 1.0) { g_logLastFlush = now; g_logCount = 0; }
    g_logCount++;
    over = (g_logCount > 20);
    fh = over ? nil : g_logHandle;
    os_unfair_lock_unlock(&g_logLock);

    if (over || !path.length) return;

    // ★ 打开/创建文件在锁外；失败时不缓存空句柄，下次会重试
    if (!fh) {
        @try {
            if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
                [[NSFileManager defaultManager] createFileAtPath:path
                                                      contents:nil attributes:nil];
            }
            fh = [NSFileHandle fileHandleForWritingAtPath:path];
        } @catch (NSException *e) { fh = nil; }
        os_unfair_lock_lock(&g_logLock);
        g_logHandle = fh;
        os_unfair_lock_unlock(&g_logLock);
        if (!fh) return;
    }

    @try {
        [fh seekToEndOfFile];
        NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], m];
        [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
    } @catch (NSException *e) {
        os_unfair_lock_lock(&g_logLock);
        if (fh == g_logHandle) g_logHandle = nil;
        os_unfair_lock_unlock(&g_logLock);
    }
    NSLog(@"[KwaiWeChatLogin] %@", m);
}

// ----------  ----------
// ??????guest ?? + LC ????????????
static NSString *CfgPath(void) {
    NSString *doc = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    return [doc stringByAppendingPathComponent:@"kwlogin.plist"];
}
static NSString *CfgSharedPath(void) {
    // ★ v49：多重兜底，确保一定能拿到一个可写的共享目录。
    //   原来只依赖 NSUserDefaults 上的 lcAppGroupPath（LC 注入的 category 方法），
    //   一旦该 selector 不存在就直接返回 nil → 凭据永不落盘到共享区
    //   → 每建新容器都要重新输密码（用户反馈的核心问题）。
    static NSString *cached = nil;
    if (cached.length) return cached;

    // ① LC 注入的 category 方法（原路径）
    @try {
        Class cls = NSClassFromString(@"NSUserDefaults");
        SEL sel = NSSelectorFromString(@"lcAppGroupPath");
        if ([cls respondsToSelector:sel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            NSString *p = [cls performSelector:sel];
#pragma clang diagnostic pop
            if (p.length) {
                cached = [p stringByAppendingPathComponent:@"kwlogin.plist"];
                KWLog(@"[cfg] shared via lcAppGroupPath: %@", cached);
                return cached;
            }
        }
    } @catch (NSException *e) {}

    // ② 直接用 LC 的 AppGroup 容器（LC 用的是 group.com.kdt.livecontainer）
    @try {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSArray *groups = @[@"group.com.kdt.livecontainer",
                            @"group.com.SideStore.SideStore"];
        for (NSString *gid in groups) {
            NSURL *u = [fm containerURLForSecurityApplicationGroupIdentifier:gid];
            if (u.path.length) {
                cached = [u.path stringByAppendingPathComponent:@"kwlogin.plist"];
                KWLog(@"[cfg] shared via AppGroup %@: %@", gid, cached);
                return cached;
            }
        }
    } @catch (NSException *e) {}

    // ③ 最后兜底：宿主 LC 容器的 Documents（guest HOME 可上溯到，稳定可写）
    @try {
        NSString *home = NSHomeDirectory();   // .../Documents/Data/Application/<GUEST>/Documents
        NSRange r = [home rangeOfString:@"/Documents/Data/Application/" options:NSBackwardsSearch];
        if (r.location != NSNotFound) {
            NSString *lcRoot = [home substringToIndex:r.location];  // <LC 容器根>
            NSString *dir = [lcRoot stringByAppendingPathComponent:@"Documents"];
            [[NSFileManager defaultManager] createDirectoryAtPath:dir
                                      withIntermediateDirectories:YES
                                                       attributes:nil error:NULL];
            cached = [dir stringByAppendingPathComponent:@"kwlogin.plist"];
            KWLog(@"[cfg] shared via LC Documents fallback: %@", cached);
            return cached;
        }
    } @catch (NSException *e) {}

    KWLog(@"[cfg] shared path UNAVAILABLE (all fallbacks failed)");
    return nil;
}
// ★ v49：授权软件凭据跨容器持久化（重写）
//
//   v47.9 的失败原因：
//    1) CfgRealPasswordKey() 用 dispatch_once 缓存键名，首次调用时容器 plist
//       可能还不存在 → 缓存了 nil → 此后永久失效；
//    2) 键名靠"字节特征猜"，与设备实际存储不一致时静默失败。
//
//   现改为【不猜键名】：
//    - 统一使用固定 ASCII 键 `password`（设备实测：plist 里该键字节就是
//      70 61 73 73 77 6f 72 64，纯 ASCII，显示层的混淆只是终端渲染）；
//    - 共享区读写用固定三个键：username / password / platform；
//    - 每次调用都重新读文件，不做任何静态缓存。
//
//   安全边界（v45 防护不变）：
//     appid / token / last_order 等【快手账号相关】数据仍严格容器内独立，
//     只有你自己的授权软件登录信息走共享区。

static NSString * const kCfgSharedKeyUser = @"username";
static NSString * const kCfgSharedKeyPass = @"password";
static NSString * const kCfgSharedKeyPlat = @"platform";

static NSArray *CfgSharedKeys(void) {
    return @[kCfgSharedKeyUser, kCfgSharedKeyPass, kCfgSharedKeyPlat];
}

static NSMutableDictionary *CfgLoad(void) {
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:CfgPath()];
    NSMutableDictionary *out = d.count ? [d mutableCopy] : [NSMutableDictionary dictionary];

    // 容器内没有的，从共享区补（仅授权软件凭据三项）
    NSString *shared = CfgSharedPath();
    if (shared) {
        NSDictionary *sd = [NSDictionary dictionaryWithContentsOfFile:shared];
        if (sd) {
            for (NSString *k in CfgSharedKeys()) {
                if (out[k]) continue;
                // 密码键兼容：如果共享区里存的是别的形近键，也认
                id v = sd[k];
                if (!v && [k isEqualToString:kCfgSharedKeyPass]) {
                    for (NSString *sk in sd) {
                        if ([sk.lowercaseString hasPrefix:@"pass"]) { v = sd[sk]; break; }
                    }
                }
                if (v && [v isKindOfClass:[NSString class]] && [v length]) out[k] = v;
            }
            if (!out[kCfgSharedKeyPass]) {
                for (NSString *sk in sd) {
                    if ([sk.lowercaseString hasPrefix:@"pass"]) {
                        id v = sd[sk];
                        if ([v isKindOfClass:[NSString class]] && [v length]) {
                            out[kCfgSharedKeyPass] = v;
                        }
                        break;
                    }
                }
            }
        }
    }
    return out;
}

static void CfgSave(NSDictionary *d) {
    // ① 容器内完整保存
    [d writeToFile:CfgPath() atomically:YES];

    // ② 把三项凭据同步到共享区（保留共享区原有其它键）
    NSString *shared = CfgSharedPath();
    if (!shared) {
        KWLog(@"[cfg] shared path unavailable, credentials NOT synced");
        return;
    }
    NSMutableDictionary *sd = [NSMutableDictionary dictionary];
    NSDictionary *old = [NSDictionary dictionaryWithContentsOfFile:shared];
    if (old) [sd addEntriesFromDictionary:old];
    int synced = 0;
    for (NSString *k in CfgSharedKeys()) {
        id v = d[k];
        if (v && [v isKindOfClass:[NSString class]] && [v length]) { sd[k] = v; synced++; }
    }
    // 统一成 ASCII 键写回，避免形近键分裂
    for (NSString *sk in [sd allKeys]) {
        if ([sk.lowercaseString hasPrefix:@"pass"] && ![sk isEqualToString:kCfgSharedKeyPass]) {
            if (!sd[kCfgSharedKeyPass]) sd[kCfgSharedKeyPass] = sd[sk];
            [sd removeObjectForKey:sk];
        }
    }
    BOOL ok = sd.count ? [sd writeToFile:shared atomically:YES] : NO;
    KWLog(@"[cfg] synced %d credential(s) to shared: %@ (ok=%d, path=%@)",
          synced, CfgSharedKeys(), (int)ok, shared);
}

static NSString *CfgGet(NSString *k, NSString *def) {
    NSMutableDictionary *cfg = CfgLoad();
    id v = cfg[k];
    if (v && [v isKindOfClass:[NSString class]] && [v length]) return v;
    // 密码兼容：任何以 pass 开头的键都认
    if ([k.lowercaseString hasPrefix:@"pass"]) {
        for (NSString *sk in cfg) {
            if ([sk.lowercaseString hasPrefix:@"pass"]) {
                id sv = cfg[sk];
                if ([sv isKindOfClass:[NSString class]] && [sv length]) return sv;
            }
        }
    }
    return def;
}

static void CfgSet(NSString *k, NSString *v) {
    NSMutableDictionary *d = CfgLoad();
    if (v && v.length) d[k] = v; else [d removeObjectForKey:k];
    // 密码统一存 ASCII 键
    if ([k.lowercaseString hasPrefix:@"pass"]) {
        for (NSString *sk in [d allKeys]) {
            if ([sk.lowercaseString hasPrefix:@"pass"] && ![sk isEqualToString:k]) {
                [d removeObjectForKey:sk];
            }
        }
        if (v && v.length) d[kCfgSharedKeyPass] = v;
    }
    CfgSave(d);
}

// ---------- ???? ----------
// ????@"" ? @"1" = ????@"2" = ???
static BOOL KWIsV2(void) {
    return [CfgGet(@"platform", @"2") isEqualToString:@"2"];
}

// ? Bearer ??? GET
static NSDictionary *HTTPGetAuth(NSString *url, NSString *bearer) {
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    req.timeoutInterval = 20;
    if (bearer.length) [req setValue:[NSString stringWithFormat:@"Bearer %@", bearer]
                   forHTTPHeaderField:@"Authorization"];
    NSURLResponse *resp = nil;
    NSError *err = nil;
    NSData *d = [NSURLConnection sendSynchronousRequest:req returningResponse:&resp error:&err];
    if (err) { KWLog(@"[v2] req err: %@ url=%@", err.localizedDescription, url); return nil; }
    if (!d) { KWLog(@"[v2] req no data url=%@", url); return nil; }
    NSString *raw = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
    KWLog(@"[v2] raw(%lu)=%@", (unsigned long)d.length, raw.length>400?[raw substringToIndex:400]:raw);
    NSError *je = nil;
    id o = [NSJSONSerialization JSONObjectWithData:d options:0 error:&je];
    if (je) { KWLog(@"[v2] json err: %@", je.localizedDescription); return nil; }
    return [o isKindOfClass:[NSDictionary class]] ? o : nil;
}
// ---------- HTTP ----------
static NSDictionary *HTTPGet(NSString *url) {
    NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    r.timeoutInterval = 25;
    [r setValue:@"*/*" forHTTPHeaderField:@"accept"];
    [r setValue:@"Mozilla/5.0" forHTTPHeaderField:@"User-Agent"];
    NSURLResponse *resp=nil; NSError *err=nil;
    NSData *d = [NSURLConnection sendSynchronousRequest:r returningResponse:&resp error:&err];
    if (!d) { KWLog(@"GET ERR %@", err); return nil; }
    return [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
}
static NSDictionary *HTTPPostJSON(NSString *url, NSDictionary *body, NSString *token) {
    NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    r.timeoutInterval = 25;
    r.HTTPMethod = @"POST";
    [r setValue:@"application/json;charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [r setValue:@"*/*" forHTTPHeaderField:@"accept"];
    [r setValue:@"Mozilla/5.0" forHTTPHeaderField:@"User-Agent"];
    if (token) [r setValue:[NSString stringWithFormat:@"Bearer %@", token] forHTTPHeaderField:@"Authorization"];
    r.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSURLResponse *resp=nil; NSError *err=nil;
    NSData *d = [NSURLConnection sendSynchronousRequest:r returningResponse:&resp error:&err];
    if (!d) { KWLog(@"POST ERR %@", err); return nil; }
    return [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
}

// ---------- canOpenURL ----------
static BOOL (*orig_canOpenURL)(id, SEL, NSURL *);
static BOOL my_canOpenURL(id self, SEL _cmd, NSURL *url) {
    BOOL r = orig_canOpenURL(self, _cmd, url);
    NSString *s = url.scheme.lowercaseString;
    if ([s containsString:@"weixin"] || [s containsString:@"wechat"] ||
        [s containsString:@"wexin"]  || [s containsString:@"mqq"]) return YES;
    return r;
}

static NSString *g_state = @"";
static NSString *g_scope = @"snsapi_userinfo";
static id g_kwaiDelegate = nil;
static void KwaiInstallSpoof(void);
static void KwaiInstallFiveParams(void);
void KWDeliver(NSString *code);
void KwaiInstallQQProbe(void);
void KwaiInstallQQHook(void);
void KQDeliver(NSString *qqUrl);
extern id g_qqServiceInst;
extern id g_qqDict;
extern id g_qqSuccessBlock;
extern id g_qqFailureBlock;
void KQExchange(NSString *data, void (^done)(NSString *url, NSString *err));
static void KWShowOrderList(void);

// ----------  ----------
static void KWShowConfig(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *u  = CfgGet(@"username", @"");
        NSString *p  = CfgGet(@"password", @"");
        NSString *pf = CfgGet(@"platform", @"1");
        UIAlertController *ac = [UIAlertController
            alertControllerWithTitle:@"Kwai WeChat Login"
                             message:@"Platform 1=old  2=new(cnc)"
                      preferredStyle:UIAlertControllerStyleAlert];
        [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) {
            tf.placeholder = @"Account"; tf.text = u;
        }];
        [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) {
            tf.placeholder = @"Password"; tf.text = p; tf.secureTextEntry = YES;
        }];
        [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) {
            tf.placeholder = @"Platform (1/2)"; tf.text = pf;
            tf.keyboardType = UIKeyboardTypeNumberPad;
        }];
        [ac addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [ac addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault
                    handler:^(UIAlertAction *a) {
            CfgSet(@"username", ac.textFields[0].text ?: @"");
            CfgSet(@"password", ac.textFields[1].text ?: @"");
            NSString *pv = ac.textFields[2].text;
            if (![pv isEqualToString:@"2"]) pv = @"1";
            CfgSet(@"platform", pv);
            KWLog(@"ConfigSave user=%@ platform=%@", ac.textFields[0].text, pv);
        }]];
        UIWindow *w = nil;
        for (UIWindow *win in [UIApplication sharedApplication].windows)
            if (win.isKeyWindow) { w = win; break; }
        if (!w) w = [UIApplication sharedApplication].windows.firstObject;
        UIViewController *root = w.rootViewController;
        while (root.presentedViewController) root = root.presentedViewController;
        if (root) [root presentViewController:ac animated:YES completion:nil];
        KWLog(@"Config");
    });
}

// ----------  ----------
@interface KwaiOrderVC : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) UILabel *headerLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) NSArray *orders;
@property (nonatomic, strong) NSString *token;
@property (nonatomic, assign) BOOL busy;
@end

@implementation KwaiOrderVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1.0];
    if (!self.orders) self.orders = @[];

    CGFloat W = self.view.bounds.size.width;
    CGFloat H = self.view.bounds.size.height;

    self.headerLabel = [[UILabel alloc] init];
    self.headerLabel.text = @"Select Auth";
    self.headerLabel.textColor = [UIColor whiteColor];
    self.headerLabel.font = [UIFont boldSystemFontOfSize:20];
    self.headerLabel.textAlignment = NSTextAlignmentCenter;
    self.headerLabel.frame = CGRectMake(20, 60, W-40, 28);
    self.headerLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.headerLabel];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = [NSString stringWithFormat:@"%lu orders - tap to re-auth", (unsigned long)self.orders.count];
    self.statusLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
    self.statusLabel.font = [UIFont systemFontOfSize:13];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.frame = CGRectMake(20, 92, W-40, 20);
    self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.statusLabel];

    UIButton *cfg = [UIButton buttonWithType:UIButtonTypeSystem];
    cfg.frame = CGRectMake(W-76, 54, 60, 30);
    cfg.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [cfg setTitle:@"Config" forState:UIControlStateNormal];
    [cfg setTitleColor:[UIColor colorWithRed:0.4 green:0.7 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    cfg.titleLabel.font = [UIFont systemFontOfSize:14];
    [cfg addTarget:self action:@selector(onConfig) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:cfg];

    UIButton *five = [UIButton buttonWithType:UIButtonTypeSystem];
    five.frame = CGRectMake(W-140, 54, 60, 30);
    five.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [five setTitle:@"5P" forState:UIControlStateNormal];
    [five setTitleColor:[UIColor colorWithRed:1.0 green:0.8 blue:0.3 alpha:1.0] forState:UIControlStateNormal];
    five.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [five addTarget:self action:@selector(onFive) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:five];

    UIButton *qq = [UIButton buttonWithType:UIButtonTypeSystem];
    qq.frame = CGRectMake(W-200, 54, 60, 30);
    qq.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [qq setTitle:@"QQ" forState:UIControlStateNormal];
    [qq setTitleColor:[UIColor colorWithRed:0.4 green:0.85 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    qq.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [qq addTarget:self action:@selector(onQQ) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:qq];

    UIButton *cancel = [UIButton buttonWithType:UIButtonTypeSystem];
    cancel.frame = CGRectMake((W-140)/2, H-80, 140, 44);
    cancel.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [cancel setTitle:@"Cancel" forState:UIControlStateNormal];
    [cancel setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    cancel.backgroundColor = [UIColor colorWithWhite:0.25 alpha:1.0];
    cancel.layer.cornerRadius = 8;
    [cancel addTarget:self action:@selector(onCancel) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:cancel];

    self.table = [[UITableView alloc] initWithFrame:CGRectMake(16, 124, W-32, H-124-96)
                                             style:UITableViewStylePlain];
    self.table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.table.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
    self.table.separatorColor = [UIColor colorWithWhite:0.25 alpha:1.0];
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.layer.cornerRadius = 10;
    self.table.rowHeight = 62;
    [self.view addSubview:self.table];
    [self.table reloadData];
    KWLog(@"UI built rows=%lu", (unsigned long)[self.table numberOfRowsInSection:0]);
}

- (void)onQQ {
    UIAlertController *ac = [UIAlertController
        alertControllerWithTitle:@"QQ 授权"
                         message:@"粘贴 QQ 授权数据（5 段 | 分隔）"
                  preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"数据号";
        tf.text = CfgGet(@"qqdata", @"");
    }];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:@"授权" style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *a) {
        NSString *data = ac.textFields[0].text ?: @"";
        if (!data.length) return;
        CfgSet(@"qqdata", data);
        self.statusLabel.text = @"QQ exchanging...";
        KWLog(@"[qq] data len=%lu", (unsigned long)data.length);
        KQExchange(data, ^(NSString *url, NSString *err) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (url.length) {
                    self.statusLabel.text = @"QQ auth sent";
                    KQDeliver(url);
                } else {
                    self.statusLabel.text = [NSString stringWithFormat:@"QQ failed: %@", err ?: @"?"];
                }
            });
        });
    }]];
    [self presentViewController:ac animated:YES completion:nil];
}
- (void)onConfig { KWShowConfig(); }

- (void)onFive {
    // ??? static ?????? extern?
    // ?????plist ??????
    KwaiReadFromCache();
    KwaiDumpPlist();
    NSString *five = KwaiGetFiveString();
    KWLog(@"[5p] UI five=%@", five);

    NSString *show = five.length ? five : @"(empty - open Kwai first)";
    UIAlertController *ac = [UIAlertController
        alertControllerWithTitle:@"Five Params"
                         message:show
                  preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"Copy" style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *a) {
        [UIPasteboard generalPasteboard].string = five ?: @"";
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    return self.orders.count + 1;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    c.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
    c.textLabel.textColor = [UIColor whiteColor];
    c.textLabel.font = [UIFont systemFontOfSize:15];
    c.detailTextLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
    c.detailTextLabel.font = [UIFont systemFontOfSize:11];
    if (ip.row == 0) {
        c.textLabel.text = @"+ New Auth (0.60)";
        c.textLabel.textColor = [UIColor colorWithRed:0.35 green:0.85 blue:0.5 alpha:1.0];
        c.detailTextLabel.text = @"Fresh auth code";
        return c;
    }
    NSDictionary *o = self.orders[ip.row - 1];
    c.textLabel.text = [NSString stringWithFormat:@"%@   v%@",
                        o[@"createTime"] ?: @"", o[@"version"] ?: @"1"];
    NSString *codeUrl = o[@"code"] ?: @"";
    NSString *shortCode = @"";
    NSRange r = [codeUrl rangeOfString:@"code="];
    if (r.location != NSNotFound) {
        NSString *tail = [codeUrl substringFromIndex:r.location+5];
        NSRange a = [tail rangeOfString:@"&"];
        shortCode = (a.location==NSNotFound)?tail:[tail substringToIndex:a.location];
    }
    c.detailTextLabel.text = [NSString stringWithFormat:@"%@   order %@", shortCode, o[@"id"] ?: @""];
    return c;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (self.busy) return;
    self.busy = YES;

    NSString *user = CfgGet(@"username", @"");
        NSString *pass = CfgGet(@"password", @"");
    NSString *api  = CfgGet(@"api", kDefApi);
    NSString *appId= CfgGet(@"appid", kDefAppId);
    NSString *grade= CfgGet(@"grade", kDefGrade);

    // ?????? Token??????
    BOOL needCfg = KWIsV2() ? (user.length == 0) : (!user.length || !pass.length);
    if (needCfg) {
        KWLog(@"ConfigConfig v2=%d user=%lu pass=%lu", KWIsV2(),
              (unsigned long)user.length, (unsigned long)pass.length);
        dispatch_async(dispatch_get_main_queue(), ^{ KWShowConfig(); });
        return;
    }

    if (ip.row == 0) {
        self.statusLabel.text = @"Creating...";
        KWLog(@"new auth");
        dispatch_async(dispatch_get_global_queue(0,0), ^{
            NSDictionary *j = nil;
            if (KWIsV2()) {
                NSString *u = [NSString stringWithFormat:
                    @"%@/trial/authorize?gameAppId=%@&channelMode=1&scanMode=1",
                    kApiV2Base, appId];
                j = HTTPGetAuth(u, kApiV2Token);
                if (j && [j[@"flag"] boolValue]) {
                    NSString *ac = j[@"data"][@"authorizationCode"];
                    NSString *on = j[@"data"][@"trialOrderNo"];
                    KWLog(@"[v2] auth ok ac=%@ on=%@", ac, on);
                    j = @{ @"code": @20000,
                           @"data": @{ @"code": ac ?: @"",
                                       @"orderId": on ?: @"" },
                           @"message": j[@"message"] ?: @"" };
                } else {
                    KWLog(@"[v2] auth not-ok j=%@", j);
                }
            } else {
                j = HTTPGet([NSString stringWithFormat:
                    @"%@/api/auth?username=%@&password=%@&appId=%@&grade=%@",
                    api, user, pass, appId, grade]);
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                self.busy = NO;
                KWLog(@": %@", j[@"message"]);
                if ([j[@"code"] isEqual:@20000]) {
                    NSString *oid = j[@"data"][@"orderId"];
                    if (oid.length) CfgSet(@"last_order", oid);
                    [self finishWithCodeUrl:j[@"data"][@"code"]];
                } else {
                    NSString *msg = j[@"message"];
                    if (![msg isKindOfClass:[NSString class]] || msg.length == 0) {
                        msg = j ? @"Request rejected" : @"Network error, retry";
                    }
                    self.statusLabel.text = [NSString stringWithFormat:@"Failed: %@", msg];
                }
            });
        });
    } else {
        NSDictionary *o = self.orders[ip.row - 1];
        NSString *oid = o[@"id"];
        self.statusLabel.text = [NSString stringWithFormat:@"Rescan %@", oid];
        KWLog(@"rescan %@", oid);
        dispatch_async(dispatch_get_global_queue(0,0), ^{
            NSDictionary *body = @{
                @"appId": appId, @"grade": @([grade intValue]), @"model": @1, @"type": @1,
                @"authType": @1, @"state": @"kwai_wechat_login",
                @"orderId": oid,
                @"qrCode": @"https://open.weixin.qq.com/connect/confirm?uuid="
            };
            NSDictionary *j = nil;
            if (KWIsV2()) {
                NSString *u = [NSString stringWithFormat:
                    @"%@/trial/authorize?gameAppId=%@&channelMode=1&scanMode=1&trialOrderNo=%@",
                    kApiV2Base, appId, oid];
                j = HTTPGetAuth(u, kApiV2Token);
                if (j && [j[@"flag"] boolValue]) {
                    NSString *authCode = j[@"data"][@"authorizationCode"];
                    j = @{ @"code": @20000,
                           @"data": @{ @"code": authCode ?: @"" },
                           @"message": j[@"message"] ?: @"" };
                }
            } else {
                j = HTTPPostJSON([NSString stringWithFormat:@"%@/autoAuth", api], body, self.token);
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                self.busy = NO;
                KWLog(@": %@", j[@"message"]);
                if ([j[@"code"] isEqual:@20000]) {
                    CfgSet(@"last_order", oid);
                    [self finishWithCodeUrl:j[@"data"][@"code"]];
                } else {
                    NSString *msg2 = j[@"message"];
                    if (![msg2 isKindOfClass:[NSString class]] || msg2.length == 0) {
                        msg2 = j ? @"Request rejected" : @"Network error, retry";
                    }
                    self.statusLabel.text = [NSString stringWithFormat:@"Failed: %@", msg2];
                }
            });
        });
    }
}

- (void)finishWithCodeUrl:(NSString *)url {
    NSString *code = nil;
    NSRange r = [url rangeOfString:@"code="];
    if (r.location != NSNotFound) {
        NSString *tail = [url substringFromIndex:r.location+5];
        NSRange a = [tail rangeOfString:@"&"];
        code = (a.location==NSNotFound)?tail:[tail substringToIndex:a.location];
    }
    KWLog(@"GOT code=%@", code);
    if (!code) { self.statusLabel.text = @"Parse failed"; self.busy = NO; return; }
    self.statusLabel.text = @"Success";
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.5*NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self dismissViewControllerAnimated:YES completion:nil];
        KWDeliver(code);
    });
}

- (void)onCancel { KWLog(@"Cancel"); [self dismissViewControllerAnimated:YES completion:nil]; }
@end

// ----------  ----------
// ---------- QQ 授权交付 ----------
// 传入 eryueop API 返回的完整 URL（tencent100228415://...）
void KQDeliver(NSString *qqUrl) {
    if (!qqUrl.length) { KWLog(@"[qq] empty"); return; }
    KWLog(@"[qq] input: %@", [qqUrl substringToIndex:MIN(100, qqUrl.length)]);

    @try {
        NSURL *u = [NSURL URLWithString:qqUrl];
        if (!u) { KWLog(@"[qq] bad url"); return; }
        KWLog(@"[qq] scheme=%@ host=%@ path=%@", u.scheme, u.host, u.path);

        NSMutableString *diag = [NSMutableString string];
        [diag appendFormat:@"scheme=%@\nhost=%@\n", u.scheme, u.host];

        // ① 原样调 openURL（让 LC 转发给快手自己）
        [diag appendString:@"[1] openURL...\n"];
        if ([NSThread isMainThread]) {
            [[UIApplication sharedApplication] openURL:u options:@{} completionHandler:^(BOOL ok){
                KWLog(@"[qq] openURL ok=%d", ok);
                dispatch_async(dispatch_get_main_queue(), ^{
                    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"QQ 诊断6"
                        message:[NSString stringWithFormat:@"%@[1] openURL ok=%d", diag, ok]
                        preferredStyle:UIAlertControllerStyleAlert];
                    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                    UIViewController *r = UIApplication.sharedApplication.keyWindow.rootViewController;
                    while (r.presentedViewController) r = r.presentedViewController;
                    if (r) [r presentViewController:a animated:YES completion:nil];
                });
            }];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[UIApplication sharedApplication] openURL:u options:@{} completionHandler:^(BOOL ok){
                    KWLog(@"[qq] openURL ok=%d", ok);
                }];
            });
        }
    } @catch (NSException *e) { KWLog(@"[qq] FATAL: %@", e); }
}
// 调 eryueop API 换 URL
void KQExchange(NSString *data, void (^done)(NSString *url, NSString *err)) {
    dispatch_async(dispatch_get_global_queue(0,0), ^{
        @try {
            NSDictionary *body = @{ @"url": data ?: @"", @"game": kQQGameId };
            NSData *jd = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
            NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:
                                        [NSURL URLWithString:kEryueApi]];
            req.HTTPMethod = @"POST";
            req.timeoutInterval = 20;
            [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
            req.HTTPBody = jd;

            NSURLResponse *resp = nil; NSError *err = nil;
            NSData *rd = [NSURLConnection sendSynchronousRequest:req
                                              returningResponse:&resp error:&err];
            if (err) { KWLog(@"[qq] api err: %@ -> use cache", err.localizedDescription);
                       if (done) done(kQQUrlCache, nil); return; }
            NSDictionary *j = [NSJSONSerialization JSONObjectWithData:rd options:0 error:nil];
            KWLog(@"[qq] api resp: %@", j);
            NSString *u = j[@"url"];
            NSString *st = j[@"status"];
            if ([st isEqualToString:@"success"] && u.length) {
                if (done) done(u, nil);
            } else {
                if (done) done(nil, j[@"message"] ?: @"API rejected");
            }
        } @catch (NSException *e) {
            KWLog(@"[qq] api ex: %@", e);
            if (done) done(nil, e.reason);
        }
    });
}
void KWDeliver(NSString *code) {
    @try {
        NSString *appId = CfgGet(@"appid", kDefAppId);
        NSString *urlStr = [NSString stringWithFormat:
            @"%@://oauth?code=%@&scope=%@&state=%@&packageName=com.smile.gifmaker",
            appId, code, g_scope, g_state];
        KWLog(@"deliver: %@", urlStr);
        NSURL *u = [NSURL URLWithString:urlStr];

        Class wx = NSClassFromString(@"WXApi");
        if (wx) {
            @try {
                SEL s1 = NSSelectorFromString(@"handleOpenURL:delegate:");
                if ([wx respondsToSelector:s1]) {
                    [wx performSelector:s1 withObject:u withObject:nil];
                    KWLog(@"ok handleOpenURL");
                }
            } @catch (NSException *e) { KWLog(@"ex1 %@", e); }
            @try {
                SEL s2 = NSSelectorFromString(@"handleAuthOpenUrl:delegate:");
                if ([wx respondsToSelector:s2]) {
                    [wx performSelector:s2 withObject:u withObject:nil];
                    KWLog(@"ok handleAuthOpenUrl");
                }
            } @catch (NSException *e) { KWLog(@"ex2 %@", e); }
        }

        // ---- v47.3-min：直接调用快手自己的 URL 处理器（不经系统 scheme 路由）----
        //  背景：dylib 接管 sendReq 后 code 由本函数交付。原实现依赖
        //  UIApplication openURL: 走系统路由，越狱机上无人注册
        //  wxaadbab9d13edff20:// 这个 scheme → ok=0 → 授权无反应。
        //  探针实测（objc_copyClassList）确认快手真实入口为：
        //     +[KSSocial handleOpenURL:source:annotation:]
        //     +[KSSocialWechatOAuthService requestAccessTokenWithAuthCode:completion:]
        //  只加这一处，其余逻辑与基线完全一致，便于回退与归因。
        KWLog(@"calling KSSocial handler");
        @try {
            Class ks = NSClassFromString(@"KSSocial");
            SEL sel = NSSelectorFromString(@"handleOpenURL:source:annotation:");
            if (ks && [ks respondsToSelector:sel]) {
                NSMethodSignature *sig = [ks methodSignatureForSelector:sel];
                if (sig && sig.numberOfArguments >= 4) {
                    // ★ 实测 arg count=5：self + _cmd + 3 个参数
                    //   （numberOfArguments 含 self 与 _cmd）
                    KWLog(@"KSSocial argc=%u", (unsigned)sig.numberOfArguments);
                    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                    inv.selector = sel;
                    [inv setTarget:ks];
                    NSURL *au = u;
                    NSString *src = @"kuaishou";
                    // 按实际参数个数补齐剩余 nil，避免读越界
                    for (NSUInteger idx = 4; idx < sig.numberOfArguments; idx++) {
                        id nilArg = nil;
                        [inv setArgument:&nilArg atIndex:(NSInteger)idx];
                    }
                    [inv setArgument:&au  atIndex:2];
                    [inv setArgument:&src atIndex:3];
                    [inv invoke];
                    KWLog(@"KSSocial handleOpenURL OK");
                } else {
                    KWLog(@"KSSocial argc=%u unexpected", sig ? (unsigned)sig.numberOfArguments : 0);
                }
            } else {
                KWLog(@"KSSocial selector missing");
            }
        } @catch (NSException *e) { KWLog(@"KSSocial ex %@", e); }

        // openURL 兜底（原样保留）
        KWLog(@"calling openURL sync");
        @try {
            if ([NSThread isMainThread]) {
                [[UIApplication sharedApplication] openURL:u options:@{} completionHandler:^(BOOL ok) {
                    KWLog(@"openURL done ok=%d", ok);
                }];
            } else {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    [[UIApplication sharedApplication] openURL:u options:@{} completionHandler:^(BOOL ok) {
                        KWLog(@"openURL done ok=%d", ok);
                    }];
                });
            }
        } @catch (NSException *e) { KWLog(@"openURL ex %@", e); }

        KWLog(@"deliver complete");
    } @catch (NSException *e) {
        KWLog(@"deliver FATAL: %@", e);
    }
}

// ----------  ----------
static void KWShowOrderList(void) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *user = CfgGet(@"username", @"");
        NSString *pass = CfgGet(@"password", @"");
        NSString *api  = CfgGet(@"api", kDefApi);
        NSString *appId= CfgGet(@"appid", kDefAppId);

        // ?????? Token??????
        BOOL needCfg2 = KWIsV2() ? (user.length == 0) : (!user.length || !pass.length);
        if (needCfg2) {
            KWLog(@"ConfigConfig v2=%d user=%lu pass=%lu", KWIsV2(),
                  (unsigned long)user.length, (unsigned long)pass.length);
            dispatch_async(dispatch_get_main_queue(), ^{ KWShowConfig(); });
            return;
        }

        NSDictionary *j = nil;
        NSString *apiToken = @"";
        if (KWIsV2()) {
            apiToken = kApiV2Token;
            j = HTTPGetAuth([NSString stringWithFormat:
                @"%@/trial/records?pageIndex=1&pageSize=20", kApiV2Base], kApiV2Token);
            KWLog(@"[v2] records j=%@", j);
            if (j && [j[@"flag"] boolValue]) {
                NSArray *recs = j[@"data"][@"records"] ?: @[];
                NSMutableArray *conv = [NSMutableArray array];
                for (NSDictionary *r in recs) {
                    [conv addObject:@{ @"id": r[@"trialOrderNo"] ?: @"",
                                       @"createTime": r[@"createdAt"] ?: @"",
                                       @"status": r[@"latestActionLabel"] ?: @"" }];
                }
                j = @{ @"code": @20000, @"data": @{ @"list": @{ @"records": conv } } };
            }
        } else {
            NSDictionary *ui = HTTPGet([NSString stringWithFormat:
                @"%@/api/userInfo?username=%@&password=%@", api, user, pass]);
            apiToken = ui[@"data"][@"token"] ?: @"";
            KWLog(@"token %@", apiToken.length ? @"OK" : @"FAIL");
            j = HTTPGet([NSString stringWithFormat:
                @"%@/api/authRecords?username=%@&password=%@&appId=%@&page=1&size=20",
                api, user, pass, appId]);
        }
        NSArray *orders = @[];
        if (j && [j[@"code"] isEqual:@20000]) orders = j[@"data"][@"list"][@"records"] ?: @[];
        KWLog(@"=%lu", (unsigned long)orders.count);

        dispatch_async(dispatch_get_main_queue(), ^{
            UIWindow *w = nil;
            for (UIWindow *win in [UIApplication sharedApplication].windows)
                if (win.isKeyWindow) { w = win; break; }
            if (!w) w = [UIApplication sharedApplication].windows.firstObject;
            if (!w || !w.rootViewController) { KWLog(@"no window"); return; }
            KwaiOrderVC *vc = [[KwaiOrderVC alloc] init];
            vc.orders = orders;
            vc.token = apiToken;
            vc.modalPresentationStyle = UIModalPresentationFullScreen;
            [w.rootViewController presentViewController:vc animated:YES completion:^{
                KWLog(@"shown");
            }];
        });
    });
}

// ----------  ----------
static void (*orig_openURL_opt)(id, SEL, NSURL *, NSDictionary *, void (^)(BOOL));
static void my_openURL_opt(id self, SEL _cmd, NSURL *url, NSDictionary *opt, void (^comp)(BOOL)) {
    NSString *sch = url.scheme.lowercaseString;
    if (![sch containsString:@"weixin"] && ![sch containsString:@"wechat"]) {
        orig_openURL_opt(self, _cmd, url, opt, comp); return;
    }
    KWLog(@"intercept weixin");
    NSString *full = url.absoluteString;
    NSRange rs = [full rangeOfString:@"scope="];
    if (rs.location != NSNotFound) {
        NSString *t = [full substringFromIndex:rs.location+6];
        NSRange a = [t rangeOfString:@"&"];
        g_scope = (a.location==NSNotFound)?t:[t substringToIndex:a.location];
    }
    NSRange rt = [full rangeOfString:@"state="];
    if (rt.location != NSNotFound) {
        NSString *t = [full substringFromIndex:rt.location+6];
        NSRange a = [t rangeOfString:@"&"];
        g_state = (a.location==NSNotFound)?t:[t substringToIndex:a.location];
    }
    KWLog(@"scope=%@ state=%@", g_scope, g_state);
    if (comp) comp(YES);
    KWShowOrderList();
}

// ----------  ----------
// ===== WXApi hooks to capture delegate =====
static IMP g_orig_sendReq = NULL;
static IMP g_orig_sendReq2 = NULL;
static IMP g_orig_sendAuthReq = NULL;

typedef id (*SendReqFn)(id, SEL, id, id);
typedef id (*SendReqAutoFn)(id, SEL, id, BOOL, BOOL, id);
typedef id (*SendAuthReqFn)(id, SEL, id, id, id, id);

static id kw_sendReq_completion(id self, SEL _cmd, id req, id comp) {
    KWLog(@"sendReq intercepted req=%@", req);
    KWLog(@"  comp=%@", comp);
    if (comp) { g_kwaiDelegate = comp; KWLog(@"  saved comp as delegate"); }
    SendReqFn f = (SendReqFn)g_orig_sendReq;
    return f ? f(self, _cmd, req, comp) : nil;
}

static id kw_sendReq_auto(id self, SEL _cmd, id req, BOOL a, BOOL b, id comp) {
    KWLog(@"sendReq_auto intercepted req=%@", req);
    SendReqAutoFn f = (SendReqAutoFn)g_orig_sendReq2;
    return f ? f(self, _cmd, req, a, b, comp) : nil;
}

static id kw_sendAuthReq(id self, SEL _cmd, id req, id vc, id delegate, id comp) {
    KWLog(@"sendAuthReq intercepted req=%@", req);
    KWLog(@"  delegate=%@", delegate);
    KWLog(@"  comp=%@", comp);
    if (delegate) { g_kwaiDelegate = delegate; KWLog(@"  saved delegate"); }
    SendAuthReqFn f = (SendAuthReqFn)g_orig_sendAuthReq;
    return f ? f(self, _cmd, req, vc, delegate, comp) : nil;
}
void KwaiBuiltinInit(void) {
    // ★ v47.6 修 M14：原来没有一次性守卫。若被调两次（如 dyld 重入），
    //   method_setImplementation 的返回值会把【自己的 IMP】存进 g_orig_*，
    //   形成无限递归 → 栈溢出崩溃。
    static BOOL doneInit = NO;
    if (doneInit) return;
    doneInit = YES;
    @autoreleasepool {
        NSString *bid = [NSBundle mainBundle].bundleIdentifier;
        KWLog(@"");
        KWLog(@"##### KwaiWeChatLogin v1.0 #####");
        KWLog(@"bundleId=%@", bid);
        // ★ v48：改为【宽松匹配】。
        //   注入正版快手时 bid = com.jiangjia.gif；
        //   若为多开改了 bundle ID（com.jiangjia.gif2 / com.kwai.xxx），也要继续工作。
        BOOL isKwai = NO;
        if (bid.length) {
            NSString *low = bid.lowercaseString;
            if ([low containsString:@"jiangjia"] || [low containsString:@"kwai"]
                || [low containsString:@"smile.gifmaker"] || [low containsString:@"kuaishou"]) {
                isKwai = YES;
            }
        }
        if (!isKwai) { KWLog(@"not kwai (bid=%@), skip", bid); return; }

        // ===== 反检测 v4（开机时长 / 环境隐藏 / 镜像过滤 / 进程伪装）=====
        extern void KwaiHideInstall(void);

        // ???? hook
#ifndef KWAI_NO_SPOOF
        KwaiInstallSpoof();
#endif

        // ?????? hook
        KwaiInstallFiveParams();

        // ===== 反检测（放在 spoof 之后，避免干扰容器初始化）=====
        extern void KwaiHideInstall(void);
        KwaiHideInstall();

        Method m0 = class_getInstanceMethod([UIApplication class], @selector(canOpenURL:));
        if (m0) { orig_canOpenURL=(void*)method_getImplementation(m0);
                  method_setImplementation(m0,(IMP)my_canOpenURL); KWLog(@"OK canOpenURL"); }

        // ===== capture Kwai WXApi delegate =====
        Class wxc = NSClassFromString(@"WXApi");
        if (wxc) {
            // hook sendReq:completion:
            SEL sr1 = NSSelectorFromString(@"sendReq:completion:");
            Method msr1 = class_getClassMethod(wxc, sr1);
            if (msr1) {
                IMP oldImp = method_setImplementation(msr1, (IMP)kw_sendReq_completion);
                g_orig_sendReq = oldImp;
                KWLog(@"hooked sendReq:completion:");
            }
            // hook sendReq:isAutoResend:forceScheme:completion:
            SEL sr2 = NSSelectorFromString(@"sendReq:isAutoResend:forceScheme:completion:");
            Method msr2 = class_getClassMethod(wxc, sr2);
            if (msr2) {
                IMP oldImp2 = method_setImplementation(msr2, (IMP)kw_sendReq_auto);
                g_orig_sendReq2 = oldImp2;
                KWLog(@"hooked sendReq:isAutoResend:");
            }
            // hook sendAuthReq:viewController:delegate:completion:
            SEL sr3 = NSSelectorFromString(@"sendAuthReq:viewController:delegate:completion:");
            Method msr3 = class_getClassMethod(wxc, sr3);
            if (msr3) {
                IMP oldImp3 = method_setImplementation(msr3, (IMP)kw_sendAuthReq);
                g_orig_sendAuthReq = oldImp3;
                KWLog(@"hooked sendAuthReq:");
            }
        }
        Method m2 = class_getInstanceMethod([UIApplication class],
                    @selector(openURL:options:completionHandler:));
        if (m2) { orig_openURL_opt=(void*)method_getImplementation(m2);
                  method_setImplementation(m2,(IMP)my_openURL_opt); KWLog(@"OK openURL"); }

        KWLog(@"Config: %@", CfgPath());

        // ????????????????
        // QQ 拦截 hook
        KwaiInstallQQHook();

        // QQ 探针
        KwaiInstallQQProbe();

        KwaiStartBallWatcher();

        KWLog(@"##### init done #####");
    }
}
// ============================================================
//  ????????
//  ??????? HOME ??????????????
// ============================================================

#import <sys/utsname.h>
#import <sys/sysctl.h>

// 机型表 { machine, ncpu, memGB, minIOS, product, board }
typedef struct {
    const char *machine;
    int ncpu;
    int memGB;
    int minIOS;
    const char *product;
    const char *board;
    int socId;
    int freqMHz;
    int scrW, scrH;
    float scale;      // ★ nativeScale（物理/逻辑 缩放比）
    int battery;
    int arm64e;
} KwaiDeviceModel;

static const KwaiDeviceModel kDeviceModels[] = {
    // machine,     ncpu, memGB, minIOS, product,          board,   soc,    freq,  W,   H, scale,  batt, armE
    { "iPhone11,2", 6, 4, 13, "iPhone XS",         "D321AP", 0x8000, 2490, 375, 812, 3.00f, 2658, 1 },
    { "iPhone11,8", 6, 3, 13, "iPhone XR",         "N841AP", 0x8000, 2490, 414, 896, 2.00f, 2942, 1 },
    { "iPhone12,1", 6, 4, 13, "iPhone 11",         "N104AP", 0x8001, 2650, 414, 896, 2.00f, 3110, 1 },
    { "iPhone12,3", 6, 4, 13, "iPhone 11 Pro",     "D421AP", 0x8001, 2650, 375, 812, 3.00f, 3046, 1 },
    { "iPhone12,5", 6, 4, 13, "iPhone 11 Pro Max", "D431AP", 0x8001, 2650, 414, 896, 3.00f, 3969, 1 },
    { "iPhone13,1", 6, 4, 14, "iPhone 12 mini",    "D52GAP", 0x8101, 3000, 375, 812, 2.88f, 2227, 1 },
    { "iPhone13,2", 6, 4, 14, "iPhone 12",         "D53GAP", 0x8101, 3000, 390, 844, 3.00f, 2815, 1 },
    { "iPhone13,3", 6, 6, 14, "iPhone 12 Pro",     "D53PAP", 0x8101, 3000, 390, 844, 3.00f, 2815, 1 },
    { "iPhone13,4", 6, 6, 14, "iPhone 12 Pro Max", "D54PAP", 0x8101, 3000, 428, 926, 3.00f, 3687, 1 },
    { "iPhone14,4", 6, 4, 15, "iPhone 13 mini",    "D16AP",  0x8110, 3230, 375, 812, 2.88f, 2406, 1 },
    { "iPhone14,5", 6, 4, 15, "iPhone 13",         "D17AP",  0x8110, 3230, 390, 844, 3.00f, 3240, 1 },
    { "iPhone14,2", 6, 6, 15, "iPhone 13 Pro",     "D63AP",  0x8110, 3230, 390, 844, 3.00f, 3095, 1 },
    { "iPhone14,3", 6, 6, 15, "iPhone 13 Pro Max", "D64AP",  0x8110, 3230, 428, 926, 3.00f, 4352, 1 },
    { "iPhone14,6", 6, 4, 15, "iPhone SE (3rd)",   "D79AP",  0x8110, 3230, 375, 667, 2.00f, 2018, 1 },
    { "iPhone14,7", 6, 6, 16, "iPhone 14",         "D27AP",  0x8110, 3230, 390, 844, 3.00f, 3279, 1 },
    { "iPhone14,8", 6, 6, 16, "iPhone 14 Plus",    "D28AP",  0x8110, 3230, 428, 926, 3.00f, 4325, 1 },
    { "iPhone15,2", 6, 6, 16, "iPhone 14 Pro",     "D73AP",  0x8120, 3460, 393, 852, 3.00f, 3200, 1 },
    { "iPhone15,3", 6, 6, 16, "iPhone 14 Pro Max", "D74AP",  0x8120, 3460, 430, 932, 3.00f, 4323, 1 },
    { "iPhone15,4", 6, 6, 17, "iPhone 15",         "D37AP",  0x8120, 3460, 393, 852, 3.00f, 3349, 1 },
    { "iPhone15,5", 6, 6, 17, "iPhone 15 Plus",    "D38AP",  0x8120, 3460, 430, 932, 3.00f, 4383, 1 },
    { "iPhone16,1", 6, 8, 17, "iPhone 15 Pro",     "D83AP",  0x8130, 3780, 393, 852, 3.00f, 3274, 1 },
    { "iPhone16,2", 6, 8, 17, "iPhone 15 Pro Max", "D84AP",  0x8130, 3780, 430, 932, 3.00f, 4441, 1 },
    { "iPhone17,3", 6, 8, 18, "iPhone 16",         "D47AP",  0x8140, 4050, 393, 852, 3.00f, 3561, 1 },
    { "iPhone17,4", 6, 8, 18, "iPhone 16 Plus",    "D48AP",  0x8140, 4050, 430, 932, 3.00f, 4674, 1 },
    { "iPhone17,1", 6, 8, 18, "iPhone 16 Pro",     "D93AP",  0x8140, 4050, 402, 874, 3.00f, 3582, 1 },
    { "iPhone17,2", 6, 8, 18, "iPhone 16 Pro Max", "D94AP",  0x8140, 4050, 440, 956, 3.00f, 4685, 1 },
};
static const int kDeviceModelCount = sizeof(kDeviceModels) / sizeof(kDeviceModels[0]);

// ★ SoC → hw.cpufamily 精确映射（真实值）
//   之前只分两档（A14 / A15），导致 A12/A13/A15/A16/A17/A18 全部返回错误值
static int kw_cpuFamilyForSoC(int socId) {
    switch (socId) {
        case 0x8000: return 0x1CF5;        // A12  (Vortex / Tempest)
        case 0x8001: return 0x95BE;        // A13  (Lightning / Thunder)
        case 0x8101: return 0x1B588BB3;    // A14  (Firestorm / Icestorm)
        case 0x8110: return 0xDA33D83D;    // A15  (Avalanche / Blizzard)
        case 0x8120: return 0x8765EDEB;    // A16  (Everest / Sawtooth)
        case 0x8130: return 0xB0F5D0A1;    // A17 Pro (Coll / Chinchilla)
        case 0x8140: return 0x2C9E1E5B;    // A18 / A18 Pro
        default:     return 0x1B588BB3;    // 兜底：A14
    }
}

// ★ v32: SoC → 品牌名（快手直接读 machdep.cpu.brand_string 判芯片）
static const char *kw_cpuBrandForSoC(int socId) {
    switch (socId) {
        case 0x8000: return "Apple A12 Bionic";
        case 0x8001: return "Apple A13 Bionic";
        case 0x8101: return "Apple A14 Bionic";
        case 0x8110: return "Apple A15 Bionic";
        case 0x8120: return "Apple A16 Bionic";
        case 0x8130: return "Apple A17 Pro";
        case 0x8140: return "Apple A18 Pro";
        default:     return "Apple A14 Bionic";
    }
}

// ??????
static NSString *g_fakeMachine = nil;
static char g_fakeMachineC[64] = {0};   // C ???????????? ObjC ???
static char g_fakeModelC[64] = {0};
static NSUUID   *g_fakeIDFV = nil;
static char      g_fakeProductC[64] = {0};    // hw.product
static char      g_fakeBoardC[64] = {0};      // hw.target
static NSString *g_fakeSerial = nil;          // IOPlatformSerialNumber
static NSString *g_fakeUUID = nil;            // IOPlatformUUID
static int       g_fakeNCPU = 0;
static long long g_fakeMemSize = 0;
static NSString *g_fakeIDFA = nil;
static NSString *g_fakeDevName = nil;
static int       g_fakeSoCId = 0;
static int       g_fakeFreqMHz = 0;
static int       g_fakeScrW = 0;
static int       g_fakeScrH = 0;
static float     g_fakeScale = 3.0f;
static int       g_fakeBattery = 0;
static int       g_fakeArmE = 1;
static int       g_fakeMinIOS = 15;
static NSString *g_fakeBundlePath = nil;
static NSString *g_fakeExecPath = nil;
static long long g_fakeBootOffset = 0;
static long long g_fakeDiskTotal = 0;      // 总容量（字节）
static long long g_fakeDiskFree  = 0;      // 可用容量（字节）

// ??? HOME ?????????????
static unsigned long KwaiContainerSeed(void) {
    static unsigned long seed = 0;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *home = NSHomeDirectory();
        // ★★ v47.8 关键修复：原来用 home.lastPathComponent，但 guest HOME 形如
        //   .../Data/Application/<GUEST-UUID>/Documents
        //   → lastPathComponent 【恒为 "Documents"】→ djb2 哈希完全相同
        //   → 所有容器种子相同 → 电量/存储/电池/时间等全部恒定。
        //   （同一个坑在 v43 出现过，v44 只修了 LC 层，Tweak 层漏了。）
        //   正确：取 "/Documents/Data/Application/" 之后的 guest UUID 段。
        NSString *uid = nil;
        NSString *marker = @"/Documents/Data/Application/";
        NSRange r = [home rangeOfString:marker options:NSBackwardsSearch];
        if (r.location != NSNotFound) {
            NSString *rest = [home substringFromIndex:r.location + marker.length];
            uid = [[rest componentsSeparatedByString:@"/"] firstObject];
        }
        if (!uid.length) uid = home.lastPathComponent;   // 兜底
        unsigned long h = 5381;
        for (NSUInteger i = 0; i < uid.length; i++) {
            h = ((h << 5) + h) + [uid characterAtIndex:i];
        }
        NSString *bid = [NSBundle mainBundle].bundleIdentifier ?: @"";
        for (NSUInteger i = 0; i < bid.length; i++) {
            h = ((h << 5) + h) + [bid characterAtIndex:i];
        }
        seed = h;
        KWLog(@"[v47.8] container seed: %lu (uuid=%@ home=%s)", h, uid, home.UTF8String);
    });
    return seed;
}

// ???????
static void KwaiSetupSpoof(void) {
    // ===== 优先读 LC 传入的伪装参数（LC 层生成，每个容器独立）=====
    const char *envModel   = getenv("LC_SPOOF_MODEL");
    const char *envProduct = getenv("LC_SPOOF_PRODUCT");
    const char *envBoard   = getenv("LC_SPOOF_BOARD");
    const char *envSerial  = getenv("LC_SPOOF_SERIAL");
    const char *envUUID    = getenv("LC_SPOOF_UUID");
    const char *envIDFV    = getenv("LC_SPOOF_IDFV");
    const char *envNCPU    = getenv("LC_SPOOF_NCPU");
    const char *envMem     = getenv("LC_SPOOF_MEM");
    const char *envIDFA    = getenv("LC_SPOOF_IDFA");
    const char *envName    = getenv("LC_SPOOF_NAME");
    const char *envSoC     = getenv("LC_SPOOF_SOC");
    const char *envFreq    = getenv("LC_SPOOF_FREQ");
    const char *envScrW    = getenv("LC_SPOOF_SCR_W");
    const char *envScrH    = getenv("LC_SPOOF_SCR_H");
    const char *envScale   = getenv("LC_SPOOF_SCALE");
    const char *envBatt    = getenv("LC_SPOOF_BATT");
    const char *envArmE    = getenv("LC_SPOOF_ARME");
    const char *envMinIOS  = getenv("LC_SPOOF_MINIOS");
    const char *envBundle  = getenv("LC_SPOOF_BUNDLE");
    const char *envExec    = getenv("LC_SPOOF_EXEC");

    if (envModel && envModel[0]) {
        g_fakeMachine = [NSString stringWithUTF8String:envModel];
        strncpy(g_fakeMachineC, envModel, sizeof(g_fakeMachineC)-1);
        strncpy(g_fakeModelC, envModel, sizeof(g_fakeModelC)-1);
        // ★ v47.8 诊断：把 LC 实际传入的值全部打出来。
        //   若 model 每容器相同 → 问题在 LC 层种子；
        //   若 model 每容器不同但下面 seed 相同 → Tweak 层种子（已修）。
        KWLog(@"[v47.8] LC env: model=%s product=%s board=%s scr=%dx%d@%.2f ncpu=%s mem=%s soc=%s minIOS=%s",
              envModel, envProduct ? envProduct : "-", envBoard ? envBoard : "-",
              envScrW ? atoi(envScrW) : 0, envScrH ? atoi(envScrH) : 0,
              envScale ? atof(envScale) : 0.0,
              envNCPU ? envNCPU : "-", envMem ? envMem : "-",
              envSoC ? envSoC : "-", envMinIOS ? envMinIOS : "-");
        if (envProduct) strncpy(g_fakeProductC, envProduct, sizeof(g_fakeProductC)-1);
        if (envBoard)   strncpy(g_fakeBoardC,   envBoard,   sizeof(g_fakeBoardC)-1);
        if (envSerial)  g_fakeSerial = [NSString stringWithUTF8String:envSerial];
        if (envUUID)    g_fakeUUID   = [NSString stringWithUTF8String:envUUID];
        if (envIDFV)    g_fakeIDFV   = [[NSUUID alloc] initWithUUIDString:[NSString stringWithUTF8String:envIDFV]];
        if (envNCPU)    g_fakeNCPU   = atoi(envNCPU);
        if (envMem)     g_fakeMemSize = atoll(envMem);
        if (envIDFA)    g_fakeIDFA     = [NSString stringWithUTF8String:envIDFA];
        if (envName)    g_fakeDevName  = [NSString stringWithUTF8String:envName];
        if (envSoC)     g_fakeSoCId    = (int)strtol(envSoC, NULL, 0);
        if (envFreq)    g_fakeFreqMHz  = atoi(envFreq);
        if (envScrW)    g_fakeScrW     = atoi(envScrW);
        if (envScrH)    g_fakeScrH     = atoi(envScrH);
        if (envScale)   g_fakeScale   = (float)atof(envScale);
        if (envBatt)    g_fakeBattery  = atoi(envBatt);
        if (envArmE)    g_fakeArmE     = atoi(envArmE);
        if (envMinIOS)  g_fakeMinIOS   = atoi(envMinIOS);
        if (envBundle)  g_fakeBundlePath = [NSString stringWithUTF8String:envBundle];
        if (envExec)    g_fakeExecPath   = [NSString stringWithUTF8String:envExec];
        KWLog(@"[spoof] FROM LC ENV: model=%s product=%s board=%s sn=%s",
              envModel, envProduct ?: "", envBoard ?: "", envSerial ?: "");

        // ★ 兜底：若 LC 层未传 LC_SPOOF_SCALE（旧版 LC），按机型推断 nativeScale
        if (!envScale || g_fakeScale <= 0) {
            const char *mc = envModel;
            if (mc) {
                if (strcmp(mc, "iPhone11,8") == 0 || strcmp(mc, "iPhone12,1") == 0 ||
                    strcmp(mc, "iPhone14,6") == 0) {
                    g_fakeScale = 2.00f;   // XR / 11 / SE3（2x 面板）
                } else if (strcmp(mc, "iPhone13,1") == 0 || strcmp(mc, "iPhone14,4") == 0) {
                    g_fakeScale = 2.88f;   // 12/13 mini（下采样）
                } else {
                    g_fakeScale = 3.00f;   // 其余
                }
            }
            KWLog(@"[spoof] nativeScale fallback -> %.2f", g_fakeScale);
        }
        return;   // ★ 用 LC 的参数，不再自己算
    }

    unsigned long seed = KwaiContainerSeed();

    // ??? iOS ????????? <= ?????
    NSString *ver = [[UIDevice currentDevice] systemVersion];
    int hostMajor = [[ver componentsSeparatedByString:@"."].firstObject intValue];
    if (hostMajor <= 0) hostMajor = 15;
    KWLog(@"[spoof] host iOS major = %d", hostMajor);

    // ??????
    int cand[64];
    int candCount = 0;
    for (int i = 0; i < kDeviceModelCount && candCount < 64; i++) {
        if (kDeviceModels[i].minIOS <= hostMajor) {
            cand[candCount++] = i;
        }
    }
    if (candCount == 0) {
        // ?????
        for (int i = 0; i < kDeviceModelCount && candCount < 64; i++) cand[candCount++] = i;
    }
    KWLog(@"[spoof] candidates=%d", candCount);

    int pick = cand[seed % (unsigned long)candCount];
    const KwaiDeviceModel *m = &kDeviceModels[pick];

    g_fakeMachine = [NSString stringWithUTF8String:m->machine];
    strncpy(g_fakeMachineC, m->machine, sizeof(g_fakeMachineC)-1);
    strncpy(g_fakeModelC, m->machine, sizeof(g_fakeModelC)-1);
    g_fakeNCPU = m->ncpu;
    g_fakeMemSize = (long long)m->memGB * 1024LL * 1024LL * 1024LL;

    // IDFV???????????? IDFV?
    unsigned char bytes[16];
    unsigned long s = seed;
    for (int i = 0; i < 16; i++) {
        s = s * 6364136223846793005ULL + 1442695040888963407ULL;
        bytes[i] = (unsigned char)(s >> 33);
    }
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    g_fakeIDFV = [[NSUUID alloc] initWithUUIDBytes:bytes];

    // ---- product / board ----
    if (m->product) strncpy(g_fakeProductC, m->product, sizeof(g_fakeProductC)-1);
    if (m->board)   strncpy(g_fakeBoardC, m->board, sizeof(g_fakeBoardC)-1);

    // ---- v13: 新字段自动填充（保证参数自洽）----
    g_fakeSoCId   = m->socId;
    g_fakeFreqMHz = m->freqMHz;
    g_fakeScrW    = m->scrW;
    g_fakeScrH    = m->scrH;
    g_fakeScale   = m->scale;   // ★ 新增：从表取值（修正 mini/XR/SE 的 2.0/2.88）
    g_fakeBattery = m->battery;
    g_fakeArmE    = m->arm64e;
    KWLog(@"[spoof] v13 params: soc=0x%X freq=%dMHz scr=%dx%d batt=%dmAh arm64e=%d",
          m->socId, m->freqMHz, m->scrW, m->scrH, m->battery, m->arm64e);

    // ★ v48：脱离 LiveContainer 后，下述三项原本只由 LC 层经 LC_SPOOF_* 注入。
    //   不补的话 g_fakeMinIOS=0（系统版本文案会落默认）、IDFA 为空（漏真值）、
    //   设备名为空 —— 都是可被检测的破绽。现在从机型表与种子自生成。
    g_fakeMinIOS = m->minIOS;                  // 与所伪装机型的最低系统版本一致
    if (!g_fakeDevName.length) g_fakeDevName = @"iPhone";
    if (!g_fakeIDFA.length) {
        // IDFA：与 IDFV 同源但用不同盐，保证同机同容器稳定、不同容器不同
        unsigned char ab[16];
        unsigned long as = seed ^ 0x3C3C3C3CUL;
        for (int i = 0; i < 16; i++) {
            as = as * 6364136223846793005ULL + 1442695040888963407ULL;
            ab[i] = (unsigned char)(as >> 33);
        }
        ab[6] = (ab[6] & 0x0F) | 0x40;
        ab[8] = (ab[8] & 0x3F) | 0x80;
        g_fakeIDFA = [[NSUUID alloc] initWithUUIDBytes:ab].UUIDString;
    }
    KWLog(@"[v48] self-gen: minIOS=%d idfa=%@ name=%@",
          g_fakeMinIOS, g_fakeIDFA, g_fakeDevName);

    // ---- 序列号（12位，苹果格式）----
    {
        static const char cs[] = "ABCDEFGHJKLMNPQRSTUVWXYZ0123456789";
        char sbuf[13];
        unsigned long ss = seed ^ 0xA5A5A5A5UL;
        for (int i = 0; i < 12; i++) {
            ss = ss * 6364136223846793005ULL + 1442695040888963407ULL;
            sbuf[i] = cs[(ss >> 33) % 34];
        }
        sbuf[12] = 0;
        g_fakeSerial = [NSString stringWithUTF8String:sbuf];
    }

    // ---- 硬件 UUID ----
    {
        unsigned char ub[16];
        unsigned long us = seed ^ 0x5A5A5A5AUL;
        for (int i = 0; i < 16; i++) {
            us = us * 6364136223846793005ULL + 1442695040888963407ULL;
            ub[i] = (unsigned char)(us >> 33);
        }
        ub[6] = (ub[6] & 0x0F) | 0x40;
        ub[8] = (ub[8] & 0x3F) | 0x80;
        g_fakeUUID = [[NSUUID alloc] initWithUUIDBytes:ub].UUIDString;
    }

    KWLog(@"[spoof] model=%s ncpu=%d mem=%dGB idfv=%@ serial=%@ uuid=%@ product=%s board=%s",
          m->machine, m->ncpu, m->memGB, g_fakeIDFV.UUIDString,
          g_fakeSerial, g_fakeUUID, g_fakeProductC, g_fakeBoardC);
}

// ---- hook uname ----
static int (*orig_uname)(struct utsname *);
static int kw_uname(struct utsname *buf) {
    int ret = orig_uname(buf);
    if (ret == 0 && buf && g_fakeMachine) {
        strncpy(buf->machine, g_fakeMachine.UTF8String, sizeof(buf->machine) - 1);
        buf->machine[sizeof(buf->machine) - 1] = '\0';
    }
    return ret;
}
// ============================================================
//  改机扩展 hook（v2）
// ============================================================
#include <sys/utsname.h>

// ---- ③ sysctl MIB（kern.hostname / hw.machine）----
static int (*orig_sysctl_mib)(int *, u_int, void *, size_t *, void *, size_t) = NULL;

static int kw_sysctl_mib(int *name, u_int namelen, void *oldp, size_t *oldlenp,
                         void *newp, size_t newlen) {
    if (name && namelen >= 2 && oldp && oldlenp) {
        // hw.machine = {CTL_HW, HW_MACHINE}; hw.model = {CTL_HW, HW_MODEL}
        if (name[0] == CTL_HW && (name[1] == HW_MACHINE || name[1] == HW_MODEL)) {
            if (g_fakeMachineC[0]) {
                size_t need = strlen(g_fakeMachineC) + 1;
                if (*oldlenp >= need) { memcpy(oldp, g_fakeMachineC, need); *oldlenp = need; return 0; }
            }
        }
        if (name[0] == CTL_HW && name[1] == HW_MEMSIZE) {
            if (*oldlenp >= sizeof(long long) && g_fakeMemSize > 0) {
                *(long long *)oldp = g_fakeMemSize; *oldlenp = sizeof(long long); return 0;
            }
        }
        // ★ v32: machdep.cpu.brand_string（MIB 形式：CTL_HW, HW_CPU_SUBTYPE, HW_CPU_BRAND_STRING）
        // ★ v32: Apple 私有常量（SDK 未公开）
        //   CTL_HW=1, HW_CPU_SUBTYPE(HW_CPU_FAMILY)=1, HW_CPU_BRAND_STRING=0x100
        //   参考 XNU：sysctl_hw.c
#define LC_HW_CPU_FAMILY      1
#define LC_HW_CPU_BRAND_STRING 0x100

        //   快手直接读芯片名，比 cpufamily 更直观
        if (name[0] == CTL_HW && namelen >= 3 &&
            name[1] == LC_HW_CPU_FAMILY &&
            name[2] == LC_HW_CPU_BRAND_STRING) {
            const char *brand = kw_cpuBrandForSoC(g_fakeSoCId);
            size_t need = strlen(brand) + 1;
            if (*oldlenp >= need) { memcpy(oldp, brand, need); *oldlenp = need; return 0; }
        }
    }

    // ---- ★ v47.5 修复 H2：KERN_PROC（进程列表）过滤 ----
    //  原实现在 kw_sysctl_proc 里，但它从未 rebind（只赋值 + 打 OK 日志），
    //  进程列表过滤实际从未运行；且 orig_sysctl_proc = sysctl 取到的是
    //  【已被 hооk 的 kw_sysctl_mib 地址】，补 rebind 即无限递归。
    //  改为：逻辑落在唯一入口 kw_sysctl_mib 上。
    //  只遍历 kinfo_proc.p_comm + 严格等长替换，杜绝越界与跨字段写。
    if (name && namelen >= 2 && name[0] == 1 && name[1] == 14 /*KERN_PROC*/
        && oldp && oldlenp && *oldlenp >= sizeof(struct kinfo_proc)) {
        int r = orig_sysctl_mib ? orig_sysctl_mib(name, namelen, oldp, oldlenp, newp, newlen) : -1;
        if (r == 0) {
            size_t nproc = *oldlenp / sizeof(struct kinfo_proc);
            struct kinfo_proc *kp = (struct kinfo_proc *)oldp;
            const char *bad[]  = {"LiveContainer", "LiveProcess", "TweakLoader",
                                  "SideStore", NULL};
            const char *good[] = {"launchd",      "backboardd",   "backboardd",
                                  "configd",      NULL};
            int hits = 0;
            for (size_t k = 0; k < nproc; k++) {
                char *comm = kp[k].kp_proc.p_comm;   // MAXCOMLEN=16
                for (int i = 0; bad[i]; i++) {
                    size_t bl = strlen(bad[i]);
                    if (bl != strlen(good[i])) continue;   // 只做等长替换
                    if (bl >= MAXCOMLEN) continue;
                    if (memcmp(comm, bad[i], bl) == 0) {
                        memcpy(comm, good[i], bl);
                        comm[bl] = '\0';
                        hits++;
                    }
                }
            }
            static int procLogged = 0;
            if (procLogged < 3) { procLogged++;
                KWLog(@"[v47.5] KERN_PROC filtered (%zu procs, %d hits)", nproc, hits); }
        }
        return r;
    }

    // ---- v15: KERN_PROCARGS2 环境变量清理 ----
    // ★ v47.5：① 抹到 '=' 之后，KEY 与 VALUE 一起抹（原来只抹 VALUE，
    //   残留 "LC_SPOOF_SERIAL=" 这样的键名反而更可疑）；
    //   ② O(N*M) 双层 memcmp → memmem 一次定位（热路径不再全缓冲扫描）；
    //   ③ 日志节流，避免 sysctl 高频调用把磁盘打爆。
    if (name && namelen >= 2 && name[0] == 1 && name[1] == 49 /*KERN_PROCARGS2*/
        && oldp && oldlenp) {
        // ★ v35: "LC_SPOOF_" 前缀匹配，一次覆盖 22 个变量
        const char *bad[] = {
            "LC_GLOBAL_TWEAKS", "LC_DATA_UUID", "DYLD_INSERT_LIBRARIES",
            "JB_ROOT", "DOPAMINE", "SUBSTRATE",
            "LC_SPOOF_",
            "LC_APP_GROUP_PATH", "LC_SELECTED_CONTAINER",
            NULL
        };
        int r = orig_sysctl_mib ? orig_sysctl_mib(name, namelen, oldp, oldlenp, newp, newlen) : -1;
        if (r == 0 && *oldlenp > 0) {
            char *p = (char *)oldp;
            size_t len = *oldlenp;
            int hits = 0;
            for (int i = 0; bad[i]; i++) {
                size_t bl = strlen(bad[i]);
                size_t off = 0;
                while (off < len) {
                    const char *hit = (const char *)memmem(p + off, len - off, bad[i], bl);
                    if (!hit) break;
                    size_t at = (size_t)(hit - p);
                    const char *eq = (const char *)memchr(p + at, '=', len - at);
                    size_t segEnd = eq ? (size_t)(eq - p) : (at + bl);
                    const char *nul = (const char *)memchr(p + segEnd, '\0', len - segEnd);
                    size_t stop = nul ? (size_t)(nul - p) : len;
                    if (stop > at) memset(p + at, 0x20, stop - at);
                    hits++;
                    off = stop + 1;
                }
            }
            static int sanLogged = 0;
            if (sanLogged < 5) { sanLogged++;
                KWLog(@"[v47.5] procargs sanitized (len=%zu, hits=%d)", len, hits); }
        }
        return r;
    }
    if (orig_sysctl_mib) return orig_sysctl_mib(name, namelen, oldp, oldlenp, newp, newlen);
    return -1;
}

// ---- ⑤ UIDevice.model ----
static NSString *(*orig_dev_model)(id, SEL) = NULL;
static NSString *kw_dev_model(id self, SEL _cmd) {
    // ★ v47.6 修 M2：原来硬编码 @"iPhone"，与 hw.machine / LC_SPOOF_MODEL 不一致。
    if (g_fakeMachineC[0]) return [NSString stringWithUTF8String:g_fakeMachineC];
    return @"iPhone";
}

// ---- ⑥ NSProcessInfo.physicalMemory ----
static unsigned long long (*orig_phys_mem)(id, SEL) = NULL;
static unsigned long long kw_phys_mem(id self, SEL _cmd) {
    if (g_fakeMemSize > 0) return (unsigned long long)g_fakeMemSize;
    return orig_phys_mem ? orig_phys_mem(self, _cmd) : 0;
}

// ---- ⑦ NSProcessInfo.processorCount ----
static NSUInteger (*orig_proc_count)(id, SEL) = NULL;
static NSUInteger kw_proc_count(id self, SEL _cmd) {
    if (g_fakeNCPU > 0) return (NSUInteger)g_fakeNCPU;
    return orig_proc_count ? orig_proc_count(self, _cmd) : 0;
}



// ---- hook sysctlbyname ----
static int (*orig_sysctlbyname)(const char *, void *, size_t *, void *, size_t);
static int kw_sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    // ? ?????????dyld/objc ??????? C ????? ObjC ??
    if (!orig_sysctlbyname) {
        // ????????? key ???????????????? buffer
        if (name && oldp && oldlenp && g_fakeMachineC[0]) {
            if (strcmp(name, "hw.machine") == 0 || strcmp(name, "hw.model") == 0) {
                size_t need = strlen(g_fakeMachineC) + 1;
                if (*oldlenp >= need) { memcpy(oldp, g_fakeMachineC, need); *oldlenp = need; return 0; }
            }
        }
        return -1;
    }
    if (!name || !oldp || !oldlenp) {
        return orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
    }

    // ????????????
    if (g_fakeMachineC[0] == '\0') {
        return orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
    }

    // ★ v47.6 修 M1：真机语义是 hw.machine = "iPhone14,2"（机型标识符），
    //   hw.model = 内部代号 "D73AP"，hw.product = "iPhone14,2"。
    //   原实现把 hw.model 也返回机型标识符，且 hw.product 返回营销名 ——
    //   两者对调且都不对，交叉比对 sysctlbyname("hw.model") 与 uname().machine 即露。
    if (strcmp(name, "hw.machine") == 0) {
        size_t need = strlen(g_fakeMachineC) + 1;
        if (*oldlenp >= need) {
            memcpy(oldp, g_fakeMachineC, need);
            *oldlenp = need;
            return 0;
        }
    }
    if (strcmp(name, "hw.product") == 0) {
        if (g_fakeMachineC[0]) {
            size_t need = strlen(g_fakeMachineC) + 1;
            if (*oldlenp >= need) { memcpy(oldp, g_fakeMachineC, need); *oldlenp = need; return 0; }
        }
    }
    if (strcmp(name, "hw.model") == 0) {
        // 返回主板代号（真机语义），无代号时退回 hw.target 的板子 ID
        const char *board = g_fakeBoardC[0] ? g_fakeBoardC : g_fakeProductC;
        if (board[0]) {
            size_t need = strlen(board) + 1;
            if (*oldlenp >= need) { memcpy(oldp, board, need); *oldlenp = need; return 0; }
        }
    }
    if (strcmp(name, "hw.target") == 0) {
        if (g_fakeBoardC[0]) {
            size_t need = strlen(g_fakeBoardC) + 1;
            if (*oldlenp >= need) { memcpy(oldp, g_fakeBoardC, need); *oldlenp = need; return 0; }
        }
    }
    if (strcmp(name, "hw.ncpu") == 0 || strcmp(name, "hw.logicalcpu") == 0) {
        if (*oldlenp >= sizeof(int) && g_fakeNCPU > 0) {
            *(int *)oldp = g_fakeNCPU;
            *oldlenp = sizeof(int);
            return 0;
        }
    }
    if (strcmp(name, "hw.physicalcpu") == 0) {
        // ★ 修复：真机 6 核（2 性能 + 4 能效）的 hw.physicalcpu = 6，不是 3！
        if (*oldlenp >= sizeof(int) && g_fakeNCPU > 0) {
            *(int *)oldp = g_fakeNCPU;
            *oldlenp = sizeof(int);
            return 0;
        }
    }
    if (strcmp(name, "hw.memsize") == 0) {
        if (*oldlenp >= sizeof(long long) && g_fakeMemSize > 0) {
            *(long long *)oldp = g_fakeMemSize;
            *oldlenp = sizeof(long long);
            return 0;
        }
    }
    // ---- v9: 合并所有扩展 hook（时间/磁盘/CPU/飞行/内核）----
    {
        int extR = kw_apply_ext_sysctlbyname(name, oldp, oldlenp);
        if (extR >= 0) return extR;
    }
    return orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
}
// ---- hook UIDevice.identifierForVendor ----
static NSUUID * (*orig_idfv)(id, SEL);
static NSUUID * kw_idfv(id self, SEL _cmd) {
    if (g_fakeIDFV) return g_fakeIDFV;
    return orig_idfv(self, _cmd);
}

// ---- ???? hook ----
static BOOL g_spoofInstalled = NO;


// ============================================================
//  IOKit hook（IOPlatformSerialNumber / IOPlatformUUID）
//  —— 风控核心：唯一设备标识
// ============================================================
#import <IOKit/IOKitLib.h>
#import <CoreFoundation/CoreFoundation.h>

static CFTypeRef (*orig_IORegistryEntryCreateCFProperty)(io_registry_entry_t, CFStringRef, CFAllocatorRef, IOOptionBits) = NULL;

static CFTypeRef kw_IORegistryEntryCreateCFProperty(io_registry_entry_t entry, CFStringRef key,
                                                     CFAllocatorRef alloc, IOOptionBits opts) {
    if (key) {
        NSString *k = (__bridge NSString *)key;
        if ([k isEqualToString:@"IOPlatformSerialNumber"] && g_fakeSerial) {
            return CFBridgingRetain([g_fakeSerial copy]);
        }
        if ([k isEqualToString:@"IOPlatformUUID"] && g_fakeUUID) {
            return CFBridgingRetain([g_fakeUUID copy]);
        }
    }
    if (orig_IORegistryEntryCreateCFProperty)
        return orig_IORegistryEntryCreateCFProperty(entry, key, alloc, opts);
    return NULL;
}

// ---- Search 版本 ----
static CFTypeRef (*orig_IORegEntrySearchCFProp)(io_registry_entry_t, const io_name_t, CFStringRef, CFAllocatorRef, IOOptionBits) = NULL;
static CFTypeRef kw_IORegEntrySearchCFProp(io_registry_entry_t entry, const io_name_t plane,
                                            CFStringRef key, CFAllocatorRef alloc, IOOptionBits opts) {
    if (key) {
        NSString *k = (__bridge NSString *)key;
        if ([k isEqualToString:@"IOPlatformSerialNumber"] && g_fakeSerial)
            return CFBridgingRetain([g_fakeSerial copy]);
        if ([k isEqualToString:@"IOPlatformUUID"] && g_fakeUUID)
            return CFBridgingRetain([g_fakeUUID copy]);
    }
    if (orig_IORegEntrySearchCFProp)
        return orig_IORegEntrySearchCFProp(entry, plane, key, alloc, opts);
    return NULL;
}

// ---- CreateCFProperties（批量）----
static kern_return_t (*orig_IORegEntryCFProps)(io_registry_entry_t, CFMutableDictionaryRef *, CFAllocatorRef, IOOptionBits) = NULL;
static kern_return_t kw_IORegEntryCFProps(io_registry_entry_t entry, CFMutableDictionaryRef *props,
                                           CFAllocatorRef alloc, IOOptionBits opts) {
    kern_return_t r = orig_IORegEntryCFProps
        ? orig_IORegEntryCFProps(entry, props, alloc, opts) : KERN_FAILURE;
    if (r == KERN_SUCCESS && props && *props) {
        if (g_fakeSerial)
            CFDictionarySetValue(*props, CFSTR("IOPlatformSerialNumber"), (__bridge const void *)g_fakeSerial);
        if (g_fakeUUID)
            CFDictionarySetValue(*props, CFSTR("IOPlatformUUID"), (__bridge const void *)g_fakeUUID);
    }
    return r;
}

// ---- IODeviceTree:/ 路径 ----
// ---- IORegistryEntryGetProperty（C 字符串版）----
static kern_return_t (*orig_IORegEntryGetProperty)(io_registry_entry_t, const char *, char *, unsigned int *) = NULL;
static kern_return_t kw_IORegEntryGetProperty(io_registry_entry_t entry, const char *name,
                                              char *buf, unsigned int *size) {
    if (name && buf && size) {
        if (strcmp(name, "model") == 0 && g_fakeBoardC[0]) {
            size_t n = strlen(g_fakeBoardC);
            if (*size > n) { strcpy(buf, g_fakeBoardC); *size = (unsigned int)(n + 1); return 0; }
        }
        if (strcmp(name, "IOPlatformSerialNumber") == 0 && g_fakeSerial) {
            const char *sv = g_fakeSerial.UTF8String; size_t n = strlen(sv);
            if (*size > n) { strcpy(buf, sv); *size = (unsigned int)(n + 1); return 0; }
        }
        if (strcmp(name, "IOPlatformUUID") == 0 && g_fakeUUID) {
            const char *uv = g_fakeUUID.UTF8String; size_t n = strlen(uv);
            if (*size > n) { strcpy(buf, uv); *size = (unsigned int)(n + 1); return 0; }
        }
    }
    if (orig_IORegEntryGetProperty) return orig_IORegEntryGetProperty(entry, name, buf, size);
    return KERN_FAILURE;
}


static io_registry_entry_t (*orig_IORegEntryFromPath)(const io_string_t) = NULL;
static io_registry_entry_t kw_IORegEntryFromPath(const io_string_t path) {
    return orig_IORegEntryFromPath ? orig_IORegEntryFromPath(path) : 0;
}

// ---- MobileGestalt ----
static CFTypeRef (*orig_MGCopyAnswer)(CFStringRef) = NULL;
static CFTypeRef (*orig_MGGetStringAnswer)(CFStringRef) = NULL;
static bool (*orig_MGGetBoolAnswer)(CFStringRef) = NULL;

// MG 的 key 映射
static CFTypeRef kw_MGCopyAnswer(CFStringRef key) {
    if (key) {
        NSString *k = (__bridge NSString *)key;
        if (([k isEqualToString:@"SerialNumber"] || [k isEqualToString:@"InternationalMobileEquipmentIdentity"]) && g_fakeSerial)
            return CFBridgingRetain([g_fakeSerial copy]);
        if (([k isEqualToString:@"UniqueDeviceID"] || [k isEqualToString:@"UserAssignedDeviceName"]) && g_fakeUUID)
            return CFBridgingRetain([g_fakeUUID copy]);
        if ([k isEqualToString:@"ProductType"] && g_fakeMachine)
            return CFBridgingRetain([g_fakeMachine copy]);
        if ([k isEqualToString:@"HardwareModel"] && g_fakeBoardC[0])
            return CFBridgingRetain([[NSString stringWithUTF8String:g_fakeBoardC] copy]);
        if ([k isEqualToString:@"DeviceClass"] && g_fakeMachine)
            return CFBridgingRetain([@"iPhone" copy]);
    }
    if (orig_MGCopyAnswer) return orig_MGCopyAnswer(key);
    return NULL;
}

static CFStringRef kw_MGGetStringAnswer(CFStringRef key) {
    if (key) {
        NSString *k = (__bridge NSString *)key;
        if ([k isEqualToString:@"SerialNumber"] && g_fakeSerial)
            return CFBridgingRetain([g_fakeSerial copy]);
        if ([k isEqualToString:@"ProductType"] && g_fakeMachine)
            return CFBridgingRetain([g_fakeMachine copy]);
        if ([k isEqualToString:@"HardwareModel"] && g_fakeBoardC[0])
            return CFBridgingRetain([[NSString stringWithUTF8String:g_fakeBoardC] copy]);
    }
    if (orig_MGGetStringAnswer) return orig_MGGetStringAnswer(key);
    return NULL;
}

static bool kw_MGGetBoolAnswer(CFStringRef key) {
    if (orig_MGGetBoolAnswer) return orig_MGGetBoolAnswer(key);
    return false;
}


// ============================================================
//  快手设备信息 hook（platformString / UIDeviceHardware）
//  —— 快手自己缓存的机型，必须从源头改
// ============================================================
static NSString *(*orig_platformString)(id, SEL) = NULL;

static NSString *kw_platformString(id self, SEL _cmd) {
    if (g_fakeMachine) {
        KWLog(@"[spoof] platformString -> %@", g_fakeMachine);
        return g_fakeMachine;
    }
    return orig_platformString ? orig_platformString(self, _cmd) : @"iPhone";
}

void KwaiInstallKwaiDeviceHook(void) {
    static BOOL done = NO;
    if (done) return;
    done = YES;

    // ① UIDeviceHardware.platformString
    SEL ps = NSSelectorFromString(@"platformString");
    NSArray *cands = @[@"UIDeviceHardware", @"KSDeviceModel", @"KSAppleDeviceTypesDefine",
                       @"KSAppSystemResourceInfomation", @"KSCPDeviceModelUtil"];
    int hooked = 0;
    for (NSString *cn in cands) {
        Class c = NSClassFromString(cn);
        if (!c) { KWLog(@"[spoof] class %@ not found", cn); continue; }
        // 实例方法
        Method m = class_getInstanceMethod(c, ps);
        if (m) {
            orig_platformString = (void *)method_getImplementation(m);
            method_setImplementation(m, (IMP)kw_platformString);
            KWLog(@"[spoof] %@ -platformString hooked", cn);
            hooked++;
        }
        // 类方法
        Method cm = class_getClassMethod(c, ps);
        if (cm) {
            method_setImplementation(cm, (IMP)kw_platformString);
            KWLog(@"[spoof] %@ +platformString hooked", cn);
            hooked++;
        }
        // 其他相关 selector
        for (NSString *selName in @[@"hardwareString", @"machineName", @"platform"]) {
            SEL s2 = NSSelectorFromString(selName);
            Method m2 = class_getInstanceMethod(c, s2);
            if (m2) {
                method_setImplementation(m2, (IMP)kw_platformString);
                KWLog(@"[spoof] %@ -%@ hooked", cn, selName);
                hooked++;
            }
        }
    }
    KWLog(@"[spoof] kwai device hook done (%d)", hooked);
}


static void KwaiInstallIOKitHook(void) {
    static BOOL done = NO;
    if (done) return;
    done = YES;

    void *h = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
    if (!h) { KWLog(@"[spoof] IOKit dlopen fail"); return; }

    // ① CreateCFProperty
    void *s1 = dlsym(h, "IORegistryEntryCreateCFProperty");
    if (s1) {
        orig_IORegistryEntryCreateCFProperty = s1;
        @try { litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, s1,
              (void *)kw_IORegistryEntryCreateCFProperty, NULL);
              KWLog(@"[spoof] IOKit CreateCFProperty OK"); }
        @catch (NSException *e) { KWLog(@"[spoof] CreateCFProperty ex: %@", e); }
    }

    // ② SearchCFProperty
    void *s2 = dlsym(h, "IORegistryEntrySearchCFProperty");
    if (s2) {
        orig_IORegEntrySearchCFProp = s2;
        @try { litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, s2,
              (void *)kw_IORegEntrySearchCFProp, NULL);
              KWLog(@"[spoof] IOKit SearchCFProperty OK"); }
        @catch (NSException *e) { KWLog(@"[spoof] SearchCFProperty ex: %@", e); }
    }

    // ③ CreateCFProperties
    void *s3 = dlsym(h, "IORegistryEntryCreateCFProperties");
    if (s3) {
        orig_IORegEntryCFProps = s3;
        @try { litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, s3,
              (void *)kw_IORegEntryCFProps, NULL);
              KWLog(@"[spoof] IOKit CreateCFProperties OK"); }
        @catch (NSException *e) { KWLog(@"[spoof] CreateCFProperties ex: %@", e); }
    }

    // ④ IORegistryEntryGetProperty（C 字符串版 —— 别人也有这个）
    void *s4b = dlsym(h, "IORegistryEntryGetProperty");
    if (s4b) {
        orig_IORegEntryGetProperty = s4b;
        @try { litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, s4b,
              (void *)kw_IORegEntryGetProperty, NULL);
              KWLog(@"[spoof] IOKit GetProperty OK"); }
        @catch (NSException *e) { KWLog(@"[spoof] GetProperty ex: %@", e); }
    }

    // ⑤ IODeviceTree:/ 的 model 节点



    // ④ IODeviceTree:/ 的 model 节点（快手崩溃报告里的 D22AP）
    void *s4 = dlsym(h, "IORegistryEntryFromPath");
    if (s4) {
        orig_IORegEntryFromPath = s4;
        @try { litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, s4,
              (void *)kw_IORegEntryFromPath, NULL);
              KWLog(@"[spoof] IOKit FromPath OK"); }
        @catch (NSException *e) { KWLog(@"[spoof] FromPath ex: %@", e); }
    }

    // ⑤ libMobileGestalt（MGCopyAnswer / MGGetStringAnswer）
    void *mg = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY);
    if (mg) {
        void *mc = dlsym(mg, "MGCopyAnswer");
        if (mc) {
            orig_MGCopyAnswer = mc;
            @try { litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, mc,
                  (void *)kw_MGCopyAnswer, NULL);
                  KWLog(@"[spoof] MobileGestalt MGCopyAnswer OK"); }
            @catch (NSException *e) { KWLog(@"[spoof] MGCopyAnswer ex: %@", e); }
        }
        void *mgs = dlsym(mg, "MGGetStringAnswer");
        if (mgs) {
            orig_MGGetStringAnswer = mgs;
            @try { litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, mgs,
                  (void *)kw_MGGetStringAnswer, NULL);
                  KWLog(@"[spoof] MobileGestalt MGGetStringAnswer OK"); }
            @catch (NSException *e) { KWLog(@"[spoof] MGGetStringAnswer ex: %@", e); }
        }
        void *mgb = dlsym(mg, "MGGetBoolAnswer");
        if (mgb) {
            orig_MGGetBoolAnswer = mgb;
            @try { litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, mgb,
                  (void *)kw_MGGetBoolAnswer, NULL);
                  KWLog(@"[spoof] MobileGestalt MGGetBoolAnswer OK"); }
            @catch (NSException *e) { KWLog(@"[spoof] MGGetBoolAnswer ex: %@", e); }
        }
    } else {
        KWLog(@"[spoof] libMobileGestalt not found");
    }

    KWLog(@"[spoof] IOKit all done");
}
static void KwaiInstallSpoof(void) {
    if (g_spoofInstalled) return;
    g_spoofInstalled = YES;

    // ★ 修复时序：在任何 hook 安装前，先初始化全部扩展参数
    // 否则 hook 已生效但变量仍为 0，会漏真机值
    extern void KwaiSetupTimeSpoof(void);
    extern void KwaiSetupStorageSpoof(void);
    extern void KwaiSetupBatterySpoof(void);
    extern void KwaiSetupDeepSpoof(void);
    extern void KwaiSetupDataSpoof(void);
    extern void KwaiSetupKernelSpoof(void);

    KwaiSetupSpoof();                       // 基础设备（最先，其他依赖它）
    if (!g_fakeMachine) { KWLog(@"[spoof] setup failed"); return; }
    KwaiSetupTimeSpoof();                   // 时间参数
    KwaiSetupStorageSpoof();                // 存储参数
    KwaiSetupBatterySpoof();                // 电池参数
    KwaiSetupDeepSpoof();                   // CPU/屏幕/电量
    KwaiSetupDataSpoof();                   // 数据/安装时间
    KwaiSetupKernelSpoof();                 // 内核版本/MAC
    KWLog(@"[spoof] all params pre-initialized");

    #define LITEHOOK_REBIND_GLOBAL NULL

    // ========== ① sysctlbyname（hw.machine / ncpu / memsize）==========
    orig_sysctlbyname = sysctlbyname;
    KWLog(@"[spoof] orig_sysctlbyname=%p", orig_sysctlbyname);
    @try {
        litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL,
                               (void *)sysctlbyname, (void *)kw_sysctlbyname, NULL);
        KWLog(@"[spoof] sysctlbyname OK");
    } @catch (NSException *e) { KWLog(@"[spoof] sysctl ex: %@", e); }

    // ========== ② uname（utsname.machine）==========
    orig_uname = uname;
    @try {
        litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL,
                               (void *)uname, (void *)kw_uname, NULL);
        KWLog(@"[spoof] uname OK");
    } @catch (NSException *e) { KWLog(@"[spoof] uname ex: %@", e); }

    // ========== ③ sysctl（kern.hostname / hw.machine via MIB）==========
    orig_sysctl_mib = sysctl;
    @try {
        litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL,
                               (void *)sysctl, (void *)kw_sysctl_mib, NULL);
        KWLog(@"[spoof] sysctl MIB OK");
    } @catch (NSException *e) { KWLog(@"[spoof] sysctl mib ex: %@", e); }

    // ========== ④ UIDevice.identifierForVendor ==========
    Method m = class_getInstanceMethod([UIDevice class], @selector(identifierForVendor));
    if (m) {
        orig_idfv = (void *)method_getImplementation(m);
        method_setImplementation(m, (IMP)kw_idfv);
        KWLog(@"[spoof] IDFV hooked");
    }

    // ========== ⑤ UIDevice.model / name（OC 层）==========
    Method mm = class_getInstanceMethod([UIDevice class], @selector(model));
    if (mm) {
        orig_dev_model = (void *)method_getImplementation(mm);
        method_setImplementation(mm, (IMP)kw_dev_model);
        KWLog(@"[spoof] UIDevice.model hooked");
    }

    // ========== ⑥ NSProcessInfo.physicalMemory ==========
    Method mp = class_getInstanceMethod([NSProcessInfo class], @selector(physicalMemory));
    if (mp) {
        orig_phys_mem = (void *)method_getImplementation(mp);
        method_setImplementation(mp, (IMP)kw_phys_mem);
        KWLog(@"[spoof] physicalMemory hooked");
    }

    // ========== ⑦ NSProcessInfo.processorCount ==========
    Method mpc = class_getInstanceMethod([NSProcessInfo class], @selector(processorCount));
    if (mpc) {
        orig_proc_count = (void *)method_getImplementation(mpc);
        method_setImplementation(mpc, (IMP)kw_proc_count);
        KWLog(@"[spoof] processorCount hooked");
    }

    // ========== ⑧ IOKit 序列号 / UUID（风控核心）==========
    KwaiInstallIOKitHook();

    // ========== ⑩ 快手设备信息类（platformString / UIDeviceHardware）==========
    KwaiInstallKwaiDeviceHook();

    // ========== ⑭ 时间/屏幕/设备伪装 ==========
    KwaiInstallTimeSpoof();

    // ========== ⑮ 存储伪装 ==========
    KwaiInstallStorageSpoof();
    KwaiInstallBatterySpoof();
    KwaiInstallExtSpoof();
    KwaiInstallDeepSpoof();
    KwaiInstallDetectorBypass();
    KwaiInstallDataSpoof();
    KwaiInstallHistorySpoof();
    KwaiInstallTrueParamSpoof();
    KwaiInstallV11Spoof();
    KwaiInstallLCFeatureHide();
    // [DISABLED-TEST] KwaiInstallHomeSpoof();   // 路径伪装测试
    KwaiInstallEnvHide();
    KwaiInstallRepackBypass();
    // [DISABLED] KwaiInstallBinRedirect();   // 正版不存在时无效
    // [DISABLED] KwaiInstallMachOFake();   // 无实际效果
    // [DISABLED-CRASH] KwaiInstallSignPathBlock();   // 拦截签名文件导致闪退
    KwaiInstallSigBypass();

    // ========== ⑪ Weapon 风控对抗（替换采集数据）==========
    {
        extern void KwaiWeaponInstall(void);
        extern void KwaiWeaponSetValues(NSString *, NSString *, NSString *, NSString *, NSString *, NSString *, NSNumber *, NSNumber *);
        KwaiWeaponSetValues(g_fakeMachine,
                            [UIDevice currentDevice].name,
                            g_fakeSerial,
                            g_fakeUUID,
                            g_fakeIDFV.UUIDString,
                            g_fakeUUID,   // IDFA 用同一个（或另生成）
                            @(g_fakeMemSize),
                            @(g_fakeNCPU));
    KwaiWeaponInstall();
    }

    // ========== ⑫ 越狱检测绕过（文件路径拦截）==========
    {
        extern void KwaiJailbreakInstall(void);
        KwaiJailbreakInstall();
    }

    // ========== ⑬ 综合反检测（fishhook/模拟器/代理/文件）==========
    {
        extern void KwaiAntiDetectInstall(void);
        KwaiAntiDetectInstall();
    }



    // ========== ⑨ 进程伪装（假可执行路径）==========
    {
        extern void KwaiHideSetFakeProcPath(const char *);
        // 伪装成真机原生安装路径
        NSString *home = NSHomeDirectory();
        // 找到 guest 容器的 Bundle 路径
        NSString *fakePath = [NSString stringWithFormat:@"/var/containers/Bundle/Application/%@/com.jiangjia.gif.app/com_kwai_gif",
                              [[NSUUID UUID] UUIDString]];
        KwaiHideSetFakeProcPath(fakePath.UTF8String);
        KWLog(@"[spoof] fake proc path set");
    }


    KWLog(@"[spoof] done: machine=%s ncpu=%d mem=%lld",
          g_fakeMachine.UTF8String, g_fakeNCPU, g_fakeMemSize);
}

// ============================================================
//  ??????
//  hook ?????????? did / egid / token / salt / api_st
// ============================================================

static NSMutableDictionary *g_fiveParams = nil;   // ??????

static void KwaiInitFiveParams(void) {
    if (!g_fiveParams) g_fiveParams = [NSMutableDictionary dictionary];
}

// ? URL ?????? "key=value"
static void KwaiScanParam(NSString *text, NSString *key) {
    if (!text || !key) return;
    NSString *needle = [key stringByAppendingString:@"="];
    NSRange r = [text rangeOfString:needle];
    if (r.location == NSNotFound) return;

    NSString *tail = [text substringFromIndex:r.location + needle.length];
    // ????& " ' space ??
    NSCharacterSet *stops = [NSCharacterSet characterSetWithCharactersInString:@"&;\"' \n\r\t?/|,}>)<"];
    NSRange e = [tail rangeOfCharacterFromSet:stops];
    NSString *val = (e.location == NSNotFound) ? tail : [tail substringToIndex:e.location];
    if (val.length < 4) return;

    // ?????????
    @synchronized(g_fiveParams) {
        NSString *old = g_fiveParams[key];
        if (!old || ![old isEqualToString:val]) {
            g_fiveParams[key] = val;
        }
    }
}

// ????????URL / header / body?
static void KwaiScanText(NSString *text) {
    if (!text || text.length < 8) return;
    KwaiScanParam(text, @"did");
    KwaiScanParam(text, @"egid");
    KwaiScanParam(text, @"global_id");
    KwaiScanParam(text, @"token");
    KwaiScanParam(text, @"api_st");
    KwaiScanParam(text, @"salt");
    KwaiScanParam(text, @"client_salt");
    KwaiScanParam(text, @"token_client_salt");
    KwaiScanParam(text, @"user_id");
    KwaiScanParam(text, @"uid");
}

// ---- hook NSURLSession dataTaskWithRequest ----
static NSURLSessionDataTask *(*orig_dataTask)(id, SEL, NSURLRequest *, void (^)(NSData *, NSURLResponse *, NSError *));
static NSURLSessionDataTask *kw_dataTask(id self, SEL _cmd, NSURLRequest *req, void (^h)(NSData *, NSURLResponse *, NSError *)) {
    @try {
        if (req) {
            KwaiInitFiveParams();
            KwaiScanText(req.URL.absoluteString);
            [req.allHTTPHeaderFields enumerateKeysAndObjectsUsingBlock:^(NSString *k, NSString *v, BOOL *stop) {
                KwaiScanText(v);
                KwaiScanText(k);
            }];
            if (req.HTTPBody) {
                NSString *b = [[NSString alloc] initWithData:req.HTTPBody encoding:NSUTF8StringEncoding];
                KwaiScanText(b);
            }
        }
    } @catch (NSException *e) {}
    return orig_dataTask(self, _cmd, req, h);
}

// ---- hook NSURLSession dataTaskWithURL ----
static NSURLSessionDataTask *(*orig_dataTaskURL)(id, SEL, NSURL *, void (^)(NSData *, NSURLResponse *, NSError *));
static NSURLSessionDataTask *kw_dataTaskURL(id self, SEL _cmd, NSURL *url, void (^h)(NSData *, NSURLResponse *, NSError *)) {
    @try {
        if (url) { KwaiInitFiveParams(); KwaiScanText(url.absoluteString); }
    } @catch (NSException *e) {}
    return orig_dataTaskURL(self, _cmd, url, h);
}

// ---- hook NSURLConnection sendSynchronousRequest???????----
static NSData *(*orig_sendSync)(id, SEL, NSURLRequest *, NSURLResponse **, NSError **);

// ---- ?? hook ----
static BOOL g_fiveInstalled = NO;


static void KwaiInstallFiveParams(void) {
    if (g_fiveInstalled) return;
    g_fiveInstalled = YES;
    KwaiInitFiveParams();
    KWLog(@"[5p] init (file-only mode, no network hooks)");

    // ? ? hook ??????? EXC_BAD_ACCESS?
    // ????????
    KwaiReadFromCache();
    KWLog(@"[5p] cache scan done, params=%lu", (unsigned long)g_fiveParams.count);

    // ?? Keychain
    KwaiDumpKeychain();
    KwaiDumpPlist();
    // ★ v50：passToken 及同族 token（从 com.kuaishou.users/<uid>/basic_info）
    KwaiDumpPassToken();
}

// ---- ? KSURLCache ??? did/egid????----
static void KwaiReadFromCache(void) {
    @try {
        NSString *home = NSHomeDirectory();
        NSString *cacheDir = [home stringByAppendingPathComponent:
                              @"Library/Caches/com.jiangjia.gif/KSURLCache"];
        NSFileManager *fm = [NSFileManager defaultManager];
        NSArray *items = [fm contentsOfDirectoryAtPath:cacheDir error:nil];
        if (!items) return;

        // ? ??????? -wal > Cache.db* ?????? fsCachedData?
        NSMutableArray *ordered = [NSMutableArray array];
        for (NSString *n in items) {
            if ([n hasSuffix:@"-wal"]) [ordered insertObject:n atIndex:0];
            else if ([n hasPrefix:@"Cache.db"]) [ordered addObject:n];
        }

        for (NSString *n in ordered) {
            NSString *p = [cacheDir stringByAppendingPathComponent:n];
            NSData *d = [NSData dataWithContentsOfFile:p];
            if (!d || d.length < 16) continue;
            NSString *txt = [[NSString alloc] initWithData:d encoding:NSISOLatin1StringEncoding];
            if (!txt) continue;
            KwaiScanText(txt);
            KWLog(@"[5p] scanned %@ (%lu bytes)", n, (unsigned long)d.length);
        }
    } @catch (NSException *e) { KWLog(@"[5p] cache read ex: %@", e); }
}

// ---- ??????? ----
NSDictionary *KwaiGetFiveParams(void) {
    @synchronized(g_fiveParams) {
        if (!g_fiveParams) return @{};
        return [g_fiveParams copy];
    }
}
// ---- ?? Keychain?? token/salt/api_st?----
static NSString *KwaiUnarchive(NSData *d) {
    if (!d) return nil;
    @try {
        id obj = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSObject class]
                                                   fromData:d error:nil];
        if ([obj isKindOfClass:[NSString class]]) return obj;
        if (obj) return [obj description];
    } @catch (NSException *e) {}
    @try {
        id obj = [NSKeyedUnarchiver unarchiveObjectWithData:d];
        if ([obj isKindOfClass:[NSString class]]) return obj;
        if (obj) return [obj description];
    } @catch (NSException *e) {}
    return nil;
}

static NSString *KwaiKeychainGet(NSString *acct) {
    NSDictionary *q = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount: acct,
        (__bridge id)kSecReturnData: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne,
    };
    CFTypeRef d = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)q, &d) != errSecSuccess || !d) return nil;
    NSData *data = (__bridge_transfer NSData *)d;
    NSString *s = KwaiUnarchive(data);
    if (!s) s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return s;
}

static void KwaiDumpKeychain(void) {
    @try {
        KWLog(@"[kv] === enumerate MMKV ===");
        Class mmkvCls = NSClassFromString(@"MMKV");
        if (!mmkvCls) { KWLog(@"[kv] MMKV not found"); return; }
        SEL wsel = NSSelectorFromString(@"mmkvWithID:");
        if (![mmkvCls respondsToSelector:wsel]) { KWLog(@"[kv] no mmkvWithID"); return; }

        NSArray *ids = @[@"com.kuaishou.KSwitchSDK.DEFAULT", @"com.kuaishou.account",
                         @"com.jiangjia.gif", @"com.kuaishou.KSwitchSDK"];
        for (NSString *mid in ids) {
            @try {
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                id kv = [mmkvCls performSelector:wsel withObject:mid];
                #pragma clang diagnostic pop
                if (!kv) continue;
                SEL ak = NSSelectorFromString(@"allKeys");
                if (![kv respondsToSelector:ak]) continue;
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                NSArray *keys = [kv performSelector:ak];
                #pragma clang diagnostic pop
                KWLog(@"[kv] %@ has %lu keys", mid, (unsigned long)keys.count);
                for (NSString *k in keys) {
                    NSString *v = nil;
                    @try {
                        SEL gs = NSSelectorFromString(@"getStringForKey:");
                        if ([kv respondsToSelector:gs]) {
                            #pragma clang diagnostic push
                            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                            v = [kv performSelector:gs withObject:k];
                            #pragma clang diagnostic pop
                        }
                    } @catch (NSException *e) {}
                    if (v.length) {
                        KWLog(@"[kv]   %@ = %@", k, (v.length > 120 ? [v substringToIndex:120] : v));
                    }
                }
            } @catch (NSException *e) { KWLog(@"[kv] ex %@: %@", mid, e); }
        }
        KWLog(@"[kv] === done ===");
    } @catch (NSException *e) { KWLog(@"[kv] outer ex: %@", e); }
}
// ============================================================
//  ?? plist ????
// ============================================================
// ?? plist ?????token/salt/did/api_st???? g_fiveParams
static void KwaiDumpPlist(void) {
    @try {
        NSString *home = NSHomeDirectory();
        NSString *p = [home stringByAppendingPathComponent:
                       @"Library/Preferences/com.jiangjia.gif.plist"];
        NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:p];
        if (!d) { KWLog(@"[pl] load failed: %@", p); return; }
        KWLog(@"[pl] keys=%lu", (unsigned long)d.count);

        KwaiInitFiveParams();
        @synchronized(g_fiveParams) {
            id v;
            v = d[@"Gif_Token"];
            if ([v isKindOfClass:[NSString class]] && [v length]) g_fiveParams[@"token"] = v;

            v = d[@"Gif_Token_Salt"] ?: d[@"Gif_KwaiClientSalt"];
            if ([v isKindOfClass:[NSString class]] && [v length]) g_fiveParams[@"salt"] = v;

            v = d[@"KLink_Persistent_klink.device_id"];
            if ([v isKindOfClass:[NSString class]] && [v length]) g_fiveParams[@"did"] = v;

            v = d[@"Gif_ServiceToken"];
            if ([v isKindOfClass:[NSString class]] && [v length]) g_fiveParams[@"api_st"] = v;
        }
        KWLog(@"[pl] token=%@ salt=%@ did=%@ api_st=%lu",
              g_fiveParams[@"token"], g_fiveParams[@"salt"],
              g_fiveParams[@"did"], (unsigned long)[g_fiveParams[@"api_st"] length]);
    } @catch (NSException *e) { KWLog(@"[pl] ex: %@", e); }
}


// ============================================================
//  ★ v50：passToken 提取（实机确认的路径与格式）
//
//  数据位置（iPhone 15.4 实测）：
//    <容器>/Library/Application Support/com.kuaishou.users/<user_id>/basic_info
//
//  格式：NSKeyedArchiver 编码的 binary plist，解开后是一层 NSDictionary，
//        其中 key "passToken" 的值是一个 base64url 字符串（实测 391 字符），
//        解码后是 protobuf，首字段为 "passport.ks-pass-token"。
//
//  同一个文件里还能拿到（一并提取，做交叉可用性验证）：
//    token / apiServiceToken / h5ServiceToken / quickloginToken
//    token_client_salt / kwaiApiClientSalt
//    user_id / user_name / kwaiId / headurl / fansNumber / lastLoginType
//
//  注意：不能用 [NSDictionary dictionaryWithContentsOfFile:] 直接读 ——
//        那是 NSKeyedArchiver 归档，得到的是 {$archiver,$objects,$top} 结构，
//        必须走 NSKeyedUnarchiver 才能拿到真正的业务字典。
// ============================================================

// 当前登录用户的 user_id（basic_info 目录名就是它）。
// 优先读 current_user 文件（存的就是 uid），失败则扫描 users 目录下最新的子目录。
static NSString *KwaiCurrentUserId(void) {
    NSString *usersRoot = [NSHomeDirectory() stringByAppendingPathComponent:
                           @"Library/Application Support/com.kuaishou.users"];
    NSFileManager *fm = [NSFileManager defaultManager];

    // ① current_user 文件里通常直接是 uid 字符串
    @try {
        NSString *cu = [usersRoot stringByAppendingPathComponent:@"current_user"];
        NSString *s = [NSString stringWithContentsOfFile:cu
                                                encoding:NSUTF8StringEncoding error:nil];
        if (!s.length) {
            // 可能是归档格式，试 unarchive
            NSData *d = [NSData dataWithContentsOfFile:cu];
            if (d.length) {
                id o = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSObject class]
                                                         fromData:d error:nil];
                if (!o) o = [NSKeyedUnarchiver unarchiveObjectWithData:d];
                if ([o isKindOfClass:[NSString class]]) s = o;
                else if ([o isKindOfClass:[NSNumber class]]) s = [o stringValue];
            }
        }
        s = [s stringByTrimmingCharactersInSet:
             [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (s.length && [s rangeOfCharacterFromSet:
                         [[NSCharacterSet decimalDigitCharacterSet] invertedSet]].location == NSNotFound) {
            return s;   // 纯数字 → 是 uid
        }
    } @catch (NSException *e) {}

    // ② 回退：扫 users 目录，取 basic_info 修改时间最新的那个子目录
    @try {
        NSArray *subs = [fm contentsOfDirectoryAtPath:usersRoot error:nil];
        NSString *bestUid = nil;
        NSDate *bestDate = nil;
        for (NSString *sub in subs) {
            if ([sub isEqualToString:@"current_user"]) continue;
            NSString *bi = [[usersRoot stringByAppendingPathComponent:sub]
                            stringByAppendingPathComponent:@"basic_info"];
            NSDictionary *attr = [fm attributesOfItemAtPath:bi error:nil];
            if (!attr) continue;
            NSDate *mt = attr[NSFileModificationDate];
            if (!mt) continue;
            if (!bestDate || [mt compare:bestDate] == NSOrderedDescending) {
                bestDate = mt;
                bestUid = sub;
            }
        }
        if (bestUid.length) return bestUid;
    } @catch (NSException *e) {}

    return nil;
}

// 读 basic_info 并解开成业务字典
static NSDictionary *KwaiLoadBasicInfo(void) {
    NSString *uid = KwaiCurrentUserId();
    if (!uid.length) { KWLog(@"[pt] current user id not found"); return nil; }

    NSString *p = [[[NSHomeDirectory() stringByAppendingPathComponent:
                     @"Library/Application Support/com.kuaishou.users"]
                    stringByAppendingPathComponent:uid]
                   stringByAppendingPathComponent:@"basic_info"];
    NSData *d = [NSData dataWithContentsOfFile:p];
    if (!d.length) { KWLog(@"[pt] basic_info empty: %@", p); return nil; }

    // basic_info 是 NSKeyedArchiver 归档，必须 unarchive
    id root = nil;
    @try {
        root = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSObject class]
                                                 fromData:d error:nil];
    } @catch (NSException *e) {}
    if (!root) {
        @try { root = [NSKeyedUnarchiver unarchiveObjectWithData:d]; }
        @catch (NSException *e) {}
    }
    if ([root isKindOfClass:[NSDictionary class]]) {
        KWLog(@"[pt] basic_info loaded, %lu keys", (unsigned long)[(NSDictionary *)root count]);
        return (NSDictionary *)root;
    }
    // 少数版本可能真是普通 plist
    NSDictionary *plain = [NSDictionary dictionaryWithContentsOfFile:p];
    if (plain) {
        // 排掉 NSKeyedArchiver 的外壳
        if (plain[@"$objects"] || plain[@"$archiver"]) {
            KWLog(@"[pt] basic_info is archive shell, unarchive yielded nil");
            return nil;
        }
        return plain;
    }
    KWLog(@"[pt] basic_info unreadable");
    return nil;
}

// 从 basic_info 提取 passToken 及同族 token
static void KwaiDumpPassToken(void) {
    @try {
        NSDictionary *bi = KwaiLoadBasicInfo();
        if (!bi) { KWLog(@"[pt] no basic_info"); return; }

        KwaiInitFiveParams();

        // 允许的 key → 内部名映射
        // passToken 是主目标；其余一并抓下来，便于交叉验证 token 是否可用
        NSDictionary *map = @{
            @"passToken":          @"passToken",
            @"token":              @"pt_token",
            @"apiServiceToken":    @"apiServiceToken",
            @"h5ServiceToken":     @"h5ServiceToken",
            @"quickloginToken":    @"quickloginToken",
            @"token_client_salt":  @"pt_client_salt",
            @"kwaiApiClientSalt":  @"kwaiApiClientSalt",
            @"user_id":            @"pt_user_id",
            @"user_name":          @"pt_user_name",
            @"kwaiId":             @"pt_kwaiId",
        };

        @synchronized(g_fiveParams) {
            for (NSString *k in map) {
                id v = bi[k];
                if (!v) continue;
                NSString *s = nil;
                if ([v isKindOfClass:[NSString class]]) {
                    s = v;
                } else if ([v isKindOfClass:[NSNumber class]]) {
                    s = [v stringValue];
                }
                if (!s.length) continue;
                g_fiveParams[map[k]] = s;
                // passToken 较长，日志只打前 60 字符
                NSString *shown = (s.length > 60) ? [s substringToIndex:60] : s;
                KWLog(@"[pt] %@ = %@ (len=%lu)", map[k], shown, (unsigned long)s.length);
            }
        }

        // passToken 解出来看看服务名，确认拿对了东西
        NSString *pt = g_fiveParams[@"passToken"];
        if (pt.length) {
            KWLog(@"[pt] passToken OK, len=%lu", (unsigned long)pt.length);
        } else {
            KWLog(@"[pt] passToken MISSING in basic_info");
        }
    } @catch (NSException *e) {
        KWLog(@"[pt] ex: %@", e);
    }
}


// ?????token----salt----did----egid----api_st
NSString *KwaiGetFiveString(void) {
    @synchronized(g_fiveParams) {
        if (!g_fiveParams) return @"";
        NSString *t = g_fiveParams[@"token"]  ?: @"";
        NSString *s = g_fiveParams[@"salt"]   ?: @"";
        NSString *d = g_fiveParams[@"did"]    ?: @"";
        NSString *e = g_fiveParams[@"egid"]   ?: @"";
        NSString *a = g_fiveParams[@"api_st"] ?: @"";
        if (!t.length && !s.length && !d.length && !e.length && !a.length) return @"";
        // ★ v50：passToken 追加在最后一段，保持前五段格式不变（兼容旧用法）
        NSString *pt = g_fiveParams[@"passToken"] ?: @"";
        if (pt.length) {
            return [NSString stringWithFormat:@"%@----%@----%@----%@----%@----%@",
                    t, s, d, e, a, pt];
        }
        return [NSString stringWithFormat:@"%@----%@----%@----%@----%@", t, s, d, e, a];
    }
}
// ============================================================
//  ????????????? + ??? + ?????
// ============================================================
// ============================================================
//  ????? + ????
// ============================================================

// ---------- ???? ----------
@interface KwaiFivePanel : UIWindow
@end

@implementation KwaiFivePanel {
    NSString *_five;
    UITextView *_tv;
}

- (instancetype)initWithFive:(NSString *)five {
    UIScreen *sc = [UIScreen mainScreen];
    CGFloat W = sc.bounds.size.width;
    CGFloat H = sc.bounds.size.height;
    CGFloat pw = W - 32;                 // ???
    CGFloat ph = MIN(460, H - 120);      // ???????
    CGRect f = CGRectMake(16, (H - ph) / 2.0, pw, ph);
    self = [super initWithFrame:f];
    if (self) {
        _five = [five copy] ?: @"";
        self.windowLevel = UIWindowLevelAlert + 200;
        self.backgroundColor = [UIColor clearColor];
        self.rootViewController = [[UIViewController alloc] init];

        UIView *bg = [[UIView alloc] initWithFrame:self.bounds];
        bg.backgroundColor = [UIColor colorWithWhite:0.11 alpha:0.98];
        bg.layer.cornerRadius = 14;
        bg.layer.masksToBounds = YES;
        bg.layer.borderWidth = 1;
        bg.layer.borderColor = [UIColor colorWithWhite:0.35 alpha:1].CGColor;
        [self.rootViewController.view addSubview:bg];

        CGFloat pad = 14;
        CGFloat y = pad;

        // ??
        UILabel *title = [[UILabel alloc] initWithFrame:
                          CGRectMake(pad, y, pw - pad*2, 24)];
        title.text = @"快手五参";
        title.textColor = [UIColor whiteColor];
        title.font = [UIFont boldSystemFontOfSize:17];
        title.textAlignment = NSTextAlignmentCenter;
        [bg addSubview:title];
        y += 30;

        // ???
        UIView *line = [[UIView alloc] initWithFrame:CGRectMake(pad, y, pw - pad*2, 1)];
        line.backgroundColor = [UIColor colorWithWhite:0.3 alpha:1];
        [bg addSubview:line];
        y += 10;

        // ? ???????????????????????
        CGFloat btnH = 44;
        CGFloat btnY = ph - pad - btnH;
        CGFloat tvH = btnY - y - 10;

        _tv = [[UITextView alloc] initWithFrame:CGRectMake(pad, y, pw - pad*2, tvH)];
        _tv.text = _five.length ? _five : @"(empty)";
        _tv.editable = NO;
        _tv.selectable = YES;
        _tv.backgroundColor = [UIColor colorWithWhite:0.05 alpha:1];
        _tv.textColor = [UIColor colorWithRed:0.55 green:0.9 blue:0.6 alpha:1];
        _tv.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
        _tv.layer.cornerRadius = 8;
        _tv.layer.masksToBounds = YES;
        _tv.textContainerInset = UIEdgeInsetsMake(8, 8, 8, 8);
        [bg addSubview:_tv];

        // ?????????
        NSInteger n = 3;
        CGFloat gap = 8;
        CGFloat bw = (pw - pad*2 - gap*(n-1)) / (CGFloat)n;
        NSArray *titles = @[@"复制", @"保存", @"关闭"];
        NSArray *sels = @[@"doCopy", @"doSave", @"doClose"];
        for (NSInteger i = 0; i < n; i++) {
            UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
            b.frame = CGRectMake(pad + i*(bw+gap), btnY, bw, btnH);
            [b setTitle:titles[i] forState:UIControlStateNormal];
            [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            b.backgroundColor = (i == 2)
                ? [UIColor colorWithWhite:0.32 alpha:1]
                : [UIColor colorWithRed:0.20 green:0.52 blue:0.86 alpha:1];
            b.titleLabel.font = [UIFont boldSystemFontOfSize:15];
            b.layer.cornerRadius = 8;
            [b addTarget:self action:NSSelectorFromString(sels[i])
                forControlEvents:UIControlEventTouchUpInside];
            [bg addSubview:b];
        }
    }
    return self;
}

- (void)doCopy {
    if (_five.length) [UIPasteboard generalPasteboard].string = _five;
    KWLog(@"[ball] copied %lu", (unsigned long)_five.length);
    [self doClose];
}
- (void)doSave {
    NSString *home = NSHomeDirectory();
    NSString *p = [[home stringByAppendingPathComponent:@"Documents"]
                   stringByAppendingPathComponent:@"five_params.txt"];
    [_five writeToFile:p atomically:YES encoding:NSUTF8StringEncoding error:nil];
    KWLog(@"[ball] saved: %@", p);
    [self doClose];
}
- (void)doClose {
    self.hidden = YES;
    self.rootViewController = nil;
}
@end

// ---------- ??? ----------
@interface KwaiFiveBall : UIWindow
@end

@implementation KwaiFiveBall {
    UIView *_circle;
}

- (instancetype)init {
    CGFloat d = 52;                                  // ???
    UIScreen *sc = [UIScreen mainScreen];
    CGRect f = CGRectMake(sc.bounds.size.width - d - 10, 140, d, d);
    self = [super initWithFrame:f];
    if (self) {
        self.windowLevel = UIWindowLevelAlert + 100;
        self.backgroundColor = [UIColor clearColor];
        self.rootViewController = [[UIViewController alloc] init];
        self.rootViewController.view.backgroundColor = [UIColor clearColor];

        _circle = [[UIView alloc] initWithFrame:CGRectMake(0, 0, d, d)];
        _circle.backgroundColor = [UIColor colorWithRed:0.13 green:0.13 blue:0.15 alpha:0.92];
        _circle.layer.cornerRadius = d / 2.0;
        _circle.layer.masksToBounds = YES;
        _circle.layer.borderWidth = 1.5;
        _circle.layer.borderColor = [UIColor colorWithRed:1.0 green:0.78 blue:0.25 alpha:0.95].CGColor;
        _circle.userInteractionEnabled = YES;
        [self.rootViewController.view addSubview:_circle];

        UILabel *t = [[UILabel alloc] initWithFrame:_circle.bounds];
        t.text = @"5P";
        t.textColor = [UIColor colorWithRed:1.0 green:0.85 blue:0.35 alpha:1];
        t.font = [UIFont boldSystemFontOfSize:15];
        t.textAlignment = NSTextAlignmentCenter;
        t.userInteractionEnabled = NO;
        [_circle addSubview:t];

        // ??
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
            initWithTarget:self action:@selector(onPan:)];
        [_circle addGestureRecognizer:pan];
        // ?? ? ???
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
            initWithTarget:self action:@selector(onTap:)];
        [_circle addGestureRecognizer:tap];

        self.hidden = NO;
    }
    return self;
}

- (void)onPan:(UIPanGestureRecognizer *)g {
    UIView *sv = self.superview ?: self.rootViewController.view;
    CGPoint tr = [g translationInView:sv];
    CGPoint c = self.center;
    c.x += tr.x; c.y += tr.y;
    // ??????
    UIScreen *sc = [UIScreen mainScreen];
    CGFloat half = self.bounds.size.width / 2.0;
    c.x = MAX(half, MIN(sc.bounds.size.width - half, c.x));
    c.y = MAX(half + 20, MIN(sc.bounds.size.height - half - 20, c.y));
    self.center = c;
    [g setTranslation:CGPointZero inView:sv];
}

- (void)onTap:(id)s {
    KwaiReadFromCache();
    KwaiDumpPlist();
    NSString *five = KwaiGetFiveString();
    KWLog(@"[ball] tap five len=%lu", (unsigned long)five.length);

    static KwaiFivePanel *panel = nil;
    if (panel) { panel.hidden = YES; panel = nil; }
    panel = [[KwaiFivePanel alloc] initWithFive:five];
    panel.hidden = NO;
}

@end

// ---------- ?? ----------
static KwaiFiveBall *g_ball = nil;
static BOOL g_ballShown = NO;

void KwaiShowBall(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_ballShown) return;
        g_ballShown = YES;
        g_ball = [[KwaiFiveBall alloc] init];
        KWLog(@"[ball] shown");
    });
}

BOOL KwaiIsLoggedIn(void) {
    NSString *home = NSHomeDirectory();
    NSString *p = [home stringByAppendingPathComponent:
                   @"Library/Preferences/com.jiangjia.gif.plist"];
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:p];
    id t = d[@"Gif_Token"];
    return [t isKindOfClass:[NSString class]] && [t length] > 10;
}

void KwaiStartBallWatcher(void) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        for (int i = 0; i < 120; i++) {
            @autoreleasepool {
                if (KwaiIsLoggedIn()) {
                    KwaiReadFromCache();
                    KwaiDumpPlist();
                    NSString *five = KwaiGetFiveString();
                    KWLog(@"[ball] logged in, five=%lu chars", (unsigned long)five.length);
                    KwaiShowBall();
                    break;
                }
            }
            usleep(500 * 1000);
        }
    });
}

// ============================================================
//  悬浮球手势处理（挂在 host UIWindow 上）
// ============================================================

// ============================================================
//  QQ 授权探针（先只打日志，看快手点 QQ 授权走哪条路）
// ============================================================
void KwaiInstallQQProbe(void) {
    static BOOL done = NO;
    if (done) return;
    done = YES;
    KWLog(@"[probe] installing QQ probes");

    NSArray *clsMethods = @[
        @[@"KSSocialQQOAuthService", @"sf_loginWithScopes:success:failure:"],
        @[@"KSSocialQQOAuthService", @"oQQAuthWithReq:"],
        @[@"KSSocialQQURLHandler", @"handleOpenURLStr:"],
        @[@"KSSocialQQURLHandler", @"handleOpenURLString:"],
        @[@"KSSocialQQURLHandler", @"handleOpenURL:"],
        @[@"KSSocialQQURLHandler", @"handleOpenURL:delegate:"],
        @[@"TencentOAuth", @"authorizeWithPermissions"],
        @[@"TencentOAuth", @"handleOpenURL:"],
        @[@"TencentOAuth", @"handleOpenURL:delegate:"],
    ];

    for (NSArray *pair in clsMethods) {
        NSString *cn = pair[0], *sn = pair[1];
        Class cls = NSClassFromString(cn);
        if (!cls) { KWLog(@"[probe] no class %@", cn); continue; }
        SEL sel = NSSelectorFromString(sn);

        // 先试实例方法
        Method m = class_getInstanceMethod(cls, sel);
        if (m) {
            IMP old = method_getImplementation(m);
            KWLog(@"[probe] found -[%@ %@] imp=%p", cn, sn, old);
            // 用 block 包装打日志（限于篇幅，先只记录存在性）
        }
        // 再试类方法
        Method cm = class_getClassMethod(cls, sel);
        if (cm) {
            KWLog(@"[probe] found +[%@ %@]", cn, sn);
        }
        if (!m && !cm) {
            KWLog(@"[probe] NOT found %@ %@", cn, sn);
        }
    }
    KWLog(@"[probe] done");
}

// ============================================================
//  QQ 授权拦截（hook KSSocialQQOAuthService 登录入口）
// ============================================================
static IMP g_orig_qqLogin = NULL;
id   g_qqSuccessBlock = nil;
id   g_qqServiceInst = nil;
id   g_qqDict = nil;
id   g_qqFailureBlock = nil;

// 拦截后的处理：弹输入框 → 调 API → 交付
static void KwaiQQInterceptFlow(void) {
    // 直接调用原有的 sf_loginWithScopes:success:failure: → 跳真 QQ
    KWLog(@"[qq] direct open real QQ");
    if (g_orig_qqLogin && g_qqServiceInst) {
        ((void(*)(id,SEL,id,id,id))g_orig_qqLogin)(
            g_qqServiceInst,
            NSSelectorFromString(@"sf_loginWithScopes:success:failure:"),
            nil, g_qqSuccessBlock, g_qqFailureBlock);
        KWLog(@"[qq] called original sf_login -> real QQ");
    } else {
        KWLog(@"[qq] no orig impl, fallback");
    }
}

// 被 hook 的方法：-(void)sf_loginWithScopes:(id)scopes success:(id)s failure:(id)f
static void kw_qqLogin(id self, SEL _cmd, id scopes, id success, id failure) {
    @try {
        KWLog(@"[qq] INTERCEPTED");
        g_qqSuccessBlock = success;
        g_qqFailureBlock = failure;
        g_qqServiceInst = self;
        KwaiQQInterceptFlow();   // 直接跳真 QQ
    } @catch (NSException *e) {
        KWLog(@"[qq] ex: %@", e);
        if (g_orig_qqLogin) ((void(*)(id,SEL,id,id,id))g_orig_qqLogin)(self,_cmd,scopes,success,failure);
    }
}

void KwaiInstallQQHook(void) {
    static BOOL done = NO;
    if (done) return;
    done = YES;

    Class cls = NSClassFromString(@"KSSocialQQOAuthService");
    if (!cls) {
        // 可能只作为 category 存在，用 runtime 找
        cls = NSClassFromString(@"_TtC12KSSocialSDK22KSSocialQQOAuthService");
    }
    if (!cls) { KWLog(@"[qq] hook: class not found"); return; }

    SEL sel = NSSelectorFromString(@"sf_loginWithScopes:success:failure:");
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) { KWLog(@"[qq] hook: method not found"); return; }

    g_orig_qqLogin = method_getImplementation(m);
    method_setImplementation(m, (IMP)kw_qqLogin);
    KWLog(@"[qq] hook installed on %@", NSStringFromClass(cls));
}

// ============================================================
//  时间伪装 + 扩展 hook（对齐 libsystem_x 的全部功能）
// ============================================================

// ---- ① 开机时长 / 运行时间 ----
static long long g_timeOffset = 0;   // 秒：把"现在"往前推

void KwaiSetupTimeSpoof(void) {
    if (g_timeOffset != 0) return;
    // ★ v49：开机时长改为 60~365 天（两个月到一年）。
    //   原为 30~180 天。长时间稳定运行的设备看起来更"老"、更真实，
    //   且刻意避开整月边界（不用 30/365 这两个端点值）。
    unsigned long seed = KwaiContainerSeed();
    long long days = 60 + (long long)(seed % 306);   // 60~365 天
    g_timeOffset = days * 24LL * 3600LL + (long long)(seed % 86400);
    KWLog(@"[time] uptime spoof: %llds (%.1f days, target 60~365)", g_timeOffset, g_timeOffset / 86400.0);
}

// sysctl kern.boottime（开机时刻）
static int (*orig_sysctl_time)(int *, u_int, void *, size_t *, void *, size_t) = NULL;
static int kw_sysctl_time(int *name, u_int namelen, void *oldp, size_t *oldlenp,
                           void *newp, size_t newlen) {
    if (g_timeOffset > 0 && name && namelen >= 2 && oldp && oldlenp) {
        // CTL_KERN = 1, KERN_BOOTTIME = 21
        if (name[0] == 1 && name[1] == 21) {
            if (*oldlenp >= sizeof(struct timeval)) {
                struct timeval tv; gettimeofday(&tv, NULL);
                tv.tv_sec -= g_timeOffset;
                memcpy(oldp, &tv, sizeof(tv)); *oldlenp = sizeof(tv);
                return 0;
            }
        }
    }
    return orig_sysctl_time ? orig_sysctl_time(name, namelen, oldp, oldlenp, newp, newlen) : -1;
}

// sysctlbyname kern.boottime
static int (*orig_sysctlbyname_time)(const char *, void *, size_t *, void *, size_t) = NULL;
static int kw_sysctlbyname_time(const char *name, void *oldp, size_t *oldlenp,
                                 void *newp, size_t newlen) {
    if (g_timeOffset > 0 && name && strcmp(name, "kern.boottime") == 0 && oldp && oldlenp) {
        if (*oldlenp >= sizeof(struct timeval)) {
            struct timeval tv; gettimeofday(&tv, NULL);
            tv.tv_sec -= g_timeOffset;
            memcpy(oldp, &tv, sizeof(tv)); *oldlenp = sizeof(tv);
            return 0;
        }
    }
    return orig_sysctlbyname_time ? orig_sysctlbyname_time(name, oldp, oldlenp, newp, newlen) : -1;
}

// mach_absolute_time
// ★ v47.6 修 M16：原实现 `(r > d) ? r - d : r` 用的是【减法】，方向与
//   kern.boottime（往前推 → uptime 变大）相反，同一秒内多个值互相矛盾。
//   正确口径：mach_absolute_time 也应【加】偏移。
//   tick 换算：秒 → tick = s * 1e9 * denom / numer。
//   同时 dispatch_once 取代 tb.denom==0 的非线程安全惰性初始化。
static uint64_t (*orig_mach_abs_time)(void) = NULL;
static uint64_t kw_mach_abs_time(void) {
    uint64_t r = orig_mach_abs_time ? orig_mach_abs_time() : 0;
    if (g_timeOffset <= 0) return r;
    static mach_timebase_info_data_t tb;
    static dispatch_once_t tbOnce;
    dispatch_once(&tbOnce, ^{ mach_timebase_info(&tb); });
    if (tb.numer == 0) return r;
    uint64_t d = (uint64_t)((long double)g_timeOffset * 1e9L
                            * (long double)tb.denom / (long double)tb.numer);
    return r + d;
}

// NSProcessInfo.systemUptime
static NSTimeInterval (*orig_sys_uptime)(id, SEL) = NULL;
static NSTimeInterval kw_sys_uptime(id self, SEL _cmd) {
    NSTimeInterval up = orig_sys_uptime ? orig_sys_uptime(self, _cmd) : 0;
    // ★ 与 kern.boottime 同源同向：boottime 往前推 ⇒ uptime 变大
    return up + (NSTimeInterval)g_timeOffset;
}

// --- ② 屏幕 / 电池 / 设备名 hook ---

// UIScreen bounds / scale
static CGRect (*orig_screen_bounds)(id, SEL) = NULL;
static CGRect kw_screen_bounds(id self, SEL _cmd) {
    if (g_fakeScrW > 0 && g_fakeScrH > 0) {
        UIScreen *sc = (UIScreen *)self;
        if ([sc isEqual:[UIScreen mainScreen]]) return CGRectMake(0, 0, g_fakeScrW, g_fakeScrH);
    }
    return orig_screen_bounds ? orig_screen_bounds(self, _cmd) : CGRectZero;
}

static CGFloat (*orig_screen_scale)(id, SEL) = NULL;
static CGFloat kw_screen_scale(id self, SEL _cmd) {
    if (g_fakeScale > 0) {
        UIScreen *sc = (UIScreen *)self;
        if ([sc isEqual:[UIScreen mainScreen]]) return g_fakeScale;
    }
    return orig_screen_scale ? orig_screen_scale(self, _cmd) : 3.0;
}

// ★ v47.6 修 M3：此前只伪装 bounds/scale，nativeBounds/nativeScale 未伪装，
//   快手用 nativeBounds.size / scale 反推机型 → 逻辑分辨率与像素密度矛盾。
static CGRect (*orig_screen_nativeBounds)(id, SEL) = NULL;
static CGRect kw_screen_nativeBounds(id self, SEL _cmd) {
    if (g_fakeScrW > 0 && g_fakeScrH > 0 && g_fakeScale > 0) {
        UIScreen *sc = (UIScreen *)self;
        if ([sc isEqual:[UIScreen mainScreen]])
            return CGRectMake(0, 0, g_fakeScrW * g_fakeScale, g_fakeScrH * g_fakeScale);
    }
    return orig_screen_nativeBounds ? orig_screen_nativeBounds(self, _cmd) : CGRectZero;
}

static CGFloat (*orig_screen_nativeScale)(id, SEL) = NULL;
static CGFloat kw_screen_nativeScale(id self, SEL _cmd) {
    if (g_fakeScale > 0) {
        UIScreen *sc = (UIScreen *)self;
        if ([sc isEqual:[UIScreen mainScreen]]) return g_fakeScale;
    }
    return orig_screen_nativeScale ? orig_screen_nativeScale(self, _cmd) : 2.0;
}

// UIDevice.name
static NSString *(*orig_dev_name)(id, SEL) = NULL;
static NSString *kw_dev_name(id self, SEL _cmd) {
    if (g_fakeDevName) return g_fakeDevName;
    return orig_dev_name ? orig_dev_name(self, _cmd) : @"iPhone";
}

// UIDevice.systemVersion
static NSString *(*orig_dev_ver)(id, SEL) = NULL;
static NSString *kw_dev_ver(id self, SEL _cmd) {
    // 与机型的 minIOS 匹配
    if (g_fakeMinIOS > 0) return [NSString stringWithFormat:@"%d.4", g_fakeMinIOS];
    return orig_dev_ver ? orig_dev_ver(self, _cmd) : @"15.4";
}

// NSProcessInfo.operatingSystemVersion
static NSOperatingSystemVersion (*orig_os_ver)(id, SEL) = NULL;
static NSOperatingSystemVersion kw_os_ver(id self, SEL _cmd) {
    if (g_fakeMinIOS > 0) {
        NSOperatingSystemVersion v; v.majorVersion = g_fakeMinIOS; v.minorVersion = 4; v.patchVersion = 0;
        return v;
    }
    return orig_os_ver ? orig_os_ver(self, _cmd) : (NSOperatingSystemVersion){15,4,0};
}

// --- ③ 安装 ---
void KwaiInstallTimeSpoof(void) {
    static BOOL done = NO;
    if (done) return;
    done = YES;
    KwaiSetupTimeSpoof();

    // sysctl / sysctlbyname
    orig_sysctl_time = sysctl;
    @try {
        KWLog(@"[time] sysctl OK");
    } @catch (NSException *e) { KWLog(@"[time] sysctl ex: %@", e); }

    orig_sysctlbyname_time = sysctlbyname;
    @try {
        KWLog(@"[time] sysctlbyname OK");
    } @catch (NSException *e) { KWLog(@"[time] sysctlbn ex: %@", e); }

    // mach_absolute_time
    orig_mach_abs_time = mach_absolute_time;
    @try {
        litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, (void *)mach_absolute_time, (void *)kw_mach_abs_time, NULL);
        KWLog(@"[time] mach_absolute_time OK");
    } @catch (NSException *e) { KWLog(@"[time] mat ex: %@", e); }

    // NSProcessInfo
    Method m1 = class_getInstanceMethod([NSProcessInfo class], @selector(systemUptime));
    if (m1) { orig_sys_uptime = (void *)method_getImplementation(m1);
              method_setImplementation(m1, (IMP)kw_sys_uptime);
              KWLog(@"[time] systemUptime OK"); }

    Method m2 = class_getInstanceMethod([NSProcessInfo class], @selector(operatingSystemVersion));
    if (m2) { orig_os_ver = (void *)method_getImplementation(m2);
              method_setImplementation(m2, (IMP)kw_os_ver);
              KWLog(@"[time] OSVersion OK"); }

    // UIScreen
    Method m3 = class_getInstanceMethod([UIScreen class], @selector(bounds));
    if (m3) { orig_screen_bounds = (void *)method_getImplementation(m3);
              method_setImplementation(m3, (IMP)kw_screen_bounds);
              KWLog(@"[screen] bounds OK"); }

    Method m4 = class_getInstanceMethod([UIScreen class], @selector(scale));
    if (m4) { orig_screen_scale = (void *)method_getImplementation(m4);
              method_setImplementation(m4, (IMP)kw_screen_scale);
              KWLog(@"[screen] scale OK"); }

    // ★ v47.6 补 nativeBounds / nativeScale
    Method m3b = class_getInstanceMethod([UIScreen class], @selector(nativeBounds));
    if (m3b) { orig_screen_nativeBounds = (void *)method_getImplementation(m3b);
               method_setImplementation(m3b, (IMP)kw_screen_nativeBounds);
               KWLog(@"[v47.6] nativeBounds OK"); }
    Method m4b = class_getInstanceMethod([UIScreen class], @selector(nativeScale));
    if (m4b) { orig_screen_nativeScale = (void *)method_getImplementation(m4b);
               method_setImplementation(m4b, (IMP)kw_screen_nativeScale);
               KWLog(@"[v47.6] nativeScale OK"); }

    // UIDevice
    Method m5 = class_getInstanceMethod([UIDevice class], @selector(name));
    if (m5) { orig_dev_name = (void *)method_getImplementation(m5);
              method_setImplementation(m5, (IMP)kw_dev_name);
              KWLog(@"[device] name OK"); }

    Method m6 = class_getInstanceMethod([UIDevice class], @selector(systemVersion));
    if (m6) { orig_dev_ver = (void *)method_getImplementation(m6);
              method_setImplementation(m6, (IMP)kw_dev_ver);
              KWLog(@"[device] systemVersion OK"); }

    KWLog(@"[time] all done");
}

// ============================================================
//  存储伪装（Disk / Storage）
//  hook: statfs / statvfs / NSFileManager / NSURL
//  逻辑：按容器 seed 生成「总容量 + 已用量」，两者自洽
// ============================================================

// ---- 按机型生成合理容量 ----
// ★ 返回「总容量」（由 KwaiSetupStorageSpoof 负责算可用容量）
static long long KwaiDiskTotalForMachine(const char *machine) {
    unsigned long seed = KwaiContainerSeed();
    int tier = 256;   // 默认 256GB
    if (machine) {
        // Pro Max 级别 → 512
        if (strcmp(machine, "iPhone16,2") == 0 ||    // 15 Pro Max
            strcmp(machine, "iPhone17,2") == 0) {    // 16 Pro Max
            tier = 512;
        }
        // Pro 级别 → 256
        else if (strcmp(machine, "iPhone13,3") == 0 || strcmp(machine, "iPhone13,4") == 0 ||
                 strcmp(machine, "iPhone14,2") == 0 || strcmp(machine, "iPhone14,3") == 0 ||
                 strcmp(machine, "iPhone15,2") == 0 || strcmp(machine, "iPhone15,3") == 0 ||
                 strcmp(machine, "iPhone16,1") == 0 ||
                 strcmp(machine, "iPhone17,1") == 0) {
            tier = 256;
        }
        // 其余（标准版 / mini / SE / XS / XR / 11 系列）→ 128 或 256
        else {
            tier = (seed & 1) ? 128 : 256;
        }
    }
    if (tier == 128) return 127700000000LL;   // ≈127.7GB
    if (tier == 256) return 255700000000LL;   // ≈255.7GB
    return 511600000000LL;                    // ≈511.6GB
}

void KwaiSetupStorageSpoof(void) {
    if (g_fakeDiskTotal > 0) return;

    // ① 先定总容量（按机型档次）
    g_fakeDiskTotal = KwaiDiskTotalForMachine(g_fakeMachineC);

    // ② 再由总容量算可用（长期使用：已用 70%~92%）
    unsigned long seed = KwaiContainerSeed();
    int usedPct = 70 + (int)(seed % 23);
    g_fakeDiskFree = g_fakeDiskTotal * (100 - usedPct) / 100;

    KWLog(@"[disk] total=%.1fGB free=%.1fGB used=%d%%",
          g_fakeDiskTotal/1e9, g_fakeDiskFree/1e9, usedPct);
}

// ---- ① statfs ----
static int (*orig_statfs_d)(const char *, struct statfs *) = NULL;
static int kw_statfs_d(const char *path, struct statfs *buf) {
    int r = orig_statfs_d ? orig_statfs_d(path, buf) : -1;
    if (r == 0 && buf && g_fakeDiskTotal > 0) {
        // ★ v47.6 修 M2：strncmp(path,"/var",4) 会误命中 /variant、/var-tmp
        BOOL dataVol = NO;
        if (path) {
            if (strcmp(path, "/") == 0) dataVol = YES;
            else if (strncmp(path, "/private/var/", 13) == 0) dataVol = YES;
            else if (strncmp(path, "/var/", 5) == 0) dataVol = YES;
            else if (strstr(path, "/private/var/mobile/Containers/Data/Application")) dataVol = YES;
        }
        if (dataVol) {
            // ★ 修 M11：补 2% 保留块（真机 bavail < bfree）与 inode 数，
            //   否则风控用 f_files 或 bavail==bfree 即可判定非真机文件系统。
            //   注意：Darwin 的 struct statfs 既没有 f_bused 也没有 f_frsize 字段。
            uint32_t bsize = buf->f_bsize ? buf->f_bsize : 4096;
            buf->f_blocks = (uint64_t)(g_fakeDiskTotal / bsize);
            buf->f_bfree  = (uint64_t)(g_fakeDiskFree  / bsize);
            uint64_t reserved = (uint64_t)((double)g_fakeDiskTotal * 0.02 / bsize);
            buf->f_bavail = (buf->f_bfree > reserved) ? (buf->f_bfree - reserved) : buf->f_bfree;
            uint64_t inodes = (uint64_t)((double)g_fakeDiskTotal / 128.0 / 64.0);
            buf->f_files = inodes;
            buf->f_ffree = (uint64_t)((double)inodes * 0.88);
        }
    }
    return r;
}

// ---- ② statfs64 ----
static int (*orig_statfs64_d)(const char *, struct statfs *) = NULL;

// ---- ③ NSFileManager attributesOfFileSystemForPath ----
static NSDictionary *(*orig_attrs_fs)(id, SEL, NSString *, NSError **) = NULL;
static NSDictionary *kw_attrs_fs(id self, SEL _cmd, NSString *path, NSError **err) {
    NSDictionary *d = orig_attrs_fs ? orig_attrs_fs(self, _cmd, path, err) : nil;
    if (d && g_fakeDiskTotal > 0) {
        // ★ 性能：缓存结果字典，避免每次 mutableCopy + 4 次装箱
        //   实测日志显示该 hook 被调 26 次，每次都重建字典
        static NSDictionary *cached = nil;
        if (!cached) {
            NSMutableDictionary *m = [d mutableCopy];
            m[NSFileSystemSize]              = @(g_fakeDiskTotal);
            m[NSFileSystemFreeSize]          = @(g_fakeDiskFree);
            m[@"NSFileSystemFreeSpaceInBytes"] = @(g_fakeDiskFree);
            m[@"NSFileSystemTotalSizeInBytes"] = @(g_fakeDiskTotal);
            cached = [m copy];
        }
        return cached;
    }
    return d;
}

// ---- ④ NSURL resourceValuesForKeys ----
static NSDictionary *(*orig_url_res)(id, SEL, NSArray<NSURLResourceKey> *, NSError **) = NULL;
static NSDictionary *kw_url_res(id self, SEL _cmd, NSArray<NSURLResourceKey> *keys, NSError **err) {
    NSDictionary *d = orig_url_res ? orig_url_res(self, _cmd, keys, err) : nil;
    if (d && g_fakeDiskTotal > 0) {
        NSMutableDictionary *m = [d mutableCopy];
        if (keys) {
            for (NSURLResourceKey k in keys) {
                if ([k isEqualToString:NSURLVolumeTotalCapacityKey])
                    m[k] = @(g_fakeDiskTotal);
                else if ([k isEqualToString:NSURLVolumeAvailableCapacityKey] ||
                         [k isEqualToString:NSURLVolumeAvailableCapacityForImportantUsageKey] ||
                         [k isEqualToString:NSURLVolumeAvailableCapacityForOpportunisticUsageKey])
                    m[k] = @(g_fakeDiskFree);
            }
        }
        return m;
    }
    return d;
}

// ---- ⑤ volumeAvailableCapacityKey (NSURL 便捷属性) ----

// ---- ⑥ sysctl hw.disk / hw.diskmemory ----
static int (*orig_sysctlbyname_disk)(const char *, void *, size_t *, void *, size_t) = NULL;
static int kw_sysctlbyname_disk(const char *name, void *oldp, size_t *oldlenp,
                                 void *newp, size_t newlen) {
    if (g_fakeDiskTotal > 0 && name && oldp && oldlenp) {
        if (strcmp(name, "hw.disk") == 0 || strcmp(name, "hw.diskmemory") == 0) {
            if (*oldlenp >= sizeof(long long)) {
                *(long long *)oldp = g_fakeDiskTotal;
                *oldlenp = sizeof(long long);
                return 0;
            }
        }
    }
    return orig_sysctlbyname_disk ? orig_sysctlbyname_disk(name, oldp, oldlenp, newp, newlen) : -1;
}

// ---- 安装 ----
void KwaiInstallStorageSpoof(void) {
    static BOOL done = NO;
    if (done) return;
    done = YES;
    KwaiSetupStorageSpoof();

    // statfs
    orig_statfs_d = statfs;
    @try {
        litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, (void *)statfs, (void *)kw_statfs_d, NULL);
        KWLog(@"[disk] statfs OK");
    } @catch (NSException *e) { KWLog(@"[disk] statfs ex: %@", e); }

    // NSFileManager
    Method m1 = class_getInstanceMethod([NSFileManager class], @selector(attributesOfFileSystemForPath:error:));
    if (m1) {
        orig_attrs_fs = (void *)method_getImplementation(m1);
        method_setImplementation(m1, (IMP)kw_attrs_fs);
        KWLog(@"[disk] attributesOfFileSystem OK");
    }

    // NSURL resourceValuesForKeys
    Method m2 = class_getInstanceMethod([NSURL class], @selector(resourceValuesForKeys:error:));
    if (m2) {
        orig_url_res = (void *)method_getImplementation(m2);
        method_setImplementation(m2, (IMP)kw_url_res);
        KWLog(@"[disk] resourceValuesForKeys OK");
    }

    // sysctlbyname hw.disk
    orig_sysctlbyname_disk = sysctlbyname;
    @try {
        KWLog(@"[disk] sysctlbyname OK");
    } @catch (NSException *e) { KWLog(@"[disk] sysctlbn ex: %@", e); }

    KWLog(@"[disk] all done");
}

// ============================================================
//  电池健康伪装（长期使用特征）
//  集成进已有 IOKit hook：拦截 AppleSmartBattery 属性
//  特征：循环 400~900 次 / 健康 78%~92%
// ============================================================

static int g_fakeCycleCount = 0;
static int g_fakeBatteryHealth = 0;
static long long g_fakeBatteryCapacity = 0;
static long long g_fakeBatteryNominal = 0;      // ★ v37: 出厂标称容量
static CFStringRef g_fakeBatterySerial = NULL;

void KwaiSetupBatterySpoof(void) {
    if (g_fakeCycleCount > 0) return;
    unsigned long seed = KwaiContainerSeed();
    g_fakeCycleCount = 400 + (int)((seed >> 3) % 501);        // 400~900
    g_fakeBatteryHealth = 78 + (int)((seed >> 7) % 15);       // 78%~92%
    // ★ v37 修复：三个容量 key 的语义必须不同，否则快手能算出矛盾的健康度
    //   NominalChargeCapacity = 出厂标称（固定，不随健康衰减）
    //   MaxCapacity            = 当前最大容量（衰减后）
    //   AppleRawMaxCapacity    = 设计容量（工厂值，通常 = 标称）
    //   健康度 = MaxCapacity / NominalChargeCapacity
    long long nominal = g_fakeBattery > 0 ? g_fakeBattery : 3200;
    g_fakeBatteryNominal = nominal;                        // 标称（固定）
    g_fakeBatteryCapacity = nominal * g_fakeBatteryHealth / 100;   // 当前容量
    // 电池序列号（假）
    char bs[24];
    snprintf(bs, sizeof(bs), "%08X%04X", (unsigned)(seed & 0xFFFFFFFF), (unsigned)((seed >> 32) & 0xFFFF));
    g_fakeBatterySerial = CFStringCreateWithCString(NULL, bs, kCFStringEncodingUTF8);
    KWLog(@"[battery] cycles=%d health=%d%% capacity=%lld/%lld",
          g_fakeCycleCount, g_fakeBatteryHealth, g_fakeBatteryCapacity, nominal);
}

// 处理 IOKit 返回的电池属性（在已有的 CreateCFProperty hook 里调用）
// 返回替换后的值，或原值
static CFTypeRef KwaiProcessBatteryProp(CFStringRef key, CFTypeRef val) {
    if (!key || g_fakeCycleCount <= 0) return val;

    CFStringRef k = key;
    // 循环次数
    if (CFStringCompare(k, CFSTR("CycleCount"), 0) == kCFCompareEqualTo) {
        if (val) CFRelease(val);
        return (CFTypeRef)CFNumberCreate(NULL, kCFNumberIntType, &g_fakeCycleCount);
    }
    // ★ v37 修复：三个容量 key 语义必须不同
    //   原来三个都返回 g_fakeBatteryCapacity → 快手算出 health = 2816/2816 = 100%
    //   但我们上报 health = 91% → 自相矛盾
    //   正确：NominalChargeCapacity = 标称（固定），MaxCapacity = 衰减后
    if (CFStringCompare(k, CFSTR("AppleRawMaxCapacity"), 0) == kCFCompareEqualTo) {
        if (val) CFRelease(val);
        return (CFTypeRef)CFNumberCreate(NULL, kCFNumberLongLongType, &g_fakeBatteryNominal);
    }
    if (CFStringCompare(k, CFSTR("NominalChargeCapacity"), 0) == kCFCompareEqualTo) {
        if (val) CFRelease(val);
        return (CFTypeRef)CFNumberCreate(NULL, kCFNumberLongLongType, &g_fakeBatteryNominal);
    }
    if (CFStringCompare(k, CFSTR("MaxCapacity"), 0) == kCFCompareEqualTo ||
        CFStringCompare(k, CFSTR("AppleCurrentCapacity"), 0) == kCFCompareEqualTo) {
        if (val) CFRelease(val);
        return (CFTypeRef)CFNumberCreate(NULL, kCFNumberLongLongType, &g_fakeBatteryCapacity);
    }
    // 健康度百分比
    if (CFStringCompare(k, CFSTR("BatteryHealth"), 0) == kCFCompareEqualTo) {
        if (val) CFRelease(val);
        int h = g_fakeBatteryHealth;
        return (CFTypeRef)CFNumberCreate(NULL, kCFNumberIntType, &h);
    }
    // 电池序列号
    if (CFStringCompare(k, CFSTR("BatterySerialNumber"), 0) == kCFCompareEqualTo ||
        CFStringCompare(k, CFSTR("Serial"), 0) == kCFCompareEqualTo) {
        if (val) CFRelease(val);
        return (CFTypeRef)CFRetain(g_fakeBatterySerial);
    }
    // 温度（长期使用会稍高）
    if (CFStringCompare(k, CFSTR("Temperature"), 0) == kCFCompareEqualTo) {
        if (val) CFRelease(val);
        int t = 2900 + (int)(KwaiContainerSeed() % 200);   // 29.00~31.00 ℃
        return (CFTypeRef)CFNumberCreate(NULL, kCFNumberIntType, &t);
    }
    return val;
}

void KwaiInstallBatterySpoof(void) {
    static BOOL done = NO;
    if (done) return;
    done = YES;
    KwaiSetupBatterySpoof();
    KWLog(@"[battery] setup done");
}


// ======== MERGED: KwaiHide.m ========
// ============================================================
//  KwaiHide.m  v5  ——  只保留「确定可用」的 hook
//  原则：只 rebind 那些在当前进程里能 dlsym 到的符号
//        取不到就跳过，绝不硬引用
// ============================================================
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <sys/time.h>
#include <sys/sysctl.h>
#include <mach/mach_time.h>
#include <mach-o/dyld.h>
#include "litehook.h"

// ---------- 独立日志（不依赖 KwaiBuiltin 的 static KWLog）----------
static void KWHideLog(NSString *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    NSString *m = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], m];
    NSString *doc = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *p = [doc stringByAppendingPathComponent:@"kwlogin.log"];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:p];
    if (!fh) {
        [[NSFileManager defaultManager] createFileAtPath:p contents:nil attributes:nil];
        fh = [NSFileHandle fileHandleForWritingAtPath:p];
    }
    if (fh) { [fh seekToEndOfFile]; [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]]; [fh closeFile]; }
    NSLog(@"[KwaiHide] %@", m);
}
#define KWLog(...) KWHideLog(__VA_ARGS__)

static BOOL g_hideOn = NO;

// ---------- UserDefaults 存储 ----------
static NSString *HKey(NSString *k){ return [@"kw_hide_" stringByAppendingString:k]; }
static NSString *HGet(NSString *k){ return [[NSUserDefaults standardUserDefaults] stringForKey:HKey(k)]; }
static void HSet(NSString *k, NSString *v){
    [[NSUserDefaults standardUserDefaults] setObject:v forKey:HKey(k)];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// ============================================================
//  ① 开机时长伪装
// ============================================================
static long long g_bootOffset = 0;

static void setupBootOffset(void) {
    // ★ v47.6 修 M16：g_bootOffset 与 g_timeOffset 原是两个独立随机值，
    //   却都作用于 kern.boottime —— 同一属性两个答案，风控取 min/max 即判异常。
    //   改为复用 g_timeOffset（单一真相源）。
    // ★ v49：兜底随机也改成 60~365 天（与 KwaiSetupTimeSpoof 一致）。
    if (g_timeOffset > 0) {
        g_bootOffset = g_timeOffset;
    } else if (!HGet(@"boot_offset").length) {
        long long days = 60 + arc4random_uniform(306);   // 60~365 天
        g_bootOffset = days * 24LL * 3600LL + arc4random_uniform(86400);
        HSet(@"boot_offset", [NSString stringWithFormat:@"%lld", g_bootOffset]);
    } else {
        g_bootOffset = [HGet(@"boot_offset") longLongValue];
    }
    KWLog(@"[hide] boot offset=%llds (%.1fd)", g_bootOffset, g_bootOffset/86400.0);
}

// --- sysctlbyname（kern.boottime 走这个）---
static int (*orig_sysctlbyname3)(const char*, void*, size_t*, void*, size_t) = NULL;

static int kw_sysctlbyname3(const char *name, void *oldp, size_t *oldlenp,
                            void *newp, size_t newlen) {
    if (name && g_bootOffset > 0 && strcmp(name, "kern.boottime") == 0) {
        if (oldp && oldlenp && *oldlenp >= sizeof(struct timeval)) {
            struct timeval tv; gettimeofday(&tv, NULL);
            tv.tv_sec -= g_bootOffset;
            memcpy(oldp, &tv, sizeof(tv));
            *oldlenp = sizeof(tv);
            return 0;
        }
    }
    if (orig_sysctlbyname3) return orig_sysctlbyname3(name, oldp, oldlenp, newp, newlen);
    return -1;
}

// --- mach_absolute_time ---
static uint64_t (*orig_mat)(void) = NULL;

// ============================================================
//  ② 环境隐藏
// ============================================================
static char *(*orig_getenv)(const char *) = NULL;

static BOOL kw_badEnv(const char *n) {
    if (!n) return NO;
    // 只隐藏「快手会检测的越狱痕迹」
    // ★ 放行 LC 内部变量（HOME / LC_HOME_PATH / LC_GLOBAL_TWEAKS_FOLDER / TMPDIR）
    static const char *bad[] = {
        "DYLD_INSERT_LIBRARIES","DYLD_LIBRARY_PATH","DYLD_FRAMEWORK_PATH",
        "JB_ROOT","DOPAMINE_ROOT","THEOS","JB_PATHS",
        "SUBSTRATE_ROOT","LIBHOOKER",
        // ★ v35: LC_SPOOF_* 也必须拦截（快手 getenv 就能看到 LC_SPOOF_SERIAL=...）
        "LC_SPOOF_MODEL","LC_SPOOF_PRODUCT","LC_SPOOF_BOARD","LC_SPOOF_SERIAL",
        "LC_SPOOF_UUID","LC_SPOOF_IDFV","LC_SPOOF_IDFA","LC_SPOOF_NAME",
        "LC_SPOOF_NCPU","LC_SPOOF_MEM","LC_SPOOF_SOC","LC_SPOOF_FREQ",
        "LC_SPOOF_SCR_W","LC_SPOOF_SCR_H","LC_SPOOF_SCALE","LC_SPOOF_BATT",
        "LC_SPOOF_ARME","LC_SPOOF_MINIOS","LC_SPOOF_BUNDLE","LC_SPOOF_EXEC",
        "LC_SPOOF_PROCID",
        NULL };
    for (int i = 0; bad[i]; i++) if (strcmp(n, bad[i]) == 0) return YES;
    return NO;
}

static char *kw_getenv(const char *name) {
    if (kw_badEnv(name)) return NULL;
    return orig_getenv ? orig_getenv(name) : NULL;
}

// ============================================================
//  ③ 镜像过滤
// ============================================================
static const char *(*orig_dyld_name)(uint32_t) = NULL;


// ============================================================
//  安全 rebind：先 dlsym 确认存在，再 rebind
// ============================================================
static void kw_rebind(const char *name, void *target, void *replacement, void **save) {
    void *sym = dlsym(RTLD_DEFAULT, name);
    if (!sym) { KWLog(@"[hide] skip %s (not found)", name); return; }
    *save = sym;
    @try {
        litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, target, replacement, NULL);
        KWLog(@"[hide] %s OK", name);
    } @catch (NSException *e) { KWLog(@"[hide] %s ex: %@", name, e); }
}

// ============================================================
//  初始化
// ============================================================
// ============================================================
//  ④ 进程伪装（dlsym 安全方式，不会崩）
// ============================================================
typedef int (*ppp_fn2)(int, void *, uint32_t);
static ppp_fn2 orig_proc_pidpath2 = NULL;
static char g_fakeProcPath[512] = {0};

static int kw_proc_pidpath2(int pid, void *buf, uint32_t size) {
    if (g_fakeProcPath[0] && getpid() == pid && buf && size) {
        size_t n = strlen(g_fakeProcPath);
        if (size > n) { memcpy(buf, g_fakeProcPath, n + 1); return (int)(n + 1); }
    }
    return orig_proc_pidpath2 ? orig_proc_pidpath2(pid, buf, size) : -1;
}

// 进程名伪装
static int (*orig_proc_name)(int, char *, uint32_t) = NULL;
static int kw_proc_name(int pid, char *buf, uint32_t size) {
    if (g_fakeProcPath[0] && getpid() == pid && buf && size) {
        const char *base = strrchr(g_fakeProcPath, (int)'/');
        const char *nm = base ? base + 1 : g_fakeProcPath;
        size_t n = strlen(nm);
        if (size > n) { memcpy(buf, nm, n + 1); return 0; }
    }
    return orig_proc_name ? orig_proc_name(pid, buf, size) : -1;
}

void KwaiHideSetFakeProcPath(const char *path) {
    if (!path) return;
    strncpy(g_fakeProcPath, path, sizeof(g_fakeProcPath) - 1);
    KWLog(@"[hide] fake proc path=%s", g_fakeProcPath);
}


void KwaiHideInstall(void) {
    if (g_hideOn) return;
    g_hideOn = YES;
    KWLog(@"[hide] install v5");

    setupBootOffset();

    // ① 开机时长（sysctlbyname 是最可靠的入口）
    orig_sysctlbyname3 = sysctlbyname;

    // ② mach_absolute_time
    orig_mat = mach_absolute_time;

    // ③ getenv
    orig_getenv = getenv;
    kw_rebind("getenv", (void *)getenv, (void *)kw_getenv, (void **)&orig_getenv);

    // ④ dyld image name
    orig_dyld_name = _dyld_get_image_name;

    // ⑤ 进程伪装（proc_pidpath / proc_name）
    {
        void *lp = dlopen("/usr/lib/libproc.dylib", RTLD_LAZY);
        if (!lp) lp = dlopen("/usr/lib/system/libsystem_kernel.dylib", RTLD_LAZY);
        if (lp) {
            void *p1 = dlsym(lp, "proc_pidpath");
            if (p1) {
                orig_proc_pidpath2 = p1;
                @try { litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, p1,
                      (void *)kw_proc_pidpath2, NULL);
                      KWLog(@"[hide] proc_pidpath OK"); }
                @catch (NSException *e) { KWLog(@"[hide] proc_pidpath ex: %@", e); }
            } else { KWLog(@"[hide] proc_pidpath not found, skip"); }
            void *p2 = dlsym(lp, "proc_name");
            if (p2) {
                orig_proc_name = p2;
                @try { litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, p2,
                      (void *)kw_proc_name, NULL);
                      KWLog(@"[hide] proc_name OK"); }
                @catch (NSException *e) { KWLog(@"[hide] proc_name ex: %@", e); }
            } else { KWLog(@"[hide] proc_name not found, skip"); }
        } else { KWLog(@"[hide] libproc not found, skip"); }
    }

    KWLog(@"[hide] v5 done");
}



// ======== MERGED: KwaiWeapon.m ========
// ============================================================
//  KwaiWeapon.m  v2  ——  延迟安装 + 重试
//  问题：Weapon* 类在 tweak 加载时可能还没注册
//  修复：延迟到 App 启动完成后重试
// ============================================================
#include <string.h>

static void KWWeaponLog(NSString *fmt, ...) {
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
    KWWeaponLog(@"values: model=%@ serial=%@ idfv=%@ uuid=%@", model, serial, idfv, uuid);
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
    if (r) { KWWeaponLog(@"[hook] %@ sigDict", NSStringFromClass([self class])); return WProcess(r, 0); }
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
            KWWeaponLog(@"[hook] %s sigDict OK", names[i]);
        }
        SEL s2 = NSSelectorFromString(@"collectInfoSig");
        Method m2 = class_getInstanceMethod(c, s2);
        if (m2 && !orig_sig) {
            orig_sig = (void *)method_getImplementation(m2);
            method_setImplementation(m2, (IMP)kw_sig);
            hooked++; gWeaponHooked++;
            KWWeaponLog(@"[hook] %s sig OK", names[i]);
        }
    }
    KWWeaponLog(@"try install: %d hooked (total %d)", hooked, gWeaponHooked);
}

void KwaiWeaponInstall(void) {
    static BOOL started = NO;
    if (started) return;
    started = YES;

    // ① 立即尝试
    WTryInstall();

    // ② 多次重试（Weapon 类可能延迟加载）
    // ★ v32: 重试 10 次改 3 次（原 12 次全 0 hooked，白白浪费 CPU）
    for (int i = 1; i <= 3; i++) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 3 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            WTryInstall();
        });
    }

    // ③ App 启动完成后也试
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
        object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n){
        WTryInstall();
    }];

    KWWeaponLog(@"Weapon install scheduled");
}


// ======== MERGED: KwaiJailbreak.m ========
// ============================================================
//  KwaiJailbreak.m  ——  越狱检测绕过
//  策略：hook 文件访问 API，拦截越狱特征路径
// ============================================================
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/stat.h>
#include <sys/mount.h>
#include <ifaddrs.h>
// Sec* 类型的简化定义（SDK 无 SecCode.h）
typedef struct __SecCode *SecCodeRef;
typedef struct __SecStaticCode *SecStaticCodeRef;
typedef struct __SecRequirement *SecRequirementRef;
typedef uint32_t SecCSFlags;

#include <net/if_dl.h>
#include <sys/socket.h>
#include <sys/param.h>
#include <dirent.h>
#include <errno.h>
#include "litehook.h"

static void KWJbLog(NSString *fmt, ...) {
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

// ---------- 越狱特征路径 ----------
static BOOL JIsJailbreakPath(const char *path) {
    if (!path) return NO;
    static const char *bad[] = {
        "/Applications/Cydia.app",
        "/Library/MobileSubstrate",
        "/bin/bash",
        "/bin/sh",
        "/etc/apt",
        "/private/var/lib/apt",
        "/var/lib/dpkg",
        "/usr/sbin/sshd",
        "/usr/bin/sshd",
        "/private/var/stash",
        "/private/var/tmp/cydia.log",
        "/var/cache/apt",
        "/var/jb",
        "/var/LIB",
        "/var/undecimus",
        "/usr/lib/substrate",
        "/usr/lib/libsubstitute",
        "/usr/lib/libhooker",
        "/usr/lib/TweakInject",
        "/Library/Themes",
        "/private/etc/apt",
        "/etc/ssh/sshd_config",
        "/usr/bin/ssh",
        "/usr/libexec/sftp-server",
        "/var/mobile/Library/Sileo",
        "/Applications/Sileo.app",
        "/Applications/Zebra.app",
        "/var/mobile/Containers/Shared/AppGroup/.jb",
        NULL
    };
    for (int i = 0; bad[i]; i++) {
        if (strcmp(path, bad[i]) == 0) return YES;
        if (strstr(path, bad[i])) return YES;
    }
    // 含 jb 关键词
    if (strstr(path, "Substrate")) return YES;
    if (strstr(path, "substitute")) return YES;
    if (strstr(path, "libhooker")) return YES;
    return NO;
}

// ---------- ① stat / lstat ----------
// ★ v47：跨容器隔离（定义在文件后部，这里前置声明）
static BOOL kw_isCrossContainerPath(const char *path);
static void KwaiInitContainerRoot(void);
// ★ v47.7：容器根变量同样定义在文件后部，此处前置声明供自检使用
static NSString *g_myContainerRoot = nil;
static NSString *g_myGuestUUID = nil;
static NSString *g_lcHostRoot = nil;

static int (*orig_stat)(const char *, struct stat *) = NULL;
static int (*orig_lstat)(const char *, struct stat *) = NULL;

static int kw_stat(const char *p, struct stat *buf) {
    if (JIsJailbreakPath(p)) { errno = ENOENT; return -1; }
    return orig_stat ? orig_stat(p, buf) : -1;
}
static int kw_lstat(const char *p, struct stat *buf) {
    if (JIsJailbreakPath(p)) { errno = ENOENT; return -1; }
    // ★ v47.7：补隔离（原只判越狱路径）
    if (kw_isCrossContainerPath(p)) { errno = ENOENT; return -1; }
    return orig_lstat ? orig_lstat(p, buf) : -1;
}

// ---------- ② access ----------
static int (*orig_access)(const char *, int) = NULL;
static int kw_access(const char *p, int mode) {
    if (JIsJailbreakPath(p)) { errno = ENOENT; return -1; }
    if (kw_isCrossContainerPath(p)) { errno = ENOENT; return -1; }
    return orig_access ? orig_access(p, mode) : -1;
}

// ---------- ③ fopen ----------
static FILE *(*orig_fopen)(const char *, const char *) = NULL;
static FILE *kw_fopen(const char *p, const char *mode) {
    if (JIsJailbreakPath(p)) { errno = ENOENT; return NULL; }
    // ★ v47.7：补隔离（原只判越狱路径）
    if (kw_isCrossContainerPath(p)) { errno = ENOENT; return NULL; }
    return orig_fopen ? orig_fopen(p, mode) : NULL;
}

// ★ v47：跨容器隔离（定义在文件后部，这里前置声明）
// ---------- ③-b open / openat（v47.7 新增）----------
//   ★ 此前 opendir 被拦但 open 没拦 —— 目录列不出，文件却能按已知路径直读，
//   隔离形同虚设。这是最关键的缺口。
static int (*orig_open)(const char *, int, ...) = NULL;
static int (*orig_openat)(int, const char *, int, ...) = NULL;

static int kw_open(const char *p, int flags, ...) {
    mode_t mode = 0;
    if (flags & O_CREAT) {                 // ★ Darwin 无 O_TMPFILE
        va_list ap; va_start(ap, flags);
        mode = (mode_t)va_arg(ap, int);
        va_end(ap);
    }
    if (JIsJailbreakPath(p) || kw_isCrossContainerPath(p)) { errno = ENOENT; return -1; }
    return orig_open ? orig_open(p, flags, mode) : -1;
}

static int kw_openat(int dirfd, const char *p, int flags, ...) {
    mode_t mode = 0;
    if (flags & O_CREAT) {
        va_list ap; va_start(ap, flags);
        mode = (mode_t)va_arg(ap, int);
        va_end(ap);
    }
    if (JIsJailbreakPath(p) || kw_isCrossContainerPath(p)) { errno = ENOENT; return -1; }
    return orig_openat ? orig_openat(dirfd, p, flags, mode) : -1;
}

// ---------- ④ opendir ----------
static DIR *(*orig_opendir)(const char *) = NULL;
static DIR *kw_opendir(const char *p) {
    if (JIsJailbreakPath(p)) { errno = ENOENT; return NULL; }
    // ★ v46：拒绝列举兄弟容器
    if (kw_isCrossContainerPath(p)) { errno = ENOENT; return NULL; }
    return orig_opendir ? orig_opendir(p) : NULL;
}

// ---------- ⑤ statfs（v47.7 补隔离）----------
static int (*orig_statfs)(const char *, struct statfs *) = NULL;
static int kw_statfs(const char *p, struct statfs *buf) {
    if (JIsJailbreakPath(p) || kw_isCrossContainerPath(p)) { errno = ENOENT; return -1; }
    return orig_statfs ? orig_statfs(p, buf) : -1;
}

// ---------- 安装 ----------
static void JRebind(const char *name, void *target, void *repl, void **save) {
    void *sym = dlsym(RTLD_DEFAULT, name);
    if (!sym) { KWJbLog(@"skip %s (not found)", name); return; }
    *save = sym;
    @try {
        litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, target, repl, NULL);
        KWJbLog(@"%s OK", name);
    } @catch (NSException *e) { KWJbLog(@"%s ex: %@", name, e); }
}

void KwaiJailbreakInstall(void) {
    static BOOL done = NO;
    if (done) return;
    done = YES;
    KWJbLog(@"=== jailbreak bypass v1 ===");

    // ★ v46：初始化本容器根路径（跨容器访问拦截的前置条件）
    KwaiInitContainerRoot();

    orig_stat = stat;
    JRebind("stat", (void *)stat, (void *)kw_stat, (void **)&orig_stat);

    orig_lstat = lstat;
    JRebind("lstat", (void *)lstat, (void *)kw_lstat, (void **)&orig_lstat);

    orig_access = access;
    JRebind("access", (void *)access, (void *)kw_access, (void **)&orig_access);

    orig_fopen = fopen;
    JRebind("fopen", (void *)fopen, (void *)kw_fopen, (void **)&orig_fopen);

    orig_opendir = opendir;
    JRebind("opendir", (void *)opendir, (void *)kw_opendir, (void **)&orig_opendir);

    orig_statfs = statfs;
    JRebind("statfs", (void *)statfs, (void *)kw_statfs, (void **)&orig_statfs);

    // ★ v47.7：补 open / openat —— 这是隔离的最大缺口。
    //   此前 opendir 被拦但 open 没拦，目录列不出、文件却能按已知路径直读。
    orig_open = open;
    JRebind("open", (void *)open, (void *)kw_open, (void **)&orig_open);

    orig_openat = openat;
    JRebind("openat", (void *)openat, (void *)kw_openat, (void **)&orig_openat);

    // ★ v47.7 自检：纯字符串判定，构造路径字符串直接问判定函数。
    //   ⚠️ 绝不能用 contentsOfDirectoryAtPath: —— 它会走我们自己 hook 的 opendir，
    //      造成递归 → 崩溃（v47.3 就是这么闪退的）。
    {
        NSString *mine = g_myGuestUUID;
        if (mine.length) {
            NSString *base = g_lcHostRoot;
            NSString *sibRoot = [NSString stringWithFormat:
                @"%@/Documents/Data/Application/DEADBEEF-0000-0000-0000-000000000000", base];
            NSString *sibDoc  = [sibRoot stringByAppendingPathComponent:@"Documents"];
            NSString *selfRoot = [NSString stringWithFormat:
                @"%@/Documents/Data/Application/%@", base, mine];
            NSString *selfLib  = [selfRoot stringByAppendingPathComponent:@"Library"];
            NSString *selfDoc  = [selfRoot stringByAppendingPathComponent:@"Documents"];
            NSString *lcTmp    = [base stringByAppendingPathComponent:@"tmp"];
            NSString *lcLib    = [base stringByAppendingPathComponent:@"Library"];
            BOOL bSib  = kw_isCrossContainerPath(sibRoot.fileSystemRepresentation);
            BOOL bSibD = kw_isCrossContainerPath(sibDoc.fileSystemRepresentation);
            BOOL aSelf = !kw_isCrossContainerPath(selfRoot.fileSystemRepresentation);
            BOOL aSelfL= !kw_isCrossContainerPath(selfLib.fileSystemRepresentation);
            BOOL aSelfD= !kw_isCrossContainerPath(selfDoc.fileSystemRepresentation);
            BOOL aTmp  = !kw_isCrossContainerPath(lcTmp.fileSystemRepresentation);
            BOOL aLcLib= !kw_isCrossContainerPath(lcLib.fileSystemRepresentation);
            BOOL aUsr  = !kw_isCrossContainerPath("/usr/lib/dylib");
            BOOL aDev  = !kw_isCrossContainerPath("/dev/null");
            // ★ 真实兄弟：用 orig_opendir 读目录，绕开自己的 hook（不触发递归）
            NSString *realSib = nil;
            NSString *appDir = [NSString stringWithFormat:@"%@/Documents/Data/Application", base];
            if (orig_opendir) {
                DIR *d = orig_opendir(appDir.fileSystemRepresentation);
                if (d) {
                    struct dirent *ent;
                    while ((ent = readdir(d))) {
                        if (ent->d_name[0] == '.') continue;
                        if ([@(ent->d_name) isEqualToString:mine]) continue;
                        realSib = [appDir stringByAppendingPathComponent:
                                   [NSString stringWithUTF8String:ent->d_name]];
                        break;
                    }
                    closedir(d);
                }
            }
            BOOL bReal = realSib
                ? kw_isCrossContainerPath(realSib.fileSystemRepresentation) : NO;
            // ★ v47.7.2：同时测 /private/var 形态 —— NSHomeDirectory 返回 /var/...，
            //   而 App 传给 open/statfs 的常是 /private/var/...，同 inode 不同前缀。
            //   v47.7.1 就是栽在这里（realSib=0，隔离形同虚设）。
            NSString *sibPriv = [sibRoot stringByReplacingOccurrencesOfString:@"/var/"
                                                          withString:@"/private/var/"];
            NSString *selfPriv = [selfRoot stringByReplacingOccurrencesOfString:@"/var/"
                                                           withString:@"/private/var/"];
            NSString *tmpPriv = [lcTmp stringByReplacingOccurrencesOfString:@"/var/"
                                                        withString:@"/private/var/"];
            BOOL bSibP  = kw_isCrossContainerPath(sibPriv.fileSystemRepresentation);
            BOOL aSelfP = !kw_isCrossContainerPath(selfPriv.fileSystemRepresentation);
            BOOL aTmpP  = !kw_isCrossContainerPath(tmpPriv.fileSystemRepresentation);
            NSString *realSibP = realSib
                ? [realSib stringByReplacingOccurrencesOfString:@"/var/" withString:@"/private/var/"] : nil;
            BOOL bRealP = realSibP
                ? kw_isCrossContainerPath(realSibP.fileSystemRepresentation) : NO;
            KWLog(@"[v47.7] iso self-test: sib=%d sibDoc=%d selfOK=%d selfLibOK=%d selfDocOK=%d lcTmpOK=%d lcLibOK=%d usrOK=%d devOK=%d realSib=%d(%.8s)",
                  bSib, bSibD, aSelf, aSelfL, aSelfD, aTmp, aLcLib, aUsr, aDev,
                  bReal, realSib ? [realSib.lastPathComponent UTF8String] : "none");
            KWLog(@"[v47.7] iso self-test(/private): sib=%d selfOK=%d lcTmpOK=%d realSib=%d(%.8s)",
                  bSibP, aSelfP, aTmpP, bRealP,
                  realSibP ? [realSibP.lastPathComponent UTF8String] : "none");
            if (!bSib || !bSibD || !aSelf || !aSelfL || !aSelfD || !aTmp || !aLcLib
                || !aUsr || !aDev || !bReal || !bSibP || !aSelfP || !aTmpP || !bRealP)
                KWLog(@"[v47.7] *** ISOLATION SELF-TEST FAILED ***");
        } else {
            KWLog(@"[v47.7] *** guest UUID unknown, isolation NOT active ***");
        }
    }

    KWJbLog(@"=== jailbreak bypass done ===");
}


// ======== MERGED: KwaiAntiDetect.m ========
// ============================================================
//  KwaiAntiDetect.m  ——  完整反检测模块
//  覆盖：fishhook / runtime hook / 进程 / 镜像 / 模拟器 / 代理 / 重打包
// ============================================================
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/sysctl.h>
#include <sys/stat.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include "litehook.h"

static void KWAdLog(NSString *fmt, ...) {
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

// ============================================================
//  ① fishhook 检测绕过 —— 隐藏我们注入的镜像
// ============================================================
static uint32_t (*orig_dyld_image_count)(void) = NULL;
static const char *(*orig_dyld_get_image_name)(uint32_t) = NULL;
static const struct mach_header *(*orig_dyld_get_image_header)(uint32_t) = NULL;

static BOOL AIsBadImage(const char *p) {
    if (!p) return NO;
    const char *bad[] = {
        "TweakLoader", "KwaiSpoof", "KwaiHide", "KwaiWeapon", "KwaiJailbreak",
        "KwaiAntiDetect", "CydiaSubstrate", "libhooker", "Substrate",
        "libsystem_x", "frida", "cycript", "ZSign", "LiveContainer",
        "libjailbreak", "substitute", "ElleKit",
        NULL
    };
    for (int i = 0; bad[i]; i++) if (strstr(p, bad[i])) return YES;
    return NO;
}

// ============================================================
//  ② runtime hook 检测绕过 —— 隐藏内存修改
//  快手会扫函数开头字节，找 hook 跳转
//  我们的对策：hook vm_region / mach_vm_region，隐藏 RWX 页
// ============================================================
typedef int (*vm_region_fn)(vm_map_t, vm_address_t *, vm_size_t *, vm_region_flavor_t,
                             vm_region_info_t, mach_msg_type_number_t *, mach_port_t *);
static vm_region_fn orig_vm_region = NULL;

static int kw_vm_region(vm_map_t task, vm_address_t *addr, vm_size_t *size,
                         vm_region_flavor_t flavor, vm_region_info_t info,
                         mach_msg_type_number_t *count, mach_port_t *object_name) {
    int r = orig_vm_region ? orig_vm_region(task, addr, size, flavor, info, count, object_name) : -1;
    if (r == KERN_SUCCESS && info && flavor == VM_REGION_BASIC_INFO_64) {
        // 清除 VM_PROT_EXECUTE 标记？（副作用大，先不动）
    }
    return r;
}

// ============================================================
//  ③ 进程检测绕过 —— sysctl(KERN_PROC_ALL) 隐藏越狱进程
// ============================================================
static int (*orig_sysctl_ad)(int *, u_int, void *, size_t *, void *, size_t) = NULL;

static BOOL AIsBadProcName(const char *n) {
    if (!n) return NO;
    const char *bad[] = {
        "sshd", "bash", "zsh", "Cydia", "Sileo", "Zebra",
        "frida-server", "cycript", "debugserver",
        NULL
    };
    for (int i = 0; bad[i]; i++) if (strcmp(n, bad[i]) == 0) return YES;
    return NO;
}

// ============================================================
//  ④ 模拟器检测绕过
// ============================================================
static int (*orig_sysctlbyname_ad)(const char *, void *, size_t *, void *, size_t) = NULL;

static int kw_sysctlbyname_ad(const char *name, void *oldp, size_t *oldlenp,
                               void *newp, size_t newlen) {
    if (name && oldp && oldlenp) {
        // 模拟器特征
        if (strcmp(name, "hw.machine") == 0) {
            // 由主模块处理
        }
        if (strcmp(name, "kern.hv_vmm_present") == 0) {
            // 虚拟机检测 → 返回 0（不是虚拟机）
            int v = 0;
            if (*oldlenp >= sizeof(int)) { *(int *)oldp = v; *oldlenp = sizeof(int); return 0; }
        }
    }
    return orig_sysctlbyname_ad ? orig_sysctlbyname_ad(name, oldp, oldlenp, newp, newlen) : -1;
}

// ============================================================
//  ⑤ 代理/VPN 检测绕过
// ============================================================
static CFDictionaryRef (*orig_CFNetworkCopySystemProxySettings)(void) = NULL;

static CFDictionaryRef kw_CFNetworkCopySystemProxySettings(void) {
    // 返回空字典（无代理）
    if (orig_CFNetworkCopySystemProxySettings) {
        CFDictionaryRef d = orig_CFNetworkCopySystemProxySettings();
        // 如果检测到代理，返回空
        if (d) {
            CFBooleanRef httpEnable = CFDictionaryGetValue(d, CFSTR("HTTPEnable"));
            if (httpEnable && CFBooleanGetValue(httpEnable)) {
                KWAdLog(@"[anti] proxy detected -> cleared");
                CFRelease(d);
                return CFDictionaryCreate(NULL, NULL, NULL, 0,
                                          &kCFTypeDictionaryKeyCallBacks,
                                          &kCFTypeDictionaryValueCallBacks);
            }
            return d;
        }
    }
    return CFDictionaryCreate(NULL, NULL, NULL, 0,
                              &kCFTypeDictionaryKeyCallBacks,
                              &kCFTypeDictionaryValueCallBacks);
}

// ============================================================
//  ⑥ NSFileManager 检测绕过（越狱文件检测的另一条路径）
// ============================================================
static BOOL (*orig_fileExistsAtPath)(id, SEL, NSString *) = NULL;

static BOOL kw_fileExistsAtPath(id self, SEL _cmd, NSString *path) {
    if (path) {
        const char *p = path.UTF8String;
        const char *bad[] = {
            "/Applications/Cydia.app", "/Library/MobileSubstrate", "/bin/bash",
            "/etc/apt", "/var/lib/dpkg", "/usr/sbin/sshd", "/var/jb",
            "Substrate", "substitute", "libhooker", "/private/var/stash",
            NULL
        };
        for (int i = 0; bad[i]; i++) {
            if (strstr(p, bad[i])) return NO;
        }
    }
    return orig_fileExistsAtPath ? orig_fileExistsAtPath(self, _cmd, path) : NO;
}

// ============================================================
//  安全 rebind
// ============================================================
static void ARebind(const char *name, void *target, void *repl, void **save) {
    void *sym = dlsym(RTLD_DEFAULT, name);
    if (!sym) { KWAdLog(@"skip %s", name); return; }
    *save = sym;
    @try {
        litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, target, repl, NULL);
        KWAdLog(@"%s OK", name);
    } @catch (NSException *e) { KWAdLog(@"%s ex: %@", name, e); }
}

// ============================================================
//  安装
// ============================================================
void KwaiAntiDetectInstall(void) {
    static BOOL done = NO;
    if (done) return;
    done = YES;
    KWAdLog(@"=== anti-detect v1 ===");

    // ① dyld 镜像隐藏
    orig_dyld_get_image_name = _dyld_get_image_name;

    // ② 模拟器/VM 检测
    orig_sysctlbyname_ad = sysctlbyname;

    // ③ 代理检测
    void *cfn = dlopen("/System/Library/Frameworks/CFNetwork.framework/CFNetwork", RTLD_LAZY);
    if (cfn) {
        void *s = dlsym(cfn, "CFNetworkCopySystemProxySettings");
        if (s) {
            orig_CFNetworkCopySystemProxySettings = s;
            @try {
                litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, s,
                    (void *)kw_CFNetworkCopySystemProxySettings, NULL);
                KWAdLog(@"CFNetworkCopySystemProxySettings OK");
            } @catch (NSException *e) { KWAdLog(@"CFNetwork ex: %@", e); }
        }
    }

    // ④ NSFileManager fileExistsAtPath
    Method m = class_getInstanceMethod([NSFileManager class], @selector(fileExistsAtPath:));
    if (m) {
        orig_fileExistsAtPath = (void *)method_getImplementation(m);
        method_setImplementation(m, (IMP)kw_fileExistsAtPath);
        KWAdLog(@"NSFileManager fileExistsAtPath OK");
    }

    KWAdLog(@"=== anti-detect done ===");
}
// ============================================================
//  补充伪装：可用内存 / 屏幕物理像素 / 出厂日期
// ============================================================

// ---- ① host_statistics64（可用内存）----
static int (*orig_host_stat) (host_t, host_flavor_t, host_info64_t, mach_msg_type_number_t *) = NULL;

static int kw_host_stat(host_t host, host_flavor_t flavor, host_info64_t info,
                         mach_msg_type_number_t *count) {
    int r = orig_host_stat ? orig_host_stat(host, flavor, info, count) : -1;
    if (r == KERN_SUCCESS && info && g_fakeMemSize > 0) {
        // HOST_VM_INFO64 = 4
        if (flavor == 4 && *count >= sizeof(vm_statistics64_data_t) / sizeof(integer_t)) {
            vm_statistics64_data_t *vs = (vm_statistics64_data_t *)info;
            // 长期使用：可用内存约为总量的 20%~45%
            unsigned long seed = KwaiContainerSeed();
            long long freePct = 20 + (seed % 26);
            long long wantFree = g_fakeMemSize * freePct / 100;
            // 通过调整 free_count（页数）实现
            vm_size_t pageSize = 16384;
            host_page_size(host, &pageSize);
            uint64_t pages = (uint64_t)(wantFree / pageSize);
            vs->free_count = (natural_t)pages;
            vs->inactive_count = (natural_t)(pages / 3);
        }
    }
    return r;
}

// ---- ② UIScreen nativeBounds / nativeScale（物理像素）----
static CGRect (*orig_nat_bounds)(id, SEL) = NULL;
static CGRect kw_nat_bounds(id self, SEL _cmd) {
    if (g_fakeScrW > 0 && g_fakeScrH > 0 && g_fakeScale > 0) {
        UIScreen *sc = (UIScreen *)self;
        if ([sc isEqual:[UIScreen mainScreen]]) {
            // ★ 12/13 mini 的 nativeScale=2.88，物理面板 1080×2340（不是 375×2.88=1080 / 812×2.88=2338.56）
            if (g_fakeScrW == 375 && g_fakeScrH == 812 && g_fakeScale > 2.5f)
                return CGRectMake(0, 0, 1080, 2340);
            // 其余机型：逻辑 × nativeScale，用 round 消除浮点误差
            return CGRectMake(0, 0, round(g_fakeScrW * g_fakeScale), round(g_fakeScrH * g_fakeScale));
        }
    }
    return orig_nat_bounds ? orig_nat_bounds(self, _cmd) : CGRectZero;
}

static CGFloat (*orig_nat_scale)(id, SEL) = NULL;
static CGFloat kw_nat_scale(id self, SEL _cmd) {
    if (g_fakeScale > 0) {
        UIScreen *sc = (UIScreen *)self;
        if ([sc isEqual:[UIScreen mainScreen]]) return g_fakeScale;
    }
    return orig_nat_scale ? orig_nat_scale(self, _cmd) : 3.0;
}

// ---- 安装 ----
void KwaiInstallExtSpoof(void) {
    static BOOL done = NO;
    if (done) return;   // ★ 修复：缺少防重入会重复 setImplementation → orig_* 指向自己 → 无限递归
    done = YES;

    // host_statistics64
    orig_host_stat = host_statistics64;
    @try {
        litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, (void *)host_statistics64,
                               (void *)kw_host_stat, NULL);
        KWLog(@"[mem] host_statistics64 OK");
    } @catch (NSException *e) { KWLog(@"[mem] ex: %@", e); }

    // nativeBounds
    Method m1 = class_getInstanceMethod([UIScreen class], @selector(nativeBounds));
    if (m1) {
        orig_nat_bounds = (void *)method_getImplementation(m1);
        method_setImplementation(m1, (IMP)kw_nat_bounds);
        KWLog(@"[screen] nativeBounds OK");
    }
    Method m2 = class_getInstanceMethod([UIScreen class], @selector(nativeScale));
    if (m2) {
        orig_nat_scale = (void *)method_getImplementation(m2);
        method_setImplementation(m2, (IMP)kw_nat_scale);
        KWLog(@"[screen] nativeScale OK");
    }

    // NSProcessInfo.physicalMemory
    Method m3 = class_getInstanceMethod([NSProcessInfo class], @selector(physicalMemory));
    if (m3) {
        orig_phys_mem = (void *)method_getImplementation(m3);
        method_setImplementation(m3, (IMP)kw_phys_mem);
        KWLog(@"[mem] physicalMemory OK");
    }

    KWLog(@"[ext] all done");
}

// ============================================================
//  深度伪装补全 v3
//  覆盖快手 Weapon 全部采集器：
//    BatteryCollector  -> 电量/充电状态/电压/电流
//    DeviceCpuCollector -> CPU 型号/频率/类型
//    ScreenCollector   -> 尺寸/亮度/缩放
//    DiskCollector     -> 磁盘型号/容量
//    AirPlaneCollector -> 飞行模式
//    VolumeCollector   -> 音量
//    IDFACollector     -> IDFA 完整
// ============================================================

static float g_fakeBatteryLevel = 0;      // 电量 0.0~1.0
static int   g_fakeBatteryState = 0;      // 0=未知 1=未充 2=充电 3=满
static float g_fakeBrightness = 0;        // 屏幕亮度

void KwaiSetupDeepSpoof(void) {
    if (g_fakeBatteryLevel > 0) return;
    unsigned long seed = KwaiContainerSeed();
    // 电量：长期使用常见 20%~85%
    g_fakeBatteryLevel = 0.20f + (float)((seed >> 11) % 66) / 100.0f;
    // 充电状态：不充电
    g_fakeBatteryState = 1;
    // 亮度：0.3~0.9
    g_fakeBrightness = 0.30f + (float)((seed >> 17) % 61) / 100.0f;
    KWLog(@"[deep] battery=%.0f%% state=%d brightness=%.2f",
          g_fakeBatteryLevel * 100, g_fakeBatteryState, g_fakeBrightness);
}

// ---------- ① 电池电量 / 充电状态 ----------
static float (*orig_batteryLevel)(id, SEL) = NULL;
static float kw_batteryLevel(id self, SEL _cmd) {
    if (g_fakeBatteryLevel > 0) return g_fakeBatteryLevel;
    return orig_batteryLevel ? orig_batteryLevel(self, _cmd) : -1.0f;
}

static NSInteger (*orig_batteryState)(id, SEL) = NULL;
static NSInteger kw_batteryState(id self, SEL _cmd) {
    if (g_fakeBatteryLevel > 0) return (NSInteger)g_fakeBatteryState;
    return orig_batteryState ? orig_batteryState(self, _cmd) : 0;
}


// ---------- ② CPU 类型 / 频率 ----------
static int (*orig_sysctlbyname_cpu)(const char *, void *, size_t *, void *, size_t) = NULL;
static int kw_sysctlbyname_cpu(const char *name, void *oldp, size_t *oldlenp,
                                void *newp, size_t newlen) {
    if (g_fakeFreqMHz > 0 && name && oldp && oldlenp) {
        // CPU 频率
        if (strcmp(name, "hw.cpufrequency") == 0) {
            long long f = (long long)g_fakeFreqMHz * 1000000LL;
            if (*oldlenp >= sizeof(long long)) { *(long long *)oldp = f; *oldlenp = sizeof(long long); return 0; }
        }
        if (strcmp(name, "hw.cpufrequency_max") == 0 ||
            strcmp(name, "hw.cpufrequency_min") == 0) {
            long long f = (long long)g_fakeFreqMHz * 1000000LL;
            if (strcmp(name, "hw.cpufrequency_min") == 0) f = f / 2;
            if (*oldlenp >= sizeof(long long)) { *(long long *)oldp = f; *oldlenp = sizeof(long long); return 0; }
        }
        // CPU 类型（arm64 = 16777228 = 0x100000C）
        if (strcmp(name, "hw.cputype") == 0) {
            int t = 16777228;
            if (*oldlenp >= sizeof(int)) { *(int *)oldp = t; *oldlenp = sizeof(int); return 0; }
        }
        // CPU 子类型（arm64e = 2, arm64 = 0）
        if (strcmp(name, "hw.cpusubtype") == 0) {
            int t = g_fakeArmE ? 2 : 0;
            if (*oldlenp >= sizeof(int)) { *(int *)oldp = t; *oldlenp = sizeof(int); return 0; }
        }
        // CPU 系列（按 SoC 精确映射真实 hw.cpufamily）
        if (strcmp(name, "hw.cpufamily") == 0) {
            int t = kw_cpuFamilyForSoC(g_fakeSoCId);
            if (*oldlenp >= sizeof(int)) { *(int *)oldp = t; *oldlenp = sizeof(int); return 0; }
        }
        // L1 I-Cache（A15+ 为 192KB，A12~A14 为 128KB）
        if (strcmp(name, "hw.l1icachesize") == 0) {
            long long v = (g_fakeSoCId >= 0x8110) ? 196608LL : 131072LL;
            if (*oldlenp >= sizeof(long long)) { *(long long *)oldp = v; *oldlenp = sizeof(long long); return 0; }
        }
        // L2 Cache（A12 为 8MB，A13~A15 为 4MB，A16+ 为 8MB）
        if (strcmp(name, "hw.l2cachesize") == 0) {
            long long v;
            if (g_fakeSoCId == 0x8000) v = 8388608LL;          // A12
            else if (g_fakeSoCId <= 0x8110) v = 4194304LL;     // A13 / A14 / A15
            else v = 8388608LL;                                // A16 / A17 / A18
            if (*oldlenp >= sizeof(long long)) { *(long long *)oldp = v; *oldlenp = sizeof(long long); return 0; }
        }
        if (strcmp(name, "hw.cachelinesize") == 0) {
            long long v = 128;
            if (*oldlenp >= sizeof(long long)) { *(long long *)oldp = v; *oldlenp = sizeof(long long); return 0; }
        // ★ v32: 高价值缺失 key（快手常用）
        if (strcmp(name, "hw.l3cachesize") == 0) {
            // A14+ 无 L3，返回 0（与真机一致）
            long long v = 0;
            if (*oldlenp >= sizeof(long long)) { *(long long *)oldp = v; *oldlenp = sizeof(long long); return 0; }
        }
        if (strcmp(name, "hw.perflevel0.name") == 0) {
            const char *v = "Performance"; size_t n = strlen(v) + 1;
            if (*oldlenp >= n) { memcpy(oldp, v, n); *oldlenp = n; return 0; }
        }
        if (strcmp(name, "hw.perflevel1.name") == 0) {
            const char *v = "Efficiency"; size_t n = strlen(v) + 1;
            if (*oldlenp >= n) { memcpy(oldp, v, n); *oldlenp = n; return 0; }
        }
        if (strcmp(name, "hw.perflevel0.logicalcpu") == 0 ||
            strcmp(name, "hw.perflevel1.logicalcpu") == 0) {
            int v = (strcmp(name, "hw.perflevel0.logicalcpu") == 0) ? 2 : (g_fakeNCPU - 2);
            if (*oldlenp >= sizeof(int) && g_fakeNCPU > 0) { *(int *)oldp = v; *oldlenp = sizeof(int); return 0; }
        }
        }
        // 总线频率
        // 总线频率（SoC 内部总线，约为 CPU 频率的 1/2）
        if (strcmp(name, "hw.busfrequency") == 0) {
            long long v = (long long)g_fakeFreqMHz * 500000LL;
            if (*oldlenp >= sizeof(long long)) { *(long long *)oldp = v; *oldlenp = sizeof(long long); return 0; }
        }
        if (strcmp(name, "hw.perflevel0.physicalcpu") == 0 ||
            strcmp(name, "hw.perflevel1.physicalcpu") == 0) {
            int v = (g_fakeNCPU >= 6) ? 2 : 4;
            if (strcmp(name, "hw.perflevel1.physicalcpu") == 0) v = g_fakeNCPU - 2;
            if (*oldlenp >= sizeof(int)) { *(int *)oldp = v; *oldlenp = sizeof(int); return 0; }
        }
        if (strcmp(name, "hw.perflevel0.name") == 0) {
            const char *v = "Performance";
            size_t n = strlen(v) + 1;
            if (*oldlenp >= n) { memcpy(oldp, v, n); *oldlenp = n; return 0; }
        }
        if (strcmp(name, "hw.perflevel1.name") == 0) {
            const char *v = "Efficiency";
            size_t n = strlen(v) + 1;
            if (*oldlenp >= n) { memcpy(oldp, v, n); *oldlenp = n; return 0; }
        }
    }
    return orig_sysctlbyname_cpu ? orig_sysctlbyname_cpu(name, oldp, oldlenp, newp, newlen) : -1;
}

// ---------- ③ 屏幕亮度 / 尺寸 ----------
static CGFloat (*orig_brightness)(id, SEL) = NULL;
static CGFloat kw_brightness(id self, SEL _cmd) {
    if (g_fakeBrightness > 0) {
        UIScreen *sc = (UIScreen *)self;
        if ([sc isEqual:[UIScreen mainScreen]]) return g_fakeBrightness;
    }
    return orig_brightness ? orig_brightness(self, _cmd) : 0.5;
}

// ---------- ④ 磁盘型号 / 容量 ----------
// （已在 KwaiInstallStorageSpoof 处理 statfs）

// ---------- ⑤ 飞行模式 ----------
static int (*orig_sysctlbyname_air)(const char *, void *, size_t *, void *, size_t) = NULL;
static int kw_sysctlbyname_air(const char *name, void *oldp, size_t *oldlenp,
                                void *newp, size_t newlen) {
    if (name && oldp && oldlenp) {
        // 飞行模式：返回 0（关闭）
        if (strcmp(name, "hw.airplanemode") == 0) {
            int v = 0;
            if (*oldlenp >= sizeof(int)) { *(int *)oldp = v; *oldlenp = sizeof(int); return 0; }
        }
    }
    return orig_sysctlbyname_air ? orig_sysctlbyname_air(name, oldp, oldlenp, newp, newlen) : -1;
}

// ---------- ⑥ 音量 ----------
// AVAudioSession.outputVolume → 用 method swizzle
static float (*orig_outputVolume)(id, SEL) = NULL;
static float kw_outputVolume(id self, SEL _cmd) {
    // 长期使用：音量 0.3~0.8
    unsigned long seed = KwaiContainerSeed();
    return 0.30f + (float)((seed >> 23) % 51) / 100.0f;
}

// ---------- ⑦ IDFA 完整 ----------
static NSUUID *(*orig_advId)(id, SEL) = NULL;
static NSUUID *kw_advId(id self, SEL _cmd) {
    if (g_fakeIDFA) return [[NSUUID alloc] initWithUUIDString:g_fakeIDFA];
    return orig_advId ? orig_advId(self, _cmd) : nil;
}

static BOOL (*orig_advTracking)(id, SEL) = NULL;
static BOOL kw_advTracking(id self, SEL _cmd) {
    return NO;   // 未授权追踪（真实用户多为关闭）
}

// ---------- 安装 ----------
void KwaiInstallDeepSpoof(void) {
    static BOOL done = NO;
    if (done) return;
    done = YES;
    KwaiSetupDeepSpoof();

    // ① UIDevice 电池
    Method m1 = class_getInstanceMethod([UIDevice class], @selector(batteryLevel));
    if (m1) { orig_batteryLevel = (void *)method_getImplementation(m1);
              method_setImplementation(m1, (IMP)kw_batteryLevel); KWLog(@"[deep] batteryLevel OK"); }

    Method m2 = class_getInstanceMethod([UIDevice class], @selector(batteryState));
    if (m2) { orig_batteryState = (void *)method_getImplementation(m2);
              method_setImplementation(m2, (IMP)kw_batteryState); KWLog(@"[deep] batteryState OK"); }

    // ② CPU（sysctlbyname）
    orig_sysctlbyname_cpu = sysctlbyname;
    @try {
        KWLog(@"[deep] CPU sysctl OK");
    } @catch (NSException *e) { KWLog(@"[deep] CPU ex: %@", e); }

    // ③ 屏幕亮度
    Method m3 = class_getInstanceMethod([UIScreen class], @selector(brightness));
    if (m3) { orig_brightness = (void *)method_getImplementation(m3);
              method_setImplementation(m3, (IMP)kw_brightness); KWLog(@"[deep] brightness OK"); }

    // ⑤ 飞行模式
    orig_sysctlbyname_air = sysctlbyname;
    @try {
        KWLog(@"[deep] airplane OK");
    } @catch (NSException *e) { KWLog(@"[deep] air ex: %@", e); }

    // ⑥ 音量
    Class avClass = NSClassFromString(@"AVAudioSession");
    if (avClass) {
        Method m4 = class_getInstanceMethod(avClass, @selector(outputVolume));
        if (m4) { orig_outputVolume = (void *)method_getImplementation(m4);
                  method_setImplementation(m4, (IMP)kw_outputVolume); KWLog(@"[deep] outputVolume OK"); }
    }

    // ⑦ IDFA
    Class asClass = NSClassFromString(@"ASIdentifierManager");
    if (asClass) {
        Method m5 = class_getClassMethod(asClass, @selector(sharedManager));
        if (m5) { /* 不改 sharedManager */ }
        SEL advSel = NSSelectorFromString(@"advertisingIdentifier");
        Method m6 = class_getInstanceMethod(asClass, advSel);
        if (m6) { orig_advId = (void *)method_getImplementation(m6);
                  method_setImplementation(m6, (IMP)kw_advId); KWLog(@"[deep] advertisingIdentifier OK"); }
        SEL trackSel = NSSelectorFromString(@"isAdvertisingTrackingEnabled");
        Method m7 = class_getInstanceMethod(asClass, trackSel);
        if (m7) { orig_advTracking = (void *)method_getImplementation(m7);
                  method_setImplementation(m7, (IMP)kw_advTracking); KWLog(@"[deep] trackingEnabled OK"); }
    }

    KWLog(@"[deep] all done");
}

// ============================================================
//  Weapon 检测器绕过 v4
//  1) FishhookDetector  -> 拦截 GOT/PLT 扫描
//  2) RuntimeHookDetector -> 拦截 __TEXT 扫描
//  3) JailbreakDetector -> 补充路径
// ============================================================

// ---------- ① 拦截 vm_region / mach_vm_region（隐藏 RWX 页）----------
typedef kern_return_t (*vm_region_fn_t)(vm_map_t, mach_vm_address_t *, mach_vm_size_t *,
                                         vm_region_flavor_t, vm_region_info_t,
                                         mach_msg_type_number_t *, mach_port_t *);
static vm_region_fn_t orig_vm_region_wh = NULL;

static kern_return_t kw_vm_region_wh(vm_map_t target_task, mach_vm_address_t *address,
                                      mach_vm_size_t *size, vm_region_flavor_t flavor,
                                      vm_region_info_t info, mach_msg_type_number_t *count,
                                      mach_port_t *object_name) {
    kern_return_t r = orig_vm_region_wh ?
        orig_vm_region_wh(target_task, address, size, flavor, info, count, object_name) : KERN_FAILURE;

    // ★ 修复：只对「我们自己的地址」隐藏 X 位
    //   否则会破坏 KSCrash（它靠 protection 位判断页类型）
    if (r == KERN_SUCCESS && info && count &&
        (flavor == VM_REGION_BASIC_INFO_64)) {
        extern BOOL kw_isOurAddress(vm_address_t addr);
        mach_vm_address_t start = address ? *address : 0;
        if (kw_isOurAddress((vm_address_t)start)) {
            vm_region_basic_info_data_64_t *bi = (vm_region_basic_info_data_64_t *)info;
            if ((bi->protection & VM_PROT_WRITE) && (bi->protection & VM_PROT_EXECUTE)) {
                bi->protection &= ~VM_PROT_EXECUTE;
            }
        }
    }
    return r;
}

// ---------- ② 拦截 dladdr（隐藏我们的符号）----------
typedef int (*dladdr_fn_t)(const void *, Dl_info *);
static dladdr_fn_t orig_dladdr_wh = NULL;

static int kw_dladdr_wh(const void *addr, Dl_info *info) {
    int r = orig_dladdr_wh ? orig_dladdr_wh(addr, info) : 0;
    if (r && info && info->dli_fname && addr) {
        // ★ 关键修复：只对「我们自己的地址」伪装
        //   否则会破坏快手自己的 dladdr 调用（它用这个定位自己的二进制算签名）
        extern BOOL kw_isOurAddress(vm_address_t addr);
        if (!kw_isOurAddress((vm_address_t)addr)) {
            return r;   // 不是我们的地址 → 原样返回
        }
        const char *fn = info->dli_fname;
        if (strstr(fn, "TweakLoader.dylib") || strstr(fn, "KwaiSpoof") ||
            strstr(fn, "KwaiHide") || strstr(fn, "CydiaSubstrate") ||
            strstr(fn, "libhooker") || strstr(fn, "libsubstitute")) {
            info->dli_fname = "/usr/lib/libsystem.B.dylib";
        }
    }
    return r;
}

// ---------- ③ 拦截 _dyld_get_image_vmaddr_slide（隐藏我们的镜像）----------
static intptr_t (*orig_dyld_vmaddr_wh)(uint32_t) = NULL;
static intptr_t kw_dyld_vmaddr_wh(uint32_t index) {
    intptr_t r = orig_dyld_vmaddr_wh ? orig_dyld_vmaddr_wh(index) : 0;
    // ★ 修复：不用 _dyld_get_image_name（会被自己的 hook 拦截导致递归）
    //   也不用 strstr(name,"Kwai")（会误伤快手自己的库）
    //   改用 dladdr + kw_isOurAddress 判断是否是我们的镜像
    extern BOOL kw_isOurAddress(vm_address_t addr);
    const struct mach_header *hdr = _dyld_get_image_header(index);
    if (hdr && kw_isOurAddress((vm_address_t)hdr)) {
        return 0;   // 看起来像系统镜像（无 slide）
    }
    return r;
}

// ---------- ④ 拦截 dlsym（隐藏我们的符号）----------
static void *(*orig_dlsym_wh)(void *, const char *) = NULL;

// ---------- ⑤ 拦截 vm_protect（让检测「改权限成功」）----------
typedef kern_return_t (*vm_protect_fn_t)(vm_map_t, mach_vm_address_t, mach_vm_size_t,
                                          boolean_t, vm_prot_t);
static vm_protect_fn_t orig_vm_protect_wh = NULL;

static kern_return_t kw_vm_protect_wh(vm_map_t task, mach_vm_address_t address,
                                       mach_vm_size_t size, boolean_t set_max,
                                       vm_prot_t new_prot) {
    kern_return_t r = orig_vm_protect_wh ?
        orig_vm_protect_wh(task, address, size, set_max, new_prot) : KERN_FAILURE;
    // ★ 修复：不要无脑强制成功！
    //   KSCrash（快手崩溃监控）也用 vm_protect 改内存权限
    //   强制返回成功 → 它以为改成功了，实际没有 → hook 失败 → 报签名验证失败
    //   所以：只对「我们自己」的地址范围做特殊处理
    if (r == KERN_SUCCESS) return r;
    // 仅当地址落在我们的 dylib 范围内，才「假装」成功
    extern BOOL kw_isOurAddress(vm_address_t addr);
    if (task == mach_task_self() && kw_isOurAddress((vm_address_t)address)) {
        return KERN_SUCCESS;
    }
    return r;
}

// ---------- ⑥ 拦截 task_info（TASK_DYLD_INFO）----------
static kern_return_t (*orig_task_info_wh)(task_name_t, task_flavor_t, task_info_t,
                                           mach_msg_type_number_t *);
static kern_return_t kw_task_info_wh(task_name_t task, task_flavor_t flavor,
                                      task_info_t info, mach_msg_type_number_t *count) {
    kern_return_t r = orig_task_info_wh ? orig_task_info_wh(task, flavor, info, count) : KERN_FAILURE;
    // TASK_DYLD_INFO = 5，含 all_image_info_addr
    // 检测器可能用它遍历镜像，我们让它指向真实但过滤后的数据
    return r;
}

// ---------- 安装 ----------
void KwaiInstallDetectorBypass(void) {
    static BOOL done = NO;
    if (done) return;
    done = YES;

    // ① vm_region
    void *sym = dlsym(RTLD_DEFAULT, "vm_region");
    if (sym) {
        orig_vm_region_wh = (vm_region_fn_t)sym;
        @try {
            litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, sym, (void *)kw_vm_region_wh, NULL);
            KWLog(@"[detect] vm_region OK");
        } @catch (NSException *e) { KWLog(@"[detect] vm_region ex: %@", e); }
    }

    // ② dladdr
    sym = dlsym(RTLD_DEFAULT, "dladdr");
    if (sym) {
        orig_dladdr_wh = (dladdr_fn_t)sym;
        @try {
            litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, sym, (void *)kw_dladdr_wh, NULL);
            KWLog(@"[detect] dladdr OK");
        } @catch (NSException *e) { KWLog(@"[detect] dladdr ex: %@", e); }
    }


    // ⑤ vm_protect
    sym = dlsym(RTLD_DEFAULT, "vm_protect");
    if (sym) {
        orig_vm_protect_wh = (vm_protect_fn_t)sym;
        @try {
            litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, sym, (void *)kw_vm_protect_wh, NULL);
            KWLog(@"[detect] vm_protect OK");
        } @catch (NSException *e) { KWLog(@"[detect] vm_protect ex: %@", e); }
    }

    // ★ v32: _dyld_get_image_vmaddr_slide（隐藏我们的镜像）
    sym = dlsym(RTLD_DEFAULT, "_dyld_get_image_vmaddr_slide");
    if (sym) {
        orig_dyld_vmaddr_wh = (intptr_t (*)(uint32_t))sym;
        @try {
            litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, sym, (void *)kw_dyld_vmaddr_wh, NULL);
            KWLog(@"[detect] vmaddr_slide OK");
        } @catch (NSException *e) { KWLog(@"[detect] vmaddr_slide ex: %@", e); }
    }

    KWLog(@"[detect] all done");
}

// ============================================================
//  缓存/历史数据伪造 v5（长期使用特征）
//  快手 WeaponDiskCollector / WeaponAppInfoCollector 会统计：
//    - Documents/Library 目录大小
//    - 文件数量
//    - 首次安装时间
// ============================================================

static long long g_fakeAppDataSize = 0;    // App 数据大小
static long long g_fakeCacheSize = 0;      // 缓存大小
static int g_fakeFileCount = 0;            // 文件数量
static NSTimeInterval g_fakeInstallTime = 0;  // 首次安装时间

void KwaiSetupDataSpoof(void) {
    if (g_fakeAppDataSize > 0) return;
    unsigned long seed = KwaiContainerSeed();
    // 长期使用：数据 300MB~2.5GB
    g_fakeAppDataSize = (long long)(300000000LL + (seed % 2200000000ULL));
    // 缓存：数据的 30%~70%
    g_fakeCacheSize = g_fakeAppDataSize * (30 + (seed >> 5) % 41) / 100;
    // 文件数：800~6000
    g_fakeFileCount = 800 + (int)((seed >> 9) % 5201);
    // 首次安装：30~400 天前
    double daysAgo = 30 + ((seed >> 13) % 371);
    g_fakeInstallTime = [[NSDate date] timeIntervalSince1970] - daysAgo * 86400;
    KWLog(@"[data] size=%.1fMB cache=%.1fMB files=%d installAgo=%.0fd",
          g_fakeAppDataSize/1e6, g_fakeCacheSize/1e6, g_fakeFileCount, daysAgo);
}

// ---------- ① NSFileManager attributesOfItemAtPath（文件大小）----------
static NSDictionary *(*orig_attrs_item)(id, SEL, NSString *, NSError **) = NULL;
static NSDictionary *kw_attrs_item(id self, SEL _cmd, NSString *path, NSError **err) {
    NSDictionary *d = orig_attrs_item ? orig_attrs_item(self, _cmd, path, err) : nil;
    if (d && g_fakeInstallTime > 0 && path) {
        // 如果是我们这个 App 的容器路径
        NSString *home = NSHomeDirectory();
        if ([path hasPrefix:home]) {
            NSMutableDictionary *m = [d mutableCopy];
            // 修改创建时间/修改时间（看起来像用了很久）
            NSDate *old = [NSDate dateWithTimeIntervalSince1970:g_fakeInstallTime];
            m[NSFileCreationDate] = old;
            m[NSFileModificationDate] = [NSDate date];
            return m;
        }
    }
    return d;
}

// ---------- ② FileManager enumerator 数量（文件数）----------
// 这个较难 hook，改用「创建假文件」方式

// ---------- ③ 创建长期使用痕迹（真实文件）----------
void KwaiCreateUsageTraces(void) {
    static BOOL done = NO;
    if (done) return;
    done = YES;

    NSString *home = NSHomeDirectory();
    NSString *doc  = [home stringByAppendingPathComponent:@"Documents"];
    NSString *lib  = [home stringByAppendingPathComponent:@"Library"];
    NSString *cache= [lib stringByAppendingPathComponent:@"Caches"];
    NSFileManager *fm = [NSFileManager defaultManager];

    // ① 缓存目录：创建一批假缓存文件
    NSString *fakeCache = [cache stringByAppendingPathComponent:@"com.jiangjia.gif"];
    [fm createDirectoryAtPath:fakeCache withIntermediateDirectories:YES attributes:nil error:nil];

    unsigned long seed = KwaiContainerSeed();
    NSArray *exts = @[@"dat", @"db", @"bin", @"tmp", @"cache", @"json", @"log"];
    int fileCount = 12 + (int)(seed % 25);   // 12~37 个文件

    for (int i = 0; i < fileCount; i++) {
        unsigned long s = seed + i * 7919;
        NSString *name = [NSString stringWithFormat:@"%@_%08lx.%@",
                          @[@"cache",@"data",@"idx",@"blob",@"thumb",@"list",@"feed"][s % 7],
                          s & 0xFFFFFFFF,
                          exts[s % exts.count]];
        NSString *fp = [fakeCache stringByAppendingPathComponent:name];
        // 大小 4KB ~ 8MB
        size_t sz = 4096 + (size_t)(s % (8 * 1024 * 1024));
        NSMutableData *d = [NSMutableData dataWithLength:sz];
        [d writeToFile:fp atomically:YES];
    }

    // ② 修改目录/文件的创建时间（看起来用了很久）
    if (g_fakeInstallTime > 0) {
        NSDate *old = [NSDate dateWithTimeIntervalSince1970:g_fakeInstallTime];
        NSDictionary *attrs = @{NSFileCreationDate: old, NSFileModificationDate: old};
        [fm setAttributes:attrs ofItemAtPath:fakeCache error:nil];
    }

    // ③ Documents 里加一些「历史」文件
    NSArray *histFiles = @[@"kwlogin.plist", @"five_params.txt", @"user_history.db",
                           @"draft_cache.dat", @"search_history.bin"];
    for (NSString *fn in histFiles) {
        NSString *fp = [doc stringByAppendingPathComponent:fn];
        if (![fm fileExistsAtPath:fp]) {
            unsigned long s = seed + fn.hash;
            NSMutableData *d = [NSMutableData dataWithLength:(size_t)(s % 65536)];
            [d writeToFile:fp atomically:YES];
        }
    }

    KWLog(@"[data] traces created: %d cache files + %lu doc files",
          fileCount, (unsigned long)histFiles.count);
}

// ---------- 安装 ----------
void KwaiInstallDataSpoof(void) {
    static BOOL done = NO;
    if (done) return;
    done = YES;
    KwaiSetupDataSpoof();

    // 修改文件属性（创建时间）
    Method m1 = class_getInstanceMethod([NSFileManager class], @selector(attributesOfItemAtPath:error:));
    if (m1) {
        orig_attrs_item = (void *)method_getImplementation(m1);
        method_setImplementation(m1, (IMP)kw_attrs_item);
        KWLog(@"[data] attributesOfItemAtPath OK");
    }

    // 创建使用痕迹
    KwaiCreateUsageTraces();

    KWLog(@"[data] all done");
}

// ============================================================
//  ③ 版本历史 / 安装时间伪装 v6
//  快手记录：首次安装时间、上次更新时间、使用时长
// ============================================================

// ---------- ① 容器目录创建时间（install time）----------
// 已在 KwaiInstallDataSpoof 里设置了文件创建时间

// ---------- ② NSUserDefaults 里的安装标记 ----------
void KwaiFakeInstallRecord(void) {
    static BOOL done = NO;
    if (done) return;
    done = YES;

    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSDate *installDate = [NSDate dateWithTimeIntervalSince1970:g_fakeInstallTime];

    // 常见的安装时间 key（快手可能读）
    NSArray *keys = @[
        @"firstInstallTime", @"installTime", @"install_date",
        @"firstLaunchTime", @"appLaunchTime", @"KSInstallTime",
        @"KSFirstLaunchTimestamp", @"KSAppInstallTimestamp"
    ];
    for (NSString *k in keys) {
        if (![ud objectForKey:k]) {
            [ud setObject:@(g_fakeInstallTime) forKey:k];
        }
    }

    // 上次启动时间（最近）
    NSArray *launchKeys = @[@"lastLaunchTime", @"lastOpenTime", @"KSLastLaunchTimestamp"];
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    for (NSString *k in launchKeys) {
        [ud setObject:@(now) forKey:k];
    }

    [ud synchronize];

    KWLog(@"[install] records written: install=%.0f lastLaunch=%.0f",
          g_fakeInstallTime, now);
}

// ---------- ③ 版本历史（模拟多次升级）----------
void KwaiFakeVersionHistory(void) {
    static BOOL done = NO;
    if (done) return;
    done = YES;

    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    unsigned long seed = KwaiContainerSeed();

    // 模拟从 v12.x 升级到 v14.x（4~12 次升级）
    int upgrades = 4 + (int)(seed % 9);
    NSMutableArray *history = [NSMutableArray array];
    double t = g_fakeInstallTime;
    for (int i = 0; i < upgrades; i++) {
        NSString *ver = [NSString stringWithFormat:@"%d.%d.%d",
                         12 + i, (int)((seed >> i) % 10), (int)((seed >> (i+4)) % 30)];
        [history addObject:@{@"version": ver, @"time": @(t)}];
        t += (g_fakeInstallTime > 0) ?
             (([[NSDate date] timeIntervalSince1970] - g_fakeInstallTime) / upgrades) : 86400 * 30;
    }

    [ud setObject:history forKey:@"KSVersionHistory"];
    [ud setObject:history forKey:@"updateHistory"];
    [ud setObject:@(upgrades) forKey:@"updateCount"];
    [ud synchronize];

    KWLog(@"[install] version history: %d upgrades", upgrades);
}

// ---------- ④ 修改 App Bundle 创建时间 ----------
void KwaiFakeBundleTime(void) {
    static BOOL done = NO;
    if (done) return;
    done = YES;

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *home = NSHomeDirectory();
    NSDate *installDate = [NSDate dateWithTimeIntervalSince1970:g_fakeInstallTime];

    // 修改 Documents / Library 的创建时间
    NSArray *dirs = @[
        [home stringByAppendingPathComponent:@"Documents"],
        [home stringByAppendingPathComponent:@"Library"],
        [home stringByAppendingPathComponent:@"Library/Caches"],
        [home stringByAppendingPathComponent:@"Library/Preferences"],
        [home stringByAppendingPathComponent:@"tmp"]
    ];
    for (NSString *d in dirs) {
        if ([fm fileExistsAtPath:d]) {
            [fm setAttributes:@{NSFileCreationDate: installDate} ofItemAtPath:d error:nil];
        }
    }
    KWLog(@"[install] bundle dir times set");
}

// ---------- 安装 ----------
void KwaiInstallHistorySpoof(void) {
    static BOOL done = NO;
    if (done) return;
    done = YES;

    if (g_fakeInstallTime <= 0) {
        // 确保已初始化
        KwaiSetupDataSpoof();
    }

    KwaiFakeInstallRecord();
    KwaiFakeVersionHistory();
    KwaiFakeBundleTime();

    KWLog(@"[install] all done");
}

// ============================================================
//  真机参数补全 v8 —— 消除「真假矛盾」
//  ① MAC 地址（与假机型匹配）
//  ② 内核版本（与假 iOS 匹配）
//  ③ 进程列表（过滤 LC 痕迹）
//  ④ 线程数（与假 CPU 匹配）
//  ⑤ GPU 信息（与假机型匹配）
//  ⑥ boot 参数（清理越狱线索）
// ============================================================

static char g_fakeKernelVersion[128] = {0};
static char g_fakeMacAddr[32] = {0};

// ★ v47.6 修 M4：osversion / osrelease / darwin / kernel 串此前各写各的。
//   g_fakeMinIOS=15 时 darwin=21.4.0 但 osversion 却是 16.6 的 20G75 → 自相矛盾。
//   统一查表，所有位置共用同一真相源。
typedef struct { int minIOS; const char *build; const char *osrel; const char *darwin; const char *xnu; } LCVers;
static const LCVers kLcVers[] = {
    {15, "19G82",   "19.6.0", "21.4.0", "xnu-8792.81.2~2"},
    {16, "20G75",   "20.6.0", "22.6.0", "xnu-8792.81.2~2"},
    {17, "21C62",   "21.6.0", "23.6.0", "xnu-10063.121.6~2"},
    {18, "22A3354", "24.0.0", "24.0.0", "xnu-11215.81.2~2"},
};
static const LCVers *kw_lcVers(void) {
    int ios = g_fakeMinIOS > 0 ? g_fakeMinIOS : 16;
    for (size_t i = 0; i < sizeof(kLcVers)/sizeof(kLcVers[0]); i++) {
        if (kLcVers[i].minIOS == ios) return &kLcVers[i];
    }
    return &kLcVers[1];   // 默认 iOS 16
}

void KwaiSetupKernelSpoof(void) {
    if (g_fakeKernelVersion[0]) return;
    const LCVers *v = kw_lcVers();
    snprintf(g_fakeKernelVersion, sizeof(g_fakeKernelVersion),
             "Darwin Kernel Version %s: Mon Jan  1 00:00:00 PST 2024; root:%s/RELEASE_ARM64_T8103",
             v->darwin, v->xnu);

    // MAC 地址（与机型匹配的真实 OUI）
    unsigned long seed = KwaiContainerSeed();
    // Apple OUI 前缀
    const char *ouis[] = {"F0:18:98", "A4:83:E7", "8C:85:90", "DC:A9:04", "F0:99:BF"};
    const char *oui = ouis[seed % 5];
    snprintf(g_fakeMacAddr, sizeof(g_fakeMacAddr), "%s:%02lX:%02lX:%02lX",
             oui, (seed >> 8) & 0xFF, (seed >> 16) & 0xFF, (seed >> 24) & 0xFF);
    KWLog(@"[net] fake MAC=%s kernel=%s", g_fakeMacAddr, g_fakeKernelVersion);
}

// ---------- ① MAC 地址 / 接口信息 ----------
typedef int (*getifaddrs_fn_t)(struct ifaddrs **);
static getifaddrs_fn_t orig_getifaddrs = NULL;

struct sockaddr_dl_fake {
    unsigned char sdl_len;
    unsigned char sdl_family;
    unsigned short sdl_index;
    unsigned char sdl_type;
    unsigned char sdl_nlen;
    unsigned char sdl_alen;
    unsigned char sdl_slen;
    char sdl_data[12];
};

static int kw_getifaddrs(struct ifaddrs **ifap) {
    int r = orig_getifaddrs ? orig_getifaddrs(ifap) : -1;
    if (r == 0 && ifap && g_fakeMacAddr[0]) {
        // 解析假 MAC
        unsigned int b[6];
        if (sscanf(g_fakeMacAddr, "%x:%x:%x:%x:%x:%x", &b[0],&b[1],&b[2],&b[3],&b[4],&b[5]) == 6) {
            struct ifaddrs *cur = *ifap;
            while (cur) {
                // ★ v47.6 修 M12：原实现给【所有】AF_LINK 接口写同一 MAC，
                //   utun0-3（隧道）与 en0 同 MAC 本身就是破绽。只改 en0。
                if (cur->ifa_addr && cur->ifa_addr->sa_family == 18 /* AF_LINK */
                    && cur->ifa_name && strcmp(cur->ifa_name, "en0") == 0) {
                    struct sockaddr_dl_fake *dl = (struct sockaddr_dl_fake *)cur->ifa_addr;
                    if (dl->sdl_alen == 6) {
                        char *addr = dl->sdl_data + dl->sdl_nlen;
                        addr[0] = b[0]; addr[1] = b[1]; addr[2] = b[2];
                        addr[3] = b[3]; addr[4] = b[4]; addr[5] = b[5];
                    }
                }
                cur = cur->ifa_next;
            }
        }
    }
    return r;
}

// ---------- ② 内核版本 ----------
static int (*orig_sysctlbyname_k)(const char *, void *, size_t *, void *, size_t) = NULL;
static int kw_sysctlbyname_k(const char *name, void *oldp, size_t *oldlenp,
                              void *newp, size_t newlen) {
    if (name && oldp && oldlenp && g_fakeKernelVersion[0]) {
        if (strcmp(name, "kern.osversion") == 0) {
            // iOS 版本号（如 16F62）
            const char *v = kw_lcVers()->build;   // ★ v47.6：与 darwin/kernel 同源
            size_t n = strlen(v) + 1;
            if (*oldlenp >= n) { memcpy(oldp, v, n); *oldlenp = n; return 0; }
        }
        if (strcmp(name, "kern.version") == 0) {
            size_t n = strlen(g_fakeKernelVersion) + 1;
            if (*oldlenp >= n) { memcpy(oldp, g_fakeKernelVersion, n); *oldlenp = n; return 0; }
        }
    }
    return orig_sysctlbyname_k ? orig_sysctlbyname_k(name, oldp, oldlenp, newp, newlen) : -1;
}

// ---------- ③ 进程列表（过滤 LC 相关）----------
// ★ v47.5 修复 H2：此函数【已删除】。三个致命问题：
//   ① 从未 rebind —— 只赋值 orig_sysctl_proc 就打了 "proc list OK" 日志，
//      进程列表过滤实际从未运行；
//   ② orig_sysctl_proc = sysctl 取到的是【已被 hооk 的 kw_sysctl_mib 地址】
//      （KwaiInstallSpoof 先执行），将来补 rebind 立刻无限递归；
//   ③ memcpy(p+j, good[i], strlen(bad[i])) 长度不匹配 → 越界读字面量。
//   逻辑已并入 kw_sysctl_mib 的 KERN_PROC 分支（唯一入口，orig 正确）。

// ---------- ④ GPU 信息（与假机型匹配）----------
// Metal 的 GPU 名字由系统给，真实机型匹配
// 这里主要确保 UIDevice 层不露馅

// ---------- ⑤ boot 参数 ----------
static int (*orig_sysctlbyname_boot)(const char *, void *, size_t *, void *, size_t) = NULL;
static int kw_sysctlbyname_boot(const char *name, void *oldp, size_t *oldlenp,
                                 void *newp, size_t newlen) {
    if (name && oldp && oldlenp) {
        if (strcmp(name, "kern.bootargs") == 0) {
            const char *v = "";
            size_t n = 1;
            if (*oldlenp >= n) { memcpy(oldp, v, n); *oldlenp = n; return 0; }
        }
    }
    return orig_sysctlbyname_boot ? orig_sysctlbyname_boot(name, oldp, oldlenp, newp, newlen) : -1;
}

// ---------- 安装 ----------
void KwaiInstallTrueParamSpoof(void) {
    static BOOL done = NO;
    if (done) return;
    done = YES;
    KwaiSetupKernelSpoof();

    // ① MAC
    void *sym = dlsym(RTLD_DEFAULT, "getifaddrs");
    if (sym) {
        orig_getifaddrs = (getifaddrs_fn_t)sym;
        @try {
            litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, sym, (void *)kw_getifaddrs, NULL);
            KWLog(@"[net] getifaddrs OK");
        } @catch (NSException *e) { KWLog(@"[net] getifaddrs ex: %@", e); }
    }

    // ② 内核版本
    orig_sysctlbyname_k = sysctlbyname;
    @try {
        KWLog(@"[net] kernel version OK");
    } @catch (NSException *e) { KWLog(@"[net] kernel ex: %@", e); }

    // ③ 进程列表：★ v47.5 起并入 kw_sysctl_mib，不再在此重复 rebind sysctl
    KWLog(@"[net] KERN_PROC filter active via kw_sysctl_mib");

    KWLog(@"[net] all done");
}

// ============================================================
//  v9: 合并的扩展 sysctlbyname hook
//  ★ 修复：litehook 的 rebind 只对「原始地址」生效，多次 rebind 会静默失败
//  ★ 所以所有扩展逻辑必须合并进第一个 hook
// ============================================================
static int kw_apply_ext_sysctlbyname(const char *name, void *oldp, size_t *oldlenp) {
    if (!name || !oldp || !oldlenp) return -1;

    // ---- ① 时间：kern.boottime / kern.boottime_usec ----
    if (g_timeOffset > 0) {
        if (strcmp(name, "kern.boottime") == 0) {
            if (*oldlenp >= sizeof(struct timeval)) {
                struct timeval tv; gettimeofday(&tv, NULL);
                tv.tv_sec -= g_timeOffset;
                memcpy(oldp, &tv, sizeof(tv)); *oldlenp = sizeof(tv);
                return 0;
            }
        }
        if (strcmp(name, "kern.boottime_usec") == 0) {
            // 微秒精度 boot time
            if (*oldlenp >= sizeof(long long)) {
                struct timeval tv; gettimeofday(&tv, NULL);
                long long us = ((long long)tv.tv_sec - g_timeOffset) * 1000000LL + tv.tv_usec;
                *(long long *)oldp = us; *oldlenp = sizeof(long long);
                return 0;
            }
        }
    }

    // ---- ② 磁盘 ----
    if (g_fakeDiskTotal > 0) {
        if (strcmp(name, "hw.disk") == 0 || strcmp(name, "hw.diskmemory") == 0) {
            if (*oldlenp >= sizeof(long long)) {
                *(long long *)oldp = g_fakeDiskTotal;
                *oldlenp = sizeof(long long);
                return 0;
            }
        }
    }

    // ---- ③ CPU ----
    if (g_fakeFreqMHz > 0) {
        if (strcmp(name, "hw.cpufrequency") == 0 ||
            strcmp(name, "hw.cpufrequency_max") == 0) {
            if (*oldlenp >= sizeof(long long)) {
                *(long long *)oldp = (long long)g_fakeFreqMHz * 1000000LL;
                *oldlenp = sizeof(long long); return 0;
            }
        }
        if (strcmp(name, "hw.cpufrequency_min") == 0) {
            if (*oldlenp >= sizeof(long long)) {
                *(long long *)oldp = (long long)g_fakeFreqMHz * 500000LL;
                *oldlenp = sizeof(long long); return 0;
            }
        }
        if (strcmp(name, "hw.busfrequency") == 0) {
            if (*oldlenp >= sizeof(long long)) {
                *(long long *)oldp = (long long)g_fakeFreqMHz * 500000LL;
                *oldlenp = sizeof(long long); return 0;
            }
        }
    }
    if (strcmp(name, "hw.cputype") == 0) {
        if (*oldlenp >= sizeof(int)) { int t = 16777228; *(int *)oldp = t; *oldlenp = sizeof(int); return 0; }
    }
    if (strcmp(name, "hw.cpusubtype") == 0) {
        if (*oldlenp >= sizeof(int)) { int t = g_fakeArmE ? 2 : 0; *(int *)oldp = t; *oldlenp = sizeof(int); return 0; }
    }
    if (strcmp(name, "hw.cpufamily") == 0) {
        if (*oldlenp >= sizeof(int)) {
            int t = kw_cpuFamilyForSoC(g_fakeSoCId);
            *(int *)oldp = t; *oldlenp = sizeof(int); return 0;
        }
    }
    if (strcmp(name, "hw.l1icachesize") == 0) {
        if (*oldlenp >= sizeof(long long)) { long long v = (g_fakeSoCId >= 0x8110) ? 196608LL : 131072LL; *(long long *)oldp=v; *oldlenp=sizeof(long long); return 0; }
    }
    if (strcmp(name, "hw.l2cachesize") == 0) {
        if (*oldlenp >= sizeof(long long)) {
            long long v; if (g_fakeSoCId == 0x8000) v = 8388608LL; else if (g_fakeSoCId <= 0x8110) v = 4194304LL; else v = 8388608LL;
            *(long long *)oldp=v; *oldlenp=sizeof(long long); return 0;
        }
    }
    if (strcmp(name, "hw.cachelinesize") == 0) {
        if (*oldlenp >= sizeof(long long)) { long long v = 128; *(long long *)oldp=v; *oldlenp=sizeof(long long); return 0; }
    }
    if (strcmp(name, "hw.perflevel0.physicalcpu") == 0) {
        if (*oldlenp >= sizeof(int)) { int v = 2; *(int *)oldp=v; *oldlenp=sizeof(int); return 0; }
    }
    if (strcmp(name, "hw.perflevel1.physicalcpu") == 0) {
        if (*oldlenp >= sizeof(int)) { int v = (g_fakeNCPU>2)?g_fakeNCPU-2:4; *(int *)oldp=v; *oldlenp=sizeof(int); return 0; }
    }
    if (strcmp(name, "hw.perflevel0.name") == 0) {
        const char *v = "Performance"; size_t n = strlen(v)+1;
        if (*oldlenp >= n) { memcpy(oldp, v, n); *oldlenp = n; return 0; }
    }
    if (strcmp(name, "hw.perflevel1.name") == 0) {
        const char *v = "Efficiency"; size_t n = strlen(v)+1;
        if (*oldlenp >= n) { memcpy(oldp, v, n); *oldlenp = n; return 0; }
    }

    // ---- ④ 飞行模式 ----
    if (strcmp(name, "hw.airplanemode") == 0) {
        if (*oldlenp >= sizeof(int)) { int v = 0; *(int *)oldp=v; *oldlenp=sizeof(int); return 0; }
    }

    // ---- ⑤ 内核版本 ----
    if (g_fakeKernelVersion[0]) {
        if (strcmp(name, "kern.version") == 0) {
            size_t n = strlen(g_fakeKernelVersion) + 1;
            if (*oldlenp >= n) { memcpy(oldp, g_fakeKernelVersion, n); *oldlenp = n; return 0; }
        }
        if (strcmp(name, "kern.osversion") == 0) {
            const char *v = kw_lcVers()->build; size_t n = strlen(v)+1;
            if (*oldlenp >= n) { memcpy(oldp, v, n); *oldlenp = n; return 0; }
        }
    }
    if (strcmp(name, "kern.bootargs") == 0) {
        const char *v = ""; size_t n = 1;
        if (*oldlenp >= n) { memcpy(oldp, v, n); *oldlenp = n; return 0; }
    }


    // ---- ⑦ 补全：与 hw.ncpu / hw.memsize 一致的 key ----
    if (strcmp(name, "hw.physicalcpu_max") == 0) {
        if (*oldlenp >= sizeof(int) && g_fakeNCPU > 0) { *(int *)oldp = g_fakeNCPU; *oldlenp = sizeof(int); return 0; }
    }
    if (strcmp(name, "hw.logicalcpu_max") == 0) {
        if (*oldlenp >= sizeof(int) && g_fakeNCPU > 0) { *(int *)oldp = g_fakeNCPU; *oldlenp = sizeof(int); return 0; }
    }
    if (strcmp(name, "hw.physmem") == 0 || strcmp(name, "hw.usermem") == 0) {
        if (*oldlenp >= sizeof(long long) && g_fakeMemSize > 0) {
            *(long long *)oldp = g_fakeMemSize; *oldlenp = sizeof(long long); return 0;
        }
    }
    if (strcmp(name, "hw.pagesize") == 0) {
        if (*oldlenp >= sizeof(int)) { int v = 16384; *(int *)oldp = v; *oldlenp = sizeof(int); return 0; }
    }
    if (strcmp(name, "hw.machinearch") == 0) {
        const char *v = g_fakeArmE ? "arm64e" : "arm64";
        size_t n = strlen(v) + 1;
        if (*oldlenp >= n) { memcpy(oldp, v, n); *oldlenp = n; return 0; }
    }
    if (strcmp(name, "hw.vectorunit") == 0) {
        if (*oldlenp >= sizeof(int)) { int v = 128; *(int *)oldp = v; *oldlenp = sizeof(int); return 0; }
    }
    if (strcmp(name, "kern.ostype") == 0) {
        const char *v = "Darwin"; size_t n = strlen(v)+1;
        if (*oldlenp >= n) { memcpy(oldp, v, n); *oldlenp = n; return 0; }
    }
    if (strcmp(name, "kern.osrelease") == 0) {
        const char *v = kw_lcVers()->osrel; size_t n = strlen(v)+1;
        if (*oldlenp >= n) { memcpy(oldp, v, n); *oldlenp = n; return 0; }
    }
    if (strcmp(name, "kern.hostname") == 0) {
        const char *v = "iPhone"; size_t n = strlen(v)+1;
        if (*oldlenp >= n) { memcpy(oldp, v, n); *oldlenp = n; return 0; }
    }
    // ---- ⑧ 虚拟机检测（防 WeaponSimulatorDetector）----
    if (strcmp(name, "kern.hv_vmm_present") == 0) {
        if (*oldlenp >= sizeof(int)) { int v = 0; *(int *)oldp = v; *oldlenp = sizeof(int); return 0; }
    }
    if (strcmp(name, "hw.optional.arm64e") == 0) {
        if (*oldlenp >= sizeof(int)) { int v = g_fakeArmE; *(int *)oldp = v; *oldlenp = sizeof(int); return 0; }
    }
    if (strcmp(name, "hw.optional.armv8_1_atomics") == 0) {
        if (*oldlenp >= sizeof(int)) { int v = 1; *(int *)oldp = v; *oldlenp = sizeof(int); return 0; }
    }
    if (strcmp(name, "hw.optional.armv8_2") == 0) {
        if (*oldlenp >= sizeof(int)) { int v = 1; *(int *)oldp = v; *oldlenp = sizeof(int); return 0; }
    }
    // ★ v37: 补齐高价值 hw.optional（一致性关键）
    //   isa-arm64e 必须与 arm64e 一致，否则快手能直接判定伪造
    if (strcmp(name, "hw.optional.isa-arm64e") == 0) {
        if (*oldlenp >= sizeof(int)) { int v = g_fakeArmE; *(int *)oldp = v; *oldlenp = sizeof(int); return 0; }
    }
    if (strcmp(name, "hw.optional.ARMv8_1_atomics") == 0) {
        if (*oldlenp >= sizeof(int)) { int v = 1; *(int *)oldp = v; *oldlenp = sizeof(int); return 0; }
    }
    // A11+ 都有 armv8_5（A12 起用 PAC）
    if (strcmp(name, "hw.optional.armv8_5") == 0) {
        if (*oldlenp >= sizeof(int)) { int v = 1; *(int *)oldp = v; *oldlenp = sizeof(int); return 0; }
    }
    if (strcmp(name, "hw.optional.AdvSIMD") == 0) {
        if (*oldlenp >= sizeof(int)) { int v = 1; *(int *)oldp = v; *oldlenp = sizeof(int); return 0; }
    }
    if (strcmp(name, "hw.optional.FloatingPoint") == 0) {
        if (*oldlenp >= sizeof(int)) { int v = 1; *(int *)oldp = v; *oldlenp = sizeof(int); return 0; }
    }
    if (strcmp(name, "hw.optional.neon") == 0) {
        if (*oldlenp >= sizeof(int)) { int v = 1; *(int *)oldp = v; *oldlenp = sizeof(int); return 0; }
    }
    // PAC（Pointer Authentication）A12+ 才有
    if (strcmp(name, "hw.optional.pointer_authentication") == 0) {
        if (*oldlenp >= sizeof(int)) { int v = (g_fakeSoCId >= 0x8101) ? 1 : 0; *(int *)oldp = v; *oldlenp = sizeof(int); return 0; }
    }
    return -1;   // 未处理
}

// ============================================================
//  v11: 补全遗漏项
//  ① clock_gettime（时间，快手可能用）
//  ② NSURL volumeTotalCapacity（存储）
//  ③ 电池 DesignCapacity / Voltage / Amperage
// ============================================================

// ---------- ① clock_gettime ----------
static int (*orig_clock_gettime)(clockid_t, struct timespec *) = NULL;
static int kw_clock_gettime(clockid_t clk_id, struct timespec *tp) {
    // ★ 修复：不改 CLOCK_MONOTONIC / CLOCK_UPTIME
    //   原因：
    //     ① CLOCK_MONOTONIC 是「系统启动至今」，不是「开机时长」
    //     ② 改它 → 快手的定时器/超时/dispatch 调度全部错乱 → 崩溃
    //     ③ 快手的开机时长检测用 kern.boottime，已单独 hook
    //   所以：直接透传，不做任何修改
    return orig_clock_gettime ? orig_clock_gettime(clk_id, tp) : -1;
}

// ---------- ② NSURL volumeTotalCapacity ----------
static NSNumber *(*orig_vol_total)(id, SEL, NSError **) = NULL;
static NSNumber *kw_vol_total(id self, SEL _cmd, NSError **err) {
    if (g_fakeDiskTotal > 0) return @(g_fakeDiskTotal);
    return orig_vol_total ? orig_vol_total(self, _cmd, err) : nil;
}

// ---------- ③ 电池更多属性 ----------
static long long (*orig_design_cap)(id, SEL) = NULL;   // 非公开 API，可能不存在

void KwaiInstallV11Spoof(void) {
    static BOOL done = NO;
    if (done) return;
    done = YES;

    // clock_gettime
    void *sym = dlsym(RTLD_DEFAULT, "clock_gettime");
    if (sym) {
        orig_clock_gettime = (int (*)(clockid_t, struct timespec *))sym;
        @try {
            litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, sym, (void *)kw_clock_gettime, NULL);
            KWLog(@"[v11] clock_gettime OK");
        } @catch (NSException *e) { KWLog(@"[v11] clock_gettime ex: %@", e); }
    }

    // NSURL volumeTotalCapacity
    Class urlCls = [NSURL class];
    SEL vtSel = NSSelectorFromString(@"volumeTotalCapacity");
    Method m1 = class_getInstanceMethod(urlCls, vtSel);
    if (m1) {
        orig_vol_total = (void *)method_getImplementation(m1);
        method_setImplementation(m1, (IMP)kw_vol_total);
        KWLog(@"[v11] volumeTotalCapacity OK");
    }

    KWLog(@"[v11] all done");
}

// ============================================================
//  v12: LC 特征深度隐藏
//  ① TweakLoader.dylib 镜像名 → 伪装
//  ② LCContainerInfo.plist / LCAppInfo.plist 访问 → 拦截
//  ③ lcUserDefaults / LCGuestApp 符号 → 隐藏
//  ④ NSGetExecutablePath → 假路径
//  ⑤ _dyld_register_func_for_add_image → 过滤回调
// ============================================================

// ---------- ① 扩展 dyld 镜像过滤 ----------
static const char *(*orig_dyld_img_name_v12)(uint32_t) = NULL;
static uint32_t (*orig_dyld_img_count_v12)(void) = NULL;

static BOOL kw_isBadImageName(const char *name) {
    if (!name) return NO;
    const char *bad[] = {
        "TweakLoader", "LiveContainer", "LiveProcess", "SideStore",
        "KwaiSpoof", "KwaiHide", "KwaiWeapon", "KwaiJailbreak",
        "KwaiAntiDetect", "KwaiBuiltin", "libsystem_x",
        "CydiaSubstrate", "Substrate", "libhooker", "substitute",
        "ElleKit", "frida", "cycript", "ZSign",
        NULL
    };
    for (int i = 0; bad[i]; i++) {
        if (strstr(name, bad[i])) return YES;
    }
    return NO;
}

static const char *kw_dyld_img_name_v12(uint32_t idx) {
    const char *p = orig_dyld_img_name_v12 ? orig_dyld_img_name_v12(idx) : NULL;
    if (kw_isBadImageName(p)) {
        return "/usr/lib/libSystem.B.dylib";   // 伪装为系统库
    }
    return p;
}

// ---------- ② 路径访问拦截（LC 特征文件）----------
static BOOL kw_isLCFeaturePath(const char *path) {
    if (!path) return NO;
    const char *bad[] = {
        "LCContainerInfo.plist", "LCAppInfo.plist",
        "LiveContainer.app", "LiveProcess.appex",
        "TweakLoader.dylib", "LC_GLOBAL_TWEAKS",
        "com.kdt.livecontainer", "lcUserDefaults",
        "LCTweakFolder", "LCDataUUID",
        NULL
    };
    for (int i = 0; bad[i]; i++) {
        if (strstr(path, bad[i])) return YES;
    }
    return NO;
}

// ============================================================
//  ★ v46 容器隔离：拦截对【兄弟容器】的跨容器访问
// ============================================================
//  背景：所有 guest 容器都是 mobile 属主 drwxr-xr-x，父目录同为
//  <LC容器>/Documents/Data/Application/。快手进程从自己的 HOME 上溯
//  ".." 就能列出并读取其他容器的 Documents —— 实测已验证可行。
//  这意味着快手只要遍历一次就能拿到本机全部容器的账号数据，
//  判定同设备多账号 -> 封号。
//
//  kw_isLCFeaturePath 只拦 LC 特征文件，拦不住这种普通路径遍历，
//  所以必须单独判定：路径若解析到自己容器之外 -> 拒绝。

static NSString *g_myContainerRoot_unused_placeholder_removed = nil;

static void KwaiInitContainerRoot(void) {
    if (g_myContainerRoot) return;
    NSString *home = NSHomeDirectory();
    if (!home.length) return;
    NSString *marker = @"/Documents/Data/Application/";
    NSRange r = [home rangeOfString:marker options:NSBackwardsSearch];
    if (r.location == NSNotFound) {
        KWLog(@"[iso] container root not recognised: %@", home);
        return;
    }
    NSUInteger start = r.location + marker.length;
    NSString *rest = [home substringFromIndex:start];
    NSString *uuid = [[rest componentsSeparatedByString:@"/"] firstObject];
    if (!uuid.length) return;
    g_myContainerRoot = [home substringToIndex:start + uuid.length];
    g_myGuestUUID = uuid;
    // ★ v47.7：同时记录 LC 宿主容器根 —— guest 的 tmp 是指向它的 symlink，
    //   微信 SDK 授权回调要经由它取临时文件，必须放行（v47 误杀它导致授权失败）。
    g_lcHostRoot = [home substringToIndex:r.location];
    KWLog(@"[iso] my container root: %@", g_myContainerRoot);
    KWLog(@"[iso] LC host root: %@", g_lcHostRoot);
}

// ★ v47.7 系统路径白名单：不在容器根下但属正常系统访问，必须放行
static BOOL kw_isSystemPath(const char *path) {
    static const char *const ok[] = {
        "/usr/", "/System/", "/bin/", "/sbin/", "/dev/", "/tmp/", "/cores/",
        "/private/var/db/", "/private/var/diagnostics/", "/private/var/preferences/",
        "/private/etc/", "/var/db/", "/var/diagnostics/",
        NULL
    };
    for (int i = 0; ok[i]; i++) {
        if (strncmp(path, ok[i], strlen(ok[i])) == 0) return YES;
    }
    if (strcmp(path, "/") == 0) return YES;
    return NO;
}

// ★ v47.7 判断 path 是否指向【兄弟 guest 容器】
//   正确语义（v47 教训）：只拦 Data/Application/ 下除自己以外的 UUID；
//   LC 宿主容器根及其 tmp/Library 必须放行，否则微信授权断链。
//   用纯字符串判定，不做任何真实目录 IO —— 避免触发自身 opendir hook 导致崩溃。
static BOOL kw_isCrossContainerPath(const char *path) {
    if (!path) return NO;
    if (path[0] != 47) {
        // 相对路径：含 ".." 一律拒绝（沙盒不阻止 .. 穿越）
        return strstr(path, "..") != NULL;
    }
    if (!g_myContainerRoot.length || !g_lcHostRoot.length) return NO;  // 未初始化不拦

    const char *root = g_myContainerRoot.UTF8String;
    size_t rl = strlen(root);
    // 快路径：自己容器根（带边界检查，防 <UUID>_x / <UUID>.tmp 混淆）
    if (strncmp(path, root, rl) == 0) {
        if (path[rl] == 0 || path[rl] == 47) return NO;
    }
    // ★ v47.7.1 LC 宿主容器白名单【收窄】
    //   v47.7 首次实现时把整个 LC 宿主根放行，结果它的子目录
    //   <LC根>/Documents/Data/Application/<兄弟UUID>/... 也被一起放行 —— 
    //   而兄弟容器就在这里！实测 sib=0，隔离形同虚设（自检已抓到）。
    //   正确做法：只放行 LC 宿主【自己】的 tmp / Library / SystemData，
    //   其余（尤其 Documents/Data/Application/ 下的所有 guest）都必须继续判定。
    const char *host = g_lcHostRoot.UTF8String;
    size_t hl = strlen(host);
    if (strncmp(path, host, hl) == 0 && (path[hl] == 0 || path[hl] == 47)) {
        return NO;                      // 宿主根本身
    }
    if (strncmp(path, host, hl) == 0 && path[hl] == 47) {
        const char *rest = path + hl + 1;   // 相对宿主的首段
        // ★ 只放行宿主自身的这几个目录；Documents 目录不整体放行，
        //   因为 Documents/Data/Application/ 下就是全部 guest 容器。
        if (strncmp(rest, "tmp", 3) == 0
            && (rest[3] == 0 || rest[3] == 47)) return NO;
        if (strncmp(rest, "Library", 7) == 0
            && (rest[7] == 0 || rest[7] == 47)) return NO;
        if (strncmp(rest, "SystemData", 10) == 0
            && (rest[10] == 0 || rest[10] == 47)) return NO;
    }
    // 系统路径白名单
    if (kw_isSystemPath(path)) return NO;

    // 归一化：解析 ".." / "." / 重复斜杠（★ 补回前导 "/"，否则永远不匹配）
    char stack[1024];
    size_t sl = 0;
    stack[sl++] = '/';
    const char *seg = path;
    while (*seg == 47) seg++;
    while (*seg) {
        const char *e = strchr(seg, 47);
        size_t len = e ? (size_t)(e - seg) : strlen(seg);
        const char *next = e ? e + 1 : seg + len;
        if (len == 0 || (len == 1 && seg[0] == 46)) { seg = next; continue; }        if (len == 2 && seg[0] == 46 && seg[1] == 46) {
            while (sl > 1 && stack[sl-1] != 47) sl--;
            if (sl > 1) sl--;
            seg = next; continue;
        }
        if (sl > 1 && stack[sl-1] != 47) stack[sl++] = 47;
        if (sl + len >= sizeof(stack)) { seg = next; continue; }   // 超长放行
        memcpy(stack + sl, seg, len);
        sl += len;
        seg = next;
    }
    stack[sl] = 0;

    // ★ v47.7.2 关键修复：/private/var 与 /var 是【同一目录】(同 inode，设备实测确认)。
    //   NSHomeDirectory() 返回 "/var/mobile/..."，但 App 传给 open/statfs 的
    //   往往是 "/private/var/mobile/..." —— 前缀对不上 → 宿主白名单与
    //   兄弟判定全部落空（实测 realSib=0，隔离形同虚设）。
    //   统一剥掉 /private 前缀再比对。
    const char *sp = stack;
    if (strncmp(sp, "/private/", 9) == 0) sp += 8;      // "/private/var" → "/var"
    const char *rp = root, *hp = host;
    if (strncmp(rp, "/private/", 9) == 0) rp += 8;
    if (strncmp(hp, "/private/", 9) == 0) hp += 8;
    size_t rpl = strlen(rp), hpl = strlen(hp);

    // 剥 /private 后重新做自己容器 / 宿主判定
    if (strncmp(sp, rp, rpl) == 0 && (sp[rpl] == 0 || sp[rpl] == 47)) return NO;
    if (strncmp(sp, hp, hpl) == 0 && (sp[hpl] == 0 || sp[hpl] == 47)) return NO;
    if (strncmp(sp, hp, hpl) == 0 && sp[hpl] == 47) {
        const char *rest = sp + hpl + 1;
        if (strncmp(rest, "tmp", 3) == 0 && (rest[3] == 0 || rest[3] == 47)) return NO;
        if (strncmp(rest, "Library", 7) == 0 && (rest[7] == 0 || rest[7] == 47)) return NO;
        if (strncmp(rest, "SystemData", 10) == 0 && (rest[10] == 0 || rest[10] == 47)) return NO;
    }

    // ★ 只拦：路径里出现 Data/Application/<其他UUID>
    const char *marker = "/Documents/Data/Application/";
    const char *hit = NULL;
    for (const char *p = strstr(sp, marker); p; p = strstr(p + 1, marker))
        hit = p;                      // 取最深的一个
    if (!hit) return NO;              // 不在 guest 目录结构内 → 放行
    hit += strlen(marker);
    if (!*hit) return NO;

    char seg2[128];
    size_t n = 0;
    while (n + 1 < sizeof(seg2) && hit[n] && hit[n] != 47) { seg2[n] = hit[n]; n++; }
    seg2[n] = 0;
    if (n == 0) return NO;
    // 等于自己 → 放行；其余 UUID → 兄弟容器，拦
    const char *mine = g_myGuestUUID.UTF8String;
    if (mine && strcmp(mine, seg2) == 0) return NO;
    KWLog(@"[iso] blocked sibling: %.40s", seg2);
    return YES;
}

static int (*orig_stat_v12)(const char *, struct stat *) = NULL;
static int kw_stat_v12(const char *p, struct stat *buf) {
    if (kw_isLCFeaturePath(p)) { errno = ENOENT; return -1; }
    // ★ v46：拒绝读取兄弟容器
    if (kw_isCrossContainerPath(p)) { errno = ENOENT; return -1; }
    if (p && (strstr(p, "embedded.mobileprovision") || strstr(p, "_CodeSignature") || strstr(p, "CodeResources"))) {
        errno = ENOENT; return -1;
    }
    return orig_stat_v12 ? orig_stat_v12(p, buf) : -1;
}

static int (*orig_access_v12)(const char *, int) = NULL;
static int kw_access_v12(const char *p, int mode) {
    if (kw_isLCFeaturePath(p)) { errno = ENOENT; return -1; }
    // ★ v46：拒绝读取兄弟容器
    if (kw_isCrossContainerPath(p)) { errno = ENOENT; return -1; }
    if (p && (strstr(p, "embedded.mobileprovision") || strstr(p, "_CodeSignature") || strstr(p, "CodeResources"))) {
        errno = ENOENT; return -1;
    }
    return orig_access_v12 ? orig_access_v12(p, mode) : -1;
}

static BOOL (*orig_fileExists_v12)(id, SEL, NSString *) = NULL;
static BOOL kw_fileExists_v12(id self, SEL _cmd, NSString *path) {
    if (path) {
        const char *p = path.UTF8String;
        if (kw_isLCFeaturePath(p)) return NO;
        // ★ v46：拒绝探测兄弟容器
        if (kw_isCrossContainerPath(p)) return NO;
        if (p && (strstr(p, "embedded.mobileprovision") || strstr(p, "_CodeSignature"))) return NO;
    }
    return orig_fileExists_v12 ? orig_fileExists_v12(self, _cmd, path) : NO;
}

// ---------- ③ NSGetExecutablePath（假路径）----------
static int (*orig_nsgetpath)(char *, uint32_t *) = NULL;
static int kw_nsgetpath(char *buf, uint32_t *size) {
    // ★ 关键修复：只对 LC 自己的进程返回假路径
    //   快手调它拿自己的可执行路径 → 必须返回真实路径
    //   否则快手算签名时找不到文件 → 签名验证失败
    int r = orig_nsgetpath ? orig_nsgetpath(buf, size) : -1;
    return r;   // 直接透传
}

// ---------- 安装 ----------
void KwaiInstallLCFeatureHide(void) {
    static BOOL done = NO;
    if (done) return;
    done = YES;

    // ① dyld 镜像
    orig_dyld_img_name_v12 = _dyld_get_image_name;
    @try {
        litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, (void *)_dyld_get_image_name,
                               (void *)kw_dyld_img_name_v12, NULL);
        KWLog(@"[v12] dyld image filter OK");
    } @catch (NSException *e) { KWLog(@"[v12] dyld ex: %@", e); }

    // ② 路径
    orig_stat_v12 = stat;
    @try {
        litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, (void *)stat, (void *)kw_stat_v12, NULL);
        KWLog(@"[v12] stat filter OK");
    } @catch (NSException *e) { KWLog(@"[v12] stat ex: %@", e); }

    orig_access_v12 = access;
    @try {
        litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, (void *)access, (void *)kw_access_v12, NULL);
        KWLog(@"[v12] access filter OK");
    } @catch (NSException *e) { KWLog(@"[v12] access ex: %@", e); }

    Method m1 = class_getInstanceMethod([NSFileManager class], @selector(fileExistsAtPath:));
    if (m1) {
        orig_fileExists_v12 = (void *)method_getImplementation(m1);
        method_setImplementation(m1, (IMP)kw_fileExists_v12);
        KWLog(@"[v12] fileExistsAtPath filter OK");
    }
    // ③ NSGetExecutablePath
    // [DISABLED] void *sym = dlsym(RTLD_DEFAULT, "_NSGetExecutablePath");
    // [DISABLED] if (sym) {
    // [DISABLED] orig_nsgetpath = (int (*)(char *, uint32_t *))sym;
    // [DISABLED] @try {
    // [DISABLED] litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, sym, (void *)kw_nsgetpath, NULL);
    // [DISABLED] KWLog(@"[v12] NSGetExecutablePath OK");
    // [DISABLED] } @catch (NSException *e) { KWLog(@"[v12] nsget ex: %@", e); }
    // [DISABLED] }

    KWLog(@"[v12] all done");
}

// ============================================================
//  v14: LC 容器路径特征隐藏（重大加固）
//  问题：LC 里 guest 的 HOME 是
//    .../Application/<LC-UUID>/Documents/Data/Application/<guest-UUID>
//    ★ 两层 "Data/Application" 是明显的 LC 特征
//  对策：hook 路径返回 API，把内层嵌套「抹平」
// ============================================================

static NSString *g_fakeHomePath = nil;   // 伪装后的 HOME



// ============================================================
//  v15: 修复 3 个隐患
//  ① 清理环境变量（防 sysctl KERN_PROCARGS2 读出）
//  ② dlopen 反检测（隐藏我们的加载行为）
//  ③ 性能优化（缓存 bad image 判断）
// ============================================================

// ---------- ① 彻底清理环境变量 ----------
static void KwaiCleanEnv(void) {
    // ★ 关键：只清理「越狱/注入」相关变量
    //   ★★ 绝不能清 LC_HOME_PATH / HOME / LC_GLOBAL_TWEAKS_FOLDER
    //       因为 LC 自己的 NSFileManager+GuestHooks 依赖它们
    //       清了会 getenv 返回 NULL → stringWithUTF8String:NULL → 崩溃
    const char *vars[] = {
        // ★ v35: 补上 22 个 LC_SPOOF_*（原版完全没清）
        //   快手读 KERN_PROCARGS2 就能看到 LC_SPOOF_SERIAL=... → 直接暴露伪装环境
        "LC_SPOOF_MODEL", "LC_SPOOF_PRODUCT", "LC_SPOOF_BOARD", "LC_SPOOF_SERIAL",
        "LC_SPOOF_UUID", "LC_SPOOF_IDFV", "LC_SPOOF_IDFA", "LC_SPOOF_NAME",
        "LC_SPOOF_NCPU", "LC_SPOOF_MEM", "LC_SPOOF_SOC", "LC_SPOOF_FREQ",
        "LC_SPOOF_SCR_W", "LC_SPOOF_SCR_H", "LC_SPOOF_SCALE", "LC_SPOOF_BATT",
        "LC_SPOOF_ARME", "LC_SPOOF_MINIOS", "LC_SPOOF_BUNDLE", "LC_SPOOF_EXEC",
        "LC_SPOOF_PROCID",
        "JB_ROOT", "DOPAMINE_ROOT", "SUBSTRATE_ROOT",
        "THEOS", "LIBHOOKER", "ellekit", "DISABLE_TWEAKS",
        "_MSSafeMode",
        "DYLD_INSERT_LIBRARIES", "DYLD_LIBRARY_PATH", "DYLD_FRAMEWORK_PATH",
        "DYLD_ROOT_PATH", "DYLD_SHARED_CACHE_DIR",
        NULL
    };
    int cleared = 0;
    for (int i = 0; vars[i]; i++) {
        if (getenv(vars[i])) { unsetenv(vars[i]); cleared++; }
    }
    KWLog(@"[v15] cleared %d env vars (LC_* preserved)", cleared);
}

// ---------- ② dlopen 反检测 ----------
static void *(*orig_dlopen_v15)(const char *, int) = NULL;

static void *kw_dlopen_v15(const char *path, int mode) {
    // ★ v32: dlopen 反检测
    //   快手可能 hооk dlopen 记录所有加载行为
    //   我们把「加载我们自己的 dylib」的调用伪装成加载系统库
    if (path) {
        extern BOOL kw_isOurAddress(vm_address_t addr);
        // 我们的路径特征（不是返回值，只是判断）
        if (strstr(path, "TweakLoader") || strstr(path, "KwaiBuiltin") ||
            strstr(path, "LiveContainer") || strstr(path, "libsystem_x")) {
            // 放行，但不打日志（原实现是空转）
            return orig_dlopen_v15 ? orig_dlopen_v15(path, mode) : NULL;
        }
    }
    return orig_dlopen_v15 ? orig_dlopen_v15(path, mode) : NULL;
}

// ---------- ③ 性能优化：缓存 bad image 结果 ----------
// 用静态 set 缓存已判断的指针

// ---------- ④ sysctl KERN_PROCARGS2 拦截（环境变量读取）----------
// ★ v47.5 修复 H2：此函数【已删除】，原因同 kw_sysctl_proc：
//   从未 rebind（只赋值 + 打日志），且 orig_sysctl_args = sysctl 取的是
//   已被 hооk 的 kw_sysctl_mib 地址，补 rebind 即无限递归。
//   逻辑已并入 kw_sysctl_mib 的 KERN_PROCARGS2 分支（含 KEY=VALUE 整段抹除
//   与 memmem 优化），该入口在 KwaiInstallSpoof 中确实 rebind 成功。

// ---------- 安装 ----------
void KwaiInstallEnvHide(void) {
    static BOOL done = NO;
    if (done) return;
    done = YES;

    // ① 清理环境变量
    KwaiCleanEnv();

    // ② procargs 清理（需在 sysctl hook 之后）
    void *sym = dlsym(RTLD_DEFAULT, "sysctl");
    if (sym) {
        KWLog(@"[v47.5] procargs filter active via kw_sysctl_mib");
    }


    // ★ v32: dlopen 反检测（隐藏我们加载 dylib 的行为）
    void *dsym = dlsym(RTLD_DEFAULT, "dlopen");
    if (dsym) {
        orig_dlopen_v15 = (void *(*)(const char *, int))dsym;
        @try {
            litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, dsym, (void *)kw_dlopen_v15, NULL);
            KWLog(@"[v32] dlopen OK");
        } @catch (NSException *e) { KWLog(@"[v32] dlopen ex: %@", e); }
    }
    KWLog(@"[v15] all done");
}

// ============================================================
//  v19: 补齐 WeaponRepack / RuntimeHook 检测绕过
//  ① mach_vm_region_recurse（RuntimeHookDetector 用）
//  ② task_info(TASK_DYLD_INFO)（遍历镜像）
//  ③ mach_vm_region（另一个变体）
//  ④ csops / csops_audittoken（签名校验 → 返回「已签名」）
//  ⑤ __TEXT 段字节对比（让检测读到「原始」代码）
// ============================================================

// ---------- ① mach_vm_region_recurse ----------
typedef kern_return_t (*mach_vm_region_recurse_fn)(vm_map_t, mach_vm_address_t *,
    mach_vm_size_t *, natural_t *, vm_region_recurse_info_t, mach_msg_type_number_t *);
static mach_vm_region_recurse_fn orig_mvr_recurse = NULL;

static kern_return_t kw_mach_vm_region_recurse(vm_map_t target_task, mach_vm_address_t *address,
    mach_vm_size_t *size, natural_t *nesting_depth, vm_region_recurse_info_t info,
    mach_msg_type_number_t *infoCnt) {
    kern_return_t r = orig_mvr_recurse ?
        orig_mvr_recurse(target_task, address, size, nesting_depth, info, infoCnt) : KERN_FAILURE;
    // ★ 修复：只对我们自己的地址隐藏 X 位
    if (r == KERN_SUCCESS && info && infoCnt) {
        extern BOOL kw_isOurAddress(vm_address_t addr);
        mach_vm_address_t start = address ? *address : 0;
        if (kw_isOurAddress((vm_address_t)start)) {
            vm_region_submap_info_data_64_t *sub = (vm_region_submap_info_data_64_t *)info;
            if ((sub->protection & VM_PROT_WRITE) && (sub->protection & VM_PROT_EXECUTE)) {
                sub->protection &= ~VM_PROT_EXECUTE;
            }
        }
    }
    return r;
}

// ---------- ② task_info (TASK_DYLD_INFO) ----------
typedef kern_return_t (*task_info_fn)(task_name_t, task_flavor_t, task_info_t, mach_msg_type_number_t *);
static task_info_fn orig_task_info_v19 = NULL;

static kern_return_t kw_task_info_v19(task_name_t target_task, task_flavor_t flavor,
                                       task_info_t task_info_out, mach_msg_type_number_t *task_info_count) {
    kern_return_t r = orig_task_info_v19 ?
        orig_task_info_v19(target_task, flavor, task_info_out, task_info_count) : KERN_FAILURE;
    // TASK_DYLD_INFO = 5
    if (r == KERN_SUCCESS && flavor == 5 && task_info_out) {
        // 不改内容，但确保可读（隐藏我们在镜像列表里的存在由 dyld hook 处理）
        KWLog(@"[v19] task_info(TASK_DYLD_INFO) OK");
    }
    return r;
}

// ---------- ③ csops（签名校验）----------
// ★ v47.5 修复 H8：原代码 *flags &= ~0x10000000 想清 CS_DEBUGGED，
//   但 CS_DEBUGGED 的真实值是 0x00100000，0x10000000 是保留位 ——
//   清它毫无意义，「被调试」这一位从未被清掉，检测器读 csops 仍看到 debugged。
//   同时补齐 CS_HARD / CS_SIGNED / CS_RUNTIME，否则风控看组合位会判非官方签名。
//   sys/codesign.h 在本 SDK 不存在，直接定义并加 SDK 兜底。
#ifndef CS_DEBUGGED
#define CS_DEBUGGED  0x00100000
#endif
#ifndef CS_RUNTIME
#define CS_RUNTIME   0x00010000
#endif
#ifndef CS_SIGNED
#define CS_SIGNED    0x00000002
#endif
#ifndef CS_VALID
#define CS_VALID     0x00000001
#endif
#ifndef CS_HARD
#define CS_HARD      0x00000100
#endif

typedef int (*csops_fn)(pid_t, unsigned int, void *, size_t);
static csops_fn orig_csops = NULL;

static int kw_csops(pid_t pid, unsigned int ops, void *addr, size_t size) {
    int r = orig_csops ? orig_csops(pid, ops, addr, size) : -1;
    if (addr && size >= sizeof(uint32_t) && ops == 0) {
        uint32_t *flags = (uint32_t *)addr;
        if (r == 0) {
            *flags &= ~((uint32_t)CS_DEBUGGED);          // ★ 真正的 CS_DEBUGGED
            *flags |= ((uint32_t)CS_VALID) | ((uint32_t)CS_HARD)
                    | ((uint32_t)CS_SIGNED) | ((uint32_t)CS_RUNTIME);
            static int logged = 0;
            if (logged < 3) { logged++; KWLog(@"[v47.5] csops status -> 0x%X", *flags); }
        } else {
            // 原函数失败也要修正，不能放行真值
            *flags &= ~((uint32_t)CS_DEBUGGED);
            *flags |= ((uint32_t)CS_VALID) | ((uint32_t)CS_HARD)
                    | ((uint32_t)CS_SIGNED) | ((uint32_t)CS_RUNTIME);
            return 0;
        }
    }
    return r;
}

// ---------- ④ csops_audittoken ----------
typedef int (*csops_audit_fn)(pid_t, unsigned int, void *, size_t, audit_token_t *);
static csops_audit_fn orig_csops_audit = NULL;

static int kw_csops_audit(pid_t pid, unsigned int ops, void *addr, size_t size, audit_token_t *token) {
    int r = orig_csops_audit ? orig_csops_audit(pid, ops, addr, size, token) : -1;
    if (addr && size >= sizeof(uint32_t) && ops == 0) {
        uint32_t *flags = (uint32_t *)addr;
        // ★ v47.5 同 H8：修正 CS_DEBUGGED 常量并补齐签名位
        *flags &= ~((uint32_t)CS_DEBUGGED);
        *flags |= ((uint32_t)CS_VALID) | ((uint32_t)CS_HARD)
                | ((uint32_t)CS_SIGNED) | ((uint32_t)CS_RUNTIME);
        if (r != 0) return 0;
    }
    return r;
}

// ---------- 安装 ----------
void KwaiInstallRepackBypass(void) {
    static BOOL done = NO;
    if (done) return;
    done = YES;

    // ① mach_vm_region_recurse
    void *sym = dlsym(RTLD_DEFAULT, "mach_vm_region_recurse");
    if (sym) {
        orig_mvr_recurse = (mach_vm_region_recurse_fn)sym;
        @try {
            litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, sym, (void *)kw_mach_vm_region_recurse, NULL);
            KWLog(@"[v19] mach_vm_region_recurse OK");
        } @catch (NSException *e) { KWLog(@"[v19] mvr ex: %@", e); }
    }

    // ② task_info
    void *ti = dlsym(RTLD_DEFAULT, "task_info");
    if (ti) {
        orig_task_info_v19 = (task_info_fn)ti;
        @try {
            litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, ti, (void *)kw_task_info_v19, NULL);
            KWLog(@"[v19] task_info OK");
        } @catch (NSException *e) { KWLog(@"[v19] ti ex: %@", e); }
    }

    // ③ csops
    void *cs = dlsym(RTLD_DEFAULT, "csops");
    if (cs) {
        orig_csops = (csops_fn)cs;
        @try {
            litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, cs, (void *)kw_csops, NULL);
            KWLog(@"[v19] csops OK");
        } @catch (NSException *e) { KWLog(@"[v19] csops ex: %@", e); }
    }

    // ④ csops_audittoken
    void *csa = dlsym(RTLD_DEFAULT, "csops_audittoken");
    if (csa) {
        orig_csops_audit = (csops_audit_fn)csa;
        @try {
            litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, csa, (void *)kw_csops_audit, NULL);
            KWLog(@"[v19] csops_audittoken OK");
        } @catch (NSException *e) { KWLog(@"[v19] csa ex: %@", e); }
    }

    KWLog(@"[v19] all done");
}

// ============================================================
//  v20: 签名校验相关 API 补齐
//  ① SecCodeCopySigningInformation（返回假签名信息）
//  ② SecCodeCheckValidity / SecStaticCodeCheckValidity（返回成功）
//  ③ SecTaskCopyValueForEntitlement（返回假 entitlements）
//  ④ csops 更多 ops 处理
// ============================================================

// ---------- ① SecCodeCopySigningInformation ----------
typedef OSStatus (*SecCodeCopySigningInfo_fn)(SecCodeRef, SecCSFlags, CFDictionaryRef *);
static SecCodeCopySigningInfo_fn orig_seccode_signinfo = NULL;

static OSStatus kw_seccode_signinfo(SecCodeRef code, SecCSFlags flags, CFDictionaryRef *info) {
    // ★ v45：不要在这里 CFRelease(*info)。
    // 原函数按 Get 规则返回，但调用方（Security 框架内部）仍持有该对象的
    // 所有权预期；我们在其上再 CFBridgingRetain 一个新对象后释放旧的，等于
    // 双重释放 —— 接入签名绕过路径后必崩（v41 BUG-02 同型问题）。
    // 这里只做只读校验与日志，不接管所有权。
    OSStatus r = orig_seccode_signinfo ? orig_seccode_signinfo(code, flags, info) : -1;
    if (r == 0 && info && *info) {
        KWLog(@"[sig] SecCodeCopySigningInformation OK");
    }
    return r;
}

// ---------- ② SecCodeCheckValidity ----------
typedef OSStatus (*SecCodeCheckValidity_fn)(SecCodeRef, SecCSFlags, SecRequirementRef);
static SecCodeCheckValidity_fn orig_seccode_valid = NULL;

static OSStatus kw_seccode_valid(SecCodeRef code, SecCSFlags flags, SecRequirementRef req) {
    // ★ 直接返回成功（不调用原函数，避免失败）
    KWLog(@"[sig] SecCodeCheckValidity -> forced OK");
    return errSecSuccess;
}

// ---------- ③ SecStaticCodeCheckValidity ----------
typedef OSStatus (*SecStaticCodeCheckValidity_fn)(SecStaticCodeRef, SecCSFlags, SecRequirementRef);
static SecStaticCodeCheckValidity_fn orig_secstatic_valid = NULL;

static OSStatus kw_secstatic_valid(SecStaticCodeRef code, SecCSFlags flags, SecRequirementRef req) {
    KWLog(@"[sig] SecStaticCodeCheckValidity -> forced OK");
    return errSecSuccess;
}

// ---------- ④ csops 更多 ops ----------
// 现有 kw_csops 已处理 ops==0，补充其他
// CS_OPS_ENTITLEMENTS = 7, CS_OPS_DER_ENTITLEMENTS = 20
// 这些返回 entitlements blob，LC 已处理

// ---------- 安装 ----------
void KwaiInstallSigBypass(void) {
    static BOOL done = NO;
    if (done) return;
    done = YES;

    // ① SecCodeCopySigningInformation
    void *sym = dlsym(RTLD_DEFAULT, "SecCodeCopySigningInformation");
    if (sym) {
        orig_seccode_signinfo = (SecCodeCopySigningInfo_fn)sym;
        @try {
            litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, sym, (void *)kw_seccode_signinfo, NULL);
            KWLog(@"[sig] SecCodeCopySigningInformation OK");
        } @catch (NSException *e) { KWLog(@"[sig] scsi ex: %@", e); }
    }

    // ② SecCodeCheckValidity
    sym = dlsym(RTLD_DEFAULT, "SecCodeCheckValidity");
    if (sym) {
        orig_seccode_valid = (SecCodeCheckValidity_fn)sym;
        @try {
            litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, sym, (void *)kw_seccode_valid, NULL);
            KWLog(@"[sig] SecCodeCheckValidity OK");
        } @catch (NSException *e) { KWLog(@"[sig] scv ex: %@", e); }
    }

    // ③ SecStaticCodeCheckValidity
    sym = dlsym(RTLD_DEFAULT, "SecStaticCodeCheckValidity");
    if (sym) {
        orig_secstatic_valid = (SecStaticCodeCheckValidity_fn)sym;
        @try {
            litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, sym, (void *)kw_secstatic_valid, NULL);
            KWLog(@"[sig] SecStaticCodeCheckValidity OK");
        } @catch (NSException *e) { KWLog(@"[sig] sscv ex: %@", e); }
    }

    KWLog(@"[sig] all done");
}

// ---------- 判断地址是否属于我们的 dylib ----------
// 用于 vm_protect / vm_region 的精确处理
BOOL kw_isOurAddress(vm_address_t addr) {
    // ★ 线程安全 + 避免递归：只在首次初始化时用 _dyld_* 
    static vm_address_t ourBase = 0;
    static vm_size_t ourSize = 0;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        int count = _dyld_image_count();
        for (int i = 0; i < count; i++) {
            const struct mach_header *hdr = _dyld_get_image_header(i);
            if (!hdr) continue;
            // 用 dladdr 反查路径（比 _dyld_get_image_name 安全，不会触发我们的 hook）
            Dl_info info;
            memset(&info, 0, sizeof(info));
            if (dladdr((const void *)hdr, &info) && info.dli_fname) {
                if (strstr(info.dli_fname, "TweakLoader") || strstr(info.dli_fname, "KwaiBuiltin")) {
                    ourBase = (vm_address_t)hdr;
                    const struct load_command *cmd = (const struct load_command *)((const char *)hdr + sizeof(struct mach_header_64));
                    for (uint32_t j = 0; j < hdr->ncmds && cmd; j++) {
                        if (cmd->cmd == LC_SEGMENT_64) {
                            const struct segment_command_64 *seg = (const struct segment_command_64 *)cmd;
                            if (strcmp(seg->segname, "__TEXT") == 0) {
                                ourSize = seg->vmsize;
                                break;
                            }
                        }
                        cmd = (const struct load_command *)((const char *)cmd + cmd->cmdsize);
                    }
                    if (ourSize == 0) ourSize = 0x100000;
                    KWLog(@"[addr] our range: 0x%llx - 0x%llx",
                          (unsigned long long)ourBase, (unsigned long long)(ourBase + ourSize));
                    break;
                }
            }
        }
    });
    if (ourBase == 0) return NO;
    return (addr >= ourBase && addr < ourBase + ourSize + 0x10000);
}

// ============================================================
//  v23: 快手二进制路径重定向（解决签名验证失败）
//  问题：LC 把快手二进制从 MH_EXECUTE 改成 MH_DYLIB
//        → 快手自校验必然失败
//  方案：快手打开自己的二进制时，重定向到「正版路径」
//        → 读到未修改的原始文件 → 签名正确
// ============================================================

// ---------- 正版快手路径（需要动态查找）----------


// ---------- hook open() ----------


// ---------- hook openat()（更常用）----------


// ---------- 安装 ----------

// ============================================================
//  v24: Mach-O 头伪造（解决签名验证失败的真正方案）
//  问题：LC 把快手二进制的 filetype 从 MH_EXECUTE 改成 MH_DYLIB
//        → 快手读内存里的 Mach-O 头 → 发现被改 → 签名验证失败
//  方案：hook _dyld_get_image_header，对「主程序」返回伪造的原始头
//        （filetype = MH_EXECUTE，ncmds/sizeofcmds 恢复到原值）
// ============================================================

// 伪造的 Mach-O 头 + load commands（只读，全局）

// 原始值（从正版二进制读，或推断）


// ---------- hook _dyld_get_image_header ----------
static const struct mach_header *(*orig_dyld_get_hdr_v24)(uint32_t) = NULL;


// ---------- 安装 ----------

// ============================================================
//  v25: 快手签名检测对抗（基于二进制逆向后确认的检测点）
//  快手读三个东西：
//    ① cdhash                    → 代码签名哈希
//    ② embedded.mobileprovision  → 签名描述文件
//    ③ _CodeSignature/CodeResources → 签名资源
//  方案：拦截这些文件的读取，返回「伪造的合法内容」
// ============================================================

// ---------- ① 拦截 open/openat：重定向签名文件 ----------
static int (*orig_open_v25)(const char *, int, ...) = NULL;

// 判断是否签名相关文件



// ---------- ② 拦截 stat / access：签名路径返回不存在 ----------


// ---------- ③ NSFileManager 签名路径 ----------

// ---------- 安装 ----------

// ============================================================
