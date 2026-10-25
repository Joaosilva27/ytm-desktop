#import "MiniPlayerController.h"

#import "ArtworkLoader.h"
#import "PlaybackState.h"

static const CGFloat YTMMiniWidth = 396;
static const CGFloat YTMMiniHeight = 132;

#pragma mark - Cover

@interface YTMCoverView : NSView
@property (nonatomic, strong, nullable) NSImage *image;
@end

@implementation YTMCoverView

- (BOOL)mouseDownCanMoveWindow {
    return YES;
}

- (void)setImage:(NSImage *)image {
    _image = image;
    self.needsDisplay = YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    NSRect bounds = self.bounds;
    NSBezierPath *clip = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:12 yRadius:12];
    [clip addClip];

    NSImage *image = self.image;
    if (!image || image.size.width <= 0 || image.size.height <= 0) {
        NSGradient *gradient = [[NSGradient alloc] initWithColors:@[
            [NSColor colorWithSRGBRed:0.16 green:0.16 blue:0.17 alpha:1.0],
            [NSColor colorWithSRGBRed:0.07 green:0.07 blue:0.08 alpha:1.0]
        ]];
        [gradient drawInRect:bounds angle:-90];

        NSImage *note = [NSImage imageWithSystemSymbolName:@"music.note" accessibilityDescription:nil];
        NSImageSymbolConfiguration *configuration =
            [NSImageSymbolConfiguration configurationWithPointSize:26 weight:NSFontWeightRegular];
        note = [note imageWithSymbolConfiguration:configuration];
        note.template = YES;
        NSRect noteRect = NSMakeRect(NSMidX(bounds) - 14, NSMidY(bounds) - 14, 28, 28);
        [[NSColor colorWithWhite:1.0 alpha:0.28] set];
        [note drawInRect:noteRect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0 respectFlipped:YES hints:nil];
        return;
    }

    NSSize imageSize = image.size;
    CGFloat scale = MAX(NSWidth(bounds) / imageSize.width, NSHeight(bounds) / imageSize.height);
    NSSize drawSize = NSMakeSize(imageSize.width * scale, imageSize.height * scale);
    NSRect drawRect = NSMakeRect(NSMidX(bounds) - drawSize.width / 2,
                                 NSMidY(bounds) - drawSize.height / 2,
                                 drawSize.width, drawSize.height);
    [image drawInRect:drawRect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0 respectFlipped:YES hints:nil];
}

@end

#pragma mark - Progress

@interface YTMProgressView : NSView
@property (nonatomic, assign) double progress;
@end

@implementation YTMProgressView

- (void)setProgress:(double)progress {
    _progress = MIN(MAX(progress, 0.0), 1.0);
    self.needsDisplay = YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    NSRect bounds = self.bounds;
    CGFloat radius = NSHeight(bounds) / 2;

    NSBezierPath *track = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:radius yRadius:radius];
    [[NSColor colorWithWhite:0.5 alpha:0.25] setFill];
    [track fill];

    if (self.progress <= 0) { return; }
    CGFloat width = MAX(NSHeight(bounds), NSWidth(bounds) * self.progress);
    NSRect fillRect = NSMakeRect(0, 0, MIN(width, NSWidth(bounds)), NSHeight(bounds));
    NSBezierPath *fill = [NSBezierPath bezierPathWithRoundedRect:fillRect xRadius:radius yRadius:radius];
    [[NSColor labelColor] setFill];
    [fill fill];
}

@end

#pragma mark - Background / panel

@interface YTMMiniBackgroundView : NSVisualEffectView
@end

@implementation YTMMiniBackgroundView
- (BOOL)mouseDownCanMoveWindow {
    return YES;
}
@end

@interface YTMMiniPanel : NSPanel
@end

@implementation YTMMiniPanel
- (BOOL)canBecomeKeyWindow { return YES; }
- (BOOL)canBecomeMainWindow { return NO; }
@end

#pragma mark - Controller

@interface MiniPlayerController ()

