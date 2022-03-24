
#import "SnapyrProxyImplementations.h"
#import "SnapyrSDK.h"


@implementation SnapyrProxyImplementations
+ (void)notificationCenterWillPresent:(NSDictionary *) info originalImp: (IMP) originalImp withCompletionHandler:(void (^)(UNNotificationPresentationOptions options)) completionHandler
{
    if (!originalImp) {
        completionHandler(UNNotificationPresentationOptionAlert);
    }
}

+ (void)notificationCenterDidReceive:(NSDictionary *)response originalImp: (IMP) originalImp withCompletionHandler:(void(^)(void))completionHandler
{
    [[SnapyrSDK sharedSDK] pushNotificationTapped:response];
    if (!originalImp) {
        completionHandler();
    }
}

+ (void)application:(SApplication *)application appdelegateRegisteredToAPNSWithToken: (NSData *) token
{
    [[SnapyrSDK sharedSDK] setPushNotificationTokenData:token];
}

@end
