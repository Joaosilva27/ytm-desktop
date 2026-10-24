#import "MainWindowController.h"

#import "LoadingOverlayView.h"
#import "WebController.h"

static const CGFloat YTMChromeInset = 28.0;

@interface MainWindowController () <NSWindowDelegate>

@property (nonatomic, strong, readwrite) WebController *webController;
@property (nonatomic, strong) LoadingOverlayView *overlayView;

@end

@implementation MainWindowController

- (instancetype)initWithWebController:(WebController *)webController {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1280, 860)
                                                   styleMask:(NSWindowStyleMaskTitled |
                                                              NSWindowStyleMaskClosable |
                                                              NSWindowStyleMaskMiniaturizable |
                                                              NSWindowStyleMaskResizable |
                                                              NSWindowStyleMaskFullSizeContentView)
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];

    self = [super initWithWindow:window];
    if (!self) { return nil; }

    _webController = webController;

    window.title = @"YouTube Music";
    window.minSize = NSMakeSize(980, 620);
    window.backgroundColor = [NSColor colorWithSRGBRed:0.012 green:0.012 blue:0.012 alpha:1.0];
    window.titlebarAppearsTransparent = YES;
    window.titleVisibility = NSWindowTitleHidden;
    window.movableByWindowBackground = NO;
    window.collectionBehavior = NSWindowCollectionBehaviorFullScreenPrimary;
    window.tabbingMode = NSWindowTabbingModeDisallowed;
    window.restorable = NO;
    window.representedURL = [NSURL URLWithString:@"https://music.youtube.com/"];
    window.delegate = self;

    NSView *container = [[NSView alloc] initWithFrame:window.contentLayoutRect];
    container.wantsLayer = YES;
    container.layer.backgroundColor = window.backgroundColor.CGColor;
    window.contentView = container;

    WKWebView *webView = webController.webView;
    webView.frame = container.bounds;
    webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [container addSubview:webView];

    _overlayView = [[LoadingOverlayView alloc] initWithFrame:container.bounds];
    _overlayView.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:_overlayView];
    [NSLayoutConstraint activateConstraints:@[
        [_overlayView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [_overlayView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [_overlayView.topAnchor constraintEqualToAnchor:container.topAnchor],
        [_overlayView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
    ]];

    NSString *autosaveKey = [@"NSWindow Frame " stringByAppendingString:@"YTMMainWindow"];
    BOOL hasSavedFrame = [[NSUserDefaults standardUserDefaults] objectForKey:autosaveKey] != nil;
    [window setFrameAutosaveName:@"YTMMainWindow"];
    if (!hasSavedFrame) {
        NSScreen *screen = NSScreen.mainScreen;
        if (screen) {
            NSRect visible = screen.visibleFrame;
            NSSize size = NSMakeSize(MIN(1280, NSWidth(visible) - 40),
                                     MIN(860, NSHeight(visible) - 40));
            size.width = MAX(size.width, 980);
            size.height = MAX(size.height, 620);
            [window setFrame:NSMakeRect(0, 0, size.width, size.height) display:NO];
        }
        [window center];
    } else {
        NSScreen *screen = window.screen ?: NSScreen.mainScreen;
        if (screen) {
            [window setFrame:[window constrainFrameRect:window.frame toScreen:screen] display:NO];
        }
    }

    return self;
}

- (void)present {
    if (self.window.miniaturized) {
        [self.window deminiaturize:nil];
    }
    [self showWindow:nil];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)applyAlwaysOnTop:(BOOL)onTop {
    self.window.level = onTop ? NSFloatingWindowLevel : NSNormalWindowLevel;
}

#pragma mark - Overlay

- (void)showLoadingWithMessage:(NSString *)message {
    [self.overlayView showLoadingWithMessage:message];
}

- (void)hideLoading {
    [self.overlayView dismiss];
}

- (void)showLoadErrorWithMessage:(NSString *)message
                          detail:(NSString *)detail
                    retryHandler:(void (^)(void))retryHandler {
    [self.overlayView showErrorWithMessage:message detail:detail retryHandler:retryHandler];
}

#pragma mark - Full screen

- (void)windowWillEnterFullScreen:(NSNotification *)notification {
    self.webController.chromeInset = 0;
}

- (void)windowDidExitFullScreen:(NSNotification *)notification {
    self.webController.chromeInset = YTMChromeInset;
}

- (void)windowDidBecomeKey:(NSNotification *)notification {
    // Re-assert the inset in case the page replaced its <style> element.
    self.webController.chromeInset = self.window.styleMask & NSWindowStyleMaskFullScreen ? 0 : YTMChromeInset;
}

@end
