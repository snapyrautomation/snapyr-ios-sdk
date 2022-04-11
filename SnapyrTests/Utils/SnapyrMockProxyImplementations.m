#import "SnapyrMockProxyImplementations.h"
#import <Foundation/Foundation.h>

@implementation SnapyrMockProxyImplementations

- (void)application:(SApplication *)application appdelegateRegisteredToAPNSWithToken: (NSData *) token
{
	NSLog(@"- (void)application:(SApplication *)application appdelegateRegisteredToAPNSWithToken: (NSData *) token");
	[self callBlockIfExist: self.didRegisteredForAPNS];
}

- (void)application:(SApplication *) application continueUserActivity:(NSUserActivity *) userActivity
{
	NSLog(@"- (void)application:(SApplication *) application continueUserActivity:(NSUserActivity *) userActivity");
	[self callBlockIfExist: self.continueUserActivity];
}

- (void)application:(SApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *) error
{
	NSLog(@"- (void)application:(SApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *) error");
	[self callBlockIfExist: self.didFailToRegisterForAPNS];
}

- (void)application:(SApplication *)application openURL:(NSURL *)url options:(NSDictionary *)options
{
	NSLog(@"- (void)application:(SApplication *)application openURL:(NSURL *)url options:(NSDictionary *)options");
	[self callBlockIfExist: self.openURL];
}

-(void)callBlockIfExist: (nullable void (^)(void)) block
{
	if (block) {
		block();
	}
}
@end
