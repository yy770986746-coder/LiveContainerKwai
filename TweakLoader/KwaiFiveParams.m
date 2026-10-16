// ============================================================
//  KwaiFiveParams — 独立提参 dylib
//
//  从 KwaiSpoof_授权+提参.dylib 中抽出的【纯提参】功能：
//    改机、微信/QQ 授权、越狱隐藏、反检测 —— 全部不含
//
//  数据来源（三层，互为补充）：
//    ① MMKV   —— com.kuaishou.KSwitchSDK.DEFAULT / com.kuaishou.account
//                 / com.jiangjia.gif / com.kuaishou.KSwitchSDK
//    ② KSURLCache —— Library/Caches/com.jiangjia.gif/KSURLCache 下的
//                    *-wal 与 Cache.db*，用 ISOLatin1 读成文本后扫 key=value
//    ③ plist  —— Library/Preferences/com.jiangjia.gif.plist
//                 （Gif_Token / Gif_Token_Salt / ... ）
//    另含 Keychain 通用密码项枚举与 NSKeyedUnarchive
//
//  输出格式：token----salt----did----egid----api_st
//
//  与宿主 App 的耦合：仅依赖 Foundation/Security/UIKit，
//  不含 litehook、不含任何 LC 依赖 → 可注入任意 App
// ============================================================

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Security/Security.h>
#include <sys/time.h>

// ============================================================
//  日志（自带，不依赖 KwaiBuiltin 的 KWLog）
// ============================================================
static NSFileHandle *g_fpLog = nil;
static NSString     *g_fpLogPath = nil;
static os_unfair_lock g_fpLogLock = OS_UNFAIR_LOCK_INIT;
static int g_fpLogCount = 0;
static NSTimeInterval g_fpLogTs = 0;

static void FPLog(NSString *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    NSString *m = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);

    NSFileHandle *fh = nil;
    NSString *path = nil;
    BOOL over = NO;

    os_unfair_lock_lock(&g_fpLogLock);
    path = g_fpLogPath;
    if (!path) {
        NSString *doc = [NSSearchPathForDirectoriesInDomains(
            NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        if (!doc) doc = NSTemporaryDirectory();
        path = [doc stringByAppendingPathComponent:@"kwai_five.log"];
        g_fpLogPath = path;
    }
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now - g_fpLogTs >= 1.0) { g_fpLogTs = now; g_fpLogCount = 0; }
    g_fpLogCount++;
    over = (g_fpLogCount > 40);
    fh = over ? nil : g_fpLog;
    os_unfair_lock_unlock(&g_fpLogLock);

    if (over || !path.length) return;

    if (!fh) {
        @try {
            if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
                [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
            }
            fh = [NSFileHandle fileHandleForWritingAtPath:path];
        } @catch (NSException *e) { fh = nil; }
        os_unfair_lock_lock(&g_fpLogLock);
        g_fpLog = fh;
        os_unfair_lock_unlock(&g_fpLogLock);
        if (!fh) return;
    }
    @try {
        [fh seekToEndOfFile];
        NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], m];
        [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
    } @catch (NSException *e) {
        os_unfair_lock_lock(&g_fpLogLock);
        if (fh == g_fpLog) g_fpLog = nil;
        os_unfair_lock_unlock(&g_fpLogLock);
    }
    NSLog(@"[KwaiFiveParams] %@", m);
}

// ============================================================
//  提参核心
// ============================================================
static NSMutableDictionary *g_fiveParams = nil;

static void KwaiInitFiveParams(void) {
    if (!g_fiveParams) g_fiveParams = [NSMutableDictionary dictionary];
}

