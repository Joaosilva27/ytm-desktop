#import "AppDelegate.h"

#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>

#import "MainWindowController.h"
#import "MiniPlayerController.h"
#import "NowPlayingService.h"
#import "PlaybackState.h"
#import "Preferences.h"
#import "SettingsWindowController.h"
#import "StatusItemController.h"
#import "WebController.h"

@interface AppDelegate () <WebControllerDelegate>

@property (nonatomic, strong) WebController *webController;
@property (nonatomic, strong) MainWindowController *mainWindowController;
@property (nonatomic, strong) NowPlayingService *nowPlayingService;
@property (nonatomic, strong) StatusItemController *statusItemController;
@property (nonatomic, strong) MiniPlayerController *miniPlayerController;
@property (nonatomic, strong) SettingsWindowController *settingsWindowController;
@property (nonatomic, assign) BOOL hasLoadedOnce;
@property (nonatomic, assign) BOOL showingError;

@end

@implementation AppDelegate

#pragma mark - Lifecycle

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

    [self buildMainMenu];

    self.webController = [[WebController alloc] init];
    self.webController.delegate = self;

    self.mainWindowController = [[MainWindowController alloc] initWithWebController:self.webController];
    [self.mainWindowController showLoadingWithMessage:@"Loading your library…"];
    [self.mainWindowController applyAlwaysOnTop:[Preferences sharedPreferences].alwaysOnTop];
    [self.mainWindowController present];

    self.nowPlayingService = [[NowPlayingService alloc] init];
    __weak typeof(self) weakSelf = self;
    self.mainWindowController.miniPlayerToggleHandler = ^{
        [weakSelf toggleMiniPlayer:nil];
    };
    self.nowPlayingService.commandHandler = ^(NSString *command, id value) {
        [weakSelf.webController performCommand:command value:value];
    };

    self.statusItemController = [[StatusItemController alloc] init];
    self.statusItemController.showWindowHandler = ^{
        [weakSelf.mainWindowController present];
    };
    self.statusItemController.showMiniPlayerHandler = ^{
        [weakSelf showMiniPlayer:nil];
    };
    self.statusItemController.showSettingsHandler = ^{
        [weakSelf showSettings:nil];
    };
    self.statusItemController.commandHandler = ^(NSString *command, id value) {
        [weakSelf.webController performCommand:command value:value];
    };
    [self.statusItemController setVisible:[Preferences sharedPreferences].showMenuBarPlayer];

    self.miniPlayerController = [[MiniPlayerController alloc] init];
    self.miniPlayerController.commandHandler = ^(NSString *command, id value) {
        [weakSelf.webController performCommand:command value:value];
    };
    self.miniPlayerController.openWindowHandler = ^{
        [weakSelf.mainWindowController present];
    };
    self.miniPlayerController.hideHandler = ^{
        [weakSelf.mainWindowController updateMiniPlayerButtonVisible:NO];
    };

    self.settingsWindowController = [[SettingsWindowController alloc] init];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(preferencesDidChange:)
                                                 name:YTMPreferencesDidChangeNotification
                                               object:nil];

    [self.webController loadStartPage];
    [self installAutomationHooks];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.nowPlayingService invalidate];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return ![Preferences sharedPreferences].keepPlayingOnClose;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    [self.mainWindowController present];
    return YES;
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

#pragma mark - Preferences

- (void)preferencesDidChange:(NSNotification *)notification {
    Preferences *preferences = [Preferences sharedPreferences];
    [self.statusItemController setVisible:preferences.showMenuBarPlayer];
    [self.mainWindowController applyAlwaysOnTop:preferences.alwaysOnTop];
    [self.miniPlayerController applyPreferredSize];
    [self.webController setAdBlockingEnabled:preferences.blockAds];
    [self.statusItemController updateWithState:self.webController.state];
}

- (void)handleCommand:(NSString *)command value:(nullable id)value {
    [self.webController performCommand:command value:value];
}

#pragma mark - WebControllerDelegate

- (void)webControllerDidStartLoading:(WebController *)controller {
    self.showingError = NO;
    if (!self.hasLoadedOnce) {
        [self.mainWindowController showLoadingWithMessage:@"Loading your library…"];
    }
}

- (void)webControllerDidFinishLoading:(WebController *)controller {
    self.hasLoadedOnce = YES;
    if (!self.showingError) {
        [self.mainWindowController hideLoading];
    }
}

- (void)webControllerDidBecomeReady:(WebController *)controller {
    self.hasLoadedOnce = YES;
    self.showingError = NO;
    [self.mainWindowController hideLoading];
}

