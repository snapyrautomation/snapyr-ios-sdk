
#import <Foundation/Foundation.h>
#import "SnapyrNotificationsProxy.h"
#import <objc/runtime.h>



static void *UserNotificationObserverContext = &UserNotificationObserverContext;

static NSString *kUserNotificationWillPresentSelectorString =
@"userNotificationCenter:willPresentNotification:withCompletionHandler:";
static NSString *kUserNotificationDidReceiveResponseSelectorString =
@"userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:";

#if TARGET_OS_IOS || TARGET_OS_TV

static NSString *const kApplicationClassName = @"UIApplication";
static NSString *const kApplicationDelegateName = @"UIApplicationDelegate";

#elif TARGET_OS_OSX

static NSString *const kApplicationClassName = @"NSApplication";
static NSString *const kApplicationDelegateName = @"NSApplicationDelegate";
#endif

/** The original instance of App Delegate. */
static id<SApplicationDelegate> sOriginalAppDelegate;

static NSString *const kDidRegisterForRemoteNotificationsSEL =
@"application:didRegisterForRemoteNotificationsWithDeviceToken:";
static NSString *const kContinueUserActivity = @"application:continueUserActivity:restorationHandler:";
static NSString *const kDidFailToRegisterForRemoteNotifiations = @"application:didFailToRegisterForRemoteNotificationsWithError:";
static NSString *const kOpenURL = @"application:openURL:options:";

static NSString *const kAppDelegateKeyPath = @"delegate";

id SnapyrPropertyNameForObject(id object, NSString *propertyName, Class klass) {
    SEL selector = NSSelectorFromString(propertyName);
    if (![object respondsToSelector:selector]) {
        return nil;
    }
    if (!klass) {
        klass = [NSObject class];
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    id property = [object performSelector:selector];
#pragma clang diagnostic pop
    if (![property isKindOfClass:klass]) {
        return nil;
    }
    return property;
}

static id SnapyrUserInfoFromNotification(id notification) {
    // Select the userInfo field from UNNotification.request.content.userInfo.
    SEL requestSelector = NSSelectorFromString(@"request");
    if (![notification respondsToSelector:requestSelector]) {
        // Cannot access the request property.
        return nil;
    }
    Class requestClass = NSClassFromString(@"UNNotificationRequest");
    id notificationRequest =
    SnapyrPropertyNameForObject(notification, @"request", requestClass);
    
    SEL notificationContentSelector = NSSelectorFromString(@"content");
    if (!notificationRequest ||
        ![notificationRequest respondsToSelector:notificationContentSelector]) {
        // Cannot access the content property.
        return nil;
    }
    Class contentClass = NSClassFromString(@"UNNotificationContent");
    id notificationContent =
    SnapyrPropertyNameForObject(notificationRequest, @"content", contentClass);
    
    SEL notificationUserInfoSelector = NSSelectorFromString(@"userInfo");
    if (!notificationContent ||
        ![notificationContent respondsToSelector:notificationUserInfoSelector]) {
        // Cannot access the userInfo property.
        return nil;
    }
    id notificationUserInfo =
    SnapyrPropertyNameForObject(notificationContent, @"userInfo", [NSDictionary class]);
    
    if (!notificationUserInfo) {
        // This is not the expected notification handler.
        return nil;
    }
    
    return notificationUserInfo;
}



@implementation SnapyrNotificationsProxy

+ (BOOL)canSwizzleMethods {
    return YES;
}

+ (instancetype)sharedProxy {
    static SnapyrNotificationsProxy *proxy;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        proxy = [[SnapyrNotificationsProxy alloc] init];
    });
    return proxy;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _originalAppDelegateImps = [[NSMutableDictionary alloc] init];
        _swizzledSelectorsByClass = [[NSMutableDictionary alloc] init];
    }
    return self;
}



- (void)swizzleMethodsIfPossible {
    // Already swizzled.
    if (self.didSwizzleMethods) {
        return;
    }
    
    [self swizzleAppDelegate:[[SnapyrNotificationsProxy sharedApplication] delegate]];
    
    [self swizzleUserNotificationsCenter];
    
    self.didSwizzleMethods = YES;
}

- (void)swizzleUserNotificationsCenter {
    if (!NSProcessInfo.processInfo.environment[@"XCTestConfigurationFilePath"]) {
        Class notificationCenterClass = NSClassFromString(@"UNUserNotificationCenter");
        if (notificationCenterClass) {
            id notificationCenter = SnapyrPropertyNameForObject(notificationCenterClass, @"currentNotificationCenter", notificationCenterClass);
            if (notificationCenter) {
                [self listenForDelegateChangesInUserNotificationCenter:notificationCenter];
            }
        }
    }
}

