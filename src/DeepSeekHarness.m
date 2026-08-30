#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <ServiceManagement/ServiceManagement.h>
#import <signal.h>
#import <unistd.h>

#define L(key) NSLocalizedString((key), nil)

typedef NS_ENUM(NSInteger, DSHServiceState) {
    DSHServiceStateUnknown,
    DSHServiceStateStopped,
    DSHServiceStateStarting,
    DSHServiceStateRunning,
    DSHServiceStateRunningExternal,
    DSHServiceStateStopping,
    DSHServiceStateUnhealthy,
    DSHServiceStateBlocked,
    DSHServiceStateFailed,
};

typedef NS_ENUM(NSInteger, DSHBrowserProbeResult) {
    DSHBrowserProbeFocused,
    DSHBrowserProbeMissing,
    DSHBrowserProbeNotRunning,
    DSHBrowserProbeUnsupported,
    DSHBrowserProbePermissionDenied,
    DSHBrowserProbeError,
};

typedef NS_ENUM(NSInteger, DSHPreferredPresentation) {
    DSHPreferredPresentationBrowser,
    DSHPreferredPresentationInApp,
};

@interface DSHListenerInfo : NSObject
@property(nonatomic, assign) pid_t pid;
@property(nonatomic, assign) BOOL isHarness;
@property(nonatomic, assign) BOOL ownedByController;
@property(nonatomic, copy) NSString *command;
@end

@implementation DSHListenerInfo
@end

@interface DeepSeekHarnessApp : NSObject <NSApplicationDelegate, NSWindowDelegate, WKNavigationDelegate, WKUIDelegate>
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSMenuItem *statusMenuItem;
@property(nonatomic, strong) NSMenuItem *openMenuItem;
@property(nonatomic, strong) NSMenuItem *alternateOpenMenuItem;
@property(nonatomic, strong) NSMenuItem *presentationMenuItem;
@property(nonatomic, strong) NSMenuItem *browserPresentationItem;
@property(nonatomic, strong) NSMenuItem *inAppPresentationItem;
@property(nonatomic, strong) NSMenuItem *serviceMenuItem;
@property(nonatomic, strong) NSMenuItem *serviceSubStatusItem;
@property(nonatomic, strong) NSMenuItem *restartMenuItem;
@property(nonatomic, strong) NSMenuItem *stopMenuItem;
@property(nonatomic, strong) NSMenuItem *addressCopyMenuItem;
@property(nonatomic, strong) NSMenuItem *diagnosticsCopyMenuItem;
@property(nonatomic, strong) NSMenuItem *loginItem;
@property(nonatomic, strong) NSTimer *statusTimer;
@property(nonatomic, strong) NSTask *serviceTask;
@property(nonatomic, strong) NSFileHandle *logHandle;
@property(nonatomic, strong) dispatch_queue_t inspectionQueue;
@property(nonatomic, strong) dispatch_queue_t browserQueue;
@property(nonatomic, strong) NSWindow *webWindow;
@property(nonatomic, strong) WKWebView *webView;
@property(nonatomic, strong) NSTextField *connectionLabel;
@property(nonatomic, strong) NSButton *windowActionButton;
@property(nonatomic, strong) NSProgressIndicator *windowProgress;
@property(nonatomic, assign) DSHServiceState serviceState;
@property(nonatomic, assign) NSInteger transitionToken;
@property(nonatomic, assign) NSInteger windowLifetimeToken;
@property(nonatomic, assign) BOOL refreshInFlight;
@property(nonatomic, assign) BOOL openRequestInFlight;
@property(nonatomic, assign) BOOL browserProbeInFlight;
@property(nonatomic, assign) BOOL serviceActionInFlight;
@property(nonatomic, assign) BOOL hasPendingPresentation;
@property(nonatomic, assign) BOOL webViewLoadFailed;
@property(nonatomic, assign) DSHPreferredPresentation pendingPresentation;
@property(nonatomic, assign) BOOL launchedInBackground;
@end

static DeepSeekHarnessApp *appDelegate;
static BOOL DSHBackgroundLaunch = NO;
static NSString * const DSHWebAddress = @"http://127.0.0.1:3080";
static NSString * const DSHPreferredPresentationKey = @"PreferredPresentation";
static NSString * const DSHOnboardingKey = @"DidCompleteOnboardingV4";
static NSString * const DSHLoginHelperIdentifier = @"com.yestar.deepseek-harness.login-helper";

@implementation DeepSeekHarnessApp

- (NSString *)homePath { return NSHomeDirectory(); }
- (NSURL *)webURL { return [NSURL URLWithString:DSHWebAddress]; }
- (NSString *)appVersion { return NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] ?: @""; }

- (NSString *)logPath {
    return [[self homePath] stringByAppendingPathComponent:@"Library/Logs/DeepSeek Harness/web.log"];
}

- (NSString *)supportPath {
    return [[self homePath] stringByAppendingPathComponent:@"Library/Application Support/DeepSeek Harness"];
}

- (NSString *)ownershipRecordPath {
    return [[self supportPath] stringByAppendingPathComponent:@"service-owner.plist"];
}

- (NSString *)privateRuntimeBinPath {
    return [[self supportPath] stringByAppendingPathComponent:@"runtime/current/bin"];
}

- (NSArray<NSString *> *)dshCandidates {
    NSString *home = [self homePath];
    return @[
        [[self supportPath] stringByAppendingPathComponent:@"npm/node_modules/.bin/dsh"],
        [home stringByAppendingPathComponent:@".local/bin/dsh"],
        @"/opt/homebrew/bin/dsh",
        @"/usr/local/bin/dsh"
    ];
}

- (NSString *)dshPath {
    for (NSString *path in [self dshCandidates]) {
        if ([NSFileManager.defaultManager isExecutableFileAtPath:path]) return path;
    }
    return nil;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.launchedInBackground = DSHBackgroundLaunch;
    [NSUserDefaults.standardUserDefaults registerDefaults:@{ DSHPreferredPresentationKey: @(DSHPreferredPresentationBrowser) }];
    self.inspectionQueue = dispatch_queue_create("com.yestar.deepseek-harness.inspection", DISPATCH_QUEUE_SERIAL);
    self.browserQueue = dispatch_queue_create("com.yestar.deepseek-harness.browser", DISPATCH_QUEUE_SERIAL);
    [self migrateLegacyLoginItem];
    self.serviceState = DSHServiceStateUnknown;
    [self buildStatusMenu];
    [self applyServiceState];
    self.statusTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                       target:self
                                                     selector:@selector(refreshServiceState:)
                                                     userInfo:nil
                                                      repeats:YES];
    [self refreshServiceState:nil];

    if (!self.launchedInBackground) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self completeOnboardingIfNeededAndOpen];
        });
    }
}

- (void)migrateLegacyLoginItem {
    NSString *legacyPath = [[self homePath] stringByAppendingPathComponent:@"Library/LaunchAgents/com.yestar.deepseek-harness.unified.plist"];
    if (![NSFileManager.defaultManager fileExistsAtPath:legacyPath]) return;
    [self runExecutable:@"/bin/launchctl"
              arguments:@[ @"bootout", [NSString stringWithFormat:@"gui/%d", getuid()], legacyPath ] timeout:2.0];
    SMAppService *service = self.loginService;
    if (service.status != SMAppServiceStatusEnabled) {
        NSError *error = nil;
        [service registerAndReturnError:&error];
    }
    [NSFileManager.defaultManager removeItemAtPath:legacyPath error:nil];
}

