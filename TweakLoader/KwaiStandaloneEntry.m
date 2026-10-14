// ============================================================
//  v48 独立入口：注入正版快手（完全不依赖 LiveContainer）
//
//  用法：
//    1) 把编译出的 dylib 放到  Foo.app/Frameworks/KwaiTweak.dylib
//    2) 给主二进制加一条
//         LC_LOAD_DYLIB -> @executable_path/Frameworks/KwaiTweak.dylib
//    3) 重新签名整个 App
//
//  与 LC 版 TweakLoader.m 的区别：
//    LC 版构造函数里会读 LC_GLOBAL_TWEAKS_FOLDER、NSUserDefaults.guestAppInfo、
//    lcMainBundle、isLiveProcess —— 这些在正版快手进程里不存在，
//    直接调用会 unrecognized selector 崩溃。本入口只做一件事：调 KwaiBuiltinInit。
// ============================================================

#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <unistd.h>

__attribute__((constructor))
static void KwaiStandaloneEntry(void) {
    extern void KwaiBuiltinInit(void);

    @autoreleasepool {
        NSLog(@"[KwaiTweak] standalone entry pid=%d bundle=%@",
              getpid(), [NSBundle mainBundle].bundleIdentifier);
        KwaiBuiltinInit();
        NSLog(@"[KwaiTweak] entry done");
    }
}