// 扫 "key=value"，value 截止到 & 或引号或换行
static void KwaiScanParam(NSString *text, NSString *key) {
    if (!text || !key) return;
    NSString *needle = [key stringByAppendingString:@"="];
    NSRange r = [text rangeOfString:needle];
    if (r.location == NSNotFound) return;
    NSUInteger s = r.location + r.length;
    if (s >= text.length) return;

    NSUInteger e = s;
    NSCharacterSet *stop = [NSCharacterSet characterSetWithCharactersInString:@"&\"'\n\r\\ "];
    while (e < text.length) {
        unichar c = [text characterAtIndex:e];
        if ([stop characterIsMember:c]) break;
        e++;
    }
    if (e <= s) return;
    NSString *val = [text substringWithRange:NSMakeRange(s, e - s)];
    if (val.length < 2) return;
    // 去掉常见后缀噪声
    NSRange semi = [val rangeOfString:@";"];
    if (semi.location != NSNotFound) val = [val substringToIndex:semi.location];
    if (!val.length) return;

    @synchronized(g_fiveParams) {
        NSString *old = g_fiveParams[key];
        // 保留更长的值（通常是完整的）
        if (!old || val.length > old.length) {
            g_fiveParams[key] = val;
            FPLog(@"[5p] %@ = %@", key, val.length > 80 ? [val substringToIndex:80] : val);
        }
    }
}

static void KwaiScanText(NSString *text) {
    if (!text.length) return;
    KwaiInitFiveParams();
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

// 读 KSURLCache
static void KwaiReadFromCache(void) {
    @try {
        NSString *home = NSHomeDirectory();
        NSString *cacheDir = [home stringByAppendingPathComponent:
                              @"Library/Caches/com.jiangjia.gif/KSURLCache"];
        NSFileManager *fm = [NSFileManager defaultManager];
        NSArray *items = [fm contentsOfDirectoryAtPath:cacheDir error:nil];
        if (!items) {
            // 退路：部分版本在 Library/Caches/ 下另有目录
            cacheDir = [home stringByAppendingPathComponent:@"Library/Caches"];
            items = [fm contentsOfDirectoryAtPath:cacheDir error:nil];
        }
        if (!items) { FPLog(@"[5p] KSURLCache not found"); return; }

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
            FPLog(@"[5p] scanned %@ (%lu bytes)", n, (unsigned long)d.length);
        }
    } @catch (NSException *e) { FPLog(@"[5p] cache read ex: %@", e); }
}

// Keychain 解档
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
    OSStatus st = SecItemCopyMatching((__bridge CFDictionaryRef)q, &d);
    if (st != errSecSuccess || !d) return nil;
    NSData *data = (__bridge_transfer NSData *)d;
    return KwaiUnarchive(data);
}

// MMKV 枚举（快手把不少东西放这里）
static void KwaiDumpMMKV(void) {
    @try {
        FPLog(@"[kv] === enumerate MMKV ===");
        Class mmkvCls = NSClassFromString(@"MMKV");
        if (!mmkvCls) { FPLog(@"[kv] MMKV not found"); return; }
        SEL wsel = NSSelectorFromString(@"mmkvWithID:");
        if (![mmkvCls respondsToSelector:wsel]) { FPLog(@"[kv] no mmkvWithID"); return; }

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
                FPLog(@"[kv] %@ has %lu keys", mid, (unsigned long)keys.count);
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
                        FPLog(@"[kv]   %@ = %@", k, (v.length > 120 ? [v substringToIndex:120] : v));
                        // 值本身也扫一遍，可能内含 token=xxx
                        if ([k rangeOfString:@"token" options:NSCaseInsensitiveSearch].location != NSNotFound
                            || [k rangeOfString:@"salt" options:NSCaseInsensitiveSearch].location != NSNotFound
                            || [k rangeOfString:@"did" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                            KwaiInitFiveParams();
                            @synchronized(g_fiveParams) {
                                NSString *lk = k.lowercaseString;
                                if ([lk containsString:@"token_client_salt"]) g_fiveParams[@"token_client_salt"] = v;
                                else if ([lk containsString:@"client_salt"])     g_fiveParams[@"client_salt"] = v;
                                else if ([lk containsString:@"salt"])            g_fiveParams[@"salt"] = v;
                                else if ([lk containsString:@"token"])           g_fiveParams[@"token"] = v;
                                if ([lk containsString:@"did"] || [lk containsString:@"deviceid"]) g_fiveParams[@"did"] = v;
                                if ([lk containsString:@"egid"]) g_fiveParams[@"egid"] = v;
                            }
                        }
                    }
                }
            } @catch (NSException *e) { FPLog(@"[kv] ex %@: %@", mid, e); }
        }
        FPLog(@"[kv] === done ===");
    } @catch (NSException *e) { FPLog(@"[kv] outer ex: %@", e); }
}

