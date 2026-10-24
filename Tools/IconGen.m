#import <AppKit/AppKit.h>

static const NSInteger kSize = 1024;

static void DrawIcon(void) {
    NSRect canvas = NSMakeRect(0, 0, kSize, kSize);
    CGFloat inset = 92;
    NSRect body = NSInsetRect(canvas, inset, inset);
    NSBezierPath *squircle = [NSBezierPath bezierPathWithRoundedRect:body xRadius:190 yRadius:190];

    // Soft, macOS-style drop shadow.
    NSShadow *shadow = [[NSShadow alloc] init];
    shadow.shadowColor = [NSColor colorWithWhite:0.0 alpha:0.38];
    shadow.shadowBlurRadius = 26;
    shadow.shadowOffset = NSMakeSize(0, -14);

    [NSGraphicsContext saveGraphicsState];
    [shadow set];
    [[NSColor blackColor] setFill];
    [squircle fill];
    [NSGraphicsContext restoreGraphicsState];

    // Red gradient body.
    [NSGraphicsContext saveGraphicsState];
    [squircle addClip];
    NSGradient *gradient = [[NSGradient alloc] initWithColorsAndLocations:
        [NSColor colorWithSRGBRed:1.00 green:0.30 blue:0.28 alpha:1.0], 0.0,
        [NSColor colorWithSRGBRed:0.94 green:0.09 blue:0.20 alpha:1.0], 0.52,
        [NSColor colorWithSRGBRed:0.72 green:0.00 blue:0.14 alpha:1.0], 1.0,
        nil];
    [gradient drawInRect:body angle:-90];

    // Top gloss.
    NSRect glossRect = NSMakeRect(body.origin.x, NSMidY(body), body.size.width, body.size.height / 2);
    NSGradient *gloss = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithWhite:1.0 alpha:0.16]
                                                     endingColor:[NSColor colorWithWhite:1.0 alpha:0.0]];
    [gloss drawInRect:glossRect angle:-90];
    [NSGraphicsContext restoreGraphicsState];

    // Inner rim.
    [NSGraphicsContext saveGraphicsState];
    NSBezierPath *rim = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(body, 2, 2) xRadius:188 yRadius:188];
    [[NSColor colorWithWhite:1.0 alpha:0.18] setStroke];
    rim.lineWidth = 3;
    [rim stroke];
    [NSGraphicsContext restoreGraphicsState];

    // White play glyph, optically centered.
    CGFloat cx = NSMidX(body) + 14;
    CGFloat cy = NSMidY(body);
    CGFloat halfHeight = 152;
    CGFloat halfWidth = 120;

    NSBezierPath *play = [NSBezierPath bezierPath];
    play.lineJoinStyle = NSLineJoinStyleRound;
    play.lineCapStyle = NSLineCapStyleRound;
    [play moveToPoint:NSMakePoint(cx - halfWidth, cy - halfHeight)];
    [play lineToPoint:NSMakePoint(cx - halfWidth, cy + halfHeight)];
    [play lineToPoint:NSMakePoint(cx + halfWidth, cy)];
    [play closePath];
    [[NSColor whiteColor] setFill];
    [play fill];
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr, "usage: icon-gen <output.png>\n");
            return 1;
        }

        NSBitmapImageRep *rep = [[NSBitmapImageRep alloc]
            initWithBitmapDataPlanes:NULL
                          pixelsWide:kSize
                          pixelsHigh:kSize
                       bitsPerSample:8
                     samplesPerPixel:4
                            hasAlpha:YES
                            isPlanar:NO
                      colorSpaceName:NSDeviceRGBColorSpace
                         bytesPerRow:0
                        bitsPerPixel:0];
        rep.size = NSMakeSize(kSize, kSize);

        NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:context];
        [context setImageInterpolation:NSImageInterpolationHigh];
        [context setShouldAntialias:YES];

        DrawIcon();

        [NSGraphicsContext restoreGraphicsState];

        NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        if (!png) {
            fprintf(stderr, "icon-gen: could not encode PNG\n");
            return 1;
        }

        NSString *path = [NSString stringWithUTF8String:argv[1]];
        NSError *error = nil;
        if (![png writeToFile:path options:NSDataWritingAtomic error:&error]) {
            fprintf(stderr, "icon-gen: %s\n", error.localizedDescription.UTF8String);
            return 1;
        }
    }
    return 0;
}
