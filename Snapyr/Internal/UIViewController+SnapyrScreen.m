#import "UIViewController+SnapyrScreen.h"
#import <objc/runtime.h>
#import "SnapyrAnalytics.h"
#import "SnapyrAnalyticsUtils.h"
#import "SnapyrScreenReporting.h"


#if TARGET_OS_IPHONE
@implementation UIViewController (SnapyrScreen)

+ (void)snapyr_swizzleViewDidAppear
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];

        SEL originalSelector = @selector(viewDidAppear:);
        SEL swizzledSelector = @selector(snapyr_viewDidAppear:);

        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);

        BOOL didAddMethod =
            class_addMethod(class,
                            originalSelector,
                            method_getImplementation(swizzledMethod),
                            method_getTypeEncoding(swizzledMethod));

        if (didAddMethod) {
            class_replaceMethod(class,
                                swizzledSelector,
                                method_getImplementation(originalMethod),
                                method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}


+ (UIViewController *)snapyr_rootViewControllerFromView:(UIView *)view
{
    UIViewController *root = view.window.rootViewController;
    return [self snapyr_topViewController:root];
}

+ (UIViewController *)snapyr_topViewController:(UIViewController *)rootViewController
{
    UIViewController *nextRootViewController = [self snapyr_nextRootViewController:rootViewController];
    if (nextRootViewController) {
        return [self snapyr_topViewController:nextRootViewController];
    }

    return rootViewController;
}

+ (UIViewController *)snapyr_nextRootViewController:(UIViewController *)rootViewController
{
    UIViewController *presentedViewController = rootViewController.presentedViewController;
    if (presentedViewController != nil) {
        return presentedViewController;
    }

    if ([rootViewController isKindOfClass:[UINavigationController class]]) {
        UIViewController *lastViewController = ((UINavigationController *)rootViewController).viewControllers.lastObject;
        return lastViewController;
    }

    if ([rootViewController isKindOfClass:[UITabBarController class]]) {
        __auto_type *currentTabViewController = ((UITabBarController*)rootViewController).selectedViewController;
        if (currentTabViewController != nil) {
            return currentTabViewController;
        }
    }

    if (rootViewController.childViewControllers.count > 0) {
        if ([rootViewController conformsToProtocol:@protocol(SnapyrScreenReporting)] && [rootViewController respondsToSelector:@selector(snapyr_mainViewController)]) {
            __auto_type screenReporting = (UIViewController<SnapyrScreenReporting>*)rootViewController;
            return screenReporting.snapyr_mainViewController;
        }

        // fall back on first child UIViewController as a "best guess" assumption
        __auto_type *firstChildViewController = rootViewController.childViewControllers.firstObject;
        if (firstChildViewController != nil) {
            return firstChildViewController;
        }
    }

    return nil;
}

- (void)snapyr_viewDidAppear:(BOOL)animated
{
    UIViewController *top = [[self class] snapyr_rootViewControllerFromView:self.view];
    if (!top) {
        SEGLog(@"Could not infer screen.");
        return;
    }

    NSString *name = [[[top class] description] stringByReplacingOccurrencesOfString:@"ViewController" withString:@""];
    
    if (!name || name.length == 0) {
        // if no class description found, try view controller's title.
        name = [top title];
        // Class name could be just "ViewController".
        if (name.length == 0) {
            SEGLog(@"Could not infer screen name.");
            name = @"Unknown";
        }
    }

    if ([top conformsToProtocol:@protocol(SnapyrScreenReporting)] && [top respondsToSelector:@selector(snapyr_trackScreen:name:)]) {
        __auto_type screenReporting = (UIViewController<SnapyrScreenReporting>*)top;
        [screenReporting snapyr_trackScreen:top name:name];
        return;
    }

    [[SnapyrAnalytics sharedAnalytics] screen:name properties:nil options:nil];

    [self snapyr_viewDidAppear:animated];
}

@end
#endif