- (void)webController:(WebController *)controller didFailWithError:(NSError *)error {
    self.showingError = YES;
    NSString *detail = error.localizedDescription;
    if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorNotConnectedToInternet) {
        detail = @"You appear to be offline. Check your internet connection and try again.";
    }
    __weak typeof(self) weakSelf = self;
    [self.mainWindowController showLoadErrorWithMessage:@"Couldn’t load YouTube Music"
                                                 detail:detail
                                           retryHandler:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) { return; }
        self.showingError = NO;
        [self.mainWindowController showLoadingWithMessage:@"Reconnecting…"];
        [self.webController reload];
    }];
}

- (void)webControllerDidCrash:(WebController *)controller {
    self.showingError = NO;
    [self.mainWindowController showLoadingWithMessage:@"Reloading YouTube Music…"];
}

- (void)webController:(WebController *)controller didUpdateState:(PlaybackState *)state {
    if ([NSProcessInfo.processInfo.environment[@"YTM_VERBOSE"] boolValue]) {
        NSLog(@"[YTM] state title=%@ artist=%@ playing=%d pos=%.1f/%.1f canNext=%d liked=%d",
              state.title, state.artist, state.isPlaying, state.position, state.duration,
              state.canNext, state.isLiked);
    }
    [self.nowPlayingService updateWithState:state];
    [self.statusItemController updateWithState:state];
    [self.miniPlayerController updateWithState:state];
    if (state.hasTrack) {
        self.mainWindowController.window.title = state.displayTitle;
    } else {
        self.mainWindowController.window.title = @"YouTube Music";
    }
}

- (void)webController:(WebController *)controller didChangeTitle:(NSString *)title {
    // The page title briefly flashes generic text while navigating; playback state is more reliable.
}

#pragma mark - Menu actions

- (void)togglePlayPause:(id)sender {
    [self.webController togglePlayPause];
}

- (void)nextTrack:(id)sender {
    [self.webController nextTrack];
}

- (void)previousTrack:(id)sender {
    [self.webController previousTrack];
}

- (void)toggleLike:(id)sender {
    PlaybackState *state = self.webController.state;
    [self.webController setLiked:!state.isLiked];
}

- (void)focusSearch:(id)sender {
    [self.webController focusSearch];
}

- (void)reloadPage:(id)sender {
    [self.webController reload];
}

- (void)goBack:(id)sender {
    [self.webController goBack];
}

- (void)goForward:(id)sender {
    [self.webController goForward];
}

- (void)goHome:(id)sender {
    [self.webController goHome];
}

- (void)openInBrowser:(id)sender {
    [self.webController openCurrentPageInBrowser];
}

- (void)toggleFullScreen:(id)sender {
    [self.mainWindowController.window toggleFullScreen:nil];
}

- (void)showMainWindow:(id)sender {
    [self.mainWindowController present];
}

- (void)showMiniPlayer:(id)sender {
    [self.miniPlayerController showWithState:self.webController.state];
    [self.mainWindowController updateMiniPlayerButtonVisible:YES];
}

- (void)toggleMiniPlayer:(id)sender {
    if (self.miniPlayerController.isVisible) {
        [self.miniPlayerController hide];
        [self.mainWindowController updateMiniPlayerButtonVisible:NO];
    } else {
        [self.miniPlayerController showWithState:self.webController.state];
        [self.mainWindowController updateMiniPlayerButtonVisible:YES];
    }
}

- (void)showSettings:(id)sender {
    [self.settingsWindowController present];
}

- (void)openHelp:(id)sender {
    NSURL *url = [NSURL URLWithString:@"https://support.google.com/youtubemusic"];
    if (url) { [[NSWorkspace sharedWorkspace] openURL:url]; }
}

- (void)showAbout:(id)sender {
    NSString *version = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"1.0";
    NSString *build = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"1";

    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.alignment = NSTextAlignmentCenter;
    paragraph.lineSpacing = 2;

    NSString *text = @"An unofficial desktop client for YouTube Music.\n"
                     @"Not affiliated with Google LLC. YouTube Music is a trademark of Google LLC.\n\n"
                     @"Built with AppKit and WebKit.";
    NSMutableAttributedString *credits = [[NSMutableAttributedString alloc] initWithString:text attributes:@{
        NSFontAttributeName: [NSFont systemFontOfSize:11],
        NSForegroundColorAttributeName: NSColor.secondaryLabelColor,
        NSParagraphStyleAttributeName: paragraph
    }];

    [NSApp orderFrontStandardAboutPanelWithOptions:@{
        NSAboutPanelOptionApplicationName: @"YTM",
        NSAboutPanelOptionApplicationVersion: version,
        NSAboutPanelOptionVersion: build,
        NSAboutPanelOptionCredits: credits
    }];
}

