#import "WebController.h"

#import "Preferences.h"

static NSString * const YTMScriptHandlerName = @"ytm";
static NSString * const YTMDefaultStartPage = @"https://music.youtube.com/";
static NSString * const YTMSafariUserAgent =
    @"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15";

@interface WebController () <WKNavigationDelegate, WKUIDelegate>

@property (nonatomic, strong, readwrite) WKWebView *webView;
@property (nonatomic, strong, nullable) PlaybackState *state;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) NSInteger consentAutomationAttempts;

- (void)handleScriptMessage:(WKScriptMessage *)message;

@end

@interface YTMScriptMessageProxy : NSObject <WKScriptMessageHandler>
@property (nonatomic, weak, nullable) WebController *controller;
@end

@implementation YTMScriptMessageProxy

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
    [self.controller handleScriptMessage:message];
}

@end

@implementation WebController

- (instancetype)init {
    self = [super init];
    if (!self) { return nil; }

    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    NSDictionary<NSString *, NSString *> *environment = NSProcessInfo.processInfo.environment;
    if ([environment[@"YTM_EPHEMERAL"] boolValue]) {
        // Used by the snapshot tooling so tests never touch the user's cookies or login.
        configuration.websiteDataStore = [WKWebsiteDataStore nonPersistentDataStore];
    } else {
        configuration.websiteDataStore = [WKWebsiteDataStore defaultDataStore];
    }
    configuration.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    configuration.suppressesIncrementalRendering = NO;
    configuration.preferences.javaScriptCanOpenWindowsAutomatically = YES;
    if ([configuration.preferences respondsToSelector:@selector(setElementFullscreenEnabled:)]) {
        configuration.preferences.elementFullscreenEnabled = YES;
    }
    if (@available(macOS 11.0, *)) {
        configuration.defaultWebpagePreferences.allowsContentJavaScript = YES;
    }

    YTMScriptMessageProxy *proxy = [[YTMScriptMessageProxy alloc] init];
    proxy.controller = self;
    [configuration.userContentController addScriptMessageHandler:proxy name:YTMScriptHandlerName];

    NSString *bridgeScript = [self resourceNamed:@"PlayerBridge" extension:@"js"];
    if (bridgeScript.length > 0) {
        WKUserScript *script = [[WKUserScript alloc] initWithSource:bridgeScript
                                                      injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
                                                   forMainFrameOnly:YES];
        [configuration.userContentController addUserScript:script];
    } else {
        NSLog(@"[YTM] PlayerBridge.js is missing from the app bundle; playback controls will be unavailable.");
    }

    _webView = [[WKWebView alloc] initWithFrame:NSZeroRect configuration:configuration];
    _webView.navigationDelegate = self;
    _webView.UIDelegate = self;
    _webView.customUserAgent = YTMSafariUserAgent;
    _webView.allowsBackForwardNavigationGestures = YES;
    _webView.allowsLinkPreview = YES;
    _webView.allowsMagnification = NO;
    _webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _webView.underPageBackgroundColor = [NSColor colorWithSRGBRed:3.0 / 255.0 green:3.0 / 255.0 blue:3.0 / 255.0 alpha:1.0];
    if (@available(macOS 13.3, *)) {
        _webView.inspectable = YES;
    }

    [_webView addObserver:self forKeyPath:@"title" options:NSKeyValueObservingOptionNew context:nil];

    return self;
}

- (void)dealloc {
    @try {
        [_webView removeObserver:self forKeyPath:@"title"];
    } @catch (__unused NSException *exception) {
    }
    [_webView.configuration.userContentController removeScriptMessageHandlerForName:YTMScriptHandlerName];
}

#pragma mark - Resources

- (nullable NSString *)resourceNamed:(NSString *)name extension:(NSString *)extension {
    NSURL *url = [NSBundle.mainBundle URLForResource:name withExtension:extension];
    if (!url) {
        // Also support running the raw executable next to the Resources folder while developing.
        NSString *fallback = [[[NSBundle.mainBundle.executableURL.path stringByDeletingLastPathComponent]
                               stringByDeletingLastPathComponent]
                              stringByAppendingPathComponent:[NSString stringWithFormat:@"Resources/%@.%@", name, extension]];
        if ([[NSFileManager defaultManager] fileExistsAtPath:fallback]) {
            url = [NSURL fileURLWithPath:fallback];
        }
    }
    if (!url) { return nil; }
    NSError *error = nil;
    NSString *source = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];
    if (!source) {
        NSLog(@"[YTM] Could not read %@.%@: %@", name, extension, error.localizedDescription);
    }
    return source;
}

#pragma mark - Loading

