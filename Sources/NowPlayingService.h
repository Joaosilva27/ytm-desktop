#import <Foundation/Foundation.h>

@class PlaybackState;

NS_ASSUME_NONNULL_BEGIN

/// Publishes the web player to Control Center, the lock screen and the media keys.
@interface NowPlayingService : NSObject

/// Called on the main queue when a remote command arrives.
@property (nonatomic, copy, nullable) void (^commandHandler)(NSString *command, id _Nullable value);

- (void)updateWithState:(nullable PlaybackState *)state;
- (void)invalidate;

@end

NS_ASSUME_NONNULL_END
