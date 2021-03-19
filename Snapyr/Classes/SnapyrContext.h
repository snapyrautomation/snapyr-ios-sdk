//
//  SnapyrContext.h
//  Analytics
//
//  Created by Tony Xiao on 9/19/16.
//  Copyright © 2016 Segment. All rights reserved.
//

@import Foundation;
#import "SnapyrIntegration.h"

typedef NS_ENUM(NSInteger, SnapyrEventType) {
    // Should not happen, but default state
    SnapyrEventTypeUndefined,
    // Core Tracking Methods
    SnapyrEventTypeIdentify,
    SnapyrEventTypeTrack,
    SnapyrEventTypeScreen,
    SnapyrEventTypeGroup,
    SnapyrEventTypeAlias,

    // General utility
    SnapyrEventTypeReset,
    SnapyrEventTypeFlush,

    // Remote Notification
    SnapyrEventTypeReceivedRemoteNotification,
    SnapyrEventTypeFailedToRegisterForRemoteNotifications,
    SnapyrEventTypeRegisteredForRemoteNotifications,
    SnapyrEventTypeHandleActionWithForRemoteNotification,

    // Application Lifecycle
    SnapyrEventTypeApplicationLifecycle,
    //    DidFinishLaunching,
    //    SnapyrEventTypeApplicationDidEnterBackground,
    //    SnapyrEventTypeApplicationWillEnterForeground,
    //    SnapyrEventTypeApplicationWillTerminate,
    //    SnapyrEventTypeApplicationWillResignActive,
    //    SnapyrEventTypeApplicationDidBecomeActive,

    // Misc.
    SnapyrEventTypeContinueUserActivity,
    SnapyrEventTypeOpenURL,

} NS_SWIFT_NAME(EventType);

@class SnapyrSDK;
@protocol SnapyrMutableContext;


NS_SWIFT_NAME(Context)
@interface SnapyrContext : NSObject <NSCopying>

// Loopback reference to the top level SnapyrSDK object.
// Not sure if it's a good idea to keep this around in the context.
// since we don't really want people to use it due to the circular
// reference and logic (Thus prefixing with underscore). But
// Right now it is required for integrations to work so I guess we'll leave it in.
@property (nonatomic, readonly, nonnull) SnapyrSDK *sdk;
@property (nonatomic, readonly) SnapyrEventType eventType;

@property (nonatomic, readonly, nullable) NSError *error;
@property (nonatomic, readonly, nullable) SnapyrPayload *payload;
@property (nonatomic, readonly) BOOL debug;

- (instancetype _Nonnull)initWithSDK:(SnapyrSDK *_Nonnull)sdk;

- (SnapyrContext *_Nonnull)modify:(void (^_Nonnull)(id<SnapyrMutableContext> _Nonnull ctx))modify;

@end

@protocol SnapyrMutableContext <NSObject>

@property (nonatomic) SnapyrEventType eventType;
@property (nonatomic, nullable) SnapyrPayload *payload;
@property (nonatomic, nullable) NSError *error;
@property (nonatomic) BOOL debug;

@end
