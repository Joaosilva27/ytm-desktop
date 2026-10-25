#import "NowPlayingService.h"

#import <AppKit/AppKit.h>
#import <MediaPlayer/MediaPlayer.h>

#import "ArtworkLoader.h"
#import "PlaybackState.h"

@interface NowPlayingService ()

@property (nonatomic, strong, nullable) PlaybackState *state;
@property (nonatomic, strong, nullable) NSImage *artworkImage;
@property (nonatomic, copy, nullable) NSString *artworkVideoID;
@property (nonatomic, strong, nullable) id<NSObject> sleepActivity;
@property (nonatomic, strong) NSMutableArray<id> *commandTokens;

@end

@implementation NowPlayingService

- (instancetype)init {
    self = [super init];
    if (!self) { return nil; }

    _commandTokens = [NSMutableArray array];
    [self configureRemoteCommands];
    return self;
}

- (void)dealloc {
    [self endSleepActivity];
}

#pragma mark - Remote commands

- (void)configureRemoteCommands {
    MPRemoteCommandCenter *center = [MPRemoteCommandCenter sharedCommandCenter];

    __weak typeof(self) weakSelf = self;

    [self addHandlerToCommand:center.playCommand block:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        return [weakSelf perform:@"play"];
    }];
    [self addHandlerToCommand:center.pauseCommand block:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        return [weakSelf perform:@"pause"];
    }];
    [self addHandlerToCommand:center.togglePlayPauseCommand block:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        return [weakSelf perform:@"toggle"];
    }];
    [self addHandlerToCommand:center.nextTrackCommand block:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        return [weakSelf perform:@"next"];
    }];
    [self addHandlerToCommand:center.previousTrackCommand block:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        return [weakSelf perform:@"previous"];
    }];

    [self addHandlerToCommand:center.changePlaybackPositionCommand block:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        MPChangePlaybackPositionCommandEvent *seekEvent = (MPChangePlaybackPositionCommandEvent *)event;
        return [weakSelf performSeek:seekEvent.positionTime];
    }];

    [self addHandlerToCommand:center.skipForwardCommand block:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        MPSkipIntervalCommandEvent *skipEvent = (MPSkipIntervalCommandEvent *)event;
        return [weakSelf performSkip:skipEvent.interval];
    }];
    [self addHandlerToCommand:center.skipBackwardCommand block:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        MPSkipIntervalCommandEvent *skipEvent = (MPSkipIntervalCommandEvent *)event;
        return [weakSelf performSkip:-skipEvent.interval];
    }];
    center.skipForwardCommand.preferredIntervals = @[@15];
    center.skipBackwardCommand.preferredIntervals = @[@15];

    [self addHandlerToCommand:center.likeCommand block:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        return [weakSelf toggleLike];
    }];
}

- (void)addHandlerToCommand:(MPRemoteCommand *)command
                      block:(MPRemoteCommandHandlerStatus (^)(MPRemoteCommandEvent *event))block {
    id token = [command addTargetWithHandler:block];
    if (token) { [self.commandTokens addObject:token]; }
}

- (MPRemoteCommandHandlerStatus)perform:(NSString *)command {
    void (^handler)(NSString *, id) = self.commandHandler;
    if (!handler || !self.state.hasTrack) {
        return MPRemoteCommandHandlerStatusNoSuchContent;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        handler(command, nil);
    });
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)performSeek:(NSTimeInterval)position {
    void (^handler)(NSString *, id) = self.commandHandler;
    if (!handler || !self.state.hasTrack || !self.state.canSeek) {
        return MPRemoteCommandHandlerStatusNoSuchContent;
    }
    NSTimeInterval clamped = MAX(0, MIN(position, self.state.duration > 0 ? self.state.duration : position));
    dispatch_async(dispatch_get_main_queue(), ^{
        handler(@"seek", @(clamped));
    });
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)performSkip:(NSTimeInterval)delta {
    if (!self.state.hasTrack || !self.state.canSeek) {
        return MPRemoteCommandHandlerStatusNoSuchContent;
    }
    return [self performSeek:MAX(0, self.state.position + delta)];
}

- (MPRemoteCommandHandlerStatus)toggleLike {
    void (^handler)(NSString *, id) = self.commandHandler;
    if (!handler || !self.state.hasTrack || !self.state.canLike) {
        return MPRemoteCommandHandlerStatusNoSuchContent;
    }
    BOOL desired = !self.state.isLiked;
    dispatch_async(dispatch_get_main_queue(), ^{
        handler(@"like", @(desired));
    });
    return MPRemoteCommandHandlerStatusSuccess;
}

#pragma mark - State