- (void)buildStatusMenu {
    self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.image = [self menuBarImage];
    self.statusItem.button.imagePosition = NSImageLeft;
    self.statusItem.button.accessibilityRoleDescription = L(@"菜单栏控制");

    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"DeepSeek Harness"];
    self.statusMenuItem = [menu addItemWithTitle:@"" action:nil keyEquivalent:@""];
    self.statusMenuItem.enabled = NO;
    [menu addItem:NSMenuItem.separatorItem];

    self.openMenuItem = [menu addItemWithTitle:L(@"打开 DeepSeek Harness") action:@selector(openHarness:) keyEquivalent:@"o"];
    self.openMenuItem.target = self;
    self.alternateOpenMenuItem = [menu addItemWithTitle:@"" action:@selector(openUsingAlternatePresentation:) keyEquivalent:@""];
    self.alternateOpenMenuItem.target = self;

    self.presentationMenuItem = [menu addItemWithTitle:L(@"默认打开方式") action:nil keyEquivalent:@""];
    NSMenu *presentationMenu = [[NSMenu alloc] initWithTitle:L(@"默认打开方式")];
    self.browserPresentationItem = [presentationMenu addItemWithTitle:L(@"默认浏览器（优先复用已有标签页）")
                                                                action:@selector(selectBrowserPresentation:) keyEquivalent:@""];
    self.browserPresentationItem.target = self;
    self.inAppPresentationItem = [presentationMenu addItemWithTitle:L(@"应用内窗口")
                                                              action:@selector(selectInAppPresentation:) keyEquivalent:@""];
    self.inAppPresentationItem.target = self;
    self.presentationMenuItem.submenu = presentationMenu;

    [menu addItem:NSMenuItem.separatorItem];
    self.serviceMenuItem = [menu addItemWithTitle:L(@"服务") action:nil keyEquivalent:@""];
    NSMenu *serviceMenu = [[NSMenu alloc] initWithTitle:L(@"服务")];
    self.serviceSubStatusItem = [serviceMenu addItemWithTitle:@"" action:nil keyEquivalent:@""];
    self.serviceSubStatusItem.enabled = NO;
    [serviceMenu addItem:NSMenuItem.separatorItem];
    self.restartMenuItem = [serviceMenu addItemWithTitle:L(@"重启服务") action:@selector(restartService:) keyEquivalent:@"r"];
    self.restartMenuItem.target = self;
    self.stopMenuItem = [serviceMenu addItemWithTitle:L(@"停止服务") action:@selector(stopService:) keyEquivalent:@""];
    self.stopMenuItem.target = self;
    [serviceMenu addItemWithTitle:L(@"立即刷新状态") action:@selector(forceRefreshService:) keyEquivalent:@""].target = self;
    [serviceMenu addItem:NSMenuItem.separatorItem];
    self.addressCopyMenuItem = [serviceMenu addItemWithTitle:L(@"复制本地地址") action:@selector(copyLocalAddress:) keyEquivalent:@""];
    self.addressCopyMenuItem.target = self;
    self.diagnosticsCopyMenuItem = [serviceMenu addItemWithTitle:L(@"复制诊断信息") action:@selector(copyDiagnostics:) keyEquivalent:@""];
    self.diagnosticsCopyMenuItem.target = self;
    [serviceMenu addItemWithTitle:L(@"查看日志") action:@selector(revealLog:) keyEquivalent:@""].target = self;
    self.serviceMenuItem.submenu = serviceMenu;

    self.loginItem = [menu addItemWithTitle:L(@"登录时静默启动") action:@selector(toggleLaunchAtLogin:) keyEquivalent:@""];
    self.loginItem.target = self;
    [menu addItemWithTitle:L(@"使用说明…") action:@selector(showUsageGuide:) keyEquivalent:@""].target = self;
    [menu addItem:NSMenuItem.separatorItem];
    [menu addItemWithTitle:[NSString stringWithFormat:L(@"关于 DeepSeek Harness %@"), [self appVersion]]
                    action:@selector(showAbout:) keyEquivalent:@""].target = self;
    [menu addItemWithTitle:L(@"退出控制器（服务继续运行）") action:@selector(quitController:) keyEquivalent:@"q"].target = self;
    self.statusItem.menu = menu;
}

- (DSHPreferredPresentation)preferredPresentation {
    NSInteger stored = [NSUserDefaults.standardUserDefaults integerForKey:DSHPreferredPresentationKey];
    return stored == DSHPreferredPresentationInApp ? DSHPreferredPresentationInApp : DSHPreferredPresentationBrowser;
}

- (BOOL)hasPersistentPreference:(NSString *)key {
    NSDictionary *domain = [NSUserDefaults.standardUserDefaults persistentDomainForName:NSBundle.mainBundle.bundleIdentifier];
    return domain[key] != nil;
}

- (void)completeOnboardingIfNeededAndOpen {
    if (![self hasPersistentPreference:DSHOnboardingKey] && ![self hasPersistentPreference:DSHPreferredPresentationKey]) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = L(@"欢迎使用 DeepSeek Harness");
        alert.informativeText = L(@"Dock 用来打开或回到 Harness；菜单栏小鲸鱼用来查看服务状态和设置。请选择以后默认在哪里打开，你可以随时在菜单中修改。");
        [alert addButtonWithTitle:L(@"使用默认浏览器")];
        [alert addButtonWithTitle:L(@"使用应用内窗口")];
        if ([alert runModal] == NSAlertSecondButtonReturn) {
            [NSUserDefaults.standardUserDefaults setInteger:DSHPreferredPresentationInApp forKey:DSHPreferredPresentationKey];
        } else {
            [NSUserDefaults.standardUserDefaults setInteger:DSHPreferredPresentationBrowser forKey:DSHPreferredPresentationKey];
        }
        [NSUserDefaults.standardUserDefaults setBool:YES forKey:DSHOnboardingKey];
        [self applyServiceState];
    }
    [self openHarness:nil];
}

- (NSImage *)menuBarImage {
    NSString *svgPath = [NSBundle.mainBundle pathForResource:@"DeepSeekWhale" ofType:@"svg"];
    NSImage *source = [[NSImage alloc] initWithContentsOfFile:svgPath];
    if (source != nil) {
        NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(18, 18)];
        [image lockFocus];
        [source drawInRect:NSMakeRect(0, 0, 18, 18) fromRect:NSZeroRect
                 operation:NSCompositingOperationSourceOver fraction:1.0];
        [image unlockFocus];
        image.template = YES;
        return image;
    }
    NSImage *fallback = [NSImage imageWithSystemSymbolName:@"circle.grid.cross.fill"
                                     accessibilityDescription:@"DeepSeek Harness"];
    fallback.template = YES;
    return fallback;
}

- (NSString *)stateTitle {
    switch (self.serviceState) {
        case DSHServiceStateStopped: return L(@"服务未启动");
        case DSHServiceStateStarting: return L(@"正在启动服务…");
        case DSHServiceStateRunning: return L(@"服务正在运行");
        case DSHServiceStateRunningExternal: return L(@"服务正在运行（外部启动）");
        case DSHServiceStateStopping: return L(@"正在停止服务…");
        case DSHServiceStateUnhealthy: return L(@"服务无响应");
        case DSHServiceStateBlocked: return L(@"端口 3080 被其他服务占用");
        case DSHServiceStateFailed: return L(@"服务操作失败");
        case DSHServiceStateUnknown: return L(@"正在检查服务…");
    }
}

- (NSColor *)stateColor {
    switch (self.serviceState) {
        case DSHServiceStateRunning:
        case DSHServiceStateRunningExternal: return NSColor.systemGreenColor;
        case DSHServiceStateStarting:
        case DSHServiceStateStopping:
        case DSHServiceStateUnknown: return NSColor.systemOrangeColor;
        case DSHServiceStateUnhealthy:
        case DSHServiceStateBlocked:
        case DSHServiceStateFailed: return NSColor.systemRedColor;
        case DSHServiceStateStopped: return NSColor.secondaryLabelColor;
    }
}

- (BOOL)isBusy {
    return self.serviceState == DSHServiceStateStarting || self.serviceState == DSHServiceStateStopping;
}

