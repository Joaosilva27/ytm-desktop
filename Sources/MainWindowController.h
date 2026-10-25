#import <AppKit/AppKit.h>

@class WebController;

NS_ASSUME_NONNULL_BEGIN

@interface MainWindowController : NSWindowController

@property (nonatomic, strong, readonly) WebController *webController;
@property (nonatomic, copy, nullable) void (^miniPlayerToggleHandler)(void);
@property (nonatomic, copy, nullable) void (^videoToggleHandler)(void);

- (instancetype)initWithWebController:(WebController *)webController;

- (void)present;
- (void)applyAlwaysOnTop:(BOOL)onTop;
- (void)updateMiniPlayerButtonVisible:(BOOL)visible;
- (void)updateVideoButtonWithHasVideo:(BOOL)hasVideo videoVisible:(BOOL)videoVisible;
- (void)performMiniPlayerButtonClick;
- (void)performVideoButtonClick;
- (void)showLoadingWithMessage:(NSString *)message;
- (void)hideLoading;
- (void)showLoadErrorWithMessage:(NSString *)message
                          detail:(nullable NSString *)detail
                    retryHandler:(void (^)(void))retryHandler;

@end

NS_ASSUME_NONNULL_END
