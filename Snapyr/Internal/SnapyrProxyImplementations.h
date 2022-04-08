

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>

#if TARGET_OS_IOS || TARGET_OS_TV

#import <UIKit/UIKit.h>

#define SApplication UIApplication
#define SApplicationDelegate UIApplicationDelegate
#define SUserActivityRestoring UIUserActivityRestoring

#elif TARGET_OS_OSX

#import <AppKit/AppKit.h>

#define SApplication NSApplication
#define SApplicationDelegate NSApplicationDelegate
#define SUserActivityRestoring NSUserActivityRestoring
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SnapyrProxyImplementations: NSObject

- (void)notificationCenterWillPresent:(NSDictionary *)info originalImp: (IMP) originalImp withCompletionHandler:(void (^)(UNNotificationPresentationOptions options)) completionHandler API_UNAVAILABLE(tvos);
- (void)notificationCenterDidReceive:(UNNotificationResponse *)response originalImp: (IMP) originalImp withCompletionHandler:(void(^)(void))completionHandler API_UNAVAILABLE(tvos);
- (void)application:(SApplication *)application appdelegateRegisteredToAPNSWithToken: (NSData *) token;
- (void)application:(SApplication *)application continueUserActivity:(NSUserActivity *) userActivity;
- (void)application:(SApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *) error;
- (void)application:(SApplication *)application openURL:(NSURL *)url options:(NSDictionary *)options;

@end

NS_ASSUME_NONNULL_END
