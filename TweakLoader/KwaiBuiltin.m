// KwaiWeChatLogin.m 鈥斺€?蹇墜寰俊鐧诲綍鍔╂墜 v1.0
// 鐢ㄩ€旓細LiveContainer 鍐呭揩鎵嬨€屽井淇＄櫥褰曘€嶈嚜鍔ㄦ巿鏉?// 杩愯鐜锛歀iveContainer TweakLoader锛堟棤闇€瓒婄嫳锛?#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString * const kDefApi   = @"http://211.154.19.45:9092";
static NSString * const kDefAppId = @"wxaadbab9d13edff20";
static NSString * const kDefGrade = @"1";

static void KWLog(NSString *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    NSString *m = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], m];
    NSString *doc = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *p = [doc stringByAppendingPathComponent:@"kwlogin.log"];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:p];
    if (!fh) { [[NSFileManager defaultManager] createFileAtPath:p contents:nil attributes:nil];
               fh = [NSFileHandle fileHandleForWritingAtPath:p]; }
    if (fh) { [fh seekToEndOfFile];
              [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]]; [fh closeFile]; }
    NSLog(@"[KwaiWeChatLogin] %@", m);
}

// ---------- 閰嶇疆 ----------
static NSString *CfgPath(void) {
    NSString *doc = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    return [doc stringByAppendingPathComponent:@"kwlogin.plist"];
}
static NSMutableDictionary *CfgLoad(void) {
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:CfgPath()];
    return d ? [d mutableCopy] : [NSMutableDictionary dictionary];
}
static void CfgSave(NSDictionary *d) { [d writeToFile:CfgPath() atomically:YES]; }
static NSString *CfgGet(NSString *k, NSString *def) {
    id v = CfgLoad()[k];
    if (v && [v isKindOfClass:[NSString class]] && [v length]) return v;
    return def;
}
static void CfgSet(NSString *k, NSString *v) {
    NSMutableDictionary *d = CfgLoad();
    if (v && v.length) d[k] = v; else [d removeObjectForKey:k];
    CfgSave(d);
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
void KWDeliver(NSString *code);
static void KWShowOrderList(void);

// ---------- 閰嶇疆寮圭獥 ----------
static void KWShowConfig(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *u = CfgGet(@"username", @"");
        NSString *p = CfgGet(@"password", @"");
        UIAlertController *ac = [UIAlertController
            alertControllerWithTitle:@"蹇墜寰俊鐧诲綍 路 閰嶇疆"
                             message:@"杈撳叆鎺堟潈骞冲彴璐﹀彿锛堟湰鍦颁繚瀛橈紝浠呴渶濉竴娆★級"
                      preferredStyle:UIAlertControllerStyleAlert];
        [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) {
            tf.placeholder = @"璐﹀彿"; tf.text = u;
            tf.keyboardType = UIKeyboardTypeNumberPad;
        }];
        [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) {
            tf.placeholder = @"瀵嗙爜"; tf.text = p; tf.secureTextEntry = YES;
        }];
        [ac addAction:[UIAlertAction actionWithTitle:@"鍙栨秷" style:UIAlertActionStyleCancel handler:nil]];
        [ac addAction:[UIAlertAction actionWithTitle:@"淇濆瓨" style:UIAlertActionStyleDefault
                    handler:^(UIAlertAction *a) {
            CfgSet(@"username", ac.textFields[0].text ?: @"");
            CfgSet(@"password", ac.textFields[1].text ?: @"");
            KWLog(@"閰嶇疆宸蹭繚瀛?user=%@", ac.textFields[0].text);
        }]];
        UIWindow *w = nil;
        for (UIWindow *win in [UIApplication sharedApplication].windows)
            if (win.isKeyWindow) { w = win; break; }
        if (!w) w = [UIApplication sharedApplication].windows.firstObject;
        UIViewController *root = w.rootViewController;
        while (root.presentedViewController) root = root.presentedViewController;
        if (root) [root presentViewController:ac animated:YES completion:nil];
        KWLog(@"閰嶇疆绐楀凡寮瑰嚭");
    });
}

