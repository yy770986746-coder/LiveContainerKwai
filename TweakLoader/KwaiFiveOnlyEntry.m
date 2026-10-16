// ============================================================
//  KwaiFiveOnly.m — 授权剥离版入口
//
//  由 KwaiBuiltin.m 剥离【全部授权代码】后得到：
//    编译单元 = KwaiFiveOnly.m（提参 + 改机 + 反检测 + 悬浮球）
//    不含：Cfg 配置、HTTP、KWDeliver/KQDeliver、KwaiOrderVC、
//          WXApi hook、canOpenURL/openURL hook、QQ 授权探针与拦截
//
//  ★ v48d 关键：本入口在 dyld 阶段执行，那时 UIApplication 的
//    connectedScenes 还是空的，若此时创建 UIWindow 会拿不到 windowScene
//    → 窗口永远不显示（表现为"插件没生效"）。
//    所以这里等 App 完成启动后再调一次 KwaiBuiltinInit 的 UI 部分。
// ============================================================

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <unistd.h>

__attribute__((constructor))
static void KwaiFiveOnlyEntry(void) {
    extern void KwaiBuiltinInit(void);
    @autoreleasepool {
        NSLog(@"[KwaiFiveOnly] entry pid=%d bundle=%@",
              getpid(), [NSBundle mainBundle].bundleIdentifier);
        KwaiBuiltinInit();
        NSLog(@"[KwaiFiveOnly] entry done");

        // ★ 关键：等 App 真正启动（scene 就绪）后再拉一次悬浮球逻辑。
        //   KwaiBuiltinInit 内部有 doneInit 守卫，重复调用是安全的。
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
                addObserverForName:UIApplicationDidBecomeActiveNotification
                            object:nil
                             queue:[NSOperationQueue mainQueue]
                        usingBlock:^(NSNotification *note) {
                NSLog(@"[KwaiFiveOnly] app became active -> retry ball");
                extern void KwaiStartBallWatcher(void);
                // 重新触发悬浮球（内部有 g_ballShown 守卫，不会重复建）
                KwaiStartBallWatcher();
            }];
        });

        // 兜底：即使没收到通知，也延迟 5 秒再试一次
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            extern void KwaiStartBallWatcher(void);
            KwaiStartBallWatcher();
        });
    }
}