- (BOOL)isRunningState {
    return self.serviceState == DSHServiceStateRunning || self.serviceState == DSHServiceStateRunningExternal;
}

- (void)applyServiceState {
    NSString *title = [self stateTitle];
    self.statusMenuItem.title = title;
    self.serviceSubStatusItem.title = title;
    NSString *accessibility = [NSString stringWithFormat:@"DeepSeek Harness: %@", title];
    self.statusItem.button.toolTip = accessibility;
    self.statusItem.button.accessibilityLabel = accessibility;
    self.statusItem.button.attributedTitle = [[NSAttributedString alloc] initWithString:@"●"
        attributes:@{ NSForegroundColorAttributeName: [self stateColor], NSFontAttributeName: [NSFont systemFontOfSize:9 weight:NSFontWeightBold] }];

    BOOL busy = [self isBusy] || self.refreshInFlight || self.openRequestInFlight || self.browserProbeInFlight || self.serviceActionInFlight;
    BOOL running = [self isRunningState];
    BOOL blocked = self.serviceState == DSHServiceStateBlocked;
    self.openMenuItem.title = busy ? L(@"正在处理…") : (running ? L(@"打开 / 聚焦 DeepSeek Harness") : L(@"启动并打开 DeepSeek Harness"));
    self.openMenuItem.enabled = !busy && !blocked;
    self.alternateOpenMenuItem.enabled = !busy && !blocked;
    self.restartMenuItem.enabled = !busy && (running || self.serviceState == DSHServiceStateUnhealthy);
    self.stopMenuItem.enabled = !busy && (running || self.serviceState == DSHServiceStateUnhealthy);

    BOOL browser = [self preferredPresentation] == DSHPreferredPresentationBrowser;
    self.presentationMenuItem.title = browser ? L(@"打开方式：默认浏览器") : L(@"打开方式：应用内窗口");
    self.alternateOpenMenuItem.title = browser ? L(@"本次改用应用内窗口") : L(@"本次改用默认浏览器");
    self.browserPresentationItem.state = browser ? NSControlStateValueOn : NSControlStateValueOff;
    self.inAppPresentationItem.state = browser ? NSControlStateValueOff : NSControlStateValueOn;
    [self applyLoginItemState];
    [self updateWindowConnectionUI];
}

- (NSString *)runExecutable:(NSString *)executable arguments:(NSArray<NSString *> *)arguments timeout:(NSTimeInterval)timeout {
    NSTask *task = [[NSTask alloc] init];
    NSPipe *pipe = NSPipe.pipe;
    task.launchPath = executable;
    task.arguments = arguments;
    task.standardOutput = pipe;
    task.standardError = pipe;
    @try {
        [task launch];
    } @catch (NSException *exception) {
        return @"";
    }

    __block NSData *data = nil;
    dispatch_group_t readerGroup = dispatch_group_create();
    dispatch_group_enter(readerGroup);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        data = [pipe.fileHandleForReading readDataToEndOfFile];
        dispatch_group_leave(readerGroup);
    });
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while (task.running && deadline.timeIntervalSinceNow > 0) [NSThread sleepForTimeInterval:0.02];
    if (task.running) {
        [task terminate];
        NSDate *terminationDeadline = [NSDate dateWithTimeIntervalSinceNow:0.5];
        while (task.running && terminationDeadline.timeIntervalSinceNow > 0) [NSThread sleepForTimeInterval:0.02];
        if (task.running) kill(task.processIdentifier, SIGKILL);
    }
    [task waitUntilExit];
    dispatch_group_wait(readerGroup, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)));
    return data ? ([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"") : @"";
}

- (BOOL)ownershipRecordMatchesPID:(pid_t)pid {
    NSDictionary *record = [NSDictionary dictionaryWithContentsOfFile:[self ownershipRecordPath]];
    return [record[@"pid"] intValue] == pid && [record[@"bundleIdentifier"] isEqualToString:NSBundle.mainBundle.bundleIdentifier];
}

- (void)writeOwnershipRecordForPID:(pid_t)pid dshPath:(NSString *)dshPath {
    [NSFileManager.defaultManager createDirectoryAtPath:[self supportPath]
                             withIntermediateDirectories:YES attributes:nil error:nil];
    NSDictionary *record = @{
        @"pid": @(pid),
        @"bundleIdentifier": NSBundle.mainBundle.bundleIdentifier ?: @"",
        @"dshPath": dshPath ?: @"",
        @"createdAt": NSDate.date
    };
    [record writeToFile:[self ownershipRecordPath] atomically:YES];
}

- (void)removeOwnershipRecord {
    [NSFileManager.defaultManager removeItemAtPath:[self ownershipRecordPath] error:nil];
}

- (DSHListenerInfo *)listenerInfo {
    DSHListenerInfo *info = [[DSHListenerInfo alloc] init];
    NSString *pidOutput = [self runExecutable:@"/usr/sbin/lsof"
                                     arguments:@[ @"-nP", @"-tiTCP:3080", @"-sTCP:LISTEN" ] timeout:2.0];
    NSString *line = [[pidOutput componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet] firstObject];
    info.pid = line.intValue;
    if (info.pid <= 0) return info;
    info.command = [self runExecutable:@"/bin/ps"
                              arguments:@[ @"-p", [NSString stringWithFormat:@"%d", info.pid], @"-o", @"command=" ] timeout:2.0];
    info.isHarness = [info.command containsString:@"deepseek-ai/dsh"] ||
        [info.command containsString:@"/.dsh/"] || [info.command containsString:@"dsh-cli"] ||
        [info.command containsString:@"/Application Support/DeepSeek Harness/npm/"];
    if (!info.isHarness) {
        NSString *files = [self runExecutable:@"/usr/sbin/lsof"
                                     arguments:@[ @"-p", [NSString stringWithFormat:@"%d", info.pid] ] timeout:2.0];
        info.isHarness = [files containsString:@"@deepseek-ai/dsh"] || [files containsString:@"/.dsh/"];
    }
    info.ownedByController = info.isHarness && [self ownershipRecordMatchesPID:info.pid];
    return info;
}

- (void)checkHTTPHealth:(void (^)(BOOL healthy))completion {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.webURL
                                                          cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:2.0];
    request.HTTPMethod = @"GET";
    NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithRequest:request
        completionHandler:^(__unused NSData *data, NSURLResponse *response, NSError *error) {
            NSInteger status = [(NSHTTPURLResponse *)response statusCode];
            BOOL healthy = error == nil && status >= 200 && status < 400;
            dispatch_async(dispatch_get_main_queue(), ^{ completion(healthy); });
        }];
    [task resume];
}

