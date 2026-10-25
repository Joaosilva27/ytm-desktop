#import "MiniPlayerController.h"

#import "ArtworkLoader.h"
#import "PlaybackState.h"
#import "Preferences.h"

typedef struct {
    CGFloat width;
    CGFloat height;
    CGFloat cornerRadius;

    CGFloat margin;
    CGFloat coverSize;
    CGFloat coverRadius;
    CGFloat coverTextGap;

    CGFloat titleTop;
    CGFloat titleSize;
    CGFloat artistSize;
    CGFloat titleTrailingGap;

    CGFloat closeTop;
    CGFloat closeTrailing;
    CGFloat closeSize;
    CGFloat closeSymbol;
    CGFloat closeGap;

    CGFloat progressTop;
    CGFloat progressHeight;
    CGFloat timeTop;
    CGFloat timeSize;

    CGFloat controlsBottom;
    CGFloat previousWidth;
    CGFloat previousSymbol;
    CGFloat playWidth;
    CGFloat playSymbol;
    CGFloat nextWidth;
    CGFloat nextSymbol;
    CGFloat likeWidth;
    CGFloat likeSymbol;
    CGFloat controlGap;
    CGFloat likeGap;
    CGFloat openWidth;
    CGFloat openSymbol;

    BOOL showsTime;
} YTMMiniMetrics;

#pragma mark - Cover

@interface YTMCoverView : NSView
@property (nonatomic, strong, nullable) NSImage *image;
@property (nonatomic, assign) CGFloat cornerRadius;
@end

@implementation YTMCoverView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _cornerRadius = 12;
    }
    return self;
}

- (BOOL)mouseDownCanMoveWindow {
    return YES;
}

- (void)setImage:(NSImage *)image {
    _image = image;
    self.needsDisplay = YES;
}

