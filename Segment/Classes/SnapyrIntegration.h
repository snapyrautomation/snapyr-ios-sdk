@import Foundation;
#import "SnapyrIdentifyPayload.h"
#import "SnapyrTrackPayload.h"
#import "SnapyrScreenPayload.h"
#import "SnapyrAliasPayload.h"
#import "SnapyrIdentifyPayload.h"
#import "SnapyrGroupPayload.h"
#import "SnapyrContext.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Integration)
@protocol SnapyrIntegration <NSObject>

@optional
// Identify will be called when the user calls either of the following:
// 1. [[SEGAnalytics sharedInstance] identify:someUserId];
// 2. [[SEGAnalytics sharedInstance] identify:someUserId traits:someTraits];
// 3. [[SEGAnalytics sharedInstance] identify:someUserId traits:someTraits options:someOptions];
// @see https://segment.com/docs/spec/identify/
- (void)identify:(SnapyrIdentifyPayload *)payload;

// Track will be called when the user calls either of the following:
// 1. [[SEGAnalytics sharedInstance] track:someEvent];
// 2. [[SEGAnalytics sharedInstance] track:someEvent properties:someProperties];
// 3. [[SEGAnalytics sharedInstance] track:someEvent properties:someProperties options:someOptions];
// @see https://segment.com/docs/spec/track/
- (void)track:(SnapyrTrackPayload *)payload;

// Screen will be called when the user calls either of the following:
// 1. [[SEGAnalytics sharedInstance] screen:someEvent];
// 2. [[SEGAnalytics sharedInstance] screen:someEvent properties:someProperties];
// 3. [[SEGAnalytics sharedInstance] screen:someEvent properties:someProperties options:someOptions];
// @see https://segment.com/docs/spec/screen/
- (void)screen:(SnapyrScreenPayload *)payload;

// Group will be called when the user calls either of the following:
// 1. [[SEGAnalytics sharedInstance] group:someGroupId];
// 2. [[SEGAnalytics sharedInstance] group:someGroupId traits:];
// 3. [[SEGAnalytics sharedInstance] group:someGroupId traits:someGroupTraits options:someOptions];
// @see https://segment.com/docs/spec/group/
- (void)group:(SnapyrGroupPayload *)payload;

// Alias will be called when the user calls either of the following:
// 1. [[SEGAnalytics sharedInstance] alias:someNewId];
// 2. [[SEGAnalytics sharedInstance] alias:someNewId options:someOptions];
// @see https://segment.com/docs/spec/alias/
- (void)alias:(SnapyrAliasPayload *)payload;

// Reset is invoked when the user logs out, and any data saved about the user should be cleared.
- (void)reset;

// Flush is invoked when any queued events should be uploaded.
- (void)flush;

// App Delegate Callbacks

// Callbacks for notifications changes.
// ------------------------------------
- (void)receivedRemoteNotification:(NSDictionary *)userInfo;
- (void)failedToRegisterForRemoteNotificationsWithError:(NSError *)error;
- (void)registeredForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken;
- (void)handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo;

// Callbacks for app state changes
// -------------------------------

- (void)applicationDidFinishLaunching:(NSNotification *)notification;
- (void)applicationDidEnterBackground;
- (void)applicationWillEnterForeground;
- (void)applicationWillTerminate;
- (void)applicationWillResignActive;
- (void)applicationDidBecomeActive;

- (void)continueUserActivity:(NSUserActivity *)activity;
- (void)openURL:(NSURL *)url options:(NSDictionary *)options;

@end

NS_ASSUME_NONNULL_END
