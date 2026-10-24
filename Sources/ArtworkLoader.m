#import "ArtworkLoader.h"

@interface ArtworkLoader ()
@property (nonatomic, strong) NSCache<NSURL *, NSImage *> *cache;
@property (nonatomic, strong) NSMutableDictionary<NSURL *, NSMutableArray<YTMArtworkCompletion> *> *pending;
@property (nonatomic, strong) NSURLSession *session;
@end

@implementation ArtworkLoader

+ (instancetype)sharedLoader {
    static ArtworkLoader *loader;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        loader = [[ArtworkLoader alloc] init];
    });
    return loader;
}

- (instancetype)init {
    self = [super init];
    if (!self) { return nil; }
    _cache = [[NSCache alloc] init];
    _cache.countLimit = 64;
    _pending = [NSMutableDictionary dictionary];

    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    configuration.requestCachePolicy = NSURLRequestReturnCacheDataElseLoad;
    configuration.URLCache = [[NSURLCache alloc] initWithMemoryCapacity:10 * 1024 * 1024
                                                          diskCapacity:100 * 1024 * 1024
                                                              diskPath:nil];
    _session = [NSURLSession sessionWithConfiguration:configuration];
    return self;
}

- (NSImage *)cachedImageForURL:(NSURL *)url {
    if (!url) { return nil; }
    return [self.cache objectForKey:url];
}

- (void)loadURL:(NSURL *)url completion:(YTMArtworkCompletion)completion {
    if (!completion) { return; }
    if (!url) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(nil); });
        return;
    }
    NSImage *cached = [self.cache objectForKey:url];
    if (cached) {
        if ([NSThread isMainThread]) {
            completion(cached);
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(cached); });
        }
        return;
    }

    NSMutableArray<YTMArtworkCompletion> *callbacks = self.pending[url];
    if (callbacks) {
        [callbacks addObject:[completion copy]];
        return;
    }
    callbacks = [NSMutableArray arrayWithObject:[completion copy]];
    self.pending[url] = callbacks;

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [self.session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) { return; }
        NSImage *image = nil;
        if (data && !error) {
            NSInteger status = [(NSHTTPURLResponse *)response statusCode];
            if (status >= 200 && status < 300) {
                image = [[NSImage alloc] initWithData:data];
            }
        }
        if (image) {
            [self.cache setObject:image forKey:url];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            NSMutableArray<YTMArtworkCompletion> *callbacks = self.pending[url];
            [self.pending removeObjectForKey:url];
            for (YTMArtworkCompletion callback in callbacks) {
                callback(image);
            }
        });
    }];
    [task resume];
}

@end
