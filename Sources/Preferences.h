#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const YTMPreferencesDidChangeNotification;

typedef NS_ENUM(NSInteger, YTMMiniPlayerSize) {
    YTMMiniPlayerSizeRegular = 0,
    YTMMiniPlayerSizeCompact = 1,
    YTMMiniPlayerSizeTiny = 2
};

@interface Preferences : NSObject

+ (instancetype)sharedPreferences;

@property (nonatomic, assign) BOOL showMenuBarPlayer;
@property (nonatomic, assign) BOOL keepPlayingOnClose;
@property (nonatomic, assign) BOOL openExternalLinksInBrowser;
@property (nonatomic, assign) BOOL alwaysOnTop;
@property (nonatomic, assign) YTMMiniPlayerSize miniPlayerSize;
@property (nonatomic, assign) BOOL blockAds;
@property (nonatomic, copy) NSString *startPage;

@end

NS_ASSUME_NONNULL_END