// 读 plist
static void KwaiDumpPlist(void) {
    @try {
        NSString *home = NSHomeDirectory();
        NSString *p = [home stringByAppendingPathComponent:
                       @"Library/Preferences/com.jiangjia.gif.plist"];
        NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:p];
        if (!d) { FPLog(@"[pl] load failed: %@", p); return; }
        FPLog(@"[pl] keys=%lu", (unsigned long)d.count);

        KwaiInitFiveParams();
        @synchronized(g_fiveParams) {
            id v;
            v = d[@"Gif_Token"];
            if ([v isKindOfClass:[NSString class]] && [v length]) g_fiveParams[@"token"] = v;
            v = d[@"Gif_Token_Salt"];
            if ([v isKindOfClass:[NSString class]] && [v length]) g_fiveParams[@"salt"] = v;
            v = d[@"Gif_KwaiClientSalt"];
            if ([v isKindOfClass:[NSString class]] && [v length]) g_fiveParams[@"client_salt"] = v;
            v = d[@"Gif_DeviceId"];
            if ([v isKindOfClass:[NSString class]] && [v length]) g_fiveParams[@"did"] = v;
            // 兜底：任何含 token/salt/did 的键都抓
            for (NSString *k in d) {
                id val = d[k];
                if (![val isKindOfClass:[NSString class]] || ![val length]) continue;
                NSString *lk = k.lowercaseString;
                if ([lk containsString:@"client_salt"] && !g_fiveParams[@"client_salt"]) g_fiveParams[@"client_salt"] = val;
                else if ([lk containsString:@"salt"] && !g_fiveParams[@"salt"]) g_fiveParams[@"salt"] = val;
                else if ([lk containsString:@"token"] && !g_fiveParams[@"token"]) g_fiveParams[@"token"] = val;
                else if (([lk containsString:@"did"] || [lk containsString:@"deviceid"]) && !g_fiveParams[@"did"]) g_fiveParams[@"did"] = val;
                else if ([lk containsString:@"egid"] && !g_fiveParams[@"egid"]) g_fiveParams[@"egid"] = val;
            }
        }
        FPLog(@"[pl] token=%@ salt=%@ did=%@ api_st=%lu",
              g_fiveParams[@"token"] ? @"Y" : @"N",
              g_fiveParams[@"salt"] ? @"Y" : @"N",
              g_fiveParams[@"did"] ? @"Y" : @"N",
              (unsigned long)[g_fiveParams[@"api_st"] length]);
    } @catch (NSException *e) { FPLog(@"[pl] ex: %@", e); }
}

// Keychain 常见账号
static void KwaiDumpKeychain(void) {
    NSArray *accts = @[@"Gif_Token", @"Gif_Token_Salt", @"Gif_ServiceToken",
                       @"token", @"api_st", @"device_id", @"did"];
    KwaiInitFiveParams();
    for (NSString *a in accts) {
        @try {
            NSString *v = KwaiKeychainGet(a);
            if (!v.length) continue;
            FPLog(@"[kc] %@ = %@", a, v.length > 80 ? [v substringToIndex:80] : v);
            @synchronized(g_fiveParams) {
                if ([a isEqualToString:@"Gif_Token"]) g_fiveParams[@"token"] = v;
                else if ([a isEqualToString:@"Gif_Token_Salt"]) g_fiveParams[@"salt"] = v;
                else if ([a isEqualToString:@"Gif_ServiceToken"] && !g_fiveParams[@"token"]) g_fiveParams[@"token"] = v;
                else if ([a isEqualToString:@"api_st"]) g_fiveParams[@"api_st"] = v;
                else if ([a isEqualToString:@"device_id"] || [a isEqualToString:@"did"]) {
                    if (!g_fiveParams[@"did"]) g_fiveParams[@"did"] = v;
                }
            }
        } @catch (NSException *e) {}
    }
}

