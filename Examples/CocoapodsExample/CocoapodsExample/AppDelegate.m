//
//  AppDelegate.m
//  CocoapodsExample
//
//  Created by Tony Xiao on 11/28/16.
//  Copyright © 2016 Segment. All rights reserved.
//

#import <Segment/SnapyrAnalytics.h>
#import "AppDelegate.h"


@interface AppDelegate ()

@end

// https://segment.com/segment-mobile/sources/ios_cocoapods_example/overview
NSString *const SEGMENT_WRITE_KEY = @"zr5x22gUVBDM3hO3uHkbMkVe6Pd6sCna";


@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [SnapyrAnalytics debug:YES];
    SnapyrAnalyticsConfiguration *configuration = [SnapyrAnalyticsConfiguration configurationWithWriteKey:SEGMENT_WRITE_KEY];
    configuration.trackApplicationLifecycleEvents = YES;
    configuration.flushAt = 1;
    [SnapyrAnalytics setupWithConfiguration:configuration];
    [[SnapyrAnalytics sharedAnalytics] identify:@"Prateek" traits:nil options: @{
                                                                              @"anonymousId":@"test_anonymousId"
                                                                              }];
    [[SnapyrAnalytics sharedAnalytics] track:@"Cocoapods Example Launched"];

    [[SnapyrAnalytics sharedAnalytics] flush];
    NSLog(@"application:didFinishLaunchingWithOptions: %@", launchOptions);
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application
{
    NSLog(@"applicationWillResignActive:");
}


- (void)applicationDidEnterBackground:(UIApplication *)application
{
    NSLog(@"applicationDidEnterBackground:");
}


- (void)applicationWillEnterForeground:(UIApplication *)application
{
    NSLog(@"applicationWillEnterForeground:");
}


- (void)applicationDidBecomeActive:(UIApplication *)application
{
    NSLog(@"applicationDidBecomeActive:");
}


- (void)applicationWillTerminate:(UIApplication *)application
{
    NSLog(@"applicationWillTerminate:");
}

@end
