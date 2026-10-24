#import "Preferences.h"

NSNotificationName const YTMPreferencesDidChangeNotification = @"YTMPreferencesDidChangeNotification";

static NSString * const KeyShowMenuBarPlayer = @"showMenuBarPlayer";
static NSString * const KeyKeepPlayingOnClose = @"keepPlayingOnClose";
static NSString * const KeyOpenExternalLinks = @"openExternalLinksInBrowser";
static NSString * const KeyAlwaysOnTop = @"alwaysOnTop";
static NSString * const KeyStartPage = @"startPage";

@implementation Preferences

+ (instancetype)sharedPreferences {
    static Preferences *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[Preferences alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (!self) { return nil; }

    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        KeyShowMenuBarPlayer: @YES,
        KeyKeepPlayingOnClose: @YES,
        KeyOpenExternalLinks: @YES,
        KeyAlwaysOnTop: @NO,
        KeyStartPage: @"https://music.youtube.com/"
    }];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    _showMenuBarPlayer = [defaults boolForKey:KeyShowMenuBarPlayer];
    _keepPlayingOnClose = [defaults boolForKey:KeyKeepPlayingOnClose];
    _openExternalLinksInBrowser = [defaults boolForKey:KeyOpenExternalLinks];
    _alwaysOnTop = [defaults boolForKey:KeyAlwaysOnTop];
    _startPage = [defaults stringForKey:KeyStartPage] ?: @"https://music.youtube.com/";
    return self;
}

- (void)setShowMenuBarPlayer:(BOOL)value {
    _showMenuBarPlayer = value;
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:KeyShowMenuBarPlayer];
    [self notify:KeyShowMenuBarPlayer];
}

- (void)setKeepPlayingOnClose:(BOOL)value {
    _keepPlayingOnClose = value;
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:KeyKeepPlayingOnClose];
    [self notify:KeyKeepPlayingOnClose];
}

- (void)setOpenExternalLinksInBrowser:(BOOL)value {
    _openExternalLinksInBrowser = value;
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:KeyOpenExternalLinks];
    [self notify:KeyOpenExternalLinks];
}

- (void)setAlwaysOnTop:(BOOL)value {
    _alwaysOnTop = value;
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:KeyAlwaysOnTop];
    [self notify:KeyAlwaysOnTop];
}

- (void)setStartPage:(NSString *)value {
    _startPage = [value copy];
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:KeyStartPage];
    [self notify:KeyStartPage];
}

- (void)notify:(NSString *)key {
    [[NSNotificationCenter defaultCenter] postNotificationName:YTMPreferencesDidChangeNotification
                                                        object:key];
}

@end
