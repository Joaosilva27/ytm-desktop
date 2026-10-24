#import "LoadingOverlayView.h"

#import <QuartzCore/QuartzCore.h>

#pragma mark - Logo

@interface YTMPlayLogoView : NSView
@end

@implementation YTMPlayLogoView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (!self) { return nil; }
    self.translatesAutoresizingMaskIntoConstraints = NO;
    return self;
}

- (BOOL)isFlipped {
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    NSRect bounds = NSInsetRect(self.bounds, 2, 2);
    NSBezierPath *squircle = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:22 yRadius:22];

    NSGradient *gradient = [[NSGradient alloc] initWithColors:@[
        [NSColor colorWithSRGBRed:1.0 green:0.19 blue:0.25 alpha:1.0],
        [NSColor colorWithSRGBRed:0.78 green:0.0 blue:0.16 alpha:1.0]
    ]];
    [gradient drawInBezierPath:squircle angle:-90];

    // Soft top highlight.
    NSBezierPath *highlight = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(bounds, 1, 1)
                                                              xRadius:21
                                                              yRadius:21];
    [[NSColor colorWithWhite:1.0 alpha:0.16] setStroke];
    highlight.lineWidth = 1;
    [highlight stroke];

    CGFloat side = bounds.size.width;
    CGFloat triangleHeight = side * 0.42;
    CGFloat triangleWidth = side * 0.36;
    CGFloat cx = NSMidX(bounds) + side * 0.025;
    CGFloat cy = NSMidY(bounds);

    NSBezierPath *play = [NSBezierPath bezierPath];
    [play moveToPoint:NSMakePoint(cx - triangleWidth / 2, cy - triangleHeight / 2)];
    [play lineToPoint:NSMakePoint(cx - triangleWidth / 2, cy + triangleHeight / 2)];
    [play lineToPoint:NSMakePoint(cx + triangleWidth / 2, cy)];
    [play closePath];
    [[NSColor whiteColor] setFill];
    [play fill];
}

@end

#pragma mark - Overlay

@interface LoadingOverlayView ()

@property (nonatomic, strong) NSView *card;
@property (nonatomic, strong) YTMPlayLogoView *logoView;
@property (nonatomic, strong) NSTextField *titleLabel;
@property (nonatomic, strong) NSTextField *detailLabel;
@property (nonatomic, strong) NSProgressIndicator *spinner;
@property (nonatomic, strong) NSButton *retryButton;
@property (nonatomic, copy, nullable) dispatch_block_t retryHandler;

@end

@implementation LoadingOverlayView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (!self) { return nil; }

    self.wantsLayer = YES;
    self.layer.backgroundColor = [NSColor colorWithSRGBRed:0.012 green:0.012 blue:0.012 alpha:1.0].CGColor;
    // The splash stays black in both themes, so render its controls in dark mode.
    self.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];

    _logoView = [[YTMPlayLogoView alloc] initWithFrame:NSMakeRect(0, 0, 76, 76)];

    _titleLabel = [self labelWithString:@"YouTube Music" size:17 weight:NSFontWeightSemibold color:[NSColor whiteColor]];
    _detailLabel = [self labelWithString:@"Loading your library…" size:12 weight:NSFontWeightRegular
                                   color:[NSColor colorWithWhite:1.0 alpha:0.55]];
    _detailLabel.alignment = NSTextAlignmentCenter;
    _detailLabel.maximumNumberOfLines = 3;
    _detailLabel.lineBreakMode = NSLineBreakByWordWrapping;
    _detailLabel.preferredMaxLayoutWidth = 360;

    _spinner = [[NSProgressIndicator alloc] init];
    _spinner.translatesAutoresizingMaskIntoConstraints = NO;
    _spinner.style = NSProgressIndicatorStyleSpinning;
    _spinner.controlSize = NSControlSizeSmall;
    _spinner.indeterminate = YES;
    _spinner.displayedWhenStopped = NO;
    [_spinner startAnimation:nil];

    _retryButton = [NSButton buttonWithTitle:@"Try Again" target:self action:@selector(retryPressed:)];
    _retryButton.bezelStyle = NSBezelStyleRounded;
    _retryButton.keyEquivalent = @"\r";
    _retryButton.hidden = YES;

    NSStackView *stack = [NSStackView stackViewWithViews:@[_logoView, _titleLabel, _detailLabel, _spinner, _retryButton]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeCenterX;
    stack.spacing = 12;
    [stack setCustomSpacing:20 afterView:_detailLabel];
    [stack setCustomSpacing:20 afterView:_spinner];
    [self addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [_logoView.widthAnchor constraintEqualToConstant:76],
        [_logoView.heightAnchor constraintEqualToConstant:76],
        [stack.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:-12],
        [stack.widthAnchor constraintLessThanOrEqualToAnchor:self.widthAnchor constant:-48],
        [_detailLabel.widthAnchor constraintEqualToConstant:360]
    ]];

    return self;
}

- (BOOL)isOpaque {
    return YES;
}

- (NSTextField *)labelWithString:(NSString *)string
                            size:(CGFloat)size
                          weight:(NSFontWeight)weight
                           color:(NSColor *)color {
    NSTextField *label = [NSTextField labelWithString:string];
    label.font = [NSFont systemFontOfSize:size weight:weight];
    label.textColor = color;
    label.alignment = NSTextAlignmentCenter;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
}

#pragma mark - States

- (void)showLoadingWithMessage:(NSString *)message {
    self.retryHandler = nil;
    self.hidden = NO;
    self.alphaValue = 1.0;
    self.detailLabel.hidden = NO;
    self.detailLabel.stringValue = message.length > 0 ? message : @"Loading your library…";
    self.spinner.hidden = NO;
    [self.spinner startAnimation:nil];
    self.retryButton.hidden = YES;
    self.titleLabel.stringValue = @"YouTube Music";
}

- (void)showErrorWithMessage:(NSString *)message
                      detail:(NSString *)detail
                retryHandler:(void (^)(void))retryHandler {
    self.retryHandler = [retryHandler copy];
    self.hidden = NO;
    self.alphaValue = 1.0;
    self.titleLabel.stringValue = message.length > 0 ? message : @"Something went wrong";
    self.detailLabel.hidden = detail.length == 0;
    self.detailLabel.stringValue = detail ?: @"";
    [self.spinner stopAnimation:nil];
    self.spinner.hidden = YES;
    self.retryButton.hidden = NO;
}

- (void)dismiss {
    if (self.hidden) { return; }
    BOOL reduceMotion = NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion;
    if (reduceMotion) {
        self.hidden = YES;
        return;
    }
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.35;
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        self.animator.alphaValue = 0.0;
    } completionHandler:^{
        self.hidden = YES;
        self.alphaValue = 1.0;
    }];
}

#pragma mark - Actions

- (void)retryPressed:(id)sender {
    dispatch_block_t handler = self.retryHandler;
    if (handler) { handler(); }
}

@end
