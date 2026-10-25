#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>

#import "PlaybackState.h"

NS_ASSUME_NONNULL_BEGIN

@class WebController;

@protocol WebControllerDelegate <NSObject>

@optional
- (void)webController:(WebController *)controller didUpdateState:(PlaybackState *)state;
- (void)webControllerDidStartLoading:(WebController *)controller;
- (void)webControllerDidFinishLoading:(WebController *)controller;
- (void)webControllerDidBecomeReady:(WebController *)controller;
- (void)webController:(WebController *)controller didFailWithError:(NSError *)error;
- (void)webController:(WebController *)controller didChangeTitle:(nullable NSString *)title;
- (void)webControllerDidCrash:(WebController *)controller;

@end

/// Owns the WKWebView that hosts music.youtube.com and the JavaScript bridge.
@interface WebController : NSObject

@property (nonatomic, strong, readonly) WKWebView *webView;
@property (nonatomic, weak, nullable) id<WebControllerDelegate> delegate;

/// Latest state reported by the page. Never mutated; a new object is produced for each update.
@property (nonatomic, strong, readonly, nullable) PlaybackState *state;

@property (nonatomic, readonly, getter=isLoading) BOOL loading;
@property (nonatomic, readonly) BOOL canGoBack;
@property (nonatomic, readonly) BOOL canGoForward;

- (instancetype)init;

- (void)loadStartPage;
- (void)loadURL:(NSURL *)url;
- (void)reload;
- (void)goBack;
- (void)goForward;
- (void)goHome;
- (void)openCurrentPageInBrowser;

- (void)togglePlayPause;
- (void)play;
- (void)pause;
- (void)nextTrack;
- (void)previousTrack;
- (void)seekTo:(NSTimeInterval)time;
- (void)setLiked:(BOOL)liked;
- (void)focusSearch;
- (void)toggleVideo;

/// Reconfigures the content-rule list and injected ad script, then reloads.
- (void)setAdBlockingEnabled:(BOOL)enabled;

/// Forwards a command coming from the menu bar, Dock, mini player or media keys.
- (void)performCommand:(NSString *)command value:(nullable id)value;

- (void)takeSnapshotWithCompletion:(void (^)(NSImage * _Nullable image, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