- (NSArray<NSURL *> *)pluginAssetURLsFromHTMLData:(NSData *)data {
    if (data.length == 0) return @[];
    NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (html.length == 0) return @[];

    NSString *marker = @"globalThis[\"__DSH_BOOT__\"] = ";
    NSRange markerRange = [html rangeOfString:marker];
    if (markerRange.location == NSNotFound) return @[];
    NSUInteger jsonStart = NSMaxRange(markerRange);
    NSRange scriptEnd = [html rangeOfString:@"</script>"
                                    options:0
                                      range:NSMakeRange(jsonStart, html.length - jsonStart)];
    if (scriptEnd.location == NSNotFound) return @[];

    NSString *payload = [html substringWithRange:NSMakeRange(jsonStart, scriptEnd.location - jsonStart)];
    payload = [payload stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if ([payload hasSuffix:@";"]) payload = [payload substringToIndex:payload.length - 1];
    NSData *jsonData = [payload dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *boot = jsonData ? [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil] : nil;
    NSArray *entries = [boot isKindOfClass:NSDictionary.class] ? boot[@"entries"] : nil;
    if (![entries isKindOfClass:NSArray.class]) return @[];

    NSMutableOrderedSet<NSURL *> *assetURLs = [NSMutableOrderedSet orderedSet];
    for (id candidate in entries) {
        if (![candidate isKindOfClass:NSDictionary.class]) continue;
        NSString *path = candidate[@"url"];
        if (![path isKindOfClass:NSString.class]) continue;
        NSURL *url = [NSURL URLWithString:path relativeToURL:self.webURL].absoluteURL;
        BOOL isLocalPlugin = [url.scheme isEqualToString:@"http"] &&
            [url.host isEqualToString:@"127.0.0.1"] && url.port.integerValue == 3080 &&
            [url.path hasPrefix:@"/plugins/"];
        if (isLocalPlugin) [assetURLs addObject:url];
    }
    return assetURLs.array;
}

- (void)checkPluginAssetsInHTMLData:(NSData *)data completion:(void (^)(BOOL healthy))completion {
    NSArray<NSURL *> *assetURLs = [self pluginAssetURLsFromHTMLData:data];
    if (assetURLs.count == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(YES); });
        return;
    }

    dispatch_group_t group = dispatch_group_create();
    NSObject *resultLock = [[NSObject alloc] init];
    __block BOOL assetsHealthy = YES;
    for (NSURL *url in assetURLs) {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                              cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                          timeoutInterval:2.0];
        request.HTTPMethod = @"HEAD";
        dispatch_group_enter(group);
        NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithRequest:request
            completionHandler:^(__unused NSData *responseData, NSURLResponse *response, NSError *error) {
                NSInteger status = [(NSHTTPURLResponse *)response statusCode];
                if (error != nil || status < 200 || status >= 400) {
                    @synchronized (resultLock) { assetsHealthy = NO; }
                }
                dispatch_group_leave(group);
            }];
        [task resume];
    }
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        BOOL healthy;
        @synchronized (resultLock) { healthy = assetsHealthy; }
        completion(healthy);
    });
}

- (void)checkPresentationHealth:(void (^)(BOOL healthy))completion {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.webURL
                                                          cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:2.0];
    request.HTTPMethod = @"GET";
    NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSInteger status = [(NSHTTPURLResponse *)response statusCode];
            if (error != nil || status < 200 || status >= 400) {
                dispatch_async(dispatch_get_main_queue(), ^{ completion(NO); });
                return;
            }
            [self checkPluginAssetsInHTMLData:data completion:completion];
        }];
    [task resume];
}

- (void)inspectServiceAndHealth:(void (^)(DSHListenerInfo *info, BOOL healthy))completion {
    dispatch_async(self.inspectionQueue, ^{
        DSHListenerInfo *info = [self listenerInfo];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!info.isHarness) { completion(info, NO); return; }
            [self checkHTTPHealth:^(BOOL healthy) { completion(info, healthy); }];
        });
    });
}

- (void)inspectServiceAndPresentationHealth:(void (^)(DSHListenerInfo *info, BOOL healthy))completion {
    dispatch_async(self.inspectionQueue, ^{
        DSHListenerInfo *info = [self listenerInfo];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!info.isHarness) { completion(info, NO); return; }
            [self checkPresentationHealth:^(BOOL healthy) { completion(info, healthy); }];
        });
    });
}

- (void)setStateFromListener:(DSHListenerInfo *)info healthy:(BOOL)healthy {
    if (info.pid <= 0) self.serviceState = DSHServiceStateStopped;
    else if (!info.isHarness) self.serviceState = DSHServiceStateBlocked;
    else if (!healthy) self.serviceState = DSHServiceStateUnhealthy;
    else self.serviceState = info.ownedByController ? DSHServiceStateRunning : DSHServiceStateRunningExternal;
}

- (void)refreshServiceState:(NSTimer *)timer {
    if (self.refreshInFlight || [self isBusy]) return;
    self.refreshInFlight = YES;
    [self inspectServiceAndHealth:^(DSHListenerInfo *info, BOOL healthy) {
        self.refreshInFlight = NO;
        if ([self isBusy]) return;
        [self setStateFromListener:info healthy:healthy];
        [self applyServiceState];
    }];
}

- (void)forceRefreshService:(id)sender {
    if (self.refreshInFlight || [self isBusy]) return;
    self.serviceState = DSHServiceStateUnknown;
    self.refreshInFlight = YES;
    [self applyServiceState];
    [self inspectServiceAndPresentationHealth:^(DSHListenerInfo *info, BOOL healthy) {
        self.refreshInFlight = NO;
        [self setStateFromListener:info healthy:healthy];
        [self applyServiceState];
    }];
}

- (void)openHarness:(id)sender {
    [self requestOpenWithPresentation:[self preferredPresentation]];
}

- (void)openUsingAlternatePresentation:(id)sender {
    DSHPreferredPresentation alternate = [self preferredPresentation] == DSHPreferredPresentationBrowser
        ? DSHPreferredPresentationInApp : DSHPreferredPresentationBrowser;
    [self requestOpenWithPresentation:alternate];
}

- (void)requestOpenWithPresentation:(DSHPreferredPresentation)presentation {
    self.pendingPresentation = presentation;
    self.hasPendingPresentation = YES;
    if ([self isBusy] || self.serviceActionInFlight) return;
    if (self.openRequestInFlight) return;
    self.openRequestInFlight = YES;
    [self applyServiceState];
    [self inspectServiceAndPresentationHealth:^(DSHListenerInfo *info, BOOL healthy) {
        self.openRequestInFlight = NO;
        if (info.pid > 0 && !info.isHarness) {
            self.serviceState = DSHServiceStateBlocked;
            [self applyServiceState];
            [self showAlertWithTitle:L(@"端口 3080 已被占用")
                             message:[NSString stringWithFormat:L(@"PID %d 正在监听 3080，但不是 DeepSeek Harness。控制器不会打开或停止这个进程。"), info.pid]];
            return;
        }
        if (info.isHarness && healthy) {
            [self setStateFromListener:info healthy:YES];
            [self applyServiceState];
            [self presentPendingHarness];
            return;
        }
        if (info.isHarness) {
            self.serviceState = DSHServiceStateUnhealthy;
            [self applyServiceState];
            if (info.ownedByController) {
                [self beginStopPID:info.pid restartAfterStop:YES presentAfterRestart:YES];
                return;
            }
            [self showUnhealthyServiceDecisionForInfo:info];
            return;
        }
        [self beginStartPresentAfterReady:YES];
    }];
}

