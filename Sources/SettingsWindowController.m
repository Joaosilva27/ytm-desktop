#import "SettingsWindowController.h"

#import "LoginItemManager.h"
#import "Preferences.h"

@interface SettingsWindowController () <NSTextFieldDelegate>

@property (nonatomic, strong) NSButton *menuBarCheckbox;
@property (nonatomic, strong) NSButton *keepPlayingCheckbox;
@property (nonatomic, strong) NSButton *alwaysOnTopCheckbox;
@property (nonatomic, strong) NSButton *blockAdsCheckbox;
@property (nonatomic, strong) NSButton *externalLinksCheckbox;
@property (nonatomic, strong) NSButton *loginCheckbox;
@property (nonatomic, strong) NSTextField *startPageField;
@property (nonatomic, strong) NSPopUpButton *miniPlayerSizePopUp;

@end

@implementation SettingsWindowController

- (instancetype)init {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 500, 560)
                                                   styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    self = [super initWithWindow:window];
    if (!self) { return nil; }

    window.title = @"Settings";
    window.restorable = NO;
    window.releasedWhenClosed = NO;
    window.collectionBehavior = NSWindowCollectionBehaviorFullScreenAuxiliary;

    NSView *content = [[NSView alloc] initWithFrame:window.contentLayoutRect];
    window.contentView = content;

    NSStackView *stack = [NSStackView stackViewWithViews:@[]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 8;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:28],
        [stack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-28],
        [stack.topAnchor constraintEqualToAnchor:content.topAnchor constant:24]
    ]];

    [stack addArrangedSubview:[self sectionLabel:@"Window"]];
    [stack setCustomSpacing:10 afterView:stack.arrangedSubviews.lastObject];

    self.menuBarCheckbox = [self checkboxWithTitle:@"Show player in the menu bar"
                                            action:@selector(menuBarChanged:)];
    [stack addArrangedSubview:self.menuBarCheckbox];

    self.keepPlayingCheckbox = [self checkboxWithTitle:@"Keep playing when the window is closed"
                                                action:@selector(keepPlayingChanged:)];
    [stack addArrangedSubview:self.keepPlayingCheckbox];

    self.alwaysOnTopCheckbox = [self checkboxWithTitle:@"Keep the window always on top"
                                                action:@selector(alwaysOnTopChanged:)];
    [stack addArrangedSubview:self.alwaysOnTopCheckbox];
    [stack setCustomSpacing:22 afterView:self.alwaysOnTopCheckbox];

    [stack addArrangedSubview:[self sectionLabel:@"Mini Player"]];
    [stack setCustomSpacing:10 afterView:stack.arrangedSubviews.lastObject];

    NSTextField *sizeLabel = [NSTextField labelWithString:@"Size"];
    sizeLabel.font = [NSFont systemFontOfSize:13];
    sizeLabel.textColor = NSColor.secondaryLabelColor;
    sizeLabel.translatesAutoresizingMaskIntoConstraints = NO;

    self.miniPlayerSizePopUp = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    self.miniPlayerSizePopUp.translatesAutoresizingMaskIntoConstraints = NO;
    self.miniPlayerSizePopUp.font = [NSFont systemFontOfSize:13];
    self.miniPlayerSizePopUp.target = self;
    self.miniPlayerSizePopUp.action = @selector(miniPlayerSizeChanged:);
    NSArray<NSString *> *miniPlayerSizeTitles = @[@"Regular", @"Compact", @"Tiny"];
    for (NSUInteger index = 0; index < miniPlayerSizeTitles.count; index++) {
        [self.miniPlayerSizePopUp addItemWithTitle:miniPlayerSizeTitles[index]];
        self.miniPlayerSizePopUp.lastItem.tag = (NSInteger)index;
    }
    [self.miniPlayerSizePopUp.widthAnchor constraintEqualToConstant:140].active = YES;

    NSStackView *sizeRow = [NSStackView stackViewWithViews:@[sizeLabel, self.miniPlayerSizePopUp]];
    sizeRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    sizeRow.alignment = NSLayoutAttributeCenterY;
    sizeRow.spacing = 8;
    sizeRow.translatesAutoresizingMaskIntoConstraints = NO;
    [stack addArrangedSubview:sizeRow];

    NSTextField *miniPlayerHint = [NSTextField labelWithString:
        @"The floating player keeps its bottom-right corner when resized."];
    miniPlayerHint.font = [NSFont systemFontOfSize:11];
    miniPlayerHint.textColor = NSColor.secondaryLabelColor;
    miniPlayerHint.translatesAutoresizingMaskIntoConstraints = NO;
    [stack addArrangedSubview:miniPlayerHint];
    [stack setCustomSpacing:22 afterView:miniPlayerHint];

    [stack addArrangedSubview:[self sectionLabel:@"Privacy"]];
    [stack setCustomSpacing:10 afterView:stack.arrangedSubviews.lastObject];

    self.blockAdsCheckbox = [self checkboxWithTitle:@"Block ads and sponsored content"
                                            action:@selector(blockAdsChanged:)];
    self.blockAdsCheckbox.toolTip = @"Uses a bundled content filter and skips in-player ads. Changing this reloads YouTube Music.";
    [stack addArrangedSubview:self.blockAdsCheckbox];
    [stack setCustomSpacing:22 afterView:self.blockAdsCheckbox];

    [stack addArrangedSubview:[self sectionLabel:@"Links"]];
    [stack setCustomSpacing:10 afterView:stack.arrangedSubviews.lastObject];

    self.externalLinksCheckbox = [self checkboxWithTitle:@"Open external links in your default browser"
                                                  action:@selector(externalLinksChanged:)];
    [stack addArrangedSubview:self.externalLinksCheckbox];
    [stack setCustomSpacing:22 afterView:self.externalLinksCheckbox];

    [stack addArrangedSubview:[self sectionLabel:@"Startup"]];
    [stack setCustomSpacing:10 afterView:stack.arrangedSubviews.lastObject];

    self.loginCheckbox = [self checkboxWithTitle:@"Launch YouTube Music at login"
                                          action:@selector(loginItemChanged:)];
    [stack addArrangedSubview:self.loginCheckbox];
    [stack setCustomSpacing:16 afterView:self.loginCheckbox];

    NSTextField *startPageLabel = [self sectionLabel:@"Start page"];
    [stack addArrangedSubview:startPageLabel];
    [stack setCustomSpacing:6 afterView:startPageLabel];

    self.startPageField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 320, 24)];
    self.startPageField.translatesAutoresizingMaskIntoConstraints = NO;
    self.startPageField.placeholderString = @"https://music.youtube.com/";
    self.startPageField.font = [NSFont systemFontOfSize:12];
    self.startPageField.delegate = self;
    self.startPageField.target = self;
    self.startPageField.action = @selector(commitStartPage:);
    self.startPageField.usesSingleLineMode = YES;

    NSButton *restoreStartPage = [NSButton buttonWithTitle:@"Reset"
                                                    target:self
                                                    action:@selector(resetStartPage:)];
    restoreStartPage.bezelStyle = NSBezelStyleRounded;
    restoreStartPage.controlSize = NSControlSizeSmall;

    NSStackView *pageRow = [NSStackView stackViewWithViews:@[self.startPageField, restoreStartPage]];
    pageRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    pageRow.alignment = NSLayoutAttributeCenterY;
    pageRow.spacing = 8;
    pageRow.translatesAutoresizingMaskIntoConstraints = NO;
    [stack addArrangedSubview:pageRow];
    [pageRow.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
    [self.startPageField.widthAnchor constraintEqualToConstant:340].active = YES;

    NSTextField *hint = [NSTextField labelWithString:@"Used when YouTube Music launches. Leave empty to use music.youtube.com."];
    hint.font = [NSFont systemFontOfSize:11];
    hint.textColor = NSColor.secondaryLabelColor;
    hint.translatesAutoresizingMaskIntoConstraints = NO;
    [stack addArrangedSubview:hint];

    [stack setCustomSpacing:28 afterView:hint];

    NSBox *separator = [[NSBox alloc] initWithFrame:NSMakeRect(0, 0, 444, 1)];
    separator.boxType = NSBoxSeparator;
    separator.translatesAutoresizingMaskIntoConstraints = NO;
    [stack addArrangedSubview:separator];
    [separator.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
    [stack setCustomSpacing:12 afterView:separator];

    NSButton *restore = [NSButton buttonWithTitle:@"Restore Defaults"
                                           target:self
                                           action:@selector(restoreDefaults:)];
    restore.bezelStyle = NSBezelStyleRounded;
    restore.controlSize = NSControlSizeSmall;

    NSString *version = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"1.0";
    NSTextField *versionLabel = [NSTextField labelWithString:
        [NSString stringWithFormat:@"YouTube Music %@ · Unofficial client", version]];
    versionLabel.font = [NSFont systemFontOfSize:11];
    versionLabel.textColor = NSColor.tertiaryLabelColor;
    versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    versionLabel.alignment = NSTextAlignmentRight;

    NSStackView *footer = [NSStackView stackViewWithViews:@[restore, versionLabel]];
    footer.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    footer.alignment = NSLayoutAttributeCenterY;
    footer.spacing = 8;
    footer.translatesAutoresizingMaskIntoConstraints = NO;
    [stack addArrangedSubview:footer];
    [footer.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;

    [self syncControls];

    return self;
}

- (void)present {
    [self syncControls];
    if (!self.window.isVisible) {
        [self.window center];
    }
    [self showWindow:nil];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

#pragma mark - Helpers

- (NSTextField *)sectionLabel:(NSString *)string {
    NSTextField *label = [NSTextField labelWithString:string];
    label.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    label.textColor = NSColor.labelColor;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
}

- (NSButton *)checkboxWithTitle:(NSString *)title action:(SEL)action {
    NSButton *checkbox = [NSButton checkboxWithTitle:title target:self action:action];
    checkbox.font = [NSFont systemFontOfSize:13];
    checkbox.translatesAutoresizingMaskIntoConstraints = NO;
    return checkbox;
}

- (void)syncControls {
    Preferences *preferences = [Preferences sharedPreferences];
    self.menuBarCheckbox.state = preferences.showMenuBarPlayer ? NSControlStateValueOn : NSControlStateValueOff;
    self.keepPlayingCheckbox.state = preferences.keepPlayingOnClose ? NSControlStateValueOn : NSControlStateValueOff;
    self.alwaysOnTopCheckbox.state = preferences.alwaysOnTop ? NSControlStateValueOn : NSControlStateValueOff;
    self.blockAdsCheckbox.state = preferences.blockAds ? NSControlStateValueOn : NSControlStateValueOff;
    self.externalLinksCheckbox.state = preferences.openExternalLinksInBrowser ? NSControlStateValueOn : NSControlStateValueOff;
    self.loginCheckbox.state = [LoginItemManager isEnabled] ? NSControlStateValueOn : NSControlStateValueOff;
    self.startPageField.stringValue = preferences.startPage;
    NSInteger sizeIndex = [self.miniPlayerSizePopUp indexOfItemWithTag:preferences.miniPlayerSize];
    if (sizeIndex >= 0) {
        [self.miniPlayerSizePopUp selectItemAtIndex:sizeIndex];
    }
}

#pragma mark - Actions

- (void)menuBarChanged:(NSButton *)sender {
    [Preferences sharedPreferences].showMenuBarPlayer = sender.state == NSControlStateValueOn;
}

- (void)keepPlayingChanged:(NSButton *)sender {
    [Preferences sharedPreferences].keepPlayingOnClose = sender.state == NSControlStateValueOn;
}

- (void)alwaysOnTopChanged:(NSButton *)sender {
    [Preferences sharedPreferences].alwaysOnTop = sender.state == NSControlStateValueOn;
}

- (void)blockAdsChanged:(NSButton *)sender {
    [Preferences sharedPreferences].blockAds = sender.state == NSControlStateValueOn;
}

- (void)externalLinksChanged:(NSButton *)sender {
    [Preferences sharedPreferences].openExternalLinksInBrowser = sender.state == NSControlStateValueOn;
}

- (void)miniPlayerSizeChanged:(NSPopUpButton *)sender {
    [Preferences sharedPreferences].miniPlayerSize = (YTMMiniPlayerSize)sender.selectedTag;
}

- (void)loginItemChanged:(NSButton *)sender {
    BOOL enable = sender.state == NSControlStateValueOn;
    NSError *error = nil;
    if ([LoginItemManager setEnabled:enable error:&error]) {
        return;
    }

    sender.state = enable ? NSControlStateValueOff : NSControlStateValueOn;
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = enable ? @"Could not enable Launch at Login" : @"Could not disable Launch at Login";
    alert.informativeText = error.localizedDescription ?: @"An unknown error occurred.";
    [alert addButtonWithTitle:@"OK"];
    if (self.window.isVisible) {
        [alert beginSheetModalForWindow:self.window completionHandler:nil];
    } else {
        [alert runModal];
    }
}

- (void)commitStartPage:(id)sender {
    [self.window makeFirstResponder:nil];
    [self applyStartPageFieldValue];
}

- (void)applyStartPageFieldValue {
    NSString *raw = [self.startPageField.stringValue stringByTrimmingCharactersInSet:
                     [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (raw.length == 0) {
        NSString *fallback = @"https://music.youtube.com/";
        self.startPageField.stringValue = fallback;
        [Preferences sharedPreferences].startPage = fallback;
        return;
    }

    NSString *normalized = raw;
    if (![normalized containsString:@"://"]) {
        normalized = [@"https://" stringByAppendingString:normalized];
    }
    NSURL *url = [NSURL URLWithString:normalized];
    if (!url || !url.host.length) {
        NSBeep();
        self.startPageField.stringValue = [Preferences sharedPreferences].startPage;
        return;
    }
    NSString *scheme = url.scheme.lowercaseString;
    if (![scheme isEqualToString:@"https"] && ![scheme isEqualToString:@"http"]) {
        NSBeep();
        self.startPageField.stringValue = [Preferences sharedPreferences].startPage;
        return;
    }
    self.startPageField.stringValue = normalized;
    [Preferences sharedPreferences].startPage = normalized;
}

- (void)resetStartPage:(id)sender {
    self.startPageField.stringValue = @"https://music.youtube.com/";
    [self applyStartPageFieldValue];
}

- (void)restoreDefaults:(id)sender {
    Preferences *preferences = [Preferences sharedPreferences];
    preferences.showMenuBarPlayer = YES;
    preferences.keepPlayingOnClose = YES;
    preferences.openExternalLinksInBrowser = YES;
    preferences.alwaysOnTop = NO;
    preferences.miniPlayerSize = YTMMiniPlayerSizeRegular;
    preferences.blockAds = YES;
    preferences.startPage = @"https://music.youtube.com/";
    [self syncControls];
}

#pragma mark - NSTextFieldDelegate

- (void)controlTextDidEndEditing:(NSNotification *)notification {
    if (notification.object == self.startPageField) {
        [self applyStartPageFieldValue];
    }
}

@end