// 对外接口
NSDictionary *KwaiGetFiveParams(void) {
    @synchronized(g_fiveParams) {
        if (!g_fiveParams) return @{};
        return [g_fiveParams copy];
    }
}

NSString *KwaiGetFiveString(void) {
    @synchronized(g_fiveParams) {
        if (!g_fiveParams) return @"";
        NSString *t = g_fiveParams[@"token"]  ?: @"";
        NSString *s = g_fiveParams[@"salt"]   ?: @"";
        NSString *d = g_fiveParams[@"did"]    ?: @"";
        NSString *e = g_fiveParams[@"egid"]   ?: @"";
        NSString *a = g_fiveParams[@"api_st"] ?: @"";
        if (!t.length && !s.length && !d.length && !e.length && !a.length) return @"";
        return [NSString stringWithFormat:@"%@----%@----%@----%@----%@", t, s, d, e, a];
    }
}

static void KwaiScanAll(void) {
    KwaiInitFiveParams();
    KwaiReadFromCache();
    FPLog(@"[5p] cache scan done, params=%lu", (unsigned long)g_fiveParams.count);
    KwaiDumpKeychain();
    KwaiDumpPlist();
    KwaiDumpMMKV();
    FPLog(@"[5p] === result ===\n%@", KwaiGetFiveString());
}

// ============================================================
//  悬浮球 UI
// ============================================================
@interface FPPanel : UIWindow
- (instancetype)initWithText:(NSString *)text;
@end

@interface FPBall : UIWindow
@end

@implementation FPPanel {
    NSString *_text;
    UITextView *_tv;
}
- (instancetype)initWithText:(NSString *)text {
    UIScreen *sc = [UIScreen mainScreen];
    CGFloat W = sc.bounds.size.width, H = sc.bounds.size.height;
    CGFloat pw = W - 32, ph = MIN(460, H - 120);
    self = [super initWithFrame:CGRectMake(16, (H - ph) / 2.0, pw, ph)];
    if (self) {
        _text = [text copy] ?: @"";
        self.windowLevel = UIWindowLevelAlert + 200;
        self.backgroundColor = [UIColor clearColor];
        self.rootViewController = [[UIViewController alloc] init];

        UIView *bg = [[UIView alloc] initWithFrame:self.bounds];
        bg.backgroundColor = [UIColor colorWithWhite:0.11 alpha:0.98];
        bg.layer.cornerRadius = 14;
        bg.layer.masksToBounds = YES;
        [self addSubview:bg];

        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, pw - 100, 26)];
        title.text = @"五参提取";
        title.textColor = [UIColor whiteColor];
        title.font = [UIFont boldSystemFontOfSize:17];
        [self addSubview:title];

        UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
        close.frame = CGRectMake(pw - 76, 10, 60, 30);
        [close setTitle:@"关闭" forState:UIControlStateNormal];
        [close setTitleColor:[UIColor colorWithRed:0.35 green:0.65 blue:1 alpha:1] forState:UIControlStateNormal];
        [close addTarget:self action:@selector(doClose) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:close];

        UIButton *copy = [UIButton buttonWithType:UIButtonTypeSystem];
        copy.frame = CGRectMake(16, ph - 46, 90, 34);
        [copy setTitle:@"复制" forState:UIControlStateNormal];
        [copy setTitleColor:[UIColor colorWithRed:0.35 green:0.65 blue:1 alpha:1] forState:UIControlStateNormal];
        [copy addTarget:self action:@selector(doCopy) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:copy];

        UIButton *re = [UIButton buttonWithType:UIButtonTypeSystem];
        re.frame = CGRectMake(114, ph - 46, 90, 34);
        [re setTitle:@"重新提取" forState:UIControlStateNormal];
        [re setTitleColor:[UIColor colorWithRed:0.35 green:0.65 blue:1 alpha:1] forState:UIControlStateNormal];
        [re addTarget:self action:@selector(doRefresh) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:re];

        _tv = [[UITextView alloc] initWithFrame:CGRectMake(12, 44, pw - 24, ph - 96)];
        _tv.backgroundColor = [UIColor colorWithWhite:0.06 alpha:1];
        _tv.textColor = [UIColor colorWithRed:0.55 green:0.95 blue:0.6 alpha:1];
        _tv.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
        _tv.editable = NO;
        _tv.layer.cornerRadius = 8;
        _tv.textContainerInset = UIEdgeInsetsMake(8, 8, 8, 8);
        _tv.text = _text;
        [self addSubview:_tv];
    }
    return self;
}
- (void)doClose {
    self.hidden = YES;
    self.windowScene = nil;
}
- (void)doCopy {
    UIPasteboard.generalPasteboard.string = _text;
    FPLog(@"[5p] copied %lu chars", (unsigned long)_text.length);
}
- (void)doRefresh {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        KwaiScanAll();
        NSString *s = KwaiGetFiveString();
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_tv.text = s.length ? s : @"(未提取到，请先登录/刷一次首页再点重新提取)";
            self->_text = s;
        });
    });
}
@end