- (void)setCornerRadius:(CGFloat)cornerRadius {
    _cornerRadius = cornerRadius;
    self.needsDisplay = YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    NSRect bounds = self.bounds;
    NSBezierPath *clip = [NSBezierPath bezierPathWithRoundedRect:bounds
                                                         xRadius:self.cornerRadius
                                                         yRadius:self.cornerRadius];
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
@property (nonatomic, strong) YTMMiniBackgroundView *backgroundView;
@property (nonatomic, strong) YTMCoverView *coverView;
@property (nonatomic, strong) NSTextField *titleLabel;
@property (nonatomic, strong) NSTextField *artistLabel;
@property (nonatomic, strong) NSTextField *timeLabel;
@property (nonatomic, strong) YTMProgressView *progressView;
@property (nonatomic, strong) NSButton *playButton;
@property (nonatomic, strong) NSButton *previousButton;
@property (nonatomic, strong) NSButton *nextButton;
@property (nonatomic, strong) NSButton *likeButton;
@property (nonatomic, strong) NSButton *openButton;
@property (nonatomic, strong) NSButton *sizeButton;
@property (nonatomic, strong) NSButton *closeButton;
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *layoutConstraints;
@property (nonatomic, strong, nullable) PlaybackState *state;
@property (nonatomic, strong, nullable) NSURL *artworkURL;
@property (nonatomic, strong, nullable) NSURL *loadingArtworkURL;
@property (nonatomic, assign) YTMMiniMetrics metrics;
@property (nonatomic, assign) YTMMiniPlayerSize appliedSize;
@property (nonatomic, assign) YTMMiniPlayerSize normalSizeBeforeTiny;

- (YTMMiniMetrics)metricsForSize:(YTMMiniPlayerSize)size;
- (void)sizePressed:(id)sender;
- (void)updateSizeButton;
- (void)applyMetricsAnimated:(BOOL)animated;
- (void)resizePanelPreservingBottomRightAnimated:(BOOL)animated;
- (void)ensureVisibleFrame;

@end

@implementation MiniPlayerController

- (instancetype)init {
    self = [super init];
    if (!self) { return nil; }

    YTMMiniPlayerSize size = [Preferences sharedPreferences].miniPlayerSize;
    YTMMiniMetrics metrics = [self metricsForSize:size];
    _appliedSize = size;
    _metrics = metrics;
    _normalSizeBeforeTiny = (size == YTMMiniPlayerSizeTiny) ? YTMMiniPlayerSizeRegular : size;

    NSPanel *panel = [[YTMMiniPanel alloc] initWithContentRect:NSMakeRect(0, 0, metrics.width, metrics.height)
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
    panel.contentMinSize = NSMakeSize(metrics.width, metrics.height);
    panel.contentMaxSize = NSMakeSize(metrics.width, metrics.height);
    if ([panel respondsToSelector:@selector(setBecomesKeyOnlyIfNeeded:)]) {
        panel.becomesKeyOnlyIfNeeded = YES;
    }
    self.panel = panel;

    YTMMiniBackgroundView *background = [[YTMMiniBackgroundView alloc] initWithFrame:panel.contentLayoutRect];
    background.material = NSVisualEffectMaterialPopover;
    background.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    background.state = NSVisualEffectStateActive;
    background.wantsLayer = YES;
    background.layer.cornerRadius = metrics.cornerRadius;
    background.layer.masksToBounds = YES;
    panel.contentView = background;
    self.backgroundView = background;

    [self buildInterfaceInView:background];
    [self applyMetricsAnimated:NO];
    [self updateWithState:nil];
    [self positionPanelIfNeeded];

    return self;
}

- (YTMMiniMetrics)metricsForSize:(YTMMiniPlayerSize)size {
    if (size == YTMMiniPlayerSizeTiny) {
        return (YTMMiniMetrics){
            .width = 252,
            .height = 80,
            .cornerRadius = 12,
            .margin = 9,
            .coverSize = 58,
            .coverRadius = 8,
            .coverTextGap = 9,
            .titleTop = 8,
            .titleSize = 12,
            .artistSize = 10,
            .titleTrailingGap = 6,
            .closeTop = 5,
            .closeTrailing = 6,
            .closeSize = 15,
            .closeSymbol = 8.5,
            .closeGap = 3,
            .progressTop = 5,
            .progressHeight = 3,
            .timeTop = 3,
            .timeSize = 8.5,
            .controlsBottom = 7,
            .previousWidth = 17,
            .previousSymbol = 9.5,
            .playWidth = 19,
            .playSymbol = 13,
            .nextWidth = 17,
            .nextSymbol = 9.5,
            .likeWidth = 17,
            .likeSymbol = 9.5,
            .controlGap = 4,
            .likeGap = 7,
            .openWidth = 17,
            .openSymbol = 9.5,
            .showsTime = NO
        };
    }

    if (size == YTMMiniPlayerSizeCompact) {
        return (YTMMiniMetrics){
            .width = 324,
            .height = 104,
            .cornerRadius = 14,
            .margin = 12,
            .coverSize = 76,
            .coverRadius = 10,
            .coverTextGap = 12,
            .titleTop = 10,
            .titleSize = 13.5,
            .artistSize = 11,
            .titleTrailingGap = 8,
            .closeTop = 8,
            .closeTrailing = 8,
            .closeSize = 18,
            .closeSymbol = 10,
            .closeGap = 4,
            .progressTop = 6,
            .progressHeight = 3.5,
            .timeTop = 3,
            .timeSize = 9,
            .controlsBottom = 10,
            .previousWidth = 22,
            .previousSymbol = 12,
            .playWidth = 24,
            .playSymbol = 16,
            .nextWidth = 22,
            .nextSymbol = 12,
            .likeWidth = 20,
            .likeSymbol = 11.5,
            .controlGap = 6,
            .likeGap = 10,
            .openWidth = 20,
            .openSymbol = 11,
            .showsTime = YES
        };
    }

    return (YTMMiniMetrics){
        .width = 396,
        .height = 132,
        .cornerRadius = 16,
        .margin = 16,
        .coverSize = 100,
        .coverRadius = 12,
        .coverTextGap = 14,
        .titleTop = 14,
        .titleSize = 15,
        .artistSize = 12,
        .titleTrailingGap = 10,
        .closeTop = 12,
        .closeTrailing = 12,
        .closeSize = 20,
        .closeSymbol = 11,
        .closeGap = 5,
        .progressTop = 8,
        .progressHeight = 4,
        .timeTop = 4,
        .timeSize = 9.5,
        .controlsBottom = 14,
        .previousWidth = 26,
        .previousSymbol = 14,
        .playWidth = 28,
        .playSymbol = 19,
        .nextWidth = 26,
        .nextSymbol = 14,
        .likeWidth = 24,
        .likeSymbol = 13,
        .controlGap = 8,
        .likeGap = 14,
        .openWidth = 24,
        .openSymbol = 13,
        .showsTime = YES
    };
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
    _openButton = openButton;

    NSButton *sizeButton = [self buttonWithSymbol:@"arrow.down.right.and.arrow.up.left"
                                             size:11
                                           action:@selector(sizePressed:)
                                          tooltip:@"Make the mini player smaller"];
    sizeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:sizeButton];
    _sizeButton = sizeButton;

    NSButton *closeButton = [self buttonWithSymbol:@"xmark" size:11 action:@selector(closePressed:) tooltip:@"Hide Mini Player"];
    closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:closeButton];
    _closeButton = closeButton;
}

