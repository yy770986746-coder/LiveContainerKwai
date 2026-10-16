// ============================================================
//  KwaiFiveOnly.m — 纯提参版入口
//
//  由 KwaiBuiltin.m 剥离【全部授权代码】后得到：
//    编译单元 = KwaiFiveOnly.m（提参 + 改机 + 反检测 + 悬浮球）
//    不含：Cfg 配置、HTTP、KWDeliver/KQDeliver、KwaiOrderVC、
//          WXApi hook、canOpenURL/openURL hook、QQ 授权探针与拦截
//
//  用法：注入到快手（正版或改 ID 的多开版），随 App 启动。
// ============================================================

#import <Foundation/Foundation.h>
#include <unistd.h>

__attribute__((constructor))
static void KwaiFiveOnlyEntry(void) {
    extern void KwaiBuiltinInit(void);
    @autoreleasepool {
        NSLog(@"[KwaiFiveOnly] entry pid=%d bundle=%@",
              getpid(), [NSBundle mainBundle].bundleIdentifier);
        KwaiBuiltinInit();
        NSLog(@"[KwaiFiveOnly] entry done");
    }
}
