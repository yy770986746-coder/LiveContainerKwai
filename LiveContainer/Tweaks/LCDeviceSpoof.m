//
//  LCDeviceSpoof.m
//  LiveContainer
//
//  设备伪装模块 —— 集成到 LC 引导层
//  目标：guest 启动时，从运行时就返回假设备信息
//  与 tweak 方式不同：这里用 LC 自己的 litehook，无独立 dylib 痕迹
//

#include <dlfcn.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/sysctl.h>
#import "../../litehook/src/litehook.h"
@import Darwin;
@import Foundation;

// ---------- 全局伪装值 ----------
static char g_LCMachine[64]  = {0};   // iPhone14,7
static char g_LCProduct[64]  = {0};   // iPhone 14
static char g_LCBoard[64]    = {0};   // D27AP
static char g_LCSerial[32]   = {0};   // 序列号
static char g_LCUUID[64]     = {0};   // 硬件 UUID
static char g_LCIDFV[64]     = {0};   // IDFV
static int  g_LCNCPU         = 0;
static long long g_LCMemSize = 0;
static BOOL g_LCSpoofOn      = NO;

// ---------- 原始函数 ----------
static int (*orig_sysctlbyname_lc)(const char *, void *, size_t *, void *, size_t) = NULL;
static int (*orig_uname_lc)(void *) = NULL;
static int (*orig_sysctl_lc)(int *, u_int, void *, size_t *, void *, size_t) = NULL;

// ---------- ① sysctlbyname ----------
static int lc_sysctlbyname(const char *name, void *oldp, size_t *oldlenp,
                           void *newp, size_t newlen) {
    if (g_LCSpoofOn && name && oldp && oldlenp) {
        if (strcmp(name, "hw.machine") == 0 || strcmp(name, "hw.model") == 0 ||
            strcmp(name, "hw.product") == 0) {
            const char *v = g_LCMachine;
            if (strcmp(name, "hw.product") == 0 && g_LCProduct[0]) v = g_LCProduct;
            size_t n = strlen(v) + 1;
            if (*oldlenp >= n) { memcpy(oldp, v, n); *oldlenp = n; return 0; }
        }
        if (strcmp(name, "hw.target") == 0 && g_LCBoard[0]) {
            size_t n = strlen(g_LCBoard) + 1;
            if (*oldlenp >= n) { memcpy(oldp, g_LCBoard, n); *oldlenp = n; return 0; }
        }
        if ((strcmp(name, "hw.ncpu") == 0 || strcmp(name, "hw.logicalcpu") == 0) && g_LCNCPU > 0) {
            if (*oldlenp >= sizeof(int)) { *(int *)oldp = g_LCNCPU; *oldlenp = sizeof(int); return 0; }
        }
        if (strcmp(name, "hw.physicalcpu") == 0 && g_LCNCPU > 0) {
            if (*oldlenp >= sizeof(int)) { *(int *)oldp = g_LCNCPU / 2; *oldlenp = sizeof(int); return 0; }
        }
        if (strcmp(name, "hw.memsize") == 0 && g_LCMemSize > 0) {
            if (*oldlenp >= sizeof(long long)) { *(long long *)oldp = g_LCMemSize; *oldlenp = sizeof(long long); return 0; }
        }
    }
    return orig_sysctlbyname_lc ? orig_sysctlbyname_lc(name, oldp, oldlenp, newp, newlen) : -1;
}

// ---------- ② uname ----------
struct lc_utsname {
    char sysname[256]; char nodename[256]; char release[256];
    char version[256]; char machine[256];
};

static int lc_uname(struct lc_utsname *buf) {
    int r = orig_uname_lc ? orig_uname_lc(buf) : -1;
    if (r == 0 && buf && g_LCSpoofOn && g_LCMachine[0]) {
        strncpy(buf->machine, g_LCMachine, sizeof(buf->machine) - 1);
        buf->machine[sizeof(buf->machine) - 1] = 0;
    }
    return r;
}

// ---------- ③ sysctl MIB ----------
#define LC_CTL_HW 6
#define LC_HW_MACHINE 1
#define LC_HW_MODEL 2
#define LC_HW_NCPU 3
#define LC_HW_MEMSIZE 24

static int lc_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp,
                     void *newp, size_t newlen) {
    if (g_LCSpoofOn && name && namelen >= 2 && oldp && oldlenp && name[0] == LC_CTL_HW) {
        if ((name[1] == LC_HW_MACHINE || name[1] == LC_HW_MODEL) && g_LCMachine[0]) {
            size_t n = strlen(g_LCMachine) + 1;
            if (*oldlenp >= n) { memcpy(oldp, g_LCMachine, n); *oldlenp = n; return 0; }
        }
        if (name[1] == LC_HW_NCPU && g_LCNCPU > 0) {
            if (*oldlenp >= sizeof(int)) { *(int *)oldp = g_LCNCPU; *oldlenp = sizeof(int); return 0; }
        }
        if (name[1] == LC_HW_MEMSIZE && g_LCMemSize > 0) {
            if (*oldlenp >= sizeof(long long)) { *(long long *)oldp = g_LCMemSize; *oldlenp = sizeof(long long); return 0; }
        }
    }
    return orig_sysctl_lc ? orig_sysctl_lc(name, namelen, oldp, oldlenp, newp, newlen) : -1;
}

// ---------- 安装 ----------
void LCDSInstall(const char *machine, const char *product, const char *board,
                 const char *serial, const char *uuid, const char *idfv,
                 int ncpu, long long memSize) {
    if (!machine || !machine[0]) return;

    strncpy(g_LCMachine, machine, sizeof(g_LCMachine) - 1);
    if (product) strncpy(g_LCProduct, product, sizeof(g_LCProduct) - 1);
    if (board)   strncpy(g_LCBoard,   board,   sizeof(g_LCBoard) - 1);
    if (serial)  strncpy(g_LCSerial,  serial,  sizeof(g_LCSerial) - 1);
    if (uuid)    strncpy(g_LCUUID,    uuid,    sizeof(g_LCUUID) - 1);
    if (idfv)    strncpy(g_LCIDFV,    idfv,    sizeof(g_LCIDFV) - 1);
    g_LCNCPU = ncpu;
    g_LCMemSize = memSize;
    g_LCSpoofOn = YES;

    // 保存原函数
    orig_sysctlbyname_lc = sysctlbyname;
    orig_uname_lc = (void *)uname;
    orig_sysctl_lc = sysctl;

    // rebind
    litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, (void *)sysctlbyname, (void *)lc_sysctlbyname, nil);
    litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, (void *)uname,        (void *)lc_uname,        nil);
    litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, (void *)sysctl,       (void *)lc_sysctl,       nil);

    NSLog(@"[LCDS] installed: %s product=%s board=%s ncpu=%d", machine, product, board, ncpu);
}