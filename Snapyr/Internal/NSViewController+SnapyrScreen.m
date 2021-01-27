//
//  NSViewController+SEGScreen.m
//  Analytics
//
//  Created by Cody Garvin on 7/8/20.
//  Copyright © 2020 Segment. All rights reserved.
//

#import "NSViewController+SnapyrScreen.h"
#import <objc/runtime.h>
#import "SnapyrAnalytics.h"
#import "SnapyrAnalyticsUtils.h"
#import "SnapyrScreenReporting.h"

#if TARGET_OS_OSX
@implementation NSViewController (SEGScreen)

+ (void)snapyr_swizzleViewDidAppear
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];

        SEL originalSelector = @selector(viewDidAppear);
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

+ (NSViewController *)snapyr_rootViewControllerFromView:(NSView *)view
{
    NSViewController *rootViewController = view.window.contentViewController;
    
    if (rootViewController.childViewControllers.count > 0) {
        if ([rootViewController conformsToProtocol:@protocol(SnapyrScreenReporting)] && [rootViewController respondsToSelector:@selector(snapyr_mainViewController)]) {
            __auto_type screenReporting = (NSViewController<SnapyrScreenReporting>*)rootViewController;
            return screenReporting.snapyr_mainViewController;
        }

        // fall back on first child UIViewController as a "best guess" assumption
        __auto_type *firstChildViewController = rootViewController.childViewControllers.firstObject;
        if (firstChildViewController != nil) {
            return firstChildViewController;
        }
    }

    return rootViewController;
}

- (void)snapyr_viewDidAppear:(BOOL)animated
{
    NSViewController *top = [[self class] snapyr_rootViewControllerFromView:self.view];
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
        __auto_type screenReporting = (NSViewController<SnapyrScreenReporting>*)top;
        [screenReporting snapyr_trackScreen:top name:name];
        return;
    }

    [[SnapyrAnalytics sharedAnalytics] screen:name properties:nil options:nil];

    [self snapyr_viewDidAppear:animated];
}
@end
#endif