#pragma mark - Menu validation

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    SEL action = menuItem.action;
    PlaybackState *state = self.webController.state;
    BOOL hasTrack = state.hasTrack;

    if (action == @selector(togglePlayPause:)) {
        menuItem.title = state.isPlaying ? @"Pause" : @"Play";
        return hasTrack;
    }
    if (action == @selector(nextTrack:)) {
        return hasTrack && state.canNext;
    }
    if (action == @selector(previousTrack:)) {
        return hasTrack && state.canPrevious;
    }
    if (action == @selector(toggleLike:)) {
        menuItem.title = state.isLiked ? @"Unlike" : @"Like";
        menuItem.state = state.isLiked ? NSControlStateValueOn : NSControlStateValueOff;
        return hasTrack && state.canLike;
    }
    if (action == @selector(goBack:)) {
        return self.webController.canGoBack;
    }
    if (action == @selector(goForward:)) {
        return self.webController.canGoForward;
    }
    if (action == @selector(toggleFullScreen:)) {
        BOOL fullScreen = (self.mainWindowController.window.styleMask & NSWindowStyleMaskFullScreen) != 0;
        menuItem.title = fullScreen ? @"Exit Full Screen" : @"Enter Full Screen";
        return YES;
    }
    if (action == @selector(toggleMiniPlayer:)) {
        menuItem.title = self.miniPlayerController.isVisible ? @"Hide Mini Player" : @"Show Mini Player";
        return YES;
    }
    return YES;
}

#pragma mark - Dock menu

- (NSMenu *)applicationDockMenu:(NSApplication *)sender {
    PlaybackState *state = self.webController.state;
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"YouTube Music"];

    NSMenuItem *play = [[NSMenuItem alloc] initWithTitle:state.isPlaying ? @"Pause" : @"Play"
                                                  action:@selector(togglePlayPause:)
                                           keyEquivalent:@""];
    play.target = self;
    play.enabled = state.hasTrack;
    [menu addItem:play];

    NSMenuItem *next = [[NSMenuItem alloc] initWithTitle:@"Next" action:@selector(nextTrack:) keyEquivalent:@""];
    next.target = self;
    next.enabled = state.hasTrack && state.canNext;
    [menu addItem:next];

    NSMenuItem *previous = [[NSMenuItem alloc] initWithTitle:@"Previous" action:@selector(previousTrack:) keyEquivalent:@""];
    previous.target = self;
    previous.enabled = state.hasTrack && state.canPrevious;
    [menu addItem:previous];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *show = [[NSMenuItem alloc] initWithTitle:@"Show YouTube Music" action:@selector(showMainWindow:) keyEquivalent:@""];
    show.target = self;
    [menu addItem:show];

    NSMenuItem *mini = [[NSMenuItem alloc] initWithTitle:@"Show Mini Player" action:@selector(toggleMiniPlayer:) keyEquivalent:@""];
    mini.target = self;
    [menu addItem:mini];

    return menu;
}

#pragma mark - Main menu

