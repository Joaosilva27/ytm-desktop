#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Immutable snapshot of the web player, built from the injected JavaScript.
@interface PlaybackState : NSObject

@property (nonatomic, assign) BOOL hasTrack;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *artist;
@property (nonatomic, copy) NSString *album;
@property (nonatomic, strong, nullable) NSURL *artworkURL;
@property (nonatomic, copy) NSString *videoID;
@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, assign) NSTimeInterval position;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, assign) BOOL canSeek;
@property (nonatomic, assign) BOOL canNext;
@property (nonatomic, assign) BOOL canPrevious;
@property (nonatomic, assign) BOOL canLike;
@property (nonatomic, assign) BOOL isLiked;
@property (nonatomic, assign) BOOL hasVideo;
@property (nonatomic, assign) BOOL videoVisible;
@property (nonatomic, strong, nullable) NSURL *pageURL;
@property (nonatomic, copy) NSString *backgroundColorHex;
@property (nonatomic, assign) BOOL isDark;

@property (nonatomic, readonly) NSString *displayTitle;
@property (nonatomic, readonly) NSString *subtitle;
@property (nonatomic, readonly) NSString *remainingText;
@property (nonatomic, readonly) double progress;

- (instancetype)initWithMessage:(NSDictionary<NSString *, id> *)message NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (BOOL)isEqualToState:(PlaybackState *)other;
+ (NSString *)timeString:(NSTimeInterval)time;

@end

@interface NSColor (YTM)
+ (nullable NSColor *)ytm_colorWithCSSColor:(NSString *)cssColor;
@end

NS_ASSUME_NONNULL_END
