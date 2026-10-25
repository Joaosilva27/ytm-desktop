#import "MainWindowController.h"

#import "LoadingOverlayView.h"
#import "WebController.h"

static const CGFloat YTMChromeInset = 28.0;

#pragma mark - Titlebar strip

/// The thin native strip above the web view. It hosts the traffic lights and the
/// mini player control, and lets the user drag the window by its top edge.
@interface YTMTitlebarStripView : NSView
@end

@implementation YTMTitlebarStripView

- (BOOL)mouseDownCanMoveWindow {
    return YES;
}

@end

@interface MainWindowController () <NSWindowDelegate>

@property (nonatomic, strong, readwrite) WebController *webController;
@property (nonatomic, strong) LoadingOverlayView *overlayView;
@property (nonatomic, strong) YTMTitlebarStripView *titlebarStrip;
@property (nonatomic, strong) NSButton *miniPlayerButton;
@property (nonatomic, strong) NSButton *videoButton;
@property (nonatomic, assign) BOOL videoButtonHasVideo;
@property (nonatomic, assign) BOOL videoButtonShowsVideo;
@property (nonatomic, strong) NSLayoutConstraint *webTopConstraint;
@property (nonatomic, assign) CGFloat chromeInset;

- (void)miniPlayerPressed:(id)sender;
- (void)videoPressed:(id)sender;
- (void)updateMiniPlayerButtonImage;
- (void)updateVideoButtonImageForVisible:(BOOL)videoVisible;

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
    webView.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:webView];

    // The 28pt titlebar strip is a real native view, not a CSS margin. Letting the
    // page start below it keeps YouTube Music's own 100vh layout untouched, which
    // avoids the WebKit compositing corruption seen with a CSS margin on the app.
    _chromeInset = YTMChromeInset;
    _webTopConstraint = [webView.topAnchor constraintEqualToAnchor:container.topAnchor
                                                         constant:_chromeInset];
    [NSLayoutConstraint activateConstraints:@[
        [webView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [webView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [webView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
        _webTopConstraint
    ]];

    _overlayView = [[LoadingOverlayView alloc] initWithFrame:NSZeroRect];
    _overlayView.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:_overlayView];
    [NSLayoutConstraint activateConstraints:@[
        [_overlayView.leadingAnchor constraintEqualToAnchor:webView.leadingAnchor],
        [_overlayView.trailingAnchor constraintEqualToAnchor:webView.trailingAnchor],
        [_overlayView.topAnchor constraintEqualToAnchor:webView.topAnchor],
        [_overlayView.bottomAnchor constraintEqualToAnchor:webView.bottomAnchor]
    ]];

    _titlebarStrip = [[YTMTitlebarStripView alloc] initWithFrame:NSZeroRect];
    _titlebarStrip.translatesAutoresizingMaskIntoConstraints = NO;
    _titlebarStrip.wantsLayer = YES;
    _titlebarStrip.layer.backgroundColor = window.backgroundColor.CGColor;
    [container addSubview:_titlebarStrip];
    [NSLayoutConstraint activateConstraints:@[
        [_titlebarStrip.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [_titlebarStrip.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [_titlebarStrip.topAnchor constraintEqualToAnchor:container.topAnchor],
        [_titlebarStrip.heightAnchor constraintEqualToConstant:YTMChromeInset]
    ]];

    _miniPlayerButton = [NSButton buttonWithTitle:@"Mini Player"
                                          target:self
                                          action:@selector(miniPlayerPressed:)];
    _miniPlayerButton.translatesAutoresizingMaskIntoConstraints = NO;
    _miniPlayerButton.bezelStyle = NSBezelStyleRounded;
    _miniPlayerButton.controlSize = NSControlSizeSmall;
    _miniPlayerButton.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    _miniPlayerButton.toolTip = @"Show or hide the floating mini player";
    [self updateMiniPlayerButtonImage];
    [_titlebarStrip addSubview:_miniPlayerButton];
    [NSLayoutConstraint activateConstraints:@[
        [_miniPlayerButton.centerYAnchor constraintEqualToAnchor:_titlebarStrip.centerYAnchor],
        [_miniPlayerButton.trailingAnchor constraintEqualToAnchor:_titlebarStrip.trailingAnchor constant:-12]
    ]];

    _videoButton = [NSButton buttonWithTitle:@"Video"
                                     target:self
                                     action:@selector(videoPressed:)];
    _videoButton.translatesAutoresizingMaskIntoConstraints = NO;
    _videoButton.bezelStyle = NSBezelStyleRounded;
    _videoButton.controlSize = NSControlSizeSmall;
    _videoButton.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    _videoButton.toolTip = @"Show the music video";
    _videoButton.hidden = YES;
    [self updateVideoButtonImageForVisible:NO];
    [_titlebarStrip addSubview:_videoButton];
    [NSLayoutConstraint activateConstraints:@[
        [_videoButton.centerYAnchor constraintEqualToAnchor:_titlebarStrip.centerYAnchor],
        [_videoButton.trailingAnchor constraintEqualToAnchor:_miniPlayerButton.leadingAnchor constant:-8]
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

#pragma mark - Titlebar controls

- (void)miniPlayerPressed:(id)sender {
    if (self.miniPlayerToggleHandler) {
        self.miniPlayerToggleHandler();
    }
}

- (void)videoPressed:(id)sender {
    if (self.videoToggleHandler) {
        self.videoToggleHandler();
    }
}

/// Test hook: exercises the same target/action path as a real click.
- (void)performMiniPlayerButtonClick {
    [self.miniPlayerButton performClick:nil];
}

- (void)performVideoButtonClick {
    [self.videoButton performClick:nil];
}

- (void)updateMiniPlayerButtonVisible:(BOOL)visible {
    self.miniPlayerButton.title = visible ? @"Hide Mini Player" : @"Mini Player";
    self.miniPlayerButton.toolTip = visible ? @"Hide the floating mini player"
                                            : @"Show the floating mini player";
    [self updateMiniPlayerButtonImage];
}

- (void)updateVideoButtonWithHasVideo:(BOOL)hasVideo videoVisible:(BOOL)videoVisible {
    // State ticks arrive every second; only rebuild the button when its meaning changes.
    if (hasVideo == self.videoButtonHasVideo && videoVisible == self.videoButtonShowsVideo) {
        return;
    }
    self.videoButtonHasVideo = hasVideo;
    self.videoButtonShowsVideo = videoVisible;

    if (!hasVideo) {
        self.videoButton.hidden = YES;
        return;
    }

    self.videoButton.hidden = NO;
    self.videoButton.title = videoVisible ? @"Audio" : @"Video";
    self.videoButton.toolTip = videoVisible ? @"Hide the music video and return to audio only"
                                            : @"Show the music video";
    [self updateVideoButtonImageForVisible:videoVisible];
}

- (void)updateVideoButtonImageForVisible:(BOOL)videoVisible {
    NSString *symbol = videoVisible ? @"music.note" : @"play.rectangle";
    NSImage *image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil];
    NSImageSymbolConfiguration *configuration =
        [NSImageSymbolConfiguration configurationWithPointSize:11 weight:NSFontWeightMedium];
    image = [image imageWithSymbolConfiguration:configuration];
    image.template = YES;
    self.videoButton.image = image;
    self.videoButton.imagePosition = image ? NSImageLeading : NSNoImage;
}

- (void)updateMiniPlayerButtonImage {
    NSString *symbol = self.miniPlayerButton.title.length > 0 &&
                       [self.miniPlayerButton.title hasPrefix:@"Hide"] ? @"pip.exit" : @"pip";
    NSImage *image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil];
    NSImageSymbolConfiguration *configuration =
        [NSImageSymbolConfiguration configurationWithPointSize:11 weight:NSFontWeightMedium];
    image = [image imageWithSymbolConfiguration:configuration];
    image.template = YES;
    self.miniPlayerButton.image = image;
    self.miniPlayerButton.imagePosition = image ? NSImageLeading : NSNoImage;
}

#pragma mark - Full screen

- (void)applyChromeInset:(CGFloat)inset {
    CGFloat clamped = MAX(0, inset);
    self.chromeInset = clamped;
    self.webTopConstraint.constant = clamped;
    self.titlebarStrip.hidden = clamped < 0.5;
    [self.window.contentView layoutSubtreeIfNeeded];
}

- (void)windowWillEnterFullScreen:(NSNotification *)notification {
    [self applyChromeInset:0];
}

- (void)windowDidExitFullScreen:(NSNotification *)notification {
    [self applyChromeInset:YTMChromeInset];
}

- (void)windowDidBecomeKey:(NSNotification *)notification {
    BOOL fullScreen = (self.window.styleMask & NSWindowStyleMaskFullScreen) != 0;
    [self applyChromeInset:fullScreen ? 0 : YTMChromeInset];
}

- (void)windowDidResize:(NSNotification *)notification {
    // Keep the native inset applied when leaving full screen through the green button.
    BOOL fullScreen = (self.window.styleMask & NSWindowStyleMaskFullScreen) != 0;
    CGFloat expected = fullScreen ? 0 : YTMChromeInset;
    if (fabs(self.chromeInset - expected) > 0.5) {
        [self applyChromeInset:expected];
    }
}

@end
