#import "AdBlocker.h"

static NSString * const YTMAdBlockRuleListIdentifier = @"YTMAdBlockRules-v1";

@interface AdBlocker ()

@property (nonatomic, strong) WKUserContentController *contentController;
@property (nonatomic, strong, nullable) WKContentRuleList *ruleList;
@property (nonatomic, strong, nullable) WKUserScript *adUserScript;
@property (nonatomic, assign, readwrite, getter=isEnabled) BOOL enabled;
@property (nonatomic, assign, readwrite, getter=isReady) BOOL ready;
@property (nonatomic, assign) BOOL ruleListAttached;
@property (nonatomic, assign) BOOL compiling;
@property (nonatomic, strong) NSMutableArray<void (^)(BOOL ready)> *pendingPreparations;

- (void)compileIfNeeded;
- (void)attachRuleList;
- (void)detachRuleList;
- (void)finishPreparation:(BOOL)success;
- (nullable NSString *)resourceNamed:(NSString *)name extension:(NSString *)extension;

@end

@implementation AdBlocker

- (instancetype)initWithUserContentController:(WKUserContentController *)controller
                                      enabled:(BOOL)enabled {
    self = [super init];
    if (!self) { return nil; }

    _contentController = controller;
    _enabled = enabled;
    _pendingPreparations = [NSMutableArray array];
    return self;
}

- (nullable WKUserScript *)userScript {
    if (_adUserScript) { return _adUserScript; }

    NSString *source = [self resourceNamed:@"AdBlocker" extension:@"js"];
    if (source.length == 0) {
        NSLog(@"[YTM] AdBlocker.js is missing from the app bundle; in-player ad suppression is unavailable.");
        return nil;
    }

    _adUserScript = [[WKUserScript alloc] initWithSource:source
                                            injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                         forMainFrameOnly:YES];
    return _adUserScript;
}

#pragma mark - Rule list

- (void)prepareWithCompletion:(void (^)(BOOL ready))completion {
    if (!completion) { return; }
    if (!self.enabled) {
        completion(YES);
        return;
    }
    if (self.ready && self.ruleList) {
        completion(YES);
        return;
    }

    [self.pendingPreparations addObject:[completion copy]];
    [self compileIfNeeded];
}

- (void)compileIfNeeded {
    if (self.compiling) { return; }

    if (self.ruleList) {
        [self attachRuleList];
        [self finishPreparation:YES];
        return;
    }

    NSString *rules = [self resourceNamed:@"AdBlockRules" extension:@"json"];
    if (rules.length == 0) {
        NSLog(@"[YTM] AdBlockRules.json is missing from the app bundle; network ad blocking is unavailable.");
        [self finishPreparation:NO];
        return;
    }

    self.compiling = YES;
    __weak typeof(self) weakSelf = self;
    [[WKContentRuleListStore defaultStore]
        compileContentRuleListForIdentifier:YTMAdBlockRuleListIdentifier
                     encodedContentRuleList:rules
                          completionHandler:^(WKContentRuleList * _Nullable contentRuleList,
                                              NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) { return; }

            self.compiling = NO;
            if (!contentRuleList) {
                NSLog(@"[YTM] Ad blocker rules failed to compile: %@",
                      error.localizedDescription ?: @"unknown error");
                [self finishPreparation:NO];
                return;
            }

            self.ruleList = contentRuleList;
            NSLog(@"[YTM] Ad blocker rules compiled.");
            if (self.enabled) {
                [self attachRuleList];
            }
            [self finishPreparation:(self.enabled && self.ruleListAttached)];
        });
    }];
}

- (void)attachRuleList {
    if (!self.ruleList || self.ruleListAttached) { return; }
    [self.contentController addContentRuleList:self.ruleList];
    self.ruleListAttached = YES;
}

- (void)detachRuleList {
    if (!self.ruleList || !self.ruleListAttached) { return; }
    [self.contentController removeContentRuleList:self.ruleList];
    self.ruleListAttached = NO;
}

- (void)finishPreparation:(BOOL)success {
    self.ready = success && self.ruleListAttached;

    NSArray<void (^)(BOOL ready)> *pending = [self.pendingPreparations copy];
    [self.pendingPreparations removeAllObjects];
    for (void (^completion)(BOOL ready) in pending) {
        completion(success);
    }
}

#pragma mark - Enablement

- (void)setEnabled:(BOOL)enabled completion:(nullable void (^)(BOOL success))completion {
    if (self.enabled == enabled) {
        if (enabled && !self.ready) {
            [self prepareWithCompletion:completion ?: ^(BOOL ready) {}];
        } else if (completion) {
            completion(YES);
        }
        return;
    }

    self.enabled = enabled;

    if (!enabled) {
        [self detachRuleList];
        self.ready = NO;
        if (completion) { completion(YES); }
        return;
    }

    [self prepareWithCompletion:^(BOOL ready) {
        if (completion) { completion(ready); }
    }];
}

#pragma mark - Resources

- (nullable NSString *)resourceNamed:(NSString *)name extension:(NSString *)extension {
    NSURL *url = [NSBundle.mainBundle URLForResource:name withExtension:extension];
    if (!url) {
        // Also support running the raw executable next to the Resources folder while developing.
        NSString *fallback = [[[NSBundle.mainBundle.executableURL.path stringByDeletingLastPathComponent]
                               stringByDeletingLastPathComponent]
                              stringByAppendingPathComponent:
                              [NSString stringWithFormat:@"Resources/%@.%@", name, extension]];
        if ([[NSFileManager defaultManager] fileExistsAtPath:fallback]) {
            url = [NSURL fileURLWithPath:fallback];
        }
    }
    if (!url) { return nil; }

    NSError *error = nil;
    NSString *source = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];
    if (!source) {
        NSLog(@"[YTM] Could not read %@.%@: %@", name, extension, error.localizedDescription);
    }
    return source;
}

@end