- (void)applyMetricsAnimated:(BOOL)animated {
    YTMMiniMetrics metrics = self.metrics;

    if (self.layoutConstraints.count > 0) {
        [NSLayoutConstraint deactivateConstraints:self.layoutConstraints];
    }

    self.backgroundView.layer.cornerRadius = metrics.cornerRadius;
    self.coverView.cornerRadius = metrics.coverRadius;
    self.titleLabel.font = [NSFont systemFontOfSize:metrics.titleSize weight:NSFontWeightSemibold];
    self.artistLabel.font = [NSFont systemFontOfSize:metrics.artistSize weight:NSFontWeightRegular];
    if (@available(macOS 10.15, *)) {
        self.timeLabel.font = [NSFont monospacedDigitSystemFontOfSize:metrics.timeSize weight:NSFontWeightRegular];
    } else {
        self.timeLabel.font = [NSFont systemFontOfSize:metrics.timeSize weight:NSFontWeightRegular];
    }
    self.timeLabel.hidden = !metrics.showsTime;

    self.previousButton.image = [self imageNamed:@"backward.fill" size:metrics.previousSymbol];
    self.playButton.image = [self imageNamed:(self.state.isPlaying ? @"pause.fill" : @"play.fill")
                                      size:metrics.playSymbol];
    self.nextButton.image = [self imageNamed:@"forward.fill" size:metrics.nextSymbol];
    self.likeButton.image = [self imageNamed:(self.state.isLiked ? @"hand.thumbsup.fill" : @"hand.thumbsup")
                                      size:metrics.likeSymbol];
    self.openButton.image = [self imageNamed:@"arrow.up.forward.square" size:metrics.openSymbol];
    self.closeButton.image = [self imageNamed:@"xmark" size:metrics.closeSymbol];
    [self updateSizeButton];

    self.layoutConstraints = @[
        [self.coverView.leadingAnchor constraintEqualToAnchor:self.backgroundView.leadingAnchor
                                                     constant:metrics.margin],
        [self.coverView.centerYAnchor constraintEqualToAnchor:self.backgroundView.centerYAnchor],
        [self.coverView.widthAnchor constraintEqualToConstant:metrics.coverSize],
        [self.coverView.heightAnchor constraintEqualToConstant:metrics.coverSize],

        [self.sizeButton.topAnchor constraintEqualToAnchor:self.backgroundView.topAnchor
                                                  constant:metrics.closeTop],
        [self.sizeButton.trailingAnchor constraintEqualToAnchor:self.closeButton.leadingAnchor
                                                       constant:-metrics.closeGap],
        [self.sizeButton.widthAnchor constraintEqualToConstant:metrics.closeSize],
        [self.sizeButton.heightAnchor constraintEqualToConstant:metrics.closeSize],

        [self.closeButton.topAnchor constraintEqualToAnchor:self.backgroundView.topAnchor
                                                   constant:metrics.closeTop],
        [self.closeButton.trailingAnchor constraintEqualToAnchor:self.backgroundView.trailingAnchor
                                                        constant:-metrics.closeTrailing],
        [self.closeButton.widthAnchor constraintEqualToConstant:metrics.closeSize],
        [self.closeButton.heightAnchor constraintEqualToConstant:metrics.closeSize],

        [self.titleLabel.topAnchor constraintEqualToAnchor:self.backgroundView.topAnchor
                                                  constant:metrics.titleTop],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.coverView.trailingAnchor
                                                      constant:metrics.coverTextGap],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.sizeButton.leadingAnchor
                                                       constant:-metrics.titleTrailingGap],

        [self.artistLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:2],
        [self.artistLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.artistLabel.trailingAnchor constraintEqualToAnchor:self.backgroundView.trailingAnchor
                                                        constant:-metrics.margin],

        [self.progressView.topAnchor constraintEqualToAnchor:self.artistLabel.bottomAnchor
                                                     constant:metrics.progressTop],
        [self.progressView.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.progressView.trailingAnchor constraintEqualToAnchor:self.backgroundView.trailingAnchor
                                                         constant:-metrics.margin],
        [self.progressView.heightAnchor constraintEqualToConstant:metrics.progressHeight],

        [self.timeLabel.topAnchor constraintEqualToAnchor:self.progressView.bottomAnchor
                                                 constant:metrics.timeTop],
        [self.timeLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.timeLabel.trailingAnchor constraintEqualToAnchor:self.progressView.trailingAnchor],

        [self.previousButton.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.previousButton.bottomAnchor constraintEqualToAnchor:self.backgroundView.bottomAnchor
                                                         constant:-metrics.controlsBottom],
        [self.previousButton.widthAnchor constraintEqualToConstant:metrics.previousWidth],
        [self.previousButton.heightAnchor constraintEqualToConstant:metrics.previousWidth],

        [self.playButton.leadingAnchor constraintEqualToAnchor:self.previousButton.trailingAnchor
                                                       constant:metrics.controlGap],
        [self.playButton.centerYAnchor constraintEqualToAnchor:self.previousButton.centerYAnchor],
        [self.playButton.widthAnchor constraintEqualToConstant:metrics.playWidth],
        [self.playButton.heightAnchor constraintEqualToConstant:metrics.playWidth],

        [self.nextButton.leadingAnchor constraintEqualToAnchor:self.playButton.trailingAnchor
                                                       constant:metrics.controlGap],
        [self.nextButton.centerYAnchor constraintEqualToAnchor:self.previousButton.centerYAnchor],
        [self.nextButton.widthAnchor constraintEqualToConstant:metrics.nextWidth],
        [self.nextButton.heightAnchor constraintEqualToConstant:metrics.nextWidth],

        [self.likeButton.leadingAnchor constraintEqualToAnchor:self.nextButton.trailingAnchor
                                                       constant:metrics.likeGap],
        [self.likeButton.centerYAnchor constraintEqualToAnchor:self.previousButton.centerYAnchor],
        [self.likeButton.widthAnchor constraintEqualToConstant:metrics.likeWidth],
        [self.likeButton.heightAnchor constraintEqualToConstant:metrics.likeWidth],

        [self.openButton.trailingAnchor constraintEqualToAnchor:self.backgroundView.trailingAnchor
                                                        constant:-metrics.margin],
        [self.openButton.centerYAnchor constraintEqualToAnchor:self.previousButton.centerYAnchor],
        [self.openButton.widthAnchor constraintEqualToConstant:metrics.openWidth],
        [self.openButton.heightAnchor constraintEqualToConstant:metrics.openWidth]
    ];
    [NSLayoutConstraint activateConstraints:self.layoutConstraints];

    self.panel.contentMinSize = NSMakeSize(1, 1);
    self.panel.contentMaxSize = NSMakeSize(metrics.width, metrics.height);
    self.panel.contentMinSize = NSMakeSize(metrics.width, metrics.height);

    [self resizePanelPreservingBottomRightAnimated:animated];
}

