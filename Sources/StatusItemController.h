#import <AppKit/AppKit.h>

@class PlaybackState;

NS_ASSUME_NONNULL_BEGIN

@interface StatusItemController : NSObject

@property (nonatomic, copy, nullable) dispatch_block_t showWindowHandler;
@property (nonatomic, copy, nullable) dispatch_block_t showMiniPlayerHandler;
@property (nonatomic, copy, nullable) dispatch_block_t showSettingsHandler;
@property (nonatomic, copy, nullable) void (^commandHandler)(NSString *command, id _Nullable value);

- (void)setVisible:(BOOL)visible;
- (void)updateWithState:(nullable PlaybackState *)state;

@end

NS_ASSUME_NONNULL_END
