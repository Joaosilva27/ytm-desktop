#import <AppKit/AppKit.h>

@class PlaybackState;

NS_ASSUME_NONNULL_BEGIN

@interface MiniPlayerController : NSObject

@property (nonatomic, copy, nullable) void (^commandHandler)(NSString *command, id _Nullable value);
@property (nonatomic, copy, nullable) dispatch_block_t openWindowHandler;
@property (nonatomic, copy, nullable) dispatch_block_t hideHandler;

@property (nonatomic, readonly, getter=isVisible) BOOL visible;
@property (nonatomic, readonly) NSWindow *window;

- (void)showWithState:(nullable PlaybackState *)state;
- (void)hide;
- (void)updateWithState:(nullable PlaybackState *)state;

@end

NS_ASSUME_NONNULL_END
