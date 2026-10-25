#import "PlaybackState.h"

@implementation PlaybackState

- (instancetype)initWithMessage:(NSDictionary<NSString *, id> *)message {
    self = [super init];
    if (!self) { return nil; }

    _title = @"";
    _artist = @"";
    _album = @"";
    _videoID = @"";
    _backgroundColorHex = @"#030303";

    _hasTrack = [self boolValue:message[@"hasTrack"]];
    _title = [self stringValue:message[@"title"]];
    _artist = [self stringValue:message[@"artist"]];
    _album = [self stringValue:message[@"album"]];
    _videoID = [self stringValue:message[@"videoId"]];

    NSString *artwork = [self stringValue:message[@"artwork"]];
    if (artwork.length > 0) {
        NSURL *url = [NSURL URLWithString:artwork];
        if ([url.scheme isEqualToString:@"https"]) {
            _artworkURL = url;
        }
    }

    _isPlaying = [self boolValue:message[@"isPlaying"]];
    _position = [self doubleValue:message[@"position"]];
    _duration = [self doubleValue:message[@"duration"]];
    _canSeek = [self boolValue:message[@"canSeek"]];
    _canNext = [self boolValue:message[@"canNext"]];
    _canPrevious = [self boolValue:message[@"canPrevious"]];
    _canLike = [self boolValue:message[@"canLike"]];
    _isLiked = [self boolValue:message[@"liked"]];
    _hasVideo = [self boolValue:message[@"hasVideo"]];
    _videoVisible = [self boolValue:message[@"videoVisible"]];

    NSString *rawURL = [self stringValue:message[@"url"]];
    if (rawURL.length > 0) {
        NSURL *url = [NSURL URLWithString:rawURL];
        if ([url.scheme isEqualToString:@"https"]) {
            _pageURL = url;
        }
    }

    NSString *bg = [self stringValue:message[@"bg"]];
    if (bg.length > 0) {
        _backgroundColorHex = bg;
    }
    _isDark = [self boolValue:message[@"isDark"]];

    return self;
}

- (NSString *)stringValue:(id)value {
    if ([value isKindOfClass:[NSString class]]) { return value; }
    return @"";
}

- (double)doubleValue:(id)value {
    if ([value respondsToSelector:@selector(doubleValue)]) { return [value doubleValue]; }
    return 0;
}

- (BOOL)boolValue:(id)value {
    if ([value respondsToSelector:@selector(boolValue)]) { return [value boolValue]; }
    return NO;
}

- (NSString *)displayTitle {
    return self.title.length > 0 ? self.title : @"YouTube Music";
}

- (NSString *)subtitle {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    if (self.artist.length > 0) { [parts addObject:self.artist]; }
    if (self.album.length > 0) { [parts addObject:self.album]; }
    return [parts componentsJoinedByString:@" • "];
}

- (double)progress {
    if (self.duration <= 0) { return 0; }
    return MIN(MAX(self.position / self.duration, 0), 1);
}

- (NSString *)remainingText {
    if (self.duration <= 0) { return @""; }
    return [NSString stringWithFormat:@"-%@", [PlaybackState timeString:MAX(self.duration - self.position, 0)]];
}

+ (NSString *)timeString:(NSTimeInterval)time {
    if (!isfinite(time) || time < 0) { return @"0:00"; }
    NSInteger total = (NSInteger)floor(time);
    NSInteger hours = total / 3600;
    NSInteger minutes = (total % 3600) / 60;
    NSInteger seconds = total % 60;
    if (hours > 0) {
        return [NSString stringWithFormat:@"%ld:%02ld:%02ld", (long)hours, (long)minutes, (long)seconds];
    }
    return [NSString stringWithFormat:@"%ld:%02ld", (long)minutes, (long)seconds];
}