@property (nonatomic, strong) NSPanel *panel;
@property (nonatomic, strong) YTMCoverView *coverView;
@property (nonatomic, strong) NSTextField *titleLabel;
@property (nonatomic, strong) NSTextField *artistLabel;
@property (nonatomic, strong) NSTextField *timeLabel;
@property (nonatomic, strong) YTMProgressView *progressView;
@property (nonatomic, strong) NSButton *playButton;
@property (nonatomic, strong) NSButton *previousButton;
@property (nonatomic, strong) NSButton *nextButton;
@property (nonatomic, strong) NSButton *likeButton;
@property (nonatomic, strong, nullable) PlaybackState *state;
@property (nonatomic, strong, nullable) NSURL *artworkURL;
@property (nonatomic, strong, nullable) NSURL *loadingArtworkURL;

- (void)ensureVisibleFrame;

@end

@implementation MiniPlayerController

- (instancetype)init {
    self = [super init];
    if (!self) { return nil; }

    NSPanel *panel = [[YTMMiniPanel alloc] initWithContentRect:NSMakeRect(0, 0, YTMMiniWidth, YTMMiniHeight)
                                                     styleMask:(NSWindowStyleMaskBorderless |
                                                                NSWindowStyleMaskNonactivatingPanel)
                                                       backing:NSBackingStoreBuffered
                                                         defer:NO];
    panel.opaque = NO;
    panel.backgroundColor = NSColor.clearColor;
    panel.hasShadow = YES;
    panel.level = NSFloatingWindowLevel;
    panel.collectionBehavior = (NSWindowCollectionBehaviorCanJoinAllSpaces |
                                NSWindowCollectionBehaviorFullScreenAuxiliary |
                                NSWindowCollectionBehaviorIgnoresCycle);
    panel.hidesOnDeactivate = NO;
    panel.releasedWhenClosed = NO;
    panel.excludedFromWindowsMenu = YES;
    panel.movableByWindowBackground = YES;
    panel.animationBehavior = NSWindowAnimationBehaviorUtilityWindow;
    panel.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    panel.contentMinSize = NSMakeSize(YTMMiniWidth, YTMMiniHeight);
    panel.contentMaxSize = NSMakeSize(YTMMiniWidth, YTMMiniHeight);
    if ([panel respondsToSelector:@selector(setBecomesKeyOnlyIfNeeded:)]) {
        panel.becomesKeyOnlyIfNeeded = YES;
    }
    self.panel = panel;

    YTMMiniBackgroundView *background = [[YTMMiniBackgroundView alloc] initWithFrame:panel.contentLayoutRect];
    background.material = NSVisualEffectMaterialPopover;
    background.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    background.state = NSVisualEffectStateActive;
    background.wantsLayer = YES;
    background.layer.cornerRadius = 16;
    background.layer.masksToBounds = YES;
    panel.contentView = background;

    [self buildInterfaceInView:background];
    [self positionPanelIfNeeded];

    return self;
}

