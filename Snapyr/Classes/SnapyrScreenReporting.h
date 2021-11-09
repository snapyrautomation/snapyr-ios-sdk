#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#elif TARGET_OS_OSX
#import <Cocoa/Cocoa.h>
#endif

#import "SnapyrSerializableValue.h"

/** Implement this protocol to override automatic screen reporting
 */

NS_ASSUME_NONNULL_BEGIN

@protocol SnapyrScreenReporting
@optional
#if TARGET_OS_IPHONE
- (void)snapyr_trackScreen:(UIViewController*)screen name:(NSString*)name;
@property (readonly, nullable) UIViewController *snapyr_mainViewController;
#elif TARGET_OS_OSX
- (void)snapyr_trackScreen:(NSViewController*)screen name:(NSString*)name;
@property (readonly, nullable) NSViewController *snapyr_mainViewController;
#endif
@end

NS_ASSUME_NONNULL_END