// ---------- 璁㈠崟鍒楄〃 ----------
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
    self.headerLabel.text = @"閫夋嫨鎺堟潈鏂瑰紡";
    self.headerLabel.textColor = [UIColor whiteColor];
    self.headerLabel.font = [UIFont boldSystemFontOfSize:20];
    self.headerLabel.textAlignment = NSTextAlignmentCenter;
    self.headerLabel.frame = CGRectMake(20, 60, W-40, 28);
    self.headerLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.headerLabel];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = [NSString stringWithFormat:@"鍏?%lu 鏉¤鍗?路 鐐归€夊嵆澶嶆壂", (unsigned long)self.orders.count];
    self.statusLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
    self.statusLabel.font = [UIFont systemFontOfSize:13];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.frame = CGRectMake(20, 92, W-40, 20);
    self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.statusLabel];

    UIButton *cfg = [UIButton buttonWithType:UIButtonTypeSystem];
    cfg.frame = CGRectMake(W-76, 54, 60, 30);
    cfg.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [cfg setTitle:@"閰嶇疆" forState:UIControlStateNormal];
    [cfg setTitleColor:[UIColor colorWithRed:0.4 green:0.7 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    cfg.titleLabel.font = [UIFont systemFontOfSize:14];
    [cfg addTarget:self action:@selector(onConfig) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:cfg];

    UIButton *cancel = [UIButton buttonWithType:UIButtonTypeSystem];
    cancel.frame = CGRectMake((W-140)/2, H-80, 140, 44);
    cancel.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [cancel setTitle:@"鍙栨秷" forState:UIControlStateNormal];
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

- (void)onConfig { KWShowConfig(); }

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
        c.textLabel.text = @"锛?鏂板缓鎺堟潈  (楼0.60)";
        c.textLabel.textColor = [UIColor colorWithRed:0.35 green:0.85 blue:0.5 alpha:1.0];
        c.detailTextLabel.text = @"鐢熸垚鍏ㄦ柊鎺堟潈鐮?;
        return c;
    }
    NSDictionary *o = self.orders[ip.row - 1];
    c.textLabel.text = [NSString stringWithFormat:@"%@   澶嶆壂%@娆?,
                        o[@"createTime"] ?: @"", o[@"version"] ?: @"1"];
    NSString *codeUrl = o[@"code"] ?: @"";
    NSString *shortCode = @"";
    NSRange r = [codeUrl rangeOfString:@"code="];
    if (r.location != NSNotFound) {
        NSString *tail = [codeUrl substringFromIndex:r.location+5];
        NSRange a = [tail rangeOfString:@"&"];
        shortCode = (a.location==NSNotFound)?tail:[tail substringToIndex:a.location];
    }
    c.detailTextLabel.text = [NSString stringWithFormat:@"%@   璁㈠崟 %@", shortCode, o[@"id"] ?: @""];
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

    if (!user.length || !pass.length) {
        self.busy = NO;
        self.statusLabel.text = @"璇峰厛鐐瑰彸涓婅銆岄厤缃€?;
        KWShowConfig();
        return;
    }

    if (ip.row == 0) {
        self.statusLabel.text = @"姝ｅ湪鏂板缓鎺堟潈...";
        KWLog(@"鏂板缓鎺堟潈");
        dispatch_async(dispatch_get_global_queue(0,0), ^{
            NSDictionary *j = HTTPGet([NSString stringWithFormat:
                @"%@/api/auth?username=%@&password=%@&appId=%@&grade=%@",
                api, user, pass, appId, grade]);
            dispatch_async(dispatch_get_main_queue(), ^{
                self.busy = NO;
                KWLog(@"鏂板缓杩斿洖: %@", j[@"message"]);
                if ([j[@"code"] isEqual:@20000]) {
                    NSString *oid = j[@"data"][@"orderId"];
                    if (oid.length) CfgSet(@"last_order", oid);
                    [self finishWithCodeUrl:j[@"data"][@"code"]];
                } else {
                    self.statusLabel.text = [NSString stringWithFormat:@"澶辫触: %@", j[@"message"]];
                }
            });
        });
    } else {
        NSDictionary *o = self.orders[ip.row - 1];
        NSString *oid = o[@"id"];
        self.statusLabel.text = [NSString stringWithFormat:@"姝ｅ湪澶嶆壂 %@ ...", oid];
        KWLog(@"澶嶆壂 %@", oid);
        dispatch_async(dispatch_get_global_queue(0,0), ^{
            NSDictionary *body = @{
                @"appId": appId, @"grade": @([grade intValue]), @"model": @1, @"type": @1,
                @"authType": @1, @"state": @"kwai_wechat_login",
                @"orderId": oid,
                @"qrCode": @"https://open.weixin.qq.com/connect/confirm?uuid="
            };
            NSDictionary *j = HTTPPostJSON([NSString stringWithFormat:@"%@/autoAuth", api], body, self.token);
            dispatch_async(dispatch_get_main_queue(), ^{
                self.busy = NO;
                KWLog(@"澶嶆壂杩斿洖: %@", j[@"message"]);
                if ([j[@"code"] isEqual:@20000]) {
                    CfgSet(@"last_order", oid);
                    [self finishWithCodeUrl:j[@"data"][@"code"]];
                } else {
                    self.statusLabel.text = [NSString stringWithFormat:@"澶嶆壂澶辫触: %@", j[@"message"]];
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
    if (!code) { self.statusLabel.text = @"瑙ｆ瀽澶辫触"; self.busy = NO; return; }
    self.statusLabel.text = @"鎺堟潈鎴愬姛";
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.5*NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self dismissViewControllerAnimated:YES completion:nil];
        KWDeliver(code);
    });
}

- (void)onCancel { KWLog(@"鍙栨秷"); [self dismissViewControllerAnimated:YES completion:nil]; }
@end

// ---------- 浜や粯 ----------
void KWDeliver(NSString *code) {
    NSString *appId = CfgGet(@"appid", kDefAppId);
    NSString *urlStr = [NSString stringWithFormat:
        @"%@://oauth?code=%@&scope=%@&state=%@&packageName=com.smile.gifmaker",
        appId, code, g_scope, g_state];
    KWLog(@"deliver: %@", urlStr);
    NSURL *u = [NSURL URLWithString:urlStr];
    Class wx = NSClassFromString(@"WXApi");
    if (wx) {
        SEL s1 = NSSelectorFromString(@"handleOpenURL:delegate:");
        if ([wx respondsToSelector:s1]) { [wx performSelector:s1 withObject:u withObject:nil]; }
        SEL s2 = NSSelectorFromString(@"handleAuthOpenUrl:delegate:");
        if ([wx respondsToSelector:s2]) { [wx performSelector:s2 withObject:u withObject:nil]; }
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] openURL:u options:@{} completionHandler:nil];
    });
}