- (void)buildMainMenu {
    NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@"Main Menu"];

    // Application
    NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:appMenuItem];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"YTM"];
    appMenuItem.submenu = appMenu;

    NSMenuItem *about = [appMenu addItemWithTitle:@"About YTM" action:@selector(showAbout:) keyEquivalent:@""];
    about.target = self;
    [appMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *settings = [appMenu addItemWithTitle:@"Settings…" action:@selector(showSettings:) keyEquivalent:@","];
    settings.target = self;
    [appMenu addItem:[NSMenuItem separatorItem]];

    NSMenu *servicesMenu = [[NSMenu alloc] initWithTitle:@"Services"];
    NSMenuItem *servicesItem = [[NSMenuItem alloc] initWithTitle:@"Services" action:nil keyEquivalent:@""];
    servicesItem.submenu = servicesMenu;
    [appMenu addItem:servicesItem];
    NSApp.servicesMenu = servicesMenu;
    [appMenu addItem:[NSMenuItem separatorItem]];

    [appMenu addItemWithTitle:@"Hide YTM" action:@selector(hide:) keyEquivalent:@"h"];
    NSMenuItem *hideOthers = [appMenu addItemWithTitle:@"Hide Others" action:@selector(hideOtherApplications:) keyEquivalent:@"h"];
    hideOthers.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagOption;
    [appMenu addItemWithTitle:@"Show All" action:@selector(unhideAllApplications:) keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *quit = [appMenu addItemWithTitle:@"Quit YTM" action:@selector(terminate:) keyEquivalent:@"q"];
    quit.keyEquivalentModifierMask = NSEventModifierFlagCommand;

    // File
    NSMenuItem *fileMenuItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:fileMenuItem];
    NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
    fileMenuItem.submenu = fileMenu;

    [fileMenu addItemWithTitle:@"Close Window" action:@selector(performClose:) keyEquivalent:@"w"];
    NSMenuItem *openBrowser = [fileMenu addItemWithTitle:@"Open in Browser"
                                                   action:@selector(openInBrowser:)
                                            keyEquivalent:@"o"];
    openBrowser.target = self;
    openBrowser.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;

    // Edit
    NSMenuItem *editMenuItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:editMenuItem];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
    editMenuItem.submenu = editMenu;

    [editMenu addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];
    NSMenuItem *redo = [editMenu addItemWithTitle:@"Redo" action:@selector(redo:) keyEquivalent:@"z"];
    redo.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
    [editMenu addItem:[NSMenuItem separatorItem]];
    [editMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
    [editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    [editMenu addItemWithTitle:@"Delete" action:@selector(delete:) keyEquivalent:@""];
    [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
    [editMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *search = [editMenu addItemWithTitle:@"Search YouTube Music"
                                             action:@selector(focusSearch:)
                                      keyEquivalent:@"f"];
    search.target = self;

    // Playback
    NSMenuItem *playbackMenuItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:playbackMenuItem];
    NSMenu *playbackMenu = [[NSMenu alloc] initWithTitle:@"Playback"];
    playbackMenuItem.submenu = playbackMenu;

    NSMenuItem *playPause = [playbackMenu addItemWithTitle:@"Play"
                                                    action:@selector(togglePlayPause:)
                                             keyEquivalent:@"p"];
    playPause.target = self;

    NSString *rightArrow = [NSString stringWithFormat:@"%C", (unichar)NSRightArrowFunctionKey];
    NSString *leftArrow = [NSString stringWithFormat:@"%C", (unichar)NSLeftArrowFunctionKey];

    NSMenuItem *next = [playbackMenu addItemWithTitle:@"Next" action:@selector(nextTrack:) keyEquivalent:rightArrow];
    next.target = self;
    next.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagOption;

    NSMenuItem *previous = [playbackMenu addItemWithTitle:@"Previous" action:@selector(previousTrack:) keyEquivalent:leftArrow];
    previous.target = self;
    previous.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagOption;

    NSMenuItem *like = [playbackMenu addItemWithTitle:@"Like" action:@selector(toggleLike:) keyEquivalent:@"l"];
    like.target = self;
    like.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;

    // View
    NSMenuItem *viewMenuItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:viewMenuItem];
    NSMenu *viewMenu = [[NSMenu alloc] initWithTitle:@"View"];
    viewMenuItem.submenu = viewMenu;

    NSMenuItem *reload = [viewMenu addItemWithTitle:@"Reload" action:@selector(reloadPage:) keyEquivalent:@"r"];
    reload.target = self;

    NSMenuItem *back = [viewMenu addItemWithTitle:@"Back" action:@selector(goBack:) keyEquivalent:@"["];
    back.target = self;

    NSMenuItem *forward = [viewMenu addItemWithTitle:@"Forward" action:@selector(goForward:) keyEquivalent:@"]"];
    forward.target = self;

    NSMenuItem *home = [viewMenu addItemWithTitle:@"Go Home" action:@selector(goHome:) keyEquivalent:@"h"];
    home.target = self;
    home.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;

    [viewMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *mini = [viewMenu addItemWithTitle:@"Show Mini Player"
                                           action:@selector(toggleMiniPlayer:)
                                    keyEquivalent:@"m"];
    mini.target = self;
    mini.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;

    [viewMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *fullScreen = [viewMenu addItemWithTitle:@"Enter Full Screen"
                                                 action:@selector(toggleFullScreen:)
                                          keyEquivalent:@"f"];
    fullScreen.target = self;
    fullScreen.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagControl;

    // Window
    NSMenuItem *windowMenuItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:windowMenuItem];
    NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];
    windowMenuItem.submenu = windowMenu;
    NSApp.windowsMenu = windowMenu;

    [windowMenu addItemWithTitle:@"Minimize" action:@selector(performMiniaturize:) keyEquivalent:@"m"];
    [windowMenu addItemWithTitle:@"Zoom" action:@selector(performZoom:) keyEquivalent:@""];
    [windowMenu addItem:[NSMenuItem separatorItem]];
    [windowMenu addItemWithTitle:@"Bring All to Front" action:@selector(arrangeInFront:) keyEquivalent:@""];

    // Help
    NSMenuItem *helpMenuItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:helpMenuItem];
    NSMenu *helpMenu = [[NSMenu alloc] initWithTitle:@"Help"];
    helpMenuItem.submenu = helpMenu;
    NSApp.helpMenu = helpMenu;

    NSMenuItem *help = [helpMenu addItemWithTitle:@"YouTube Music Help"
                                           action:@selector(openHelp:)
                                    keyEquivalent:@"?"];
    help.target = self;

    NSApp.mainMenu = mainMenu;
}

