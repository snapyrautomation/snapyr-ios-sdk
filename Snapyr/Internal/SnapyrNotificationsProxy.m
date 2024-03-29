
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
		if (!_proxyImplementations) {
			_proxyImplementations = [[SnapyrProxyImplementations alloc] init];
		}
    }
    return self;
}

- (void)dealloc {
	[self unswizzleMethodsIfPossible];
	self.swizzledSelectorsByClass = nil;
	self.originalAppDelegateImps = nil;
}

- (void)unswizzleMethodsIfPossible
{
	// Already unswizzled.
	if (!self.didSwizzleMethods) {
		return;
	}
	[self unswizzleAllMethods];
	[self.originalAppDelegateImps removeAllObjects];
	[self removeUserNotificationCenterDelegateObserver];
	self.didSwizzleMethods = NO;
}

- (void)swizzleMethodsIfPossible {
    // Already swizzled.
    if (self.didSwizzleMethods) {
        return;
    }
	id appDel = _customAppDelegate;
	if (!appDel) {
		appDel = [[SnapyrNotificationsProxy sharedApplication] delegate];
	}
    [self swizzleAppDelegate: appDel];
    
    [self swizzleUserNotificationsCenter];
    
    self.didSwizzleMethods = YES;
}

- (void)swizzleUserNotificationsCenter {
    if (!NSProcessInfo.processInfo.environment[@"XCTestConfigurationFilePath"]) {
        if (@available(tvOS 12, *)) {}
        else {
            Class notificationCenterClass = NSClassFromString(@"UNUserNotificationCenter");
            if (notificationCenterClass) {
                id notificationCenter = SnapyrPropertyNameForObject(notificationCenterClass, @"currentNotificationCenter", notificationCenterClass);
                if (notificationCenter) {
                    [self listenForDelegateChangesInUserNotificationCenter:notificationCenter];
                }
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
    NSArray *selectors = self.swizzledSelectorsByClass[className];
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

- (void)unswizzleAllMethods {
	for (NSString *className in self.swizzledSelectorsByClass) {
		Class klass = NSClassFromString(className);
		NSArray *selectorStrings = self.swizzledSelectorsByClass[className];
		for (NSString *selectorString in selectorStrings) {
			SEL selector = NSSelectorFromString(selectorString);
			[self unswizzleSelector:selector inClass:klass];
		}
	}
	[self.swizzledSelectorsByClass removeAllObjects];
//	self.swizzledSelectorsByClass = [@{} mutableCopy];
}

- (void)unswizzleSelector:(SEL)selector inClass:(Class)klass {
	Method swizzledMethod = class_getInstanceMethod(klass, selector);
	if (!swizzledMethod) {
		// This class doesn't seem to have this selector as an instance method? Bail out.
		return;
	}
	
	IMP originalImp = [self originalImplementationForSelector:selector];
	if (originalImp) {
		// Restore the original implementation as the current implementation
		method_setImplementation(swizzledMethod, originalImp);
		[self removeImplementationForSelector:selector];
	} else {
		// This class originally did not have an implementation for this selector.
		
		// We can't actually remove methods in Objective C 2.0, but we could set
		// its method to something non-existent. This should give us the same
		// behavior as if the method was not implemented.
		// See: http://stackoverflow.com/a/8276527/9849
		
		IMP nonExistantMethodImplementation = [self nonExistantMethodImplementationForClass:klass];
		method_setImplementation(swizzledMethod, nonExistantMethodImplementation);
	}
}

- (void)unswizzleUserNotificationCenterDelegate:(id _Nonnull)delegate {
	if (self.currentUserNotificationCenterDelegate != delegate) {
		// We aren't swizzling this delegate, so don't do anything.
		return;
	}
	SEL willPresentNotificationSelector =
	NSSelectorFromString(kUserNotificationWillPresentSelectorString);
	// Call unswizzle methods, even if the method was not implemented (it will fail gracefully).
	[self unswizzleSelector:willPresentNotificationSelector
					inClass:[self.currentUserNotificationCenterDelegate class]];
	SEL didReceiveNotificationResponseSelector =
	NSSelectorFromString(kUserNotificationDidReceiveResponseSelectorString);
	[self unswizzleSelector:didReceiveNotificationResponseSelector
					inClass:[self.currentUserNotificationCenterDelegate class]];
	self.currentUserNotificationCenterDelegate = nil;
	self.hasSwizzledUserNotificationDelegate = NO;
}

- (void)removeImplementationForSelector:(SEL)selector {
	NSString *selectorString = NSStringFromSelector(selector);
	[self.originalAppDelegateImps removeObjectForKey:selectorString];
}

// Swizzled methods


void SnapyrSwizzleWillPresentNotificationWithHandler(id self, SEL cmd, id center, id notification, void (^handler)(NSUInteger)) {
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
	
#if !TARGET_OS_TV
	[[proxy proxyImplementations] notificationCenterWillPresent:notificationUserInfo originalImp:originalImp withCompletionHandler:handler];
#endif
	// Execute the original implementation.
	callOriginalMethodIfAvailable();
}


void SnapyrSwizzleDidReceiveNotificationResponseWithHandler(id self, SEL cmd, id center, id response, void (^handler)(void)) {
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
	
#if !TARGET_OS_TV
	[[proxy proxyImplementations] notificationCenterDidReceive:response originalImp:originalImp withCompletionHandler:handler];
#endif
	// Execute the original implementation.
	callOriginalMethodIfAvailable();
}


void SnapyrSwizzleDidRegisteredForRemote(id self, SEL cmd, id application, id token) {
	SnapyrNotificationsProxy *proxy = [SnapyrNotificationsProxy sharedProxy];
	IMP originalImp = [proxy originalImplementationForSelector:cmd];
	
	void (^callOriginalMethodIfAvailable)(void) = ^{
		if (originalImp) {
			((void (*)(id, SEL, id, id))originalImp)(self, cmd, application, token);
		}
		return;
	};
	
	[[proxy proxyImplementations] application:application appdelegateRegisteredToAPNSWithToken:token];
	
	// Execute the original implementation.
	callOriginalMethodIfAvailable();
}


void SnapyrSwizzleContinueUserActivity(id self, SEL cmd, id application, id userActivity, id handler)
{
	SnapyrNotificationsProxy *proxy = [SnapyrNotificationsProxy sharedProxy];
	IMP originalImp = [proxy originalImplementationForSelector:cmd];
	
	void (^callOriginalMethodIfAvailable)(void) = ^{
		if (originalImp) {
			((void (*)(id, SEL, id, id, id))originalImp)(self, cmd, application, userActivity, handler);
		}
		return;
	};
	
	[[proxy proxyImplementations] application:application continueUserActivity:userActivity];
	
	// Execute the original implementation.
	callOriginalMethodIfAvailable();
}

void SnapyrSwizzleFailToRegisterForPN(id self, SEL cmd, id application, id error)
{
	SnapyrNotificationsProxy *proxy = [SnapyrNotificationsProxy sharedProxy];
	IMP originalImp = [proxy originalImplementationForSelector:cmd];
	
	void (^callOriginalMethodIfAvailable)(void) = ^{
		if (originalImp) {
			((void (*)(id, SEL, id, id))originalImp)(self, cmd, application, error);
		}
		return;
	};
	
	[[proxy proxyImplementations] application:application didFailToRegisterForRemoteNotificationsWithError:error];
	
	// Execute the original implementation.
	callOriginalMethodIfAvailable();
}

void SnapyrSwizzleOpenURL(id self, SEL cmd, id application, id url, id options)
{
	SnapyrNotificationsProxy *proxy = [SnapyrNotificationsProxy sharedProxy];
	IMP originalImp = [proxy originalImplementationForSelector:cmd];
	
	void (^callOriginalMethodIfAvailable)(void) = ^{
		if (originalImp) {
			((void (*)(id, SEL, id, id, id))originalImp)(self, cmd, application, url, options);
		}
		return;
	};
	
	[[proxy proxyImplementations] application:application openURL:url options:options];
	
	// Execute the original implementation.
	callOriginalMethodIfAvailable();
}


@end
