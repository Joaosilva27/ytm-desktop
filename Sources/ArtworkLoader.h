#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^YTMArtworkCompletion)(NSImage * _Nullable image);

@interface ArtworkLoader : NSObject

+ (instancetype)sharedLoader;
- (nullable NSImage *)cachedImageForURL:(nullable NSURL *)url;
- (void)loadURL:(nullable NSURL *)url completion:(YTMArtworkCompletion)completion;

@end

NS_ASSUME_NONNULL_END
