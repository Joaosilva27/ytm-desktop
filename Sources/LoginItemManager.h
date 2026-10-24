#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const YTMLoginItemErrorDomain;

/// LaunchAgent-based login item, so locally built (ad-hoc signed) apps work.
@interface LoginItemManager : NSObject

+ (BOOL)isEnabled;
+ (BOOL)setEnabled:(BOOL)enabled error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