#pragma mark - Automation hooks

/// Hidden hooks used by the build scripts to validate the app without manual clicking.
- (void)installAutomationHooks {
    NSDictionary<NSString *, NSString *> *environment = NSProcessInfo.processInfo.environment;

    NSString *action = environment[@"YTM_ACTION"];
    if (action.length > 0) {
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) { return; }
            if ([action isEqualToString:@"mini"]) {
                [self showMiniPlayer:nil];
            } else if ([action isEqualToString:@"minibutton"]) {
                [self.mainWindowController performMiniPlayerButtonClick];
            } else if ([action isEqualToString:@"adblocktoggle"]) {
                Preferences *preferences = [Preferences sharedPreferences];
                preferences.blockAds = !preferences.blockAds;
            } else if ([action isEqualToString:@"settings"]) {
                [self showSettings:nil];
            } else if ([action isEqualToString:@"fullscreen"]) {
                [self toggleFullScreen:nil];
            }
        });
    }

    NSString *snapshotPath = environment[@"YTM_SNAPSHOT"];
    if (snapshotPath.length == 0) { return; }

    double delay = 8.0;
    NSString *delayValue = environment[@"YTM_SNAPSHOT_DELAY"];
    if (delayValue.length > 0) {
        delay = MAX(0.5, delayValue.doubleValue);
    }

    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) { return; }
        BOOL windowMode = [environment[@"YTM_SNAPSHOT_MODE"] isEqualToString:@"window"];
        if (windowMode) {
            NSImage *image = [self captureWindowImage];
            [self writeSnapshotImage:image path:snapshotPath error:nil];
            if ([environment[@"YTM_SNAPSHOT_EXIT"] boolValue]) {
                [NSApp terminate:nil];
            }
            return;
        }
        [self.webController takeSnapshotWithCompletion:^(NSImage *image, NSError *error) {
            [self writeSnapshotImage:image path:snapshotPath error:error];
            if ([environment[@"YTM_SNAPSHOT_EXIT"] boolValue]) {
                [NSApp terminate:nil];
            }
        }];
    });
}

- (nullable NSImage *)captureWindowImage {
    NSDictionary<NSString *, NSString *> *environment = NSProcessInfo.processInfo.environment;
    NSString *which = environment[@"YTM_SNAPSHOT_WINDOW"];
    NSWindow *window = self.mainWindowController.window;
    if ([which isEqualToString:@"mini"]) {
        window = self.miniPlayerController.window;
    } else if ([which isEqualToString:@"settings"]) {
        window = self.settingsWindowController.window;
    }
    if (!window) { return nil; }
    CGImageRef image = CGWindowListCreateImage(CGRectNull,
                                               kCGWindowListOptionIncludingWindow,
                                               (CGWindowID)window.windowNumber,
                                               kCGWindowImageBoundsIgnoreFraming);
    if (!image) { return nil; }
    NSImage *result = [[NSImage alloc] initWithCGImage:image size:NSZeroSize];
    CGImageRelease(image);
    return result;
}

- (void)writeSnapshotImage:(nullable NSImage *)image path:(NSString *)snapshotPath error:(nullable NSError *)error {
    if (!image) {
        NSLog(@"[YTM] Snapshot failed: %@", error.localizedDescription ?: @"no image");
        return;
    }

    NSBitmapImageRep *representation = nil;
    CGImageRef cgImage = [image CGImageForProposedRect:NULL context:nil hints:nil];
    if (cgImage) {
        representation = [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
    } else if (image.TIFFRepresentation) {
        representation = [NSBitmapImageRep imageRepWithData:image.TIFFRepresentation];
    }
    NSData *png = [representation representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    NSString *path = [snapshotPath stringByExpandingTildeInPath];
    if (!path.isAbsolutePath) {
        path = [[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:path];
    }
    NSError *writeError = nil;
    if (png && [png writeToFile:path options:NSDataWritingAtomic error:&writeError]) {
        NSLog(@"[YTM] Snapshot written to %@", path);
    } else {
        NSLog(@"[YTM] Snapshot failed: %@", writeError.localizedDescription ?: @"unknown error");
    }
}

@end
