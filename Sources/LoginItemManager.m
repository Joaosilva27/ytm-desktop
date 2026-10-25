#import "LoginItemManager.h"

NSString * const YTMLoginItemErrorDomain = @"com.joaosilva.ytmdesktop.loginitem";
static NSString * const LoginItemLabel = @"com.joaosilva.ytmdesktop.login";

@implementation LoginItemManager

+ (NSURL *)plistURL {
    NSURL *home = [NSURL fileURLWithPath:NSHomeDirectory()];
    return [[home URLByAppendingPathComponent:@"Library/LaunchAgents" isDirectory:YES]
            URLByAppendingPathComponent:[LoginItemLabel stringByAppendingPathExtension:@"plist"]];
}

+ (BOOL)isEnabled {
    return [[NSFileManager defaultManager] fileExistsAtPath:self.plistURL.path];
}

+ (BOOL)setEnabled:(BOOL)enabled error:(NSError **)error {
    if (enabled) {
        return [self install:error];
    }
    return [self uninstall:error];
}

+ (BOOL)install:(NSError **)error {
    if (![NSBundle.mainBundle.bundleURL.pathExtension isEqualToString:@"app"]) {
        [self setError:error message:@"Launch at login only works when YouTube Music is running from an app bundle."];
        return NO;
    }

    NSString *executable = NSBundle.mainBundle.executableURL.path ?: NSBundle.mainBundle.bundlePath;
    NSDictionary *plist = @{
        @"Label": LoginItemLabel,
        @"ProgramArguments": @[executable],
        @"RunAtLoad": @YES,
        @"ProcessType": @"Interactive",
        @"LimitLoadToSessionType": @"Aqua",
        @"StandardOutPath": @"/dev/null",
        @"StandardErrorPath": @"/dev/null"
    };

    NSError *serializationError = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:plist
                                                              format:NSPropertyListXMLFormat_v1_0
                                                             options:0
                                                               error:&serializationError];
    if (!data) {
        if (error) { *error = serializationError; }
        return NO;
    }

    // Unload any copy that launchd already knows about, then leave the plist on
    // disk for the next login session. Do not bootstrap it now: RunAtLoad would
    // launch a second copy of the app while the user is toggling the setting.
    [self runLaunchctl:@[@"bootout", [NSString stringWithFormat:@"gui/%u/%@", getuid(), LoginItemLabel]]];

    NSURL *directory = [self.plistURL URLByDeletingLastPathComponent];
    NSError *directoryError = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtURL:directory
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&directoryError]) {
        if (error) { *error = directoryError; }
        return NO;
    }
    if (![data writeToURL:self.plistURL options:NSDataWritingAtomic error:error]) {
        return NO;
    }
    return YES;
}

+ (BOOL)uninstall:(NSError **)error {
    [self runLaunchctl:@[@"bootout", [NSString stringWithFormat:@"gui/%u/%@", getuid(), LoginItemLabel]]];
    if ([self isEnabled]) {
        return [[NSFileManager defaultManager] removeItemAtURL:self.plistURL error:error];
    }
    return YES;
}

+ (NSDictionary<NSString *, id> *)runLaunchctl:(NSArray<NSString *> *)arguments {
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:@"/bin/launchctl"];
    task.arguments = arguments;
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    task.standardError = pipe;
    @try {
        NSError *launchError = nil;
        if (![task launchAndReturnError:&launchError]) {
            return @{@"status": @(-1), @"output": launchError.localizedDescription ?: @"launchctl failed"};
        }
        [task waitUntilExit];
        NSData *data = [pipe.fileHandleForReading readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
        output = [output stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        return @{@"status": @(task.terminationStatus), @"output": output};
    } @catch (NSException *exception) {
        return @{@"status": @(-1), @"output": exception.reason ?: @"launchctl failed"};
    }
}

+ (void)setError:(NSError **)error message:(NSString *)message {
    if (!error) { return; }
    *error = [NSError errorWithDomain:YTMLoginItemErrorDomain
                                 code:1
                             userInfo:@{NSLocalizedDescriptionKey: message}];
}

@end