- (BOOL)isEqualToState:(PlaybackState *)other {
    if (other == self) { return YES; }
    if (!other) { return NO; }
    return self.hasTrack == other.hasTrack
        && [self.title isEqualToString:other.title]
        && [self.artist isEqualToString:other.artist]
        && [self.album isEqualToString:other.album]
        && (self.artworkURL == other.artworkURL || [self.artworkURL isEqual:other.artworkURL])
        && [self.videoID isEqualToString:other.videoID]
        && self.isPlaying == other.isPlaying
        && fabs(self.position - other.position) < 0.01
        && fabs(self.duration - other.duration) < 0.01
        && self.canSeek == other.canSeek
        && self.canNext == other.canNext
        && self.canPrevious == other.canPrevious
        && self.canLike == other.canLike
        && self.isLiked == other.isLiked
        && self.hasVideo == other.hasVideo
        && self.videoVisible == other.videoVisible
        && [self.backgroundColorHex isEqualToString:other.backgroundColorHex]
        && self.isDark == other.isDark;
}

@end

@implementation NSColor (YTM)

+ (NSColor *)ytm_colorWithCSSColor:(NSString *)cssColor {
    if (![cssColor isKindOfClass:[NSString class]]) { return nil; }
    NSString *value = [[cssColor stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    if (value.length == 0) { return nil; }

    if ([value hasPrefix:@"#"]) {
        NSString *hex = [value substringFromIndex:1];
        if (hex.length == 3) {
            hex = [NSString stringWithFormat:@"%c%c%c%c%c%c",
                   [hex characterAtIndex:0], [hex characterAtIndex:0],
                   [hex characterAtIndex:1], [hex characterAtIndex:1],
                   [hex characterAtIndex:2], [hex characterAtIndex:2]];
        }
        unsigned long long number = 0;
        NSScanner *scanner = [NSScanner scannerWithString:hex];
        if (hex.length != 6 && hex.length != 8) { return nil; }
        if (![scanner scanHexLongLong:&number]) { return nil; }
        BOOL hasAlpha = hex.length == 8;
        CGFloat r = (CGFloat)((number >> (hasAlpha ? 24 : 16)) & 0xFF) / 255.0;
        CGFloat g = (CGFloat)((number >> (hasAlpha ? 16 : 8)) & 0xFF) / 255.0;
        CGFloat b = (CGFloat)((number >> (hasAlpha ? 8 : 0)) & 0xFF) / 255.0;
        CGFloat a = hasAlpha ? (CGFloat)(number & 0xFF) / 255.0 : 1.0;
        return [NSColor colorWithSRGBRed:r green:g blue:b alpha:a];
    }

    if (![value hasPrefix:@"rgb"]) { return nil; }
    NSRange open = [value rangeOfString:@"("];
    NSRange close = [value rangeOfString:@")" options:NSBackwardsSearch];
    if (open.location == NSNotFound || close.location == NSNotFound) { return nil; }
    NSString *body = [value substringWithRange:NSMakeRange(open.location + 1, close.location - open.location - 1)];
    body = [body stringByReplacingOccurrencesOfString:@"/" withString:@" "];
    NSArray<NSString *> *parts = [body componentsSeparatedByCharactersInSet:
        [NSCharacterSet characterSetWithCharactersInString:@", "]];
    NSMutableArray<NSNumber *> *numbers = [NSMutableArray array];
    for (NSString *part in parts) {
        if (part.length == 0) { continue; }
        NSScanner *scanner = [NSScanner scannerWithString:part];
        double component = 0;
        if ([scanner scanDouble:&component]) {
            [numbers addObject:@(component)];
        }
    }
    if (numbers.count < 3) { return nil; }
    CGFloat r = MIN(MAX(numbers[0].doubleValue / 255.0, 0), 1);
    CGFloat g = MIN(MAX(numbers[1].doubleValue / 255.0, 0), 1);
    CGFloat b = MIN(MAX(numbers[2].doubleValue / 255.0, 0), 1);
    CGFloat a = numbers.count >= 4 ? MIN(MAX(numbers[3].doubleValue, 0), 1) : 1;
    return [NSColor colorWithSRGBRed:r green:g blue:b alpha:a];
}

@end
