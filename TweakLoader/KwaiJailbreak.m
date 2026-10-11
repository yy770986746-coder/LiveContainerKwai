// ============================================================
//  KwaiJailbreak.m  ——  越狱检测绕过
//  策略：hook 文件访问 API，拦截越狱特征路径
// ============================================================
#import <Foundation/Foundation.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/stat.h>
#include <sys/mount.h>
#include <sys/param.h>
#include <dirent.h>
#include <dlfcn.h>
#include <errno.h>
#include "litehook.h"

static void JLog(NSString *fmt, ...) {
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
static int (*orig_stat)(const char *, struct stat *) = NULL;
static int (*orig_lstat)(const char *, struct stat *) = NULL;

static int kw_stat(const char *p, struct stat *buf) {
    if (JIsJailbreakPath(p)) { errno = ENOENT; return -1; }
    return orig_stat ? orig_stat(p, buf) : -1;
}
static int kw_lstat(const char *p, struct stat *buf) {
    if (JIsJailbreakPath(p)) { errno = ENOENT; return -1; }
    return orig_lstat ? orig_lstat(p, buf) : -1;
}

// ---------- ② access ----------
static int (*orig_access)(const char *, int) = NULL;
static int kw_access(const char *p, int mode) {
    if (JIsJailbreakPath(p)) { errno = ENOENT; return -1; }
    return orig_access ? orig_access(p, mode) : -1;
}

// ---------- ③ fopen ----------
static FILE *(*orig_fopen)(const char *, const char *) = NULL;
static FILE *kw_fopen(const char *p, const char *mode) {
    if (JIsJailbreakPath(p)) { errno = ENOENT; return NULL; }
    return orig_fopen ? orig_fopen(p, mode) : NULL;
}

// ---------- ④ opendir ----------
static DIR *(*orig_opendir)(const char *) = NULL;
static DIR *kw_opendir(const char *p) {
    if (JIsJailbreakPath(p)) { errno = ENOENT; return NULL; }
    return orig_opendir ? orig_opendir(p) : NULL;
}

// ---------- ⑤ statfs ----------
static int (*orig_statfs)(const char *, struct statfs *) = NULL;
static int kw_statfs(const char *p, struct statfs *buf) {
    if (JIsJailbreakPath(p)) { errno = ENOENT; return -1; }
    return orig_statfs ? orig_statfs(p, buf) : -1;
}

// ---------- 安装 ----------
static void JRebind(const char *name, void *target, void *repl, void **save) {
    void *sym = dlsym(RTLD_DEFAULT, name);
    if (!sym) { JLog(@"skip %s (not found)", name); return; }
    *save = sym;
    @try {
        litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, target, repl, NULL);
        JLog(@"%s OK", name);
    } @catch (NSException *e) { JLog(@"%s ex: %@", name, e); }
}

void KwaiJailbreakInstall(void) {
    static BOOL done = NO;
    if (done) return;
    done = YES;
    JLog(@"=== jailbreak bypass v1 ===");

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

    JLog(@"=== jailbreak bypass done ===");
}