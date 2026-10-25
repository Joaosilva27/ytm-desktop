#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Owns the bundled content-rule list and the injected ad-suppression script.
@interface AdBlocker : NSObject

@property (nonatomic, readonly, getter=isEnabled) BOOL enabled;
@property (nonatomic, readonly, getter=isReady) BOOL ready;
@property (nonatomic, strong, readonly, nullable) WKUserScript *userScript;

- (instancetype)initWithUserContentController:(WKUserContentController *)controller
                                      enabled:(BOOL)enabled NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// Compiles and attaches the rule list when enabled, then calls completion on the main queue.
- (void)prepareWithCompletion:(void (^)(BOOL ready))completion;

/// Adds or removes the rule list. Calls completion on the main queue.
- (void)setEnabled:(BOOL)enabled completion:(nullable void (^)(BOOL success))completion;

@end

NS_ASSUME_NONNULL_END