- (void)loadStartPage {
    NSString *override = NSProcessInfo.processInfo.environment[@"YTM_START_URL"];
    NSString *raw = override.length > 0 ? override : [Preferences sharedPreferences].startPage;
    NSURL *url = [self sanitizedURLFromString:raw];
    if (!url) {
        url = [NSURL URLWithString:YTMDefaultStartPage];
    }
    [self loadURL:url];
}

- (void)loadURL:(NSURL *)url {
    if (!url) { return; }
    [self.webView loadRequest:[NSURLRequest requestWithURL:url]];
}

- (void)reload {
    if (self.webView.URL) {
        [self.webView reload];
    } else {
        [self loadStartPage];
    }
}

- (void)goBack {
    if (self.webView.canGoBack) { [self.webView goBack]; }
}

- (void)goForward {
    if (self.webView.canGoForward) { [self.webView goForward]; }
}

- (void)goHome {
    [self loadURL:[NSURL URLWithString:YTMDefaultStartPage]];
}

- (void)openCurrentPageInBrowser {
    NSURL *url = self.webView.URL;
    if (url) {
        [[NSWorkspace sharedWorkspace] openURL:url];
    }
}

- (BOOL)canGoBack {
    return self.webView.canGoBack;
}

- (BOOL)canGoForward {
    return self.webView.canGoForward;
}

- (NSURL *)sanitizedURLFromString:(NSString *)raw {
    NSString *value = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (value.length == 0) { return nil; }
    if (![value containsString:@"://"]) {
        value = [@"https://" stringByAppendingString:value];
    }
    NSURL *url = [NSURL URLWithString:value];
    if (!url || !url.host.length) { return nil; }
    NSString *scheme = url.scheme.lowercaseString;
    if (![scheme isEqualToString:@"https"] && ![scheme isEqualToString:@"http"]) { return nil; }
    return url;
}

#pragma mark - Commands

- (void)sendCommand:(NSString *)command value:(nullable id)value {
    NSArray *arguments = value ? @[command, value] : @[command];
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:arguments options:0 error:&error];
    if (!data) {
        NSLog(@"[YTM] Could not encode command %@: %@", command, error.localizedDescription);
        return;
    }
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSString *script = [NSString stringWithFormat:
        @"(function(){try{var a=%@;if(window.__ytm&&window.__ytm.command){window.__ytm.command(a[0],a[1]);}}catch(e){}})();",
        json];
    [self.webView evaluateJavaScript:script completionHandler:nil];
}

- (void)togglePlayPause { [self sendCommand:@"toggle" value:nil]; }
- (void)play { [self sendCommand:@"play" value:nil]; }
- (void)pause { [self sendCommand:@"pause" value:nil]; }
- (void)nextTrack { [self sendCommand:@"next" value:nil]; }
- (void)previousTrack { [self sendCommand:@"previous" value:nil]; }
- (void)seekTo:(NSTimeInterval)time { [self sendCommand:@"seek" value:@(MAX(0, time))]; }
- (void)setLiked:(BOOL)liked { [self sendCommand:@"like" value:@(liked)]; }
- (void)focusSearch { [self sendCommand:@"focusSearch" value:nil]; }

- (void)performCommand:(NSString *)command value:(nullable id)value {
    if ([command isEqualToString:@"seek"]) {
        [self seekTo:[value doubleValue]];
        return;
    }
    if ([command isEqualToString:@"like"]) {
        [self setLiked:[value boolValue]];
        return;
    }
    [self sendCommand:command value:value];
}

#pragma mark - Script messages

- (void)handleScriptMessage:(WKScriptMessage *)message {
    if (![message.name isEqualToString:YTMScriptHandlerName]) { return; }
    if (![message.body isKindOfClass:[NSDictionary class]]) { return; }

    NSDictionary *body = (NSDictionary *)message.body;
    NSString *type = body[@"type"];
    if ([type isEqualToString:@"ready"]) {
        [self.delegate webControllerDidBecomeReady:self];
        return;
    }
    if (![type isEqualToString:@"state"]) { return; }

    PlaybackState *next = [[PlaybackState alloc] initWithMessage:body];
    BOOL changed = !self.state || ![self.state isEqualToState:next];
    self.state = next;
    // Position ticks every second, so always forward it; consumers decide how much to redraw.
    if (changed || next.isPlaying) {
        [self.delegate webController:self didUpdateState:next];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:@"title"]) {
        [self.delegate webController:self didChangeTitle:self.webView.title];
        return;
    }
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

#pragma mark - Snapshot