- (void)beginStartPresentAfterReady:(BOOL)presentAfterReady {
    if ([self isBusy]) return;
    NSString *dshPath = [self dshPath];
    if (dshPath == nil) {
        self.serviceState = DSHServiceStateFailed;
        [self applyServiceState];
        [self showAlertWithTitle:L(@"找不到 DeepSeek Harness") message:L(@"未找到可执行的 dsh。请使用完整安装包重新安装。")];
        return;
    }
    NSString *logPath = [self logPath];
    [NSFileManager.defaultManager createDirectoryAtPath:logPath.stringByDeletingLastPathComponent
                             withIntermediateDirectories:YES attributes:nil error:nil];
    [NSFileManager.defaultManager createFileAtPath:logPath contents:nil attributes:nil];
    self.logHandle = [NSFileHandle fileHandleForWritingAtPath:logPath];
    if (!self.logHandle) {
        self.serviceState = DSHServiceStateFailed;
        [self applyServiceState];
        [self showAlertWithTitle:L(@"无法创建日志") message:[NSString stringWithFormat:L(@"无法写入 %@。"), logPath]];
        return;
    }
    [self.logHandle seekToEndOfFile];
    self.serviceState = DSHServiceStateStarting;
    NSInteger token = ++self.transitionToken;
    [self applyServiceState];
    self.serviceTask = [[NSTask alloc] init];
    self.serviceTask.launchPath = dshPath;
    // Presentation is owned by this controller. Prevent DSH from opening a
    // second browser tab before the saved browser/in-app preference is applied.
    self.serviceTask.arguments = @[ @"web", @"--no-open" ];
    NSMutableDictionary *environment = NSProcessInfo.processInfo.environment.mutableCopy;
    NSString *existingPath = environment[@"PATH"] ?: @"/usr/bin:/bin:/usr/sbin:/sbin";
    environment[@"PATH"] = [NSString stringWithFormat:@"%@:%@", [self privateRuntimeBinPath], existingPath];
    self.serviceTask.environment = environment;
    self.serviceTask.standardOutput = self.logHandle;
    self.serviceTask.standardError = self.logHandle;
    __weak typeof(self) weakSelf = self;
    self.serviceTask.terminationHandler = ^(NSTask *task) {
        if (task.terminationStatus == 0) return;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            typeof(self) strongSelf = weakSelf;
            if (!strongSelf || strongSelf.transitionToken != token || strongSelf.serviceState != DSHServiceStateStarting) return;
            [strongSelf inspectServiceAndHealth:^(DSHListenerInfo *info, BOOL healthy) {
                if (strongSelf.transitionToken != token || strongSelf.serviceState != DSHServiceStateStarting) return;
                if (info.isHarness && healthy) return;
                if (info.pid <= 0) {
                    strongSelf.serviceState = DSHServiceStateFailed;
                    [strongSelf applyServiceState];
                    [strongSelf showAlertWithTitle:L(@"服务启动失败") message:[NSString stringWithFormat:L(@"dsh 已提前退出。请查看日志：%@"), [strongSelf logPath]]];
                }
            }];
        });
    };
    @try {
        [self.serviceTask launch];
    } @catch (NSException *exception) {
        self.serviceState = DSHServiceStateFailed;
        [self applyServiceState];
        [self showAlertWithTitle:L(@"启动失败") message:[NSString stringWithFormat:L(@"无法执行 dsh web。请查看日志：%@"), logPath]];
        return;
    }
    [self pollForReadyWithToken:token attemptsRemaining:60 dshPath:dshPath presentAfterReady:presentAfterReady];
}

- (void)pollForReadyWithToken:(NSInteger)token attemptsRemaining:(NSInteger)attemptsRemaining
                      dshPath:(NSString *)dshPath presentAfterReady:(BOOL)presentAfterReady {
    if (token != self.transitionToken || self.serviceState != DSHServiceStateStarting) return;
    [self inspectServiceAndHealth:^(DSHListenerInfo *info, BOOL healthy) {
        if (token != self.transitionToken || self.serviceState != DSHServiceStateStarting) return;
        if (info.pid > 0 && !info.isHarness) {
            if (self.serviceTask.running) [self.serviceTask terminate];
            self.serviceState = DSHServiceStateBlocked;
            [self applyServiceState];
            [self showAlertWithTitle:L(@"端口 3080 被占用") message:L(@"启动过程中检测到其他监听进程；新启动的 Harness 已安全终止。")];
            return;
        }
        if (info.isHarness && healthy) {
            [self checkPresentationHealth:^(BOOL presentationHealthy) {
                if (token != self.transitionToken || self.serviceState != DSHServiceStateStarting) return;
                if (!presentationHealthy) {
                    self.serviceState = DSHServiceStateUnhealthy;
                    [self applyServiceState];
                    [self showAlertWithTitle:L(@"服务未准备好")
                                     message:[NSString stringWithFormat:L(@"服务已经启动，但一个或多个插件资源仍无法加载。请更新或移除有问题的插件，然后从鲸鱼菜单重启服务。日志：%@"), [self logPath]]];
                    return;
                }
                [self writeOwnershipRecordForPID:info.pid dshPath:dshPath];
                self.serviceState = DSHServiceStateRunning;
                [self applyServiceState];
                if (presentAfterReady || self.hasPendingPresentation) [self presentPendingHarness];
            }];
            return;
        }
        if (attemptsRemaining <= 0) {
            self.serviceState = info.isHarness ? DSHServiceStateUnhealthy : DSHServiceStateFailed;
            [self applyServiceState];
            [self showAlertWithTitle:L(@"服务未准备好") message:[NSString stringWithFormat:L(@"已等待 30 秒，但网页健康检查仍未通过。请查看日志：%@"), [self logPath]]];
            return;
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self pollForReadyWithToken:token attemptsRemaining:attemptsRemaining - 1 dshPath:dshPath presentAfterReady:presentAfterReady];
        });
    }];
}

- (void)presentPendingHarness {
    DSHPreferredPresentation presentation = self.hasPendingPresentation ? self.pendingPresentation : [self preferredPresentation];
    self.hasPendingPresentation = NO;
    [self presentHarnessUsingPresentation:presentation];
}

- (void)presentHarnessUsingPresentation:(DSHPreferredPresentation)presentation {
    if (presentation == DSHPreferredPresentationInApp) [self openInAppWindow];
    else [self presentInDefaultBrowser];
}

- (void)stopService:(id)sender {
    if (self.serviceActionInFlight || [self isBusy]) return;
    self.serviceActionInFlight = YES;
    [self applyServiceState];
    [self inspectServiceAndHealth:^(DSHListenerInfo *info, __unused BOOL healthy) {
        self.serviceActionInFlight = NO;
        [self applyServiceState];
        if (!info.isHarness) {
            [self setStateFromListener:info healthy:NO];
            [self applyServiceState];
            return;
        }
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = info.ownedByController ? L(@"停止 DeepSeek Harness？") : L(@"停止外部启动的 Harness？");
        alert.informativeText = info.ownedByController
            ? L(@"当前页面会断开；之后可以从 Dock 或菜单栏重新启动。")
            : L(@"这个服务不是由当前控制器启动的。停止它可能影响终端或其他工具中的任务。");
        [alert addButtonWithTitle:info.ownedByController ? L(@"停止服务") : L(@"仍要停止")];
        [alert addButtonWithTitle:L(@"取消")];
        if ([alert runModal] == NSAlertFirstButtonReturn) [self beginStopPID:info.pid restartAfterStop:NO presentAfterRestart:NO];
    }];
}

- (void)restartService:(id)sender {
    [self restartServicePresentAfterRestart:NO];
}

- (void)restartServicePresentAfterRestart:(BOOL)presentAfterRestart {
    if (self.serviceActionInFlight || [self isBusy]) return;
    self.serviceActionInFlight = YES;
    [self applyServiceState];
    [self inspectServiceAndHealth:^(DSHListenerInfo *info, __unused BOOL healthy) {
        self.serviceActionInFlight = NO;
        [self applyServiceState];
        if (info.pid <= 0) { [self beginStartPresentAfterReady:presentAfterRestart]; return; }
        if (!info.isHarness) {
            self.serviceState = DSHServiceStateBlocked;
            [self applyServiceState];
            [self showAlertWithTitle:L(@"无法安全重启") message:L(@"端口 3080 由其他服务占用，控制器不会停止它。")];
            return;
        }
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = info.ownedByController ? L(@"重启 DeepSeek Harness？") : L(@"重启外部启动的 Harness？");
        alert.informativeText = info.ownedByController
            ? L(@"控制器会等待旧服务完全停止，再启动并通过健康检查。")
            : L(@"这个服务不是由当前控制器启动的。重启可能中断其他工具中的任务。");
        [alert addButtonWithTitle:L(@"重启服务")];
        [alert addButtonWithTitle:L(@"取消")];
        if ([alert runModal] == NSAlertFirstButtonReturn) [self beginStopPID:info.pid restartAfterStop:YES presentAfterRestart:presentAfterRestart];
    }];
}