- (void)listenForDelegateChangesInUserNotificationCenter:(id)notificationCenter {
    Class notificationCenterClass = NSClassFromString(@"UNUserNotificationCenter");
    if (![notificationCenter isKindOfClass:notificationCenterClass]) {
        return;
    }
    id delegate = SnapyrPropertyNameForObject(notificationCenter, @"delegate", nil);
    Protocol *delegateProtocol = NSProtocolFromString(@"UNUserNotificationCenterDelegate");
    if ([delegate conformsToProtocol:delegateProtocol]) {
        // Swizzle this object now, if available
        [self swizzleUserNotificationCenterDelegate:delegate];
    }
    // Add KVO observer for "delegate" keyPath for future changes
    [self addDelegateObserverToUserNotificationCenter:notificationCenter];
}

- (void)swizzleUserNotificationCenterDelegate:(id _Nonnull)delegate {
    if (self.currentUserNotificationCenterDelegate == delegate) {
        // Via pointer-check, compare if we have already swizzled this item.
        return;
    }
    Protocol *userNotificationCenterProtocol =
    NSProtocolFromString(@"UNUserNotificationCenterDelegate");
    if ([delegate conformsToProtocol:userNotificationCenterProtocol]) {
        SEL willPresentNotificationSelector =
        NSSelectorFromString(kUserNotificationWillPresentSelectorString);
        // Swizzle the optional method
        // "userNotificationCenter:willPresentNotification:withCompletionHandler:", if it is
        // implemented. Do not swizzle otherwise, as an implementation *will* be created, which will
        // fool iOS into thinking that this method is implemented, and therefore not send notifications
        // to the fallback method in the app delegate
        // "application:didReceiveRemoteNotification:fetchCompletionHandler:".
            [self swizzleSelector:willPresentNotificationSelector
                          inClass:[delegate class]
               withImplementation:(IMP)SnapyrSwizzleWillPresentNotificationWithHandler
                       inProtocol:userNotificationCenterProtocol];
        SEL didReceiveNotificationResponseSelector =
        NSSelectorFromString(kUserNotificationDidReceiveResponseSelectorString);
            [self swizzleSelector:didReceiveNotificationResponseSelector
                          inClass:[delegate class]
               withImplementation:(IMP)SnapyrSwizzleDidReceiveNotificationResponseWithHandler
                       inProtocol:userNotificationCenterProtocol];
        self.currentUserNotificationCenterDelegate = delegate;
        self.hasSwizzledUserNotificationDelegate = YES;
    }
}

- (void)swizzleAppDelegate:(id _Nonnull)delegate {
    Protocol *appDelegate =
    NSProtocolFromString(kApplicationDelegateName);
    if ([delegate conformsToProtocol:appDelegate]) {

        SEL didRegisterForRemoteNotificationsSEL =
        NSSelectorFromString(kDidRegisterForRemoteNotificationsSEL);
            [self swizzleSelector:didRegisterForRemoteNotificationsSEL
                          inClass:[delegate class]
               withImplementation:(IMP)SnapyrSwizzleDidRegisteredForRemote
                       inProtocol:appDelegate];
        
        SEL continueUserActivitySEL = NSSelectorFromString(kContinueUserActivity);
        [self swizzleSelector:continueUserActivitySEL
                      inClass:[delegate class]
           withImplementation:(IMP)SnapyrSwizzleContinueUserActivity
                   inProtocol:appDelegate];
        
        SEL failToRegisterForPNSEL = NSSelectorFromString(kDidFailToRegisterForRemoteNotifiations);
        [self swizzleSelector:failToRegisterForPNSEL
                      inClass:[delegate class]
           withImplementation:(IMP)SnapyrSwizzleFailToRegisterForPN
                   inProtocol:appDelegate];
        
        SEL openUrlSEL = NSSelectorFromString(kOpenURL);
        [self swizzleSelector:openUrlSEL
                      inClass:[delegate class]
           withImplementation:(IMP)SnapyrSwizzleOpenURL
                   inProtocol:appDelegate];
    }
}

- (void)addDelegateObserverToUserNotificationCenter:(id)userNotificationCenter {
    [self removeUserNotificationCenterDelegateObserver];
    @try {
        [userNotificationCenter addObserver:self
                                 forKeyPath:NSStringFromSelector(@selector(delegate))
                                    options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                                    context:UserNotificationObserverContext];
        self.userNotificationCenter = userNotificationCenter;
        self.isObservingUserNotificationDelegateChanges = YES;
    } @catch (NSException *exception) {
    }
}

- (void)removeUserNotificationCenterDelegateObserver {
    if (!self.userNotificationCenter) {
        return;
    }
    @try {
        [self.userNotificationCenter removeObserver:self
                                         forKeyPath:NSStringFromSelector(@selector(delegate))
                                            context:UserNotificationObserverContext];
        self.userNotificationCenter = nil;
        self.isObservingUserNotificationDelegateChanges = NO;
    } @catch (NSException *exception) {
    }
}