- (void)takeSnapshotWithCompletion:(void (^)(NSImage * _Nullable, NSError * _Nullable))completion {
    WKSnapshotConfiguration *configuration = [[WKSnapshotConfiguration alloc] init];
    configuration.rect = self.webView.bounds;
    configuration.snapshotWidth = @(self.webView.bounds.size.width);
    [self.webView takeSnapshotWithConfiguration:configuration completionHandler:^(NSImage * _Nullable snapshotImage, NSError * _Nullable error) {
        if (completion) { completion(snapshotImage, error); }
    }];
}

#pragma mark - URL policy

- (BOOL)isAllowedHost:(NSString *)host {
    if (!host.length) { return NO; }
    NSString *value = host.lowercaseString;
    NSArray<NSString *> *domains = @[
        @"youtube.com",
        @"youtu.be",
        @"google.com",
        @"googleusercontent.com"
    ];
    for (NSString *domain in domains) {
        if ([value isEqualToString:domain] || [value hasSuffix:[@"." stringByAppendingString:domain]]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)isInternalURL:(NSURL *)url {
    if (!url) { return NO; }
    NSString *scheme = url.scheme.lowercaseString;
    if ([scheme isEqualToString:@"about"]) { return YES; }
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) { return NO; }
    return [self isAllowedHost:url.host];
}

- (void)openExternally:(NSURL *)url {
    if (!url) { return; }
    if ([NSProcessInfo.processInfo.environment[@"YTM_VERBOSE"] boolValue]) {
        NSLog(@"[YTM] Opening externally: %@", url.absoluteString);
    }
    [[NSWorkspace sharedWorkspace] openURL:url];
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView
    decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                    decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *url = navigationAction.request.URL;
    if (!url) {
        decisionHandler(WKNavigationActionPolicyAllow);
        return;
    }

    if (navigationAction.shouldPerformDownload) {
        [self openExternally:url];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }

    BOOL isMainFrame = navigationAction.targetFrame.isMainFrame;
    if (!isMainFrame) {
        decisionHandler(WKNavigationActionPolicyAllow);
        return;
    }

    if ([NSProcessInfo.processInfo.environment[@"YTM_VERBOSE"] boolValue]) {
        NSLog(@"[YTM] Navigate: %@ (target=%@, type=%ld)",
              url.absoluteString,
              navigationAction.targetFrame ? @"frame" : @"new-window",
              (long)navigationAction.navigationType);
    }

    if ([self isInternalURL:url]) {
        decisionHandler(WKNavigationActionPolicyAllow);
        return;
    }

    // mailto:, tel: and friends always belong to the system.
    NSString *scheme = url.scheme.lowercaseString;
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) {
        [self openExternally:url];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }

    if ([Preferences sharedPreferences].openExternalLinksInBrowser) {
        [self openExternally:url];
        decisionHandler(WKNavigationActionPolicyCancel);
    } else {
        decisionHandler(WKNavigationActionPolicyAllow);
    }
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    self.loading = YES;
    if ([NSProcessInfo.processInfo.environment[@"YTM_VERBOSE"] boolValue]) {
        NSLog(@"[YTM] Start: %@", webView.URL.absoluteString);
    }
    [self.delegate webControllerDidStartLoading:self];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    self.loading = NO;
    if ([NSProcessInfo.processInfo.environment[@"YTM_VERBOSE"] boolValue]) {
        NSLog(@"[YTM] Loaded %@", webView.URL.absoluteString);
    }
    [self runConsentAutomationForURL:webView.URL];
    [self runDebugScriptIfNeededForURL:webView.URL];
    [self.delegate webControllerDidFinishLoading:self];
}

/// Test-only: evaluates YTM_DEBUG_JS after each successful page load.
- (void)runDebugScriptIfNeededForURL:(NSURL *)url {
    NSString *script = NSProcessInfo.processInfo.environment[@"YTM_DEBUG_JS"];
    if (script.length == 0 || !url) { return; }
    if (![url.host.lowercaseString containsString:@"music.youtube.com"]) { return; }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.webView evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
            NSLog(@"[YTM] Debug JS: %@ %@", result, error.localizedDescription ?: @"");
        }];
    });
}

