#import <AppKit/AppKit.h>

@class WebController;

NS_ASSUME_NONNULL_BEGIN

@interface MainWindowController : NSWindowController

@property (nonatomic, strong, readonly) WebController *webController;

- (instancetype)initWithWebController:(WebController *)webController;

- (void)present;
- (void)applyAlwaysOnTop:(BOOL)onTop;
- (void)showLoadingWithMessage:(NSString *)message;
- (void)hideLoading;
- (void)showLoadErrorWithMessage:(NSString *)message
                          detail:(nullable NSString *)detail
                    retryHandler:(void (^)(void))retryHandler;

@end

NS_ASSUME_NONNULL_END