- (void)swizzleSelector:(SEL)originalSelector inClass:(Class)klass withImplementation:(IMP)swizzledImplementation inProtocol:(Protocol *)protocol {
    Method originalMethod = class_getInstanceMethod(klass, originalSelector);
    
    if (originalMethod) {
        // This class implements this method, so replace the original implementation
        // with our new implementation and save the old implementation.
        
        IMP originalMethodImplementation =
        method_setImplementation(originalMethod, swizzledImplementation);
        
        IMP nonexistantMethodImplementation = [self nonExistantMethodImplementationForClass:klass];
        
        if (originalMethodImplementation &&
            originalMethodImplementation != nonexistantMethodImplementation &&
            originalMethodImplementation != swizzledImplementation) {
            [self saveOriginalImplementation:originalMethodImplementation forSelector:originalSelector];
        }
    } else {
        // The class doesn't have this method, so add our swizzled implementation as the
        // original implementation of the original method.
        struct objc_method_description methodDescription =
        protocol_getMethodDescription(protocol, originalSelector, NO, YES);
        
        class_addMethod(klass, originalSelector, swizzledImplementation, methodDescription.types);
    }
    [self trackSwizzledSelector:originalSelector ofClass:klass];
}
- (IMP)nonExistantMethodImplementationForClass:(Class)klass {
    SEL nonExistantSelector = NSSelectorFromString(@"aNonExistantMethod");
    IMP nonExistantMethodImplementation = class_getMethodImplementation(klass, nonExistantSelector);
    return nonExistantMethodImplementation;
}

- (void)saveOriginalImplementation:(IMP)imp forSelector:(SEL)selector {
    if (imp && selector) {
        NSValue *IMPValue = [NSValue valueWithPointer:imp];
        NSString *selectorString = NSStringFromSelector(selector);
        self.originalAppDelegateImps[selectorString] = IMPValue;
    }
}

- (void)trackSwizzledSelector:(SEL)selector ofClass:(Class)klass {
    NSString *className = NSStringFromClass(klass);
    NSString *selectorString = NSStringFromSelector(selector);
    NSArray *selectors = self.swizzledSelectorsByClass[selectorString];
    if (selectors) {
        selectors = [selectors arrayByAddingObject:selectorString];
    } else {
        selectors = @[ selectorString ];
    }
    self.swizzledSelectorsByClass[className] = selectors;
}

- (IMP)originalImplementationForSelector:(SEL)selector {
    NSString *selectorString = NSStringFromSelector(selector);
    NSValue *implementationValue = self.originalAppDelegateImps[selectorString];
    if (!implementationValue) {
        return nil;
    }
    
    IMP imp;
    [implementationValue getValue:&imp];
    return imp;
}

+ (SApplication *)sharedApplication {
    id sharedApplication = nil;
    Class uiApplicationClass = NSClassFromString(kApplicationClassName);
    if (uiApplicationClass &&
        [uiApplicationClass respondsToSelector:(NSSelectorFromString(@"sharedApplication"))]) {
        sharedApplication = [uiApplicationClass sharedApplication];
    }
    return sharedApplication;
}

@end


// Swizzled methods


static void SnapyrSwizzleWillPresentNotificationWithHandler(id self, SEL cmd, id center, id notification, void (^handler)(NSUInteger)) {
    SnapyrNotificationsProxy *proxy = [SnapyrNotificationsProxy sharedProxy];
    IMP originalImp = [proxy originalImplementationForSelector:cmd];
    
    void (^callOriginalMethodIfAvailable)(void) = ^{
        if (originalImp) {
            ((void (*)(id, SEL, id, id, void (^)(NSUInteger)))originalImp)(self, cmd, center,
                                                                           notification, handler);
        }
        return;
    };
    
    Class notificationCenterClass = NSClassFromString(@"UNUserNotificationCenter");
    Class notificationClass = NSClassFromString(@"UNNotification");
    if (!notificationCenterClass || !notificationClass) {
        // Can't find UserNotifications framework. Do not swizzle, just execute the original method.
        callOriginalMethodIfAvailable();
    }
    
    if (!center || ![center isKindOfClass:[notificationCenterClass class]]) {
        // Invalid parameter type from the original method.
        // Do not swizzle, just execute the original method.
        callOriginalMethodIfAvailable();
        return;
    }
    
    if (!notification || ![notification isKindOfClass:[notificationClass class]]) {
        // Invalid parameter type from the original method.
        // Do not swizzle, just execute the original method.
        callOriginalMethodIfAvailable();
        return;
    }
    
    if (!handler) {
        // Invalid parameter type from the original method.
        // Do not swizzle, just execute the original method.
        callOriginalMethodIfAvailable();
        return;
    }
    
    // Attempt to access the user info
    id notificationUserInfo = SnapyrUserInfoFromNotification(notification);
    
    if (!notificationUserInfo) {
        // Could not access notification.request.content.userInfo.
        callOriginalMethodIfAvailable();
        return;
    }
    
    [SnapyrProxyImplementations notificationCenterWillPresent:notificationUserInfo originalImp:originalImp withCompletionHandler:handler];
    // Execute the original implementation.
    callOriginalMethodIfAvailable();
}