- (void)beginStopPID:(pid_t)pid restartAfterStop:(BOOL)restartAfterStop presentAfterRestart:(BOOL)presentAfterRestart {
    self.serviceState = DSHServiceStateStopping;
    NSInteger token = ++self.transitionToken;
    [self applyServiceState];
    if (kill(pid, SIGTERM) != 0) {
        self.serviceState = DSHServiceStateFailed;
        [self applyServiceState];
        [self showAlertWithTitle:L(@"停止失败") message:[NSString stringWithFormat:L(@"无法停止 PID %d。"), pid]];
        return;
    }
    [self pollForStoppedWithToken:token attemptsRemaining:30 restartAfterStop:restartAfterStop presentAfterRestart:presentAfterRestart];
}

- (void)pollForStoppedWithToken:(NSInteger)token attemptsRemaining:(NSInteger)attemptsRemaining
                restartAfterStop:(BOOL)restartAfterStop presentAfterRestart:(BOOL)presentAfterRestart {
    if (token != self.transitionToken || self.serviceState != DSHServiceStateStopping) return;
    dispatch_async(self.inspectionQueue, ^{
        DSHListenerInfo *info = [self listenerInfo];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (token != self.transitionToken || self.serviceState != DSHServiceStateStopping) return;
            if (info.pid <= 0) {
                [self removeOwnershipRecord];
                self.serviceState = DSHServiceStateStopped;
                [self applyServiceState];
                if (restartAfterStop) [self beginStartPresentAfterReady:presentAfterRestart];
                else if (self.hasPendingPresentation) [self beginStartPresentAfterReady:YES];
                return;
            }
            if (attemptsRemaining <= 0) {
                self.serviceState = info.isHarness ? DSHServiceStateFailed : DSHServiceStateBlocked;
                [self applyServiceState];
                [self showAlertWithTitle:L(@"服务未能停止") message:L(@"已等待 15 秒。控制器不会强制终止进程，以免丢失工作。")];
                return;
            }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self pollForStoppedWithToken:token attemptsRemaining:attemptsRemaining - 1 restartAfterStop:restartAfterStop presentAfterRestart:presentAfterRestart];
            });
        });
    });
}

- (void)showUnhealthyServiceDecisionForInfo:(DSHListenerInfo *)info {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = L(@"Harness 服务没有响应");
    alert.informativeText = info.ownedByController
        ? L(@"端口已经由 Harness 监听，但网页或插件资源健康检查失败。重新启动服务通常可以恢复。")
        : L(@"这个 Harness 由控制器之外的工具启动，而且网页或插件资源健康检查失败。重启可能中断其他工具中的任务。");
    [alert addButtonWithTitle:L(@"重启服务")];
    [alert addButtonWithTitle:L(@"查看日志")];
    [alert addButtonWithTitle:L(@"取消")];
    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) [self beginStopPID:info.pid restartAfterStop:YES presentAfterRestart:YES];
    else if (response == NSAlertSecondButtonReturn) [self revealLog:nil];
}

- (NSString *)defaultBrowserBundleIdentifier {
    NSURL *browserURL = [NSWorkspace.sharedWorkspace URLForApplicationToOpenURL:self.webURL];
    return [NSBundle bundleWithURL:browserURL].bundleIdentifier;
}

- (BOOL)isApplicationRunningWithBundleIdentifier:(NSString *)bundleIdentifier {
    for (NSRunningApplication *application in NSWorkspace.sharedWorkspace.runningApplications) {
        if ([application.bundleIdentifier isEqualToString:bundleIdentifier]) return YES;
    }
    return NO;
}

- (NSString *)focusScriptForBrowser:(NSString *)bundleIdentifier {
    if ([bundleIdentifier isEqualToString:@"com.apple.Safari"]) {
        return @"tell application id \"com.apple.Safari\"\n"
            "repeat with theWindow in windows\n"
            "repeat with theTab in tabs of theWindow\n"
            "set tabURL to URL of theTab\n"
            "if tabURL starts with \"http://127.0.0.1:3080\" or tabURL starts with \"http://localhost:3080\" then\n"
            "set current tab of theWindow to theTab\nset index of theWindow to 1\nactivate\nreturn \"found\"\nend if\n"
            "end repeat\nend repeat\nend tell\nreturn \"missing\"\n";
    }
    NSSet *chromium = [NSSet setWithArray:@[
        @"com.google.Chrome", @"com.google.Chrome.canary", @"com.microsoft.edgemac", @"com.microsoft.edgemac.Canary",
        @"com.brave.Browser", @"company.thebrowser.Browser", @"com.vivaldi.Vivaldi", @"com.operasoftware.Opera",
        @"com.operasoftware.OperaGX", @"org.chromium.Chromium"
    ]];
    if (![chromium containsObject:bundleIdentifier]) return nil;
    return [NSString stringWithFormat:
        @"tell application id \"%@\"\nrepeat with windowIndex from 1 to count of windows\n"
        "set theWindow to window windowIndex\nrepeat with tabIndex from 1 to count of tabs of theWindow\n"
        "set tabURL to URL of tab tabIndex of theWindow\n"
        "if tabURL starts with \"http://127.0.0.1:3080\" or tabURL starts with \"http://localhost:3080\" then\n"
        "set active tab index of theWindow to tabIndex\nset index of theWindow to 1\nactivate\nreturn \"found\"\n"
        "end if\nend repeat\nend repeat\nend tell\nreturn \"missing\"\n", bundleIdentifier];
}

- (DSHBrowserProbeResult)focusExistingHarnessPage {
    @autoreleasepool {
        NSString *bundleIdentifier = [self defaultBrowserBundleIdentifier];
        if (bundleIdentifier.length == 0) return DSHBrowserProbeError;
        NSString *source = [self focusScriptForBrowser:bundleIdentifier];
        if (!source) return DSHBrowserProbeUnsupported;
        if (![self isApplicationRunningWithBundleIdentifier:bundleIdentifier]) return DSHBrowserProbeNotRunning;
        NSDictionary *error = nil;
        NSAppleEventDescriptor *result = [[[NSAppleScript alloc] initWithSource:source] executeAndReturnError:&error];
        if (!error && [result.stringValue isEqualToString:@"found"]) return DSHBrowserProbeFocused;
        if ([error[NSAppleScriptErrorNumber] integerValue] == -1743) return DSHBrowserProbePermissionDenied;
        return error ? DSHBrowserProbeError : DSHBrowserProbeMissing;
    }
}

- (NSString *)unsupportedBrowserChoiceKey:(NSString *)bundleIdentifier {
    return [@"UnsupportedBrowserChoice." stringByAppendingString:bundleIdentifier ?: @"unknown"];
}

- (void)presentInDefaultBrowser {
    if (self.browserProbeInFlight) return;
    self.browserProbeInFlight = YES;
    [self applyServiceState];
    dispatch_async(self.browserQueue, ^{
        DSHBrowserProbeResult result = [self focusExistingHarnessPage];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.browserProbeInFlight = NO;
            [self applyServiceState];
            if (result == DSHBrowserProbeFocused) return;
            if (result == DSHBrowserProbePermissionDenied) { [self showAutomationPermissionDecision]; return; }
            if (result == DSHBrowserProbeUnsupported || result == DSHBrowserProbeError) {
                [self handleUnsupportedBrowser];
                return;
            }
            [NSWorkspace.sharedWorkspace openURL:self.webURL];
        });
    });
}