// ---------- 鎷夊垪琛?----------
static void KWShowOrderList(void) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *user = CfgGet(@"username", @"");
        NSString *pass = CfgGet(@"password", @"");
        NSString *api  = CfgGet(@"api", kDefApi);
        NSString *appId= CfgGet(@"appid", kDefAppId);

        if (!user.length || !pass.length) {
            KWLog(@"鏈厤缃紝寮归厤缃獥");
            dispatch_async(dispatch_get_main_queue(), ^{ KWShowConfig(); });
            return;
        }

        NSDictionary *ui = HTTPGet([NSString stringWithFormat:
            @"%@/api/userInfo?username=%@&password=%@", api, user, pass]);
        NSString *token = ui[@"data"][@"token"];
        KWLog(@"token %@", token ? @"OK" : @"FAIL");

        NSDictionary *j = HTTPGet([NSString stringWithFormat:
            @"%@/api/authRecords?username=%@&password=%@&appId=%@&page=1&size=20",
            api, user, pass, appId]);
        NSArray *orders = @[];
        if (j && [j[@"code"] isEqual:@20000]) orders = j[@"data"][@"list"][@"records"] ?: @[];
        KWLog(@"璁㈠崟鏁?%lu", (unsigned long)orders.count);

        dispatch_async(dispatch_get_main_queue(), ^{
            UIWindow *w = nil;
            for (UIWindow *win in [UIApplication sharedApplication].windows)
                if (win.isKeyWindow) { w = win; break; }
            if (!w) w = [UIApplication sharedApplication].windows.firstObject;
            if (!w || !w.rootViewController) { KWLog(@"no window"); return; }
            KwaiOrderVC *vc = [[KwaiOrderVC alloc] init];
            vc.orders = orders;
            vc.token = token;
            vc.modalPresentationStyle = UIModalPresentationFullScreen;
            [w.rootViewController presentViewController:vc animated:YES completion:^{
                KWLog(@"shown");
            }];
        });
    });
}

// ---------- 鎷︽埅 ----------
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

// ---------- 鍒濆鍖?----------
void KwaiBuiltinInit(void) {
    @autoreleasepool {
        NSString *bid = [NSBundle mainBundle].bundleIdentifier;
        KWLog(@"");
        KWLog(@"##### KwaiWeChatLogin v1.0 #####");
        KWLog(@"bundleId=%@", bid);
        if (![bid isEqualToString:@"com.jiangjia.gif"]) { KWLog(@"闈炲揩鎵嬭繘绋?); return; }

        Method m0 = class_getInstanceMethod([UIApplication class], @selector(canOpenURL:));
        if (m0) { orig_canOpenURL=(void*)method_getImplementation(m0);
                  method_setImplementation(m0,(IMP)my_canOpenURL); KWLog(@"OK canOpenURL"); }

        Method m2 = class_getInstanceMethod([UIApplication class],
                    @selector(openURL:options:completionHandler:));
        if (m2) { orig_openURL_opt=(void*)method_getImplementation(m2);
                  method_setImplementation(m2,(IMP)my_openURL_opt); KWLog(@"OK openURL"); }

        KWLog(@"閰嶇疆: %@", CfgPath());
        KWLog(@"##### 鍒濆鍖栧畬鎴?#####");
    }
}