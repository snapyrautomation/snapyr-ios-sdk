
#import "SnapyrProxyImplementations.h"
#import "SnapyrSDK.h"


@implementation SnapyrProxyImplementations
+ (void)notificationCenterWillPresent:(NSDictionary *) info originalImp: (IMP) originalImp withCompletionHandler:(void (^)(UNNotificationPresentationOptions options)) completionHandler
{
    if (!originalImp) {
        completionHandler(UNNotificationPresentationOptionAlert);
    }
}

+ (void)notificationCenterDidReceive:(UNNotificationResponse *)response originalImp: (IMP) originalImp withCompletionHandler:(void(^)(void))completionHandler
{
    [[SnapyrSDK sharedSDK] pushNotificationTappedWithNotification:response.notification];
    [[SnapyrSDK sharedSDK] handleActionWithIdentifier:response.actionIdentifier forRemoteNotification:response.notification.request.content.userInfo];
    if (!originalImp) {
        completionHandler();
    }
}

+ (void)application:(SApplication *)application appdelegateRegisteredToAPNSWithToken: (NSData *) token
{
    [[SnapyrSDK sharedSDK] setPushNotificationTokenData:token];
    [[SnapyrSDK sharedSDK] registeredForRemoteNotificationsWithDeviceToken:token];
}

+ (void)application:(SApplication *) application continueUserActivity:(NSUserActivity *) userActivity
{
    [[SnapyrSDK sharedSDK] continueUserActivity:userActivity];
}

+ (void)application:(SApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *) error
{
    [[SnapyrSDK sharedSDK] failedToRegisterForRemoteNotificationsWithError:error];
}

+ (void)application:(SApplication *)application openURL:(NSURL *)url options:(NSDictionary *)options
{
    [[SnapyrSDK sharedSDK] openURL:url options:options];
}

@end