- (void)buildInterfaceInView:(NSView *)view {
    _coverView = [[YTMCoverView alloc] initWithFrame:NSZeroRect];
    _coverView.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:_coverView];

    _titleLabel = [self labelWithString:@"" size:15 weight:NSFontWeightSemibold color:NSColor.labelColor];
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _titleLabel.maximumNumberOfLines = 1;
    [_titleLabel setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                                forOrientation:NSLayoutConstraintOrientationHorizontal];
    [view addSubview:_titleLabel];

    _artistLabel = [self labelWithString:@"" size:12 weight:NSFontWeightRegular color:NSColor.secondaryLabelColor];
    _artistLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _artistLabel.maximumNumberOfLines = 1;
    [_artistLabel setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                                 forOrientation:NSLayoutConstraintOrientationHorizontal];
    [view addSubview:_artistLabel];

    _progressView = [[YTMProgressView alloc] initWithFrame:NSZeroRect];
    _progressView.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:_progressView];

    _timeLabel = [self labelWithString:@"0:00 / 0:00" size:9.5 weight:NSFontWeightRegular color:NSColor.tertiaryLabelColor];
    if (@available(macOS 10.15, *)) {
        _timeLabel.font = [NSFont monospacedDigitSystemFontOfSize:9.5 weight:NSFontWeightRegular];
    }
    [view addSubview:_timeLabel];

    _previousButton = [self buttonWithSymbol:@"backward.fill" size:14 action:@selector(previousPressed:) tooltip:@"Previous"];
    _previousButton.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:_previousButton];

    _playButton = [self buttonWithSymbol:@"play.fill" size:19 action:@selector(playPausePressed:) tooltip:@"Play or Pause"];
    _playButton.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:_playButton];

    _nextButton = [self buttonWithSymbol:@"forward.fill" size:14 action:@selector(nextPressed:) tooltip:@"Next"];
    _nextButton.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:_nextButton];

    _likeButton = [self buttonWithSymbol:@"hand.thumbsup" size:13 action:@selector(likePressed:) tooltip:@"Like"];
    _likeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:_likeButton];

    NSButton *openButton = [self buttonWithSymbol:@"arrow.up.forward.square" size:13 action:@selector(openPressed:) tooltip:@"Open YouTube Music"];
    openButton.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:openButton];

    NSButton *closeButton = [self buttonWithSymbol:@"xmark" size:11 action:@selector(closePressed:) tooltip:@"Hide Mini Player"];
    closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:closeButton];

    [NSLayoutConstraint activateConstraints:@[
        [_coverView.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:16],
        [_coverView.centerYAnchor constraintEqualToAnchor:view.centerYAnchor],
        [_coverView.widthAnchor constraintEqualToConstant:100],
        [_coverView.heightAnchor constraintEqualToConstant:100],

        [closeButton.topAnchor constraintEqualToAnchor:view.topAnchor constant:12],
        [closeButton.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-12],
        [closeButton.widthAnchor constraintEqualToConstant:20],
        [closeButton.heightAnchor constraintEqualToConstant:20],

        [_titleLabel.topAnchor constraintEqualToAnchor:view.topAnchor constant:14],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_coverView.trailingAnchor constant:14],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:closeButton.leadingAnchor constant:-10],

        [_artistLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:2],
        [_artistLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_artistLabel.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-16],

        [_progressView.topAnchor constraintEqualToAnchor:_artistLabel.bottomAnchor constant:8],
        [_progressView.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_progressView.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-16],
        [_progressView.heightAnchor constraintEqualToConstant:4],

        [_timeLabel.topAnchor constraintEqualToAnchor:_progressView.bottomAnchor constant:4],
        [_timeLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_timeLabel.trailingAnchor constraintEqualToAnchor:_progressView.trailingAnchor],

        [_previousButton.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_previousButton.bottomAnchor constraintEqualToAnchor:view.bottomAnchor constant:-14],
        [_previousButton.widthAnchor constraintEqualToConstant:26],
        [_previousButton.heightAnchor constraintEqualToConstant:26],

        [_playButton.leadingAnchor constraintEqualToAnchor:_previousButton.trailingAnchor constant:8],
        [_playButton.centerYAnchor constraintEqualToAnchor:_previousButton.centerYAnchor],
        [_playButton.widthAnchor constraintEqualToConstant:28],
        [_playButton.heightAnchor constraintEqualToConstant:28],

        [_nextButton.leadingAnchor constraintEqualToAnchor:_playButton.trailingAnchor constant:8],
        [_nextButton.centerYAnchor constraintEqualToAnchor:_previousButton.centerYAnchor],
        [_nextButton.widthAnchor constraintEqualToConstant:26],
        [_nextButton.heightAnchor constraintEqualToConstant:26],

        [_likeButton.leadingAnchor constraintEqualToAnchor:_nextButton.trailingAnchor constant:14],
        [_likeButton.centerYAnchor constraintEqualToAnchor:_previousButton.centerYAnchor],
        [_likeButton.widthAnchor constraintEqualToConstant:24],
        [_likeButton.heightAnchor constraintEqualToConstant:24],

        [openButton.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-16],
        [openButton.centerYAnchor constraintEqualToAnchor:_previousButton.centerYAnchor],
        [openButton.widthAnchor constraintEqualToConstant:24],
        [openButton.heightAnchor constraintEqualToConstant:24]
    ]];

    [self updateWithState:nil];
}