- (void)resizePanelPreservingBottomRightAnimated:(BOOL)animated {
    NSScreen *screen = self.panel.screen ?: NSScreen.mainScreen;
    NSRect frame = self.panel.frame;
    CGFloat right = NSMaxX(frame);
    CGFloat bottom = NSMinY(frame);

    frame.size = NSMakeSize(self.metrics.width, self.metrics.height);
    frame.origin = NSMakePoint(right - NSWidth(frame), bottom);

    if (screen) {
        NSRect visible = screen.visibleFrame;
        frame.origin.x = MIN(MAX(frame.origin.x, NSMinX(visible)),
                             NSMaxX(visible) - NSWidth(frame));
        frame.origin.y = MIN(MAX(frame.origin.y, NSMinY(visible)),
                             NSMaxY(visible) - NSHeight(frame));
    }

    [self.panel setFrame:frame display:YES animate:animated && self.panel.isVisible];
}

- (void)applyPreferredSize {
    YTMMiniPlayerSize size = [Preferences sharedPreferences].miniPlayerSize;
    YTMMiniMetrics metrics = [self metricsForSize:size];
    if (size != YTMMiniPlayerSizeTiny) {
        self.normalSizeBeforeTiny = size;
    }
    if (size == self.appliedSize &&
        metrics.width == self.metrics.width &&
        metrics.height == self.metrics.height) {
        return;
    }

    self.appliedSize = size;
    self.metrics = metrics;
    [self applyMetricsAnimated:self.panel.isVisible];
    [self ensureVisibleFrame];
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
        frame.size = NSMakeSize(self.metrics.width, self.metrics.height);
        [self.panel setFrame:frame display:NO];
        return;
    }

    NSScreen *screen = NSScreen.mainScreen;
    if (!screen) { return; }
    NSRect visible = screen.visibleFrame;
    NSRect frame = self.panel.frame;
    frame.size = NSMakeSize(self.metrics.width, self.metrics.height);
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
    frame.size = NSMakeSize(self.metrics.width, self.metrics.height);

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
    self.playButton.image = [self imageNamed:state.isPlaying ? @"pause.fill" : @"play.fill"
                                      size:self.metrics.playSymbol];
    self.playButton.enabled = hasTrack;
    self.previousButton.enabled = hasTrack && state.canPrevious;
    self.nextButton.enabled = hasTrack && state.canNext;
    self.likeButton.enabled = hasTrack && state.canLike;
    self.likeButton.image = [self imageNamed:state.isLiked ? @"hand.thumbsup.fill" : @"hand.thumbsup"
                                      size:self.metrics.likeSymbol];
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

