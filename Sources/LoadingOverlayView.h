#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

/// First-launch splash and error surface shown on top of the web view.
@interface LoadingOverlayView : NSView

- (void)showLoadingWithMessage:(NSString *)message;
- (void)showErrorWithMessage:(NSString *)message detail:(nullable NSString *)detail retryHandler:(void (^)(void))retryHandler;
- (void)dismiss;

@end

NS_ASSUME_NONNULL_END