- (NSTextField *)labelWithString:(NSString *)string
                            size:(CGFloat)size
                          weight:(NSFontWeight)weight
                           color:(NSColor *)color {
    NSTextField *label = [NSTextField labelWithString:string];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [NSFont systemFontOfSize:size weight:weight];
    label.textColor = color;
    label.alignment = NSTextAlignmentLeft;
    return label;
}

- (NSButton *)buttonWithSymbol:(NSString *)symbol size:(CGFloat)size action:(SEL)action tooltip:(NSString *)tooltip {
    NSImage *image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:tooltip];
    NSImageSymbolConfiguration *configuration =
        [NSImageSymbolConfiguration configurationWithPointSize:size weight:NSFontWeightMedium];
    image = [image imageWithSymbolConfiguration:configuration];
    image.template = YES;

    NSButton *button = [NSButton buttonWithImage:image target:self action:action];
    button.bordered = NO;
    button.imagePosition = NSImageOnly;
    button.imageScaling = NSImageScaleProportionallyDown;
    button.contentTintColor = NSColor.labelColor;
    button.focusRingType = NSFocusRingTypeNone;
    button.toolTip = tooltip;
    return button;
}

#pragma mark - Positioning

- (void)positionPanelIfNeeded {
    NSString *autosaveKey = [@"NSWindow Frame " stringByAppendingString:@"YTMMiniPlayer"];
    BOOL hasSavedFrame = [[NSUserDefaults standardUserDefaults] objectForKey:autosaveKey] != nil;
    [self.panel setFrameAutosaveName:@"YTMMiniPlayer"];
    if (hasSavedFrame) {
        NSScreen *screen = self.panel.screen ?: NSScreen.mainScreen;
        if (screen) {
            [self.panel setFrame:[self.panel constrainFrameRect:self.panel.frame toScreen:screen] display:NO];
        }
        // Old builds could autosave a width stretched by a long track title; always reset the size.
        NSRect frame = self.panel.frame;
        frame.size = NSMakeSize(YTMMiniWidth, YTMMiniHeight);
        [self.panel setFrame:frame display:NO];
        return;
    }

    NSScreen *screen = NSScreen.mainScreen;
    if (!screen) { return; }
    NSRect visible = screen.visibleFrame;
    NSRect frame = self.panel.frame;
    frame.size = NSMakeSize(YTMMiniWidth, YTMMiniHeight);
    frame.origin.x = NSMaxX(visible) - NSWidth(frame) - 24;
    frame.origin.y = NSMinY(visible) + 24;
    [self.panel setFrame:frame display:NO];
}

#pragma mark - Visibility

- (BOOL)isVisible {
    return self.panel.isVisible;
}

- (NSWindow *)window {
    return self.panel;
}

- (void)showWithState:(PlaybackState *)state {
    [self updateWithState:state];
    [self ensureVisibleFrame];
    [self.panel orderFrontRegardless];
}

- (void)ensureVisibleFrame {
    NSScreen *screen = self.panel.screen ?: NSScreen.mainScreen;
    if (!screen) { return; }

    NSRect frame = self.panel.frame;
    frame.size = NSMakeSize(YTMMiniWidth, YTMMiniHeight);

    NSRect visible = screen.visibleFrame;
    BOOL intersectsAnyScreen = NO;
    for (NSScreen *candidate in NSScreen.screens) {
        if (NSIntersectsRect(NSInsetRect(candidate.visibleFrame, -8, -8), frame)) {
            intersectsAnyScreen = YES;
            break;
        }
    }

    if (!intersectsAnyScreen) {
        frame.origin.x = NSMaxX(visible) - NSWidth(frame) - 24;
        frame.origin.y = NSMinY(visible) + 24;
    } else {
        frame.origin.x = MIN(MAX(frame.origin.x, NSMinX(visible) - NSWidth(frame) + 48),
                             NSMaxX(visible) - 48);
        frame.origin.y = MIN(MAX(frame.origin.y, NSMinY(visible) - 48),
                             NSMaxY(visible) - 48);
    }

    [self.panel setFrame:frame display:NO];
}

