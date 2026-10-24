#import "StatusItemController.h"

#import "LoginItemManager.h"
#import "PlaybackState.h"

@interface StatusItemController () <NSMenuDelegate>

@property (nonatomic, strong, nullable) NSStatusItem *statusItem;
@property (nonatomic, strong) NSMenu *menu;
@property (nonatomic, strong, nullable) PlaybackState *state;

@property (nonatomic, strong) NSMenuItem *titleItem;
@property (nonatomic, strong) NSMenuItem *artistItem;
@property (nonatomic, strong) NSMenuItem *playPauseItem;
@property (nonatomic, strong) NSMenuItem *previousItem;
@property (nonatomic, strong) NSMenuItem *nextItem;
@property (nonatomic, strong) NSMenuItem *likeItem;
@property (nonatomic, strong) NSMenuItem *loginItem;

@end

@implementation StatusItemController

- (instancetype)init {
    self = [super init];
    if (!self) { return nil; }
    [self buildMenu];
    return self;
}

- (void)dealloc {
    if (self.statusItem) {
        [NSStatusBar.systemStatusBar removeStatusItem:self.statusItem];
    }
}

#pragma mark - Status item

- (void)setVisible:(BOOL)visible {
    BOOL currentlyVisible = self.statusItem != nil;
    if (visible == currentlyVisible) { return; }

    if (visible) {
        NSStatusItem *item = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
        item.behavior = NSStatusItemBehaviorRemovalAllowed;
        item.menu = self.menu;
        item.button.toolTip = @"YouTube Music";
        item.button.image = [self statusImageForPlaying:NO];
        self.statusItem = item;
    } else {
        [NSStatusBar.systemStatusBar removeStatusItem:self.statusItem];
        self.statusItem = nil;
    }
}

- (NSImage *)statusImageForPlaying:(BOOL)playing {
    NSString *name = playing ? @"waveform" : @"music.note";
    NSImage *image = [NSImage imageWithSystemSymbolName:name accessibilityDescription:@"YouTube Music"];
    if (!image) {
        image = [NSImage imageWithSystemSymbolName:@"music.note" accessibilityDescription:@"YouTube Music"];
    }
    image.template = YES;
    NSImageSymbolConfiguration *configuration =
        [NSImageSymbolConfiguration configurationWithPointSize:14 weight:NSFontWeightMedium];
    return [image imageWithSymbolConfiguration:configuration] ?: image;
}

#pragma mark - Menu

- (void)buildMenu {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"YouTube Music"];
    menu.autoenablesItems = NO;

    self.titleItem = [[NSMenuItem alloc] initWithTitle:@"Not Playing" action:nil keyEquivalent:@""];
    self.titleItem.enabled = NO;
    [menu addItem:self.titleItem];

    self.artistItem = [[NSMenuItem alloc] initWithTitle:@"YouTube Music" action:nil keyEquivalent:@""];
    self.artistItem.enabled = NO;
    [menu addItem:self.artistItem];

    [menu addItem:[NSMenuItem separatorItem]];

    self.previousItem = [self itemWithTitle:@"Previous" symbol:@"backward.fill" action:@selector(previous:)];
    [menu addItem:self.previousItem];

    self.playPauseItem = [self itemWithTitle:@"Play" symbol:@"play.fill" action:@selector(playPause:)];
    [menu addItem:self.playPauseItem];

    self.nextItem = [self itemWithTitle:@"Next" symbol:@"forward.fill" action:@selector(next:)];
    [menu addItem:self.nextItem];

    self.likeItem = [self itemWithTitle:@"Like" symbol:@"hand.thumbsup" action:@selector(toggleLike:)];
    [menu addItem:self.likeItem];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *show = [self itemWithTitle:@"Show YouTube Music" symbol:@"macwindow" action:@selector(showWindow:)];
    [menu addItem:show];

    NSMenuItem *mini = [self itemWithTitle:@"Mini Player" symbol:@"rectangle.compress.vertical" action:@selector(showMiniPlayer:)];
    [menu addItem:mini];

    NSMenuItem *settings = [self itemWithTitle:@"Settings…" symbol:@"gearshape" action:@selector(showSettings:)];
    [menu addItem:settings];

    [menu addItem:[NSMenuItem separatorItem]];

    self.loginItem = [self itemWithTitle:@"Launch at Login" symbol:@"power" action:@selector(toggleLoginItem:)];
    [menu addItem:self.loginItem];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *quit = [self itemWithTitle:@"Quit YouTube Music" symbol:nil action:@selector(quit:)];
    quit.keyEquivalent = @"q";
    quit.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    [menu addItem:quit];

    menu.delegate = self;
    self.menu = menu;
}

- (NSMenuItem *)itemWithTitle:(NSString *)title symbol:(NSString *)symbol action:(SEL)action {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:@""];
    item.target = self;
    if (symbol.length > 0) {
        NSImage *image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil];
        image.template = YES;
        item.image = image;
    }
    return item;
}