- (void)updateWithState:(PlaybackState *)state {
    self.state = state;

    MPRemoteCommandCenter *center = [MPRemoteCommandCenter sharedCommandCenter];
    BOOL hasTrack = state.hasTrack;
    center.playCommand.enabled = hasTrack && !state.isPlaying;
    center.pauseCommand.enabled = hasTrack && state.isPlaying;
    center.togglePlayPauseCommand.enabled = hasTrack;
    center.nextTrackCommand.enabled = hasTrack && state.canNext;
    center.previousTrackCommand.enabled = hasTrack && (state.canPrevious || state.position > 3);
    center.changePlaybackPositionCommand.enabled = hasTrack && state.canSeek;
    center.skipForwardCommand.enabled = hasTrack && state.canSeek;
    center.skipBackwardCommand.enabled = hasTrack && state.canSeek;
    center.likeCommand.enabled = hasTrack && state.canLike;

    if (!hasTrack) {
        [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nil;
        [MPNowPlayingInfoCenter defaultCenter].playbackState = MPNowPlayingPlaybackStateStopped;
        self.artworkImage = nil;
        self.artworkVideoID = nil;
        [self endSleepActivity];
        return;
    }

    if (![self.artworkVideoID isEqualToString:state.videoID]) {
        self.artworkVideoID = state.videoID;
        self.artworkImage = [[ArtworkLoader sharedLoader] cachedImageForURL:state.artworkURL];
        if (!self.artworkImage && state.artworkURL) {
            [self loadArtworkForState:state];
        }
    }

    [self publishInfoForState:state];
    [self updatePlaybackStateForState:state];

    if (state.isPlaying) {
        [self beginSleepActivity];
    } else {
        [self endSleepActivity];
    }
}

- (void)loadArtworkForState:(PlaybackState *)state {
    NSString *videoID = state.videoID;
    NSURL *url = state.artworkURL;
    if (!url) { return; }
    __weak typeof(self) weakSelf = self;
    [[ArtworkLoader sharedLoader] loadURL:url completion:^(NSImage *image) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !image) { return; }
        if (![self.artworkVideoID isEqualToString:videoID]) { return; }
        self.artworkImage = image;
        if (self.state.hasTrack) {
            [self publishInfoForState:self.state];
        }
    }];
}

- (void)publishInfoForState:(PlaybackState *)state {
    NSMutableDictionary<NSString *, id> *info = [NSMutableDictionary dictionary];
    info[MPMediaItemPropertyTitle] = state.displayTitle;
    if (state.artist.length > 0) {
        info[MPMediaItemPropertyArtist] = state.artist;
    }
    if (state.album.length > 0) {
        info[MPMediaItemPropertyAlbumTitle] = state.album;
    }
    if (state.duration > 0) {
        info[MPMediaItemPropertyPlaybackDuration] = @(state.duration);
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(state.position);
    }
    info[MPNowPlayingInfoPropertyPlaybackRate] = @(state.isPlaying ? 1.0 : 0.0);
    info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = @1.0;
    info[MPNowPlayingInfoPropertyMediaType] = @(MPNowPlayingInfoMediaTypeAudio);
    info[MPNowPlayingInfoPropertyIsLiveStream] = @NO;
    if (state.videoID.length > 0) {
        info[MPNowPlayingInfoPropertyExternalContentIdentifier] = state.videoID;
    }
    if (state.pageURL) {
        info[MPNowPlayingInfoPropertyAssetURL] = state.pageURL;
    }

    NSImage *artwork = self.artworkImage ?: [NSImage imageNamed:NSImageNameApplicationIcon];
    if (artwork) {
        CGFloat side = 512;
        info[MPMediaItemPropertyArtwork] = [[MPMediaItemArtwork alloc] initWithBoundsSize:NSMakeSize(side, side)
                                                                         requestHandler:^NSImage * _Nonnull(CGSize size) {
            return artwork;
        }];
    }

    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = info;
}

- (void)updatePlaybackStateForState:(PlaybackState *)state {
    MPNowPlayingPlaybackState playbackState = MPNowPlayingPlaybackStatePaused;
    if (state.isPlaying) {
        playbackState = MPNowPlayingPlaybackStatePlaying;
    }
    [MPNowPlayingInfoCenter defaultCenter].playbackState = playbackState;
}

#pragma mark - Sleep

- (void)beginSleepActivity {
    if (self.sleepActivity) { return; }
    self.sleepActivity = [NSProcessInfo.processInfo beginActivityWithOptions:(NSActivityUserInitiated |
                                                                              NSActivityIdleSystemSleepDisabled)
                                                                      reason:@"Playing music with YouTube Music"];
}

- (void)endSleepActivity {
    if (!self.sleepActivity) { return; }
    [NSProcessInfo.processInfo endActivity:self.sleepActivity];
    self.sleepActivity = nil;
}

#pragma mark - Teardown

- (void)invalidate {
    [self endSleepActivity];
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nil;
    [MPNowPlayingInfoCenter defaultCenter].playbackState = MPNowPlayingPlaybackStateStopped;

    MPRemoteCommandCenter *center = [MPRemoteCommandCenter sharedCommandCenter];
    NSArray<MPRemoteCommand *> *commands = @[
        center.playCommand, center.pauseCommand, center.togglePlayPauseCommand,
        center.nextTrackCommand, center.previousTrackCommand,
        center.changePlaybackPositionCommand, center.skipForwardCommand,
        center.skipBackwardCommand, center.likeCommand
    ];
    for (MPRemoteCommand *command in commands) {
        for (id token in self.commandTokens) {
            [command removeTarget:token];
        }
    }
    [self.commandTokens removeAllObjects];
}

@end
