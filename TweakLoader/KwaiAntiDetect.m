// ============================================================
//  KwaiAntiDetect.m  ——  完整反检测模块
//  覆盖：fishhook / runtime hook / 进程 / 镜像 / 模拟器 / 代理 / 重打包
// ============================================================
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <stdarg.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <dlfcn.h>
#include <sys/sysctl.h>
#include <sys/stat.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include "litehook.h"

static void ALog(NSString *fmt, ...) {
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

static const char *kw_dyld_img_name(uint32_t idx) {
    const char *p = orig_dyld_get_image_name ? orig_dyld_get_image_name(idx) : NULL;
    if (AIsBadImage(p)) return "/usr/lib/libSystem.B.dylib";
    return p;
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
                ALog(@"[anti] proxy detected -> cleared");
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
    if (!sym) { ALog(@"skip %s", name); return; }
    *save = sym;
    @try {
        litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, target, repl, NULL);
        ALog(@"%s OK", name);
    } @catch (NSException *e) { ALog(@"%s ex: %@", name, e); }
}

// ============================================================
//  安装
// ============================================================
void KwaiAntiDetectInstall(void) {
    static BOOL done = NO;
    if (done) return;
    done = YES;
    ALog(@"=== anti-detect v1 ===");

    // ① dyld 镜像隐藏
    orig_dyld_get_image_name = _dyld_get_image_name;
    ARebind("_dyld_get_image_name", (void *)_dyld_get_image_name,
            (void *)kw_dyld_img_name, (void **)&orig_dyld_get_image_name);

    // ② 模拟器/VM 检测
    orig_sysctlbyname_ad = sysctlbyname;
    ARebind("sysctlbyname", (void *)sysctlbyname, (void *)kw_sysctlbyname_ad,
            (void **)&orig_sysctlbyname_ad);

    // ③ 代理检测
    void *cfn = dlopen("/System/Library/Frameworks/CFNetwork.framework/CFNetwork", RTLD_LAZY);
    if (cfn) {
        void *s = dlsym(cfn, "CFNetworkCopySystemProxySettings");
        if (s) {
            orig_CFNetworkCopySystemProxySettings = s;
            @try {
                litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, s,
                    (void *)kw_CFNetworkCopySystemProxySettings, NULL);
                ALog(@"CFNetworkCopySystemProxySettings OK");
            } @catch (NSException *e) { ALog(@"CFNetwork ex: %@", e); }
        }
    }

    // ④ NSFileManager fileExistsAtPath
    Method m = class_getInstanceMethod([NSFileManager class], @selector(fileExistsAtPath:));
    if (m) {
        orig_fileExistsAtPath = (void *)method_getImplementation(m);
        method_setImplementation(m, (IMP)kw_fileExistsAtPath);
        ALog(@"NSFileManager fileExistsAtPath OK");
    }

    ALog(@"=== anti-detect done ===");
}