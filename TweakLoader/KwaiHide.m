// ============================================================
//  KwaiHide.m  v5  ——  只保留「确定可用」的 hook
//  原则：只 rebind 那些在当前进程里能 dlsym 到的符号
//        取不到就跳过，绝不硬引用
// ============================================================
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <string.h>
#include <stdarg.h>
#include <stdlib.h>
#include <time.h>
#include <sys/time.h>
#include <sys/sysctl.h>
#include <mach/mach_time.h>
#include <mach-o/dyld.h>
#include <dlfcn.h>
#include "litehook.h"

// ---------- 独立日志（不依赖 KwaiBuiltin 的 static KWLog）----------
static void HKLog(NSString *fmt, ...) {
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
#define KWLog(...) HKLog(__VA_ARGS__)

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
    NSString *saved = HGet(@"boot_offset");
    if (saved.length) { g_bootOffset = saved.longLongValue; }
    else {
        long long days = arc4random_uniform(90) + 1;
        long long secs = days * 24LL * 3600LL + arc4random_uniform(86400);
        g_bootOffset = secs;
        HSet(@"boot_offset", [NSString stringWithFormat:@"%lld", g_bootOffset]);
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

static uint64_t kw_mat(void) {
    uint64_t real = orig_mat ? orig_mat() : 0;
    if (g_bootOffset <= 0) return real;
    static mach_timebase_info_data_t tb = {0,0};
    if (tb.denom == 0) mach_timebase_info(&tb);
    uint64_t delta = (uint64_t)((long double)g_bootOffset * 1e9L * tb.denom / tb.numer);
    return (real > delta) ? (real - delta) : real;
}

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

static BOOL kw_badImage(const char *p) {
    if (!p) return NO;
    static const char *bad[] = {
        "TweakLoader","KwaiSpoof","KwaiHide","CydiaSubstrate",
        "libhooker","Substrate","libsystem_x","frida", NULL };
    for (int i = 0; bad[i]; i++) if (strstr(p, bad[i])) return YES;
    return NO;
}

static const char *kw_dyld_name(uint32_t idx) {
    const char *p = orig_dyld_name ? orig_dyld_name(idx) : NULL;
    if (kw_badImage(p)) return "/usr/lib/libSystem.B.dylib";
    return p;
}

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
    kw_rebind("sysctlbyname", (void *)sysctlbyname, (void *)kw_sysctlbyname3,
              (void **)&orig_sysctlbyname3);

    // ② mach_absolute_time
    orig_mat = mach_absolute_time;
    kw_rebind("mach_absolute_time", (void *)mach_absolute_time, (void *)kw_mat,
              (void **)&orig_mat);

    // ③ getenv
    orig_getenv = getenv;
    kw_rebind("getenv", (void *)getenv, (void *)kw_getenv, (void **)&orig_getenv);

    // ④ dyld image name
    orig_dyld_name = _dyld_get_image_name;
    kw_rebind("_dyld_get_image_name", (void *)_dyld_get_image_name,
              (void *)kw_dyld_name, (void **)&orig_dyld_name);

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