- (void)hide {
    [self.panel orderOut:nil];
    if (self.hideHandler) { self.hideHandler(); }
}

#pragma mark - State

- (void)updateWithState:(PlaybackState *)state {
    self.state = state;
    BOOL hasTrack = state.hasTrack;

    self.panel.appearance = [NSAppearance appearanceNamed:
        (state == nil || state.isDark ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua)];

    self.titleLabel.stringValue = hasTrack ? state.title : @"Not Playing";
    self.artistLabel.stringValue = hasTrack
        ? (state.subtitle.length > 0 ? state.subtitle : @"YouTube Music")
        : @"YouTube Music";
    self.playButton.image = [self imageNamed:state.isPlaying ? @"pause.fill" : @"play.fill" size:19];
    self.playButton.enabled = hasTrack;
    self.previousButton.enabled = hasTrack && state.canPrevious;
    self.nextButton.enabled = hasTrack && state.canNext;
    self.likeButton.enabled = hasTrack && state.canLike;
    self.likeButton.image = [self imageNamed:state.isLiked ? @"hand.thumbsup.fill" : @"hand.thumbsup" size:13];
    self.progressView.progress = state.progress;

    if (hasTrack && state.duration > 0) {
        self.timeLabel.stringValue = [NSString stringWithFormat:@"%@ / %@",
                                      [PlaybackState timeString:state.position],
                                      [PlaybackState timeString:state.duration]];
    } else {
        self.timeLabel.stringValue = @"0:00 / 0:00";
    }

    [self updateArtworkForState:state];
}

- (void)updateArtworkForState:(PlaybackState *)state {
    NSURL *url = state.artworkURL;
    if (!url) {
        self.artworkURL = nil;
        self.loadingArtworkURL = nil;
        self.coverView.image = nil;
        return;
    }
    if ([self.artworkURL isEqual:url] && self.coverView.image) {
        return;
    }
    self.artworkURL = url;

    NSImage *cached = [[ArtworkLoader sharedLoader] cachedImageForURL:url];
    if (cached) {
        self.coverView.image = cached;
        self.loadingArtworkURL = nil;
        return;
    }

    if ([self.loadingArtworkURL isEqual:url]) { return; }
    self.loadingArtworkURL = url;
    self.coverView.image = nil;
    __weak typeof(self) weakSelf = self;
    [[ArtworkLoader sharedLoader] loadURL:url completion:^(NSImage *image) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) { return; }
        if (![self.artworkURL isEqual:url]) { return; }
        self.loadingArtworkURL = nil;
        if (image) {
            self.coverView.image = image;
        }
    }];
}

- (NSImage *)imageNamed:(NSString *)name size:(CGFloat)size {
    NSImage *image = [NSImage imageWithSystemSymbolName:name accessibilityDescription:nil];
    NSImageSymbolConfiguration *configuration =
        [NSImageSymbolConfiguration configurationWithPointSize:size weight:NSFontWeightMedium];
    return [image imageWithSymbolConfiguration:configuration] ?: image;
}

#pragma mark - Actions

- (void)sendCommand:(NSString *)command value:(nullable id)value {
    if (self.commandHandler) {
        self.commandHandler(command, value);
    }
}

- (void)playPausePressed:(id)sender {
    [self sendCommand:@"toggle" value:nil];
}

- (void)previousPressed:(id)sender {
    [self sendCommand:@"previous" value:nil];
}

- (void)nextPressed:(id)sender {
    [self sendCommand:@"next" value:nil];
}

- (void)likePressed:(id)sender {
    [self sendCommand:@"like" value:@(!self.state.isLiked)];
}

- (void)openPressed:(id)sender {
    if (self.openWindowHandler) { self.openWindowHandler(); }
}

- (void)closePressed:(id)sender {
    [self hide];
}

@end
