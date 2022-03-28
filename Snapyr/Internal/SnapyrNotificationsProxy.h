
#import <Foundation/Foundation.h>
#import "SnapyrProxyImplementations.h"

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

@interface SnapyrNotificationsProxy : NSObject

@property(strong, nonatomic) NSMutableDictionary<NSString *, NSValue *> *originalAppDelegateImps;
@property(strong, nonatomic) NSMutableDictionary<NSString *, NSArray *> *swizzledSelectorsByClass;

@property(nonatomic) BOOL didSwizzleMethods;

@property(nonatomic) BOOL hasSwizzledUserNotificationDelegate;
@property(nonatomic) BOOL isObservingUserNotificationDelegateChanges;

@property(strong, nonatomic) id userNotificationCenter;
@property(strong, nonatomic) id currentUserNotificationCenterDelegate;

+ (instancetype)sharedProxy;
+ (BOOL)canSwizzleMethods;
- (void)swizzleMethodsIfPossible;
- (IMP)originalImplementationForSelector:(SEL)selector;
+ (SApplication *)sharedApplication;
@end

static void SnapyrSwizzleWillPresentNotificationWithHandler(id self, SEL cmd, id center, id notification, void (^handler)(NSUInteger));
static void SnapyrSwizzleDidReceiveNotificationResponseWithHandler(id self, SEL cmd, id center, id response, void (^handler)(void));
static void SnapyrSwizzleDidRegisteredForRemote(id self, SEL cmd, id application, id token);
static void SnapyrSwizzleContinueUserActivity(id self, SEL cmd, id application, id userActivity, id handler);
static void SnapyrSwizzleFailToRegisterForPN(id self, SEL cmd, id application, id error);
static void SnapyrSwizzleOpenURL(id self, SEL cmd, id application, id url, id options);