- (void)handleUnsupportedBrowser {
    NSString *browser = [self defaultBrowserBundleIdentifier] ?: @"unknown";
    NSString *key = [self unsupportedBrowserChoiceKey:browser];
    NSInteger choice = [NSUserDefaults.standardUserDefaults integerForKey:key];
    if (choice == 1) {
        if ([self preferredPresentation] == DSHPreferredPresentationInApp) [NSWorkspace.sharedWorkspace openURL:self.webURL];
        else [self openInAppWindow];
        return;
    }
    if (choice == 2) { [NSWorkspace.sharedWorkspace openURL:self.webURL]; return; }
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = L(@"当前浏览器无法可靠复用标签页");
    alert.informativeText = L(@"为了避免重复标签，建议使用应用内窗口。这个选择只询问一次，以后可从菜单栏修改默认打开方式。");
    [alert addButtonWithTitle:L(@"改用应用内窗口（推荐）")];
    [alert addButtonWithTitle:L(@"仍使用浏览器")];
    if ([alert runModal] == NSAlertSecondButtonReturn) {
        [NSUserDefaults.standardUserDefaults setInteger:2 forKey:key];
        [NSWorkspace.sharedWorkspace openURL:self.webURL];
    } else {
        [NSUserDefaults.standardUserDefaults setInteger:1 forKey:key];
        [NSUserDefaults.standardUserDefaults setInteger:DSHPreferredPresentationInApp forKey:DSHPreferredPresentationKey];
        [self applyServiceState];
        [self openInAppWindow];
    }
}

- (void)showAutomationPermissionDecision {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = L(@"需要一次浏览器自动化权限");
    alert.informativeText = L(@"这项权限只用于查找并聚焦 127.0.0.1:3080 标签。未授权时控制器不会盲目创建重复页面。");
    [alert addButtonWithTitle:L(@"打开自动化设置")];
    [alert addButtonWithTitle:L(@"改用应用内窗口")];
    [alert addButtonWithTitle:L(@"取消")];
    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"]];
    } else if (response == NSAlertSecondButtonReturn) {
        [NSUserDefaults.standardUserDefaults setInteger:DSHPreferredPresentationInApp forKey:DSHPreferredPresentationKey];
        [self applyServiceState];
        [self openInAppWindow];
    }
}