- (void)sizePressed:(id)sender {
    YTMMiniPlayerSize current = [Preferences sharedPreferences].miniPlayerSize;
    YTMMiniPlayerSize next;
    if (current == YTMMiniPlayerSizeTiny) {
        next = self.normalSizeBeforeTiny;
    } else {
        self.normalSizeBeforeTiny = current;
        next = YTMMiniPlayerSizeTiny;
    }
    [Preferences sharedPreferences].miniPlayerSize = next;
    [self applyPreferredSize];
}

- (void)updateSizeButton {
    BOOL tiny = self.appliedSize == YTMMiniPlayerSizeTiny;
    NSString *symbol = tiny ? @"arrow.up.left.and.arrow.down.right"
                            : @"arrow.down.right.and.arrow.up.left";
    NSString *tooltip = tiny ? @"Make the mini player bigger"
                             : @"Make the mini player smaller";

    NSImage *image = [NSImage imageWithSystemSymbolName:symbol
                               accessibilityDescription:tooltip];
    NSImageSymbolConfiguration *configuration =
        [NSImageSymbolConfiguration configurationWithPointSize:MAX(10.0, self.metrics.closeSymbol)
                                                        weight:NSFontWeightMedium];
    image = [image imageWithSymbolConfiguration:configuration] ?: image;
    self.sizeButton.image = image;
    self.sizeButton.toolTip = tooltip;
}

- (void)performSizeButtonClick {
    [self.sizeButton performClick:nil];
}

- (void)closePressed:(id)sender {
    [self hide];
}

@end