- (void)updateWithState:(PlaybackState *)state {
    self.state = state;
    [self updateStatusButton];
    [self updateMenuItems];
}

- (void)updateStatusButton {
    if (!self.statusItem) { return; }
    PlaybackState *state = self.state;
    self.statusItem.button.image = [self statusImageForPlaying:state.isPlaying];
    if (state.hasTrack) {
        NSString *tooltip = state.subtitle.length > 0
            ? [NSString stringWithFormat:@"%@ — %@", state.title, state.subtitle]
            : state.title;
        self.statusItem.button.toolTip = tooltip;
    } else {
        self.statusItem.button.toolTip = @"YouTube Music";
    }
}

- (void)updateMenuItems {
    PlaybackState *state = self.state;
    BOOL hasTrack = state.hasTrack;

    if (hasTrack) {
        self.titleItem.attributedTitle = [self attributedTitle:state.title
                                                          font:[NSFont systemFontOfSize:13 weight:NSFontWeightSemibold]
                                                         color:NSColor.labelColor];
        NSString *subtitle = state.subtitle;
        self.artistItem.attributedTitle = [self attributedTitle:subtitle.length > 0 ? subtitle : @"YouTube Music"
                                                          font:[NSFont systemFontOfSize:11 weight:NSFontWeightRegular]
                                                         color:NSColor.secondaryLabelColor];
        self.artistItem.hidden = subtitle.length == 0;
    } else {
        self.titleItem.attributedTitle = [self attributedTitle:@"Not Playing"
                                                          font:[NSFont systemFontOfSize:13 weight:NSFontWeightSemibold]
                                                         color:NSColor.labelColor];
        self.artistItem.attributedTitle = [self attributedTitle:@"YouTube Music"
                                                          font:[NSFont systemFontOfSize:11 weight:NSFontWeightRegular]
                                                         color:NSColor.secondaryLabelColor];
        self.artistItem.hidden = NO;
    }

    self.playPauseItem.title = state.isPlaying ? @"Pause" : @"Play";
    self.playPauseItem.image = [self menuImageNamed:state.isPlaying ? @"pause.fill" : @"play.fill"];
    self.playPauseItem.enabled = hasTrack;

    self.previousItem.enabled = hasTrack && state.canPrevious;
    self.nextItem.enabled = hasTrack && state.canNext;

    self.likeItem.title = state.isLiked ? @"Unlike" : @"Like";
    self.likeItem.image = [self menuImageNamed:state.isLiked ? @"hand.thumbsup.fill" : @"hand.thumbsup"];
    self.likeItem.enabled = hasTrack && state.canLike;

    self.loginItem.state = [LoginItemManager isEnabled] ? NSControlStateValueOn : NSControlStateValueOff;
}

- (NSImage *)menuImageNamed:(NSString *)name {
    NSImage *image = [NSImage imageWithSystemSymbolName:name accessibilityDescription:nil];
    image.template = YES;
    return image;
}

- (NSAttributedString *)attributedTitle:(NSString *)title font:(NSFont *)font color:(NSColor *)color {
    return [[NSAttributedString alloc] initWithString:title ?: @"" attributes:@{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: color
    }];
}

#pragma mark - NSMenuDelegate

- (void)menuWillOpen:(NSMenu *)menu {
    [self updateMenuItems];
}

#pragma mark - Actions

- (void)sendCommand:(NSString *)command value:(nullable id)value {
    if (self.commandHandler) {
        self.commandHandler(command, value);
    }
}

- (void)playPause:(id)sender {
    [self sendCommand:@"toggle" value:nil];
}

- (void)previous:(id)sender {
    [self sendCommand:@"previous" value:nil];
}

- (void)next:(id)sender {
    [self sendCommand:@"next" value:nil];
}

- (void)toggleLike:(id)sender {
    BOOL liked = !self.state.isLiked;
    [self sendCommand:@"like" value:@(liked)];
}

- (void)showWindow:(id)sender {
    if (self.showWindowHandler) { self.showWindowHandler(); }
}

- (void)showMiniPlayer:(id)sender {
    if (self.showMiniPlayerHandler) { self.showMiniPlayerHandler(); }
}

- (void)showSettings:(id)sender {
    if (self.showSettingsHandler) { self.showSettingsHandler(); }
}

- (void)toggleLoginItem:(id)sender {
    BOOL enable = ![LoginItemManager isEnabled];
    NSError *error = nil;
    if ([LoginItemManager setEnabled:enable error:&error]) {
        self.loginItem.state = enable ? NSControlStateValueOn : NSControlStateValueOff;
        return;
    }

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = enable ? @"Could not enable Launch at Login" : @"Could not disable Launch at Login";
    alert.informativeText = error.localizedDescription ?: @"An unknown error occurred.";
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

- (void)quit:(id)sender {
    [NSApp terminate:nil];
}

@end