@implementation FPBall {
    CGFloat _lx, _ly;
}
- (instancetype)init {
    CGFloat W = [UIScreen mainScreen].bounds.size.width;
    CGFloat H = [UIScreen mainScreen].bounds.size.height;
    CGFloat d = 46;
    self = [super initWithFrame:CGRectMake(W - d - 10, H * 0.55, d, d)];
    if (self) {
        self.windowLevel = UIWindowLevelAlert + 100;
        self.backgroundColor = [UIColor clearColor];
        self.rootViewController = [[UIViewController alloc] init];

        UIView *v = [[UIView alloc] initWithFrame:self.bounds];
        v.backgroundColor = [UIColor colorWithRed:0.15 green:0.45 blue:0.95 alpha:0.85];
        v.layer.cornerRadius = d / 2;
        v.layer.masksToBounds = YES;
        v.userInteractionEnabled = NO;
        [self addSubview:v];

        UILabel *l = [[UILabel alloc] initWithFrame:v.bounds];
        l.text = @"参";
        l.textAlignment = NSTextAlignmentCenter;
        l.textColor = [UIColor whiteColor];
        l.font = [UIFont boldSystemFontOfSize:18];
        [v addSubview:l];

        [self addGestureRecognizer:[[UITapGestureRecognizer alloc]
            initWithTarget:self action:@selector(onTap:)]];
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
            initWithTarget:self action:@selector(onPan:)];
        [self addGestureRecognizer:pan];
    }
    return self;
}
- (void)onTap:(UITapGestureRecognizer *)g {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        KwaiScanAll();
        NSString *s = KwaiGetFiveString();
        dispatch_async(dispatch_get_main_queue(), ^{
            static FPPanel *panel = nil;
            if (panel) { panel.hidden = YES; panel = nil; }
            panel = [[FPPanel alloc] initWithText:
                     s.length ? s : @"(未提取到，请先登录/刷新首页)"];
            panel.hidden = NO;
            FPLog(@"[5p] panel shown, five=%lu chars", (unsigned long)s.length);
        });
    });
}
- (void)onPan:(UIPanGestureRecognizer *)g {
    UIView *sv = self.superview ?: self;
    CGPoint p = [g translationInView:sv];
    CGRect f = self.frame;
    f.origin.x += p.x;
    f.origin.y += p.y;
    CGFloat W = sv.bounds.size.width, H = sv.bounds.size.height;
    f.origin.x = MAX(4, MIN(W - f.size.width - 4, f.origin.x));
    f.origin.y = MAX(60, MIN(H - f.size.height - 4, f.origin.y));
    self.frame = f;
    [g setTranslation:CGPointZero inView:sv];
}
@end

// ============================================================
//  入口
// ============================================================
__attribute__((constructor))
static void KwaiFiveParamsEntry(void) {
    @autoreleasepool {
        FPLog(@"[5p] entry pid=%d bundle=%@", getpid(), [NSBundle mainBundle].bundleIdentifier);

        // 首屏就绪后再扫描 + 显示悬浮球
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                KwaiScanAll();
                dispatch_async(dispatch_get_main_queue(), ^{
                    static FPBall *ball = nil;
                    if (!ball) ball = [[FPBall alloc] init];
                    FPLog(@"[5p] ball shown");
                });
            });
        });
    }
}
