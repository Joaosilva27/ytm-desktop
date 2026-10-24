#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const YTMPreferencesDidChangeNotification;

@interface Preferences : NSObject

+ (instancetype)sharedPreferences;

@property (nonatomic, assign) BOOL showMenuBarPlayer;
@property (nonatomic, assign) BOOL keepPlayingOnClose;
@property (nonatomic, assign) BOOL openExternalLinksInBrowser;
@property (nonatomic, assign) BOOL alwaysOnTop;
@property (nonatomic, copy) NSString *startPage;

@end

NS_ASSUME_NONNULL_END
