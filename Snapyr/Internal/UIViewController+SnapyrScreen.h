#import "SnapyrSerializableValue.h"

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>

@interface UIViewController (SnapyrScreen)

+ (void)snapyr_swizzleViewDidAppear;
+ (UIViewController *)snapyr_rootViewControllerFromView:(UIView *)view;

@end

#endif
