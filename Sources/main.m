#import <AppKit/AppKit.h>

#import "AppDelegate.h"

static AppDelegate *YTMAppDelegate;

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        YTMAppDelegate = [[AppDelegate alloc] init];
        application.delegate = YTMAppDelegate;
        [application run];
    }
    return 0;
}