- (void)openInAppWindow {
    self.windowLifetimeToken++;
    if (self.webWindow) {
        [self.webWindow makeKeyAndOrderFront:nil];
        [NSApp activateIgnoringOtherApps:YES];
        [self updateWindowConnectionUI];
        return;
    }
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1180, 820)
        styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable)
        backing:NSBackingStoreBuffered defer:NO];
    window.title = @"DeepSeek Harness";
    window.delegate = self;
    window.releasedWhenClosed = NO;
    window.minSize = NSMakeSize(800, 560);
    [window setFrameAutosaveName:@"DeepSeekHarnessMainWindow"];

    NSView *container = [[NSView alloc] initWithFrame:window.contentView.bounds];
    NSVisualEffectView *bar = [[NSVisualEffectView alloc] initWithFrame:NSZeroRect];
    bar.material = NSVisualEffectMaterialHeaderView;
    bar.blendingMode = NSVisualEffectBlendingModeWithinWindow;
    bar.state = NSVisualEffectStateFollowsWindowActiveState;
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    self.connectionLabel = [NSTextField labelWithString:L(@"正在连接…")];
    self.connectionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.connectionLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    self.windowProgress = [[NSProgressIndicator alloc] initWithFrame:NSZeroRect];
    self.windowProgress.style = NSProgressIndicatorStyleSpinning;
    self.windowProgress.controlSize = NSControlSizeSmall;
    self.windowProgress.displayedWhenStopped = NO;
    self.windowProgress.translatesAutoresizingMaskIntoConstraints = NO;
    self.windowActionButton = [NSButton buttonWithTitle:L(@"重新加载") target:self action:@selector(reloadWebView:)];
    self.windowActionButton.bezelStyle = NSBezelStyleRounded;
    self.windowActionButton.controlSize = NSControlSizeSmall;
    self.windowActionButton.translatesAutoresizingMaskIntoConstraints = NO;
    [bar addSubview:self.windowProgress];
    [bar addSubview:self.connectionLabel];
    [bar addSubview:self.windowActionButton];

    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    WKWebView *webView = [[WKWebView alloc] initWithFrame:NSZeroRect configuration:configuration];
    webView.translatesAutoresizingMaskIntoConstraints = NO;
    webView.navigationDelegate = self;
    webView.UIDelegate = self;
    [container addSubview:bar];
    [container addSubview:webView];
    window.contentView = container;
    [NSLayoutConstraint activateConstraints:@[
        [bar.topAnchor constraintEqualToAnchor:container.topAnchor],
        [bar.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [bar.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [bar.heightAnchor constraintEqualToConstant:38],
        [self.windowProgress.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor constant:12],
        [self.windowProgress.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],
        [self.connectionLabel.leadingAnchor constraintEqualToAnchor:self.windowProgress.trailingAnchor constant:8],
        [self.connectionLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.windowActionButton.leadingAnchor constant:-8],
        [self.connectionLabel.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],
        [self.windowActionButton.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor constant:-10],
        [self.windowActionButton.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],
        [webView.topAnchor constraintEqualToAnchor:bar.bottomAnchor],
        [webView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [webView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [webView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
    ]];
    self.webWindow = window;
    self.webView = webView;
    self.webViewLoadFailed = NO;
    [self updateWindowConnectionUI];
    [webView loadRequest:[NSURLRequest requestWithURL:self.webURL]];
    [window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)reloadWebView:(id)sender {
    if ([self isRunningState]) [self.webView loadRequest:[NSURLRequest requestWithURL:self.webURL]];
    else [self requestOpenWithPresentation:DSHPreferredPresentationInApp];
}

- (void)updateWindowConnectionUI {
    if (!self.connectionLabel) return;
    if ([self isRunningState]) {
        if (self.webView.loading) {
            self.connectionLabel.stringValue = L(@"正在加载…");
            self.connectionLabel.textColor = NSColor.secondaryLabelColor;
            self.windowActionButton.enabled = NO;
            [self.windowProgress startAnimation:nil];
            return;
        }
        if (self.webViewLoadFailed) {
            self.connectionLabel.stringValue = L(@"页面连接失败 · 点击重新连接");
            self.connectionLabel.textColor = NSColor.systemRedColor;
            self.windowActionButton.title = L(@"重新连接");
            self.windowActionButton.enabled = YES;
            [self.windowProgress stopAnimation:nil];
            return;
        }
        self.connectionLabel.stringValue = L(@"已连接 · 127.0.0.1:3080");
        self.connectionLabel.textColor = NSColor.secondaryLabelColor;
        self.windowActionButton.title = L(@"重新加载");
        self.windowActionButton.enabled = YES;
        [self.windowProgress stopAnimation:nil];
    } else if (self.serviceState == DSHServiceStateStarting || self.serviceState == DSHServiceStateUnknown) {
        self.connectionLabel.stringValue = L(@"正在连接服务…");
        self.connectionLabel.textColor = NSColor.secondaryLabelColor;
        self.windowActionButton.enabled = NO;
        [self.windowProgress startAnimation:nil];
    } else {
        self.connectionLabel.stringValue = self.serviceState == DSHServiceStateUnhealthy ? L(@"服务无响应") : L(@"服务未连接");
        self.connectionLabel.textColor = NSColor.systemRedColor;
        self.windowActionButton.title = L(@"启动并重连");
        self.windowActionButton.enabled = self.serviceState != DSHServiceStateBlocked;
        [self.windowProgress stopAnimation:nil];
    }
}

- (BOOL)windowShouldClose:(NSWindow *)sender {
    if (sender != self.webWindow) return YES;
    [sender orderOut:nil];
    NSInteger token = ++self.windowLifetimeToken;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * 60 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (token != self.windowLifetimeToken || self.webWindow.visible) return;
        [self.webView stopLoading];
        self.webView.navigationDelegate = nil;
        self.webView.UIDelegate = nil;
        self.webView = nil;
        self.webWindow = nil;
        self.connectionLabel = nil;
        self.windowActionButton = nil;
        self.windowProgress = nil;
    });
    return NO;
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    self.webViewLoadFailed = NO;
    self.connectionLabel.stringValue = L(@"正在加载…");
    [self.windowProgress startAnimation:nil];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    self.webViewLoadFailed = NO;
    [self.windowProgress stopAnimation:nil];
    self.connectionLabel.stringValue = L(@"已连接 · 127.0.0.1:3080");
    self.connectionLabel.textColor = NSColor.secondaryLabelColor;
    if (webView.title.length > 0) {
        BOOL alreadyBranded = [webView.title rangeOfString:@"DeepSeek Harness" options:NSCaseInsensitiveSearch].location != NSNotFound;
        self.webWindow.title = alreadyBranded ? webView.title : [NSString stringWithFormat:@"%@ — DeepSeek Harness", webView.title];
    }
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [self showWebViewError:error];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [self showWebViewError:error];
}

- (void)showWebViewError:(NSError *)error {
    if (error.code == NSURLErrorCancelled) return;
    self.webViewLoadFailed = YES;
    [self.windowProgress stopAnimation:nil];
    self.connectionLabel.stringValue = L(@"页面连接失败 · 点击重新连接");
    self.connectionLabel.textColor = NSColor.systemRedColor;
    self.windowActionButton.title = L(@"重新连接");
    self.windowActionButton.enabled = YES;
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
 decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *url = navigationAction.request.URL;
    NSString *host = url.host.lowercaseString;
    BOOL local = [host isEqualToString:@"127.0.0.1"] || [host isEqualToString:@"localhost"] || url.isFileURL;
    if (!local && ([@[ @"http", @"https" ] containsObject:url.scheme.lowercaseString])) {
        [NSWorkspace.sharedWorkspace openURL:url];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration
   forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures {
    NSURL *url = navigationAction.request.URL;
    if (url) {
        NSString *host = url.host.lowercaseString;
        if ([host isEqualToString:@"127.0.0.1"] || [host isEqualToString:@"localhost"]) [webView loadRequest:navigationAction.request];
        else [NSWorkspace.sharedWorkspace openURL:url];
    }
    return nil;
}

- (void)selectBrowserPresentation:(id)sender {
    [NSUserDefaults.standardUserDefaults setInteger:DSHPreferredPresentationBrowser forKey:DSHPreferredPresentationKey];
    NSString *browser = [self defaultBrowserBundleIdentifier] ?: @"unknown";
    [NSUserDefaults.standardUserDefaults setInteger:2 forKey:[self unsupportedBrowserChoiceKey:browser]];
    [self applyServiceState];
}

- (void)selectInAppPresentation:(id)sender {
    [NSUserDefaults.standardUserDefaults setInteger:DSHPreferredPresentationInApp forKey:DSHPreferredPresentationKey];
    [self applyServiceState];
}

- (SMAppService *)loginService {
    return [SMAppService loginItemServiceWithIdentifier:DSHLoginHelperIdentifier];
}

- (void)applyLoginItemState {
    if (!self.loginItem) return;
    SMAppServiceStatus status = self.loginService.status;
    self.loginItem.state = status == SMAppServiceStatusEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.loginItem.title = status == SMAppServiceStatusRequiresApproval
        ? L(@"登录时静默启动（需要批准）") : L(@"登录时静默启动");
    self.loginItem.enabled = status != SMAppServiceStatusNotFound;
}

- (void)toggleLaunchAtLogin:(id)sender {
    SMAppService *service = self.loginService;
    NSError *error = nil;
    if (service.status == SMAppServiceStatusEnabled) {
        if (![service unregisterAndReturnError:&error]) [self showAlertWithTitle:L(@"无法关闭登录启动") message:error.localizedDescription ?: @""];
    } else if (service.status == SMAppServiceStatusRequiresApproval) {
        [SMAppService openSystemSettingsLoginItems];
    } else {
        if (![service registerAndReturnError:&error]) {
            [self showAlertWithTitle:L(@"无法开启登录启动") message:error.localizedDescription ?: @""];
        } else if (service.status == SMAppServiceStatusRequiresApproval) {
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = L(@"需要在系统设置中批准");
            alert.informativeText = L(@"macOS 要求你在“通用 → 登录项”中允许 DeepSeek Harness。登录启动只启动小鲸鱼，不会自动打开页面。");
            [alert addButtonWithTitle:L(@"打开登录项设置")];
            [alert addButtonWithTitle:L(@"稍后")];
            if ([alert runModal] == NSAlertFirstButtonReturn) [SMAppService openSystemSettingsLoginItems];
        }
    }
    [self applyLoginItemState];
}

- (void)copyLocalAddress:(id)sender {
    [NSPasteboard.generalPasteboard clearContents];
    [NSPasteboard.generalPasteboard setString:DSHWebAddress forType:NSPasteboardTypeString];
    self.addressCopyMenuItem.title = L(@"已复制本地地址 ✓");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.addressCopyMenuItem.title = L(@"复制本地地址");
    });
}

- (void)copyDiagnostics:(id)sender {
    NSString *mode = [self preferredPresentation] == DSHPreferredPresentationBrowser ? L(@"默认浏览器") : L(@"应用内窗口");
    NSString *diagnostics = [NSString stringWithFormat:L(@"DeepSeek Harness %@\n状态：%@\n地址：%@\n打开方式：%@\n默认浏览器：%@\n日志：%@"),
        [self appVersion], [self stateTitle], DSHWebAddress, mode, [self defaultBrowserBundleIdentifier] ?: L(@"未识别"), [self logPath]];
    [NSPasteboard.generalPasteboard clearContents];
    [NSPasteboard.generalPasteboard setString:diagnostics forType:NSPasteboardTypeString];
    self.diagnosticsCopyMenuItem.title = L(@"已复制诊断信息 ✓");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.diagnosticsCopyMenuItem.title = L(@"复制诊断信息");
    });
}

- (void)revealLog:(id)sender {
    NSURL *logURL = [NSURL fileURLWithPath:[self logPath]];
    if (![NSFileManager.defaultManager fileExistsAtPath:logURL.path]) {
        [NSFileManager.defaultManager createDirectoryAtPath:logURL.URLByDeletingLastPathComponent.path
                                 withIntermediateDirectories:YES attributes:nil error:nil];
        [NSFileManager.defaultManager createFileAtPath:logURL.path contents:nil attributes:nil];
    }
    [NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[ logURL ]];
}

- (void)showUsageGuide:(id)sender {
    [self showAlertWithTitle:L(@"DeepSeek Harness 使用说明")
                     message:L(@"• 点击 Dock：按默认方式打开或回到 Harness\n• 点击菜单栏小鲸鱼：查看状态、切换打开方式、重启或停止服务\n• 红色圆点表示异常，橙色表示处理中，绿色表示运行正常\n• 应用内窗口关闭后，小鲸鱼和服务仍继续运行\n• “登录时静默启动”只启动小鲸鱼，不自动打开页面")];
}

- (void)showAbout:(id)sender {
    NSString *mode = [self preferredPresentation] == DSHPreferredPresentationBrowser ? L(@"默认浏览器") : L(@"应用内窗口");
    [self showAlertWithTitle:@"DeepSeek Harness"
                     message:[NSString stringWithFormat:L(@"版本 %@\n本地地址：%@\n默认打开方式：%@\n服务状态：%@\n\n控制器不会存储或上传你的 DeepSeek 凭据。"), [self appVersion], DSHWebAddress, mode, [self stateTitle]]];
}

- (void)quitController:(id)sender { [NSApp terminate:nil]; }

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    [self openHarness:nil];
    return YES;
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = title;
    alert.informativeText = message;
    [alert runModal];
}

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        for (int index = 1; index < argc; index++) {
            if (strcmp(argv[index], "--background") == 0) DSHBackgroundLaunch = YES;
        }
        NSApplication *application = NSApplication.sharedApplication;
        appDelegate = [[DeepSeekHarnessApp alloc] init];
        application.delegate = appDelegate;
        [application setActivationPolicy:NSApplicationActivationPolicyAccessory];
        [application run];
    }
    return 0;
}