static void SnapyrSwizzleDidReceiveNotificationResponseWithHandler(id self, SEL cmd, id center, id response, void (^handler)(void)) {
    SnapyrNotificationsProxy *proxy = [SnapyrNotificationsProxy sharedProxy];
    IMP originalImp = [proxy originalImplementationForSelector:cmd];
    
    void (^callOriginalMethodIfAvailable)(void) = ^{
        if (originalImp) {
            ((void (*)(id, SEL, id, id, void (^)(void)))originalImp)(self, cmd, center, response,
                                                                     handler);
        }
        return;
    };
    
    Class notificationCenterClass = NSClassFromString(@"UNUserNotificationCenter");
    Class responseClass = NSClassFromString(@"UNNotificationResponse");
    if (!center || ![center isKindOfClass:[notificationCenterClass class]]) {
        // Invalid parameter type from the original method.
        // Do not swizzle, just execute the original method.
        callOriginalMethodIfAvailable();
        return;
    }
    
    if (!response || ![response isKindOfClass:[responseClass class]]) {
        // Invalid parameter type from the original method.
        // Do not swizzle, just execute the original method.
        callOriginalMethodIfAvailable();
        return;
    }
    
    if (!handler) {
        // Invalid parameter type from the original method.
        // Do not swizzle, just execute the original method.
        callOriginalMethodIfAvailable();
        return;
    }
      
    
    [SnapyrProxyImplementations notificationCenterDidReceive:response originalImp:originalImp withCompletionHandler:handler];
    // Execute the original implementation.
    callOriginalMethodIfAvailable();
}


static void SnapyrSwizzleDidRegisteredForRemote(id self, SEL cmd, id application, id token) {
    SnapyrNotificationsProxy *proxy = [SnapyrNotificationsProxy sharedProxy];
    IMP originalImp = [proxy originalImplementationForSelector:cmd];
    
    void (^callOriginalMethodIfAvailable)(void) = ^{
        if (originalImp) {
            ((void (*)(id, SEL, id, id))originalImp)(self, cmd, application, token);
        }
        return;
    };
    
    [SnapyrProxyImplementations application:application appdelegateRegisteredToAPNSWithToken:token];
    
    // Execute the original implementation.
    callOriginalMethodIfAvailable();
}


static void SnapyrSwizzleContinueUserActivity(id self, SEL cmd, id application, id userActivity, id handler)
{
    SnapyrNotificationsProxy *proxy = [SnapyrNotificationsProxy sharedProxy];
    IMP originalImp = [proxy originalImplementationForSelector:cmd];
    
    void (^callOriginalMethodIfAvailable)(void) = ^{
        if (originalImp) {
            ((void (*)(id, SEL, id, id, id))originalImp)(self, cmd, application, userActivity, handler);
        }
        return;
    };
    
    [SnapyrProxyImplementations application:application continueUserActivity:userActivity];
    
    // Execute the original implementation.
    callOriginalMethodIfAvailable();
}

static void SnapyrSwizzleFailToRegisterForPN(id self, SEL cmd, id application, id error)
{
    SnapyrNotificationsProxy *proxy = [SnapyrNotificationsProxy sharedProxy];
    IMP originalImp = [proxy originalImplementationForSelector:cmd];
    
    void (^callOriginalMethodIfAvailable)(void) = ^{
        if (originalImp) {
            ((void (*)(id, SEL, id, id))originalImp)(self, cmd, application, error);
        }
        return;
    };
    
    [SnapyrProxyImplementations application:application didFailToRegisterForRemoteNotificationsWithError:error];
    
    // Execute the original implementation.
    callOriginalMethodIfAvailable();
}

static void SnapyrSwizzleOpenURL(id self, SEL cmd, id application, id url, id options)
{
    SnapyrNotificationsProxy *proxy = [SnapyrNotificationsProxy sharedProxy];
    IMP originalImp = [proxy originalImplementationForSelector:cmd];
    
    void (^callOriginalMethodIfAvailable)(void) = ^{
        if (originalImp) {
            ((void (*)(id, SEL, id, id, id))originalImp)(self, cmd, application, url, options);
        }
        return;
    };
    
    [SnapyrProxyImplementations application:application openURL:url options:options];
    
    // Execute the original implementation.
    callOriginalMethodIfAvailable();
}