/// Test-only: accepts or rejects Google's cookie interstitial in an ephemeral profile.
- (void)runConsentAutomationForURL:(NSURL *)url {
    NSString *mode = NSProcessInfo.processInfo.environment[@"YTM_AUTOCONSENT"];
    if (mode.length == 0 || !url) { return; }
    if (![url.absoluteString.lowercaseString containsString:@"consent"]) { return; }
    if (self.consentAutomationAttempts >= 6) { return; }
    self.consentAutomationAttempts += 1;

    NSString *needle = [mode.lowercaseString isEqualToString:@"accept"] ? @"accept all" : @"reject all";
    NSString *script = [NSString stringWithFormat:
        @"(function(){try{"
         "var needle=%@;var nodes=Array.prototype.slice.call(document.querySelectorAll('button, [role=\"button\"], a'));"
         "for(var i=0;i<nodes.length;i++){var t=(nodes[i].innerText||nodes[i].textContent||'').trim().toLowerCase();"
         "if(t.indexOf(needle)>=0){nodes[i].click();return 'clicked '+t;}}return 'not found';"
         "}catch(e){return 'error '+e;}})();",
        [self javaScriptStringLiteral:needle]];
    __weak typeof(self) weakSelf = self;
    [self.webView evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
        NSLog(@"[YTM] Consent automation (%@): %@ %@", mode, result, error.localizedDescription ?: @"");
        if ([result isKindOfClass:[NSString class]] && [(NSString *)result hasPrefix:@"not found"]) {
            // The interstitial may be in an iframe; try again on the next load.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [weakSelf runConsentAutomationForURL:weakSelf.webView.URL];
            });
        }
    }];
}

- (NSString *)javaScriptStringLiteral:(NSString *)string {
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[string ?: @""] options:0 error:nil];
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (json.length < 2) { return @"\"\""; }
    return [json substringWithRange:NSMakeRange(1, json.length - 2)];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [self handleNavigationError:error];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [self handleNavigationError:error];
}

- (void)handleNavigationError:(NSError *)error {
    if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled) {
        return;
    }
    self.loading = NO;
    [self.delegate webController:self didFailWithError:error];
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
    NSLog(@"[YTM] Web content process terminated; reloading.");
    self.state = nil;
    self.loading = YES;
    if ([self.delegate respondsToSelector:@selector(webControllerDidCrash:)]) {
        [self.delegate webControllerDidCrash:self];
    }
    [webView reload];
}

#pragma mark - WKUIDelegate

- (nullable WKWebView *)webView:(WKWebView *)webView
    createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration
               forNavigationAction:(WKNavigationAction *)navigationAction
                    windowFeatures:(WKWindowFeatures *)windowFeatures {
    NSURL *url = navigationAction.request.URL;
    if (!url) { return nil; }

    if ([NSProcessInfo.processInfo.environment[@"YTM_VERBOSE"] boolValue]) {
        NSLog(@"[YTM] New window requested: %@", url.absoluteString);
    }

    NSString *scheme = url.scheme.lowercaseString;
    if ([scheme isEqualToString:@"about"] || [scheme isEqualToString:@"blob"] ||
        [scheme isEqualToString:@"data"] || [scheme isEqualToString:@"javascript"]) {
        // Scripted popups start on about:blank. Loading that into the main view
        // replaces the app with an empty black document, which is far worse than
        // simply ignoring the popup.
        return nil;
    }

    if ([self isInternalURL:url]) {
        [webView loadRequest:navigationAction.request];
    } else {
        [self openExternally:url];
    }
    return nil;
}

- (void)webView:(WKWebView *)webView
    runJavaScriptAlertPanelWithMessage:(NSString *)message
                      initiatedByFrame:(WKFrameInfo *)frame
                     completionHandler:(void (^)(void))completionHandler {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"YouTube Music";
    alert.informativeText = message;
    [alert addButtonWithTitle:@"OK"];
    [alert beginSheetModalForWindow:webView.window completionHandler:^(NSModalResponse returnCode) {
        completionHandler();
    }];
}

- (void)webView:(WKWebView *)webView
    runJavaScriptConfirmPanelWithMessage:(NSString *)message
                        initiatedByFrame:(WKFrameInfo *)frame
                       completionHandler:(void (^)(BOOL result))completionHandler {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"YouTube Music";
    alert.informativeText = message;
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert beginSheetModalForWindow:webView.window completionHandler:^(NSModalResponse returnCode) {
        completionHandler(returnCode == NSAlertFirstButtonReturn);
    }];
}

- (void)webView:(WKWebView *)webView
    runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt
                              defaultText:(nullable NSString *)defaultText
                         initiatedByFrame:(WKFrameInfo *)frame
                        completionHandler:(void (^)(NSString * _Nullable result))completionHandler {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"YouTube Music";
    alert.informativeText = prompt;
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 260, 24)];
    field.stringValue = defaultText ?: @"";
    alert.accessoryView = field;
    [alert beginSheetModalForWindow:webView.window completionHandler:^(NSModalResponse returnCode) {
        completionHandler(returnCode == NSAlertFirstButtonReturn ? field.stringValue : nil);
    }];
}

@end
