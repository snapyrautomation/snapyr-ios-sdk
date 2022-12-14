#import <objc/runtime.h>
#import "SnapyrSDKUtils.h"
#import "SnapyrSDK.h"
#import "SnapyrIntegrationFactory.h"
#import "SnapyrIntegration.h"
#import "SnapyrSnapyrIntegrationFactory.h"
#import "UIViewController+SnapyrScreen.h"
#import "NSViewController+SnapyrScreen.h"
#import "SnapyrStoreKitTracker.h"
#import "SnapyrHTTPClient.h"
#import "SnapyrStorage.h"
#import "SnapyrFileStorage.h"
#import "SnapyrUserDefaultsStorage.h"
#import "SnapyrMiddleware.h"
#import "SnapyrContext.h"
#import "SnapyrIntegrationsManager.h"
#import "SnapyrState.h"
#import "SnapyrUtils.h"
#import "SnapyrNotificationsProxy.h"
#import "SnapyrActions/SnapyrActionViewController.h"
#import "SnapyrNotification.h"

static SnapyrSDK *__sharedInstance = nil;


@interface SnapyrSDK ()

@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, strong) SnapyrSDKConfiguration *oneTimeConfiguration;
@property (nonatomic, strong) SnapyrStoreKitTracker *storeKitTracker;
@property (nonatomic, strong) SnapyrIntegrationsManager *integrationsManager;
@property (nonatomic, strong) SnapyrMiddlewareRunner *runner;
#if !TARGET_OS_OSX && !TARGET_OS_TV
@property (nonatomic, strong) SnapyrActionViewController *inAppViewController;
#endif
@end


@implementation SnapyrSDK

#if !TARGET_OS_OSX && !TARGET_OS_TV
- (void)triggerTestInAppPopupWithHtml:(NSString *)htmlContent
{
    NSDictionary *samplePayload = @{
        @"content": @{
            @"payload": htmlContent,
            @"payloadType": @"html",
        },
        @"actionType": @"overlay",
        @"userId": @"user123",
        @"actionToken": @"abcdef123456",
        @"timestamp": @"2022-01-02T12:34:56Z",
    };
    SnapyrInAppMessage *message = [[SnapyrInAppMessage alloc] initWithActionPayload:samplePayload];
    _inAppViewController = [[SnapyrActionViewController alloc] initWithSDK:self withMessage:message];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.inAppViewController showHtmlMessage];
    });
}
#endif

+ (void)setupWithConfiguration:(SnapyrSDKConfiguration *)configuration;
{
    [SnapyrUtils setConfiguration:configuration];
    // TODO: fix up swizzling and re-enable
//	SnapyrNotificationsProxy *proxy = [SnapyrNotificationsProxy sharedProxy];
//	if (configuration.swizzleAppDelegateAndUserNotificationsDelegate) {
//		[proxy swizzleMethodsIfPossible];
//	} else {
//		[proxy unswizzleMethodsIfPossible];
//	}
    DLog(@"SnapyrSDK.setupWithConfiguration");
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __sharedInstance = [[self alloc] initWithConfiguration:configuration];
    });
}

+ (void)handleNoticationExtensionRequestWithBestAttemptContent:(UNMutableNotificationContent * _Nonnull)bestAttemptContent originalRequest:(UNNotificationRequest *_Nonnull)originalRequest contentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler
{
    [SnapyrSDK handleNoticationExtensionRequestWithBestAttemptContent:bestAttemptContent originalRequest:originalRequest contentHandler:contentHandler snapyrEnvironment:SnapyrEnvironmentDefault];
}

+ (void)handleNoticationExtensionRequestWithWriteKey:(NSString *)writeKey bestAttemptContent:(UNMutableNotificationContent * _Nonnull)bestAttemptContent originalRequest:(UNNotificationRequest *_Nonnull)originalRequest contentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler
{
    [SnapyrSDK handleNoticationExtensionRequestWithWriteKey:writeKey bestAttemptContent:bestAttemptContent originalRequest:originalRequest contentHandler:contentHandler snapyrEnvironment:SnapyrEnvironmentDefault];
}

+ (void)handleNoticationExtensionRequestWithBestAttemptContent:(UNMutableNotificationContent * _Nonnull)bestAttemptContent originalRequest:(UNNotificationRequest *_Nonnull)originalRequest contentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler snapyrEnvironment:(SnapyrEnvironment)snapyrEnvironment
{
    @try {
        NSString *writeKey = [SnapyrUtils getWriteKey];
        if (!writeKey) {
            DLog(@"SnapyrSDK NotifExt: Could not get stored write key; returning");
            contentHandler(bestAttemptContent);
            return;
        }
        [SnapyrSDK handleNoticationExtensionRequestWithWriteKey:writeKey bestAttemptContent:bestAttemptContent originalRequest:originalRequest contentHandler:contentHandler snapyrEnvironment:SnapyrEnvironmentDefault];
    } @catch (NSException *exception) {
        DLog(@"SnapyrSDK NotifExt: Could not get stored write key; returning");
        contentHandler(bestAttemptContent);
        return;
    }
    
}

+ (void)handleNoticationExtensionRequestWithWriteKey:(NSString *)writeKey bestAttemptContent:(UNMutableNotificationContent * _Nonnull)bestAttemptContent originalRequest:(UNNotificationRequest *_Nonnull)originalRequest contentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler snapyrEnvironment:(SnapyrEnvironment)snapyrEnvironment
{
    NSDictionary *snapyrData = originalRequest.content.userInfo[@"snapyr"];
    if (!snapyrData) {
        DLog(@"SnapyrSDK NotifExt: Not a Snapyr notification (no Snapyr payload); returning.");
        contentHandler(bestAttemptContent);
        return;
    }
    
    SnapyrSDKConfiguration *config = [SnapyrUtils getSavedConfigurationWithEnvironment:snapyrEnvironment];
    SnapyrSDK *sdk = [[SnapyrSDK alloc] initWithConfiguration:config];
    [sdk pushNotificationReceived:originalRequest.content.userInfo];
    
    NSDictionary *payloadTemplate = snapyrData[@"pushTemplate"];
    if (!payloadTemplate || !payloadTemplate[@"id"] || !payloadTemplate[@"modified"]) {
        DLog(@"SnapyrSDK NotifExt: Missing template data on payload; returning.");
        contentHandler(bestAttemptContent);
        return;
    }
    
    
    __block bool categoryFetchFinished = NO;
    __block bool imageFetchFinished = NO;
    void (^tryToComplete)(void) = ^void {
        if (categoryFetchFinished && imageFetchFinished) {
            contentHandler(bestAttemptContent);
        }
    };
    
    // Always set category id to template ID - if this template has no actions (no category registered) it will simply be ignored
    bestAttemptContent.categoryIdentifier = payloadTemplate[@"id"];
    
    SnapyrSDKConfiguration *oneOffConfig = [SnapyrSDKConfiguration configurationWithWriteKey:writeKey];
    oneOffConfig.snapyrEnvironment = snapyrEnvironment;
    SnapyrIntegrationsManager *integrationsManager = [[SnapyrIntegrationsManager alloc] initForExtensionWithConfig:oneOffConfig];
    NSDictionary *cachedTemplate = [integrationsManager getCachedPushDataForTemplateId:payloadTemplate[@"id"]];
    
    if (cachedTemplate == nil || [cachedTemplate[@"modified"] caseInsensitiveCompare:payloadTemplate[@"modified"]] == NSOrderedAscending) {
        // Template id missing from cache, or outdated. Trigger SDK settings refresh and check again
        [integrationsManager refreshSettingsWithCompletionHandler:^(BOOL success, NSDictionary *settings) {
            if (success) {
                DLog(@"SnapyrSDK NotifExt: Settings refresh successful.");
                // When updated categories were just registered (as part of refreshSettings...), they're not available yet for the current
                // notification - it'll still use the outdated category definition.
                // Reading the categories back seems to invalidate/flush the updates, making this work. Fun times.
                // Since the category read is async, wait until the callback to process the original notification extension contentHandler
                // callback (which finishes processing the incoming notification - it's ready to display w/ new categories at that point)
                // TODO: move this readback/flush into the integrations manager code?
                if ((NSBundle.mainBundle.bundleIdentifier) && (!NSProcessInfo.processInfo.environment[@"XCTestConfigurationFilePath"])) {
                    @try {
                        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
                        [center getNotificationCategoriesWithCompletionHandler:^(NSSet<UNNotificationCategory *> *categories) {
                            NSDictionary *newCachedTemplate = [integrationsManager getCachedPushDataForTemplateId:payloadTemplate[@"id"]];
                            if (newCachedTemplate == nil) {
                                DLog(@"SnapyrSDK NotifExt: Template on payload still missing from updated settings.");
                            } else {
                                DLog(@"SnapyrSDK NotifExt: Template data found after settings refresh.");
                            }
                            categoryFetchFinished = YES;
                            tryToComplete();
                        }];
                    } @catch (NSException *exception) {
                        DLog(@"SnapyrSDK NotifExt: Issue with UNUserNotificationManager occured");
                        categoryFetchFinished = YES;
                        tryToComplete();
                    }
                }
            } else {
                // Nothing further we can do, let the service extension finish processing
                DLog(@"SnapyrSDK NotifExt: Failed attempt to refresh template data.");
                categoryFetchFinished = YES;
                tryToComplete();
            }
        }];
    } else {
        // Cached template data is up-to-date - no further work to do
        DLog(@"SnapyrSDK NotifExt: Using cached template data.");
        categoryFetchFinished = YES;
        tryToComplete();
    }
    NSString *urlPath = snapyrData[@"imageUrl"];
    if (![urlPath isEqualToString:@""]) {
        NSURL *url = [[NSURL alloc] initWithString:urlPath];
        NSURL *destination = [[[NSURL alloc] initFileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:url.lastPathComponent];
        
        NSURLSessionConfiguration *config = NSURLSessionConfiguration.defaultSessionConfiguration;
        config.timeoutIntervalForRequest = 4;
        config.timeoutIntervalForResource = 4;
        
        NSURLSessionDataTask *task = [[NSURLSession sessionWithConfiguration:config] dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if ((data == NULL) || (error != NULL)) {
                DLog(@"SnapyrSDK NotifExt: Could not fetch notification image from URL");
                imageFetchFinished = YES;
                tryToComplete();
            } else {
                @try {
                    [data writeToURL:destination atomically:false];
                    // empty attachment lets the system create its own UUID
                    UNNotificationAttachment *attachment = [UNNotificationAttachment attachmentWithIdentifier:@"" URL:destination options:NULL error:NULL];
                    bestAttemptContent.attachments = @[attachment];
                    imageFetchFinished = YES;
                    tryToComplete();
                } @catch (NSException *exception) {
                    DLog(@"SnapyrSDK NotifExt: Exception happened while creating attachment");
                    imageFetchFinished = YES;
                    tryToComplete();
                }
            }
        }];
        [task resume];
    } else {
        imageFetchFinished = YES;
        tryToComplete();
    }
}

// Just pass thru to integrationsManager, where the data actually lives
// TODO: (@paulwsmith) rename/refactor to `getPayloadForActionId`? (support deep link + other payload types like user-defined JSON)
- (nullable NSURL *)getDeepLinkForActionId:(NSString *)actionId
{
    return [self.integrationsManager getDeepLinkForActionId:actionId];
}

- (instancetype)initWithConfiguration:(SnapyrSDKConfiguration *)configuration
{
    DLog(@"SnapyrSDK.initWithConfiguration");
    NSCParameterAssert(configuration != nil);

    if (self = [self init]) {
        self.oneTimeConfiguration = configuration;
        self.enabled = YES;
        // In swift this would not have been OK... But hey.. It's objc
        // TODO: Figure out if this is really the best way to do things here.
        self.integrationsManager = [[SnapyrIntegrationsManager alloc] initWithSDK:self];
        
        // Looks like SnapyrIntegrationsManager is the only middleware we are adding to the runnner...
        self.runner = [[SnapyrMiddlewareRunner alloc] initWithMiddleware:
                                                       [configuration.sourceMiddleware ?: @[] arrayByAddingObject:self.integrationsManager]];

        // Pass through for application state change events
        id<SnapyrApplicationProtocol> application = configuration.application;
        if (application) {
#if TARGET_OS_IPHONE
            // Attach to application state change hooks
            NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
            for (NSString *name in @[ UIApplicationDidEnterBackgroundNotification,
                                      UIApplicationDidFinishLaunchingNotification,
                                      UIApplicationWillEnterForegroundNotification,
                                      UIApplicationWillTerminateNotification,
                                      UIApplicationWillResignActiveNotification,
                                      UIApplicationDidBecomeActiveNotification ]) {
                [nc addObserver:self selector:@selector(handleAppStateNotification:) name:name object:application];
            }
#elif TARGET_OS_OSX
            // Attach to application state change hooks
            NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
            for (NSString *name in @[ NSApplicationDidResignActiveNotification,
                                      NSApplicationDidFinishLaunchingNotification,
                                      NSApplicationWillBecomeActiveNotification,
                                      NSApplicationWillTerminateNotification,
                                      NSApplicationWillResignActiveNotification,
                                      NSApplicationDidBecomeActiveNotification]) {
                [nc addObserver:self selector:@selector(handleAppStateNotification:) name:name object:application];
            }
#endif
        }

#if TARGET_OS_IPHONE
        if (configuration.recordScreenViews) {
            [UIViewController snapyr_swizzleViewDidAppear];
        }
#elif TARGET_OS_OSX
        if (configuration.recordScreenViews) {
            [NSViewController snapyr_swizzleViewDidAppear];
        }
#endif
        if (configuration.trackInAppPurchases) {
            _storeKitTracker = [SnapyrStoreKitTracker trackTransactionsForSDK:self];
        }

#if !TARGET_OS_TV
        if (configuration.trackPushNotifications && configuration.launchOptions) {
#if TARGET_OS_IOS
            NSDictionary *remoteNotification = configuration.launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey];
#else
            NSDictionary *remoteNotification = configuration.launchOptions[NSApplicationLaunchUserNotificationKey];
#endif
            if (remoteNotification) {
                [self trackPushNotification:remoteNotification fromLaunch:YES];
            }
        }
#endif
        
        [SnapyrState sharedInstance].configuration = configuration;
        [[SnapyrState sharedInstance].context updateStaticContext];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -

NSString *const SnapyrVersionKey = @"SnapyrVersionKey";
NSString *const SnapyrBuildKeyV2 = @"SnapyrBuildKeyV2";

#if TARGET_OS_IPHONE
- (void)handleAppStateNotification:(NSNotification *)note
{
    SnapyrApplicationLifecyclePayload *payload = [[SnapyrApplicationLifecyclePayload alloc] init];
    payload.notificationName = note.name;
    [self run:SnapyrEventTypeApplicationLifecycle payload:payload];

    if ([note.name isEqualToString:UIApplicationDidFinishLaunchingNotification]) {
        [self _applicationDidFinishLaunchingWithOptions:note.userInfo];
    } else if ([note.name isEqualToString:UIApplicationWillEnterForegroundNotification]) {
        [self _applicationWillEnterForeground];
    } else if ([note.name isEqualToString:UIApplicationDidEnterBackgroundNotification]) {
      [self _applicationDidEnterBackground];
    }
}
#elif TARGET_OS_OSX
- (void)handleAppStateNotification:(NSNotification *)note
{
    SnapyrApplicationLifecyclePayload *payload = [[SnapyrApplicationLifecyclePayload alloc] init];
    payload.notificationName = note.name;
    [self run:SnapyrEventTypeApplicationLifecycle payload:payload];

    if ([note.name isEqualToString:NSApplicationDidFinishLaunchingNotification]) {
        [self _applicationDidFinishLaunchingWithOptions:note.userInfo];
    } else if ([note.name isEqualToString:NSApplicationWillBecomeActiveNotification]) {
        [self _applicationWillEnterForeground];
    } else if ([note.name isEqualToString:NSApplicationDidResignActiveNotification]) {
      [self _applicationDidEnterBackground];
    }
}
#endif

- (void)_applicationDidFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    if (!self.oneTimeConfiguration.trackApplicationLifecycleEvents) {
        return;
    }
    
    NSUserDefaults *userDefaults = getGroupUserDefaults();

    NSString *previousVersion = [userDefaults stringForKey:SnapyrVersionKey];
    NSString *previousBuildV2 = [userDefaults stringForKey:SnapyrBuildKeyV2];
    
    NSString *currentVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
    NSString *currentBuild = [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"];

    if (!previousBuildV2) {
        [self track:@"Application Installed" properties:@{
            @"version" : currentVersion ?: @"",
            @"build" : currentBuild ?: @"",
        }];
    } else if (![currentBuild isEqualToString:previousBuildV2]) {
        [self track:@"Application Updated" properties:@{
            @"previous_version" : previousVersion ?: @"",
            @"previous_build" : previousBuildV2 ?: @"",
            @"version" : currentVersion ?: @"",
            @"build" : currentBuild ?: @"",
        }];
    }

#if TARGET_OS_IPHONE
    [self track:@"Application Opened" properties:@{
        @"from_background" : @NO,
        @"version" : currentVersion ?: @"",
        @"build" : currentBuild ?: @"",
        @"referring_application" : launchOptions[UIApplicationLaunchOptionsSourceApplicationKey] ?: @"",
        @"url" : launchOptions[UIApplicationLaunchOptionsURLKey] ?: @"",
    }];
#elif TARGET_OS_OSX
    [self track:@"Application Opened" properties:@{
        @"from_background" : @NO,
        @"version" : currentVersion ?: @"",
        @"build" : currentBuild ?: @"",
        @"default_launch" : launchOptions[NSApplicationLaunchIsDefaultLaunchKey] ?: @(YES),
    }];
#endif


    [userDefaults setObject:currentVersion forKey:SnapyrVersionKey];
    [userDefaults setObject:currentBuild forKey:SnapyrBuildKeyV2];

    [userDefaults synchronize];
}

- (void)_applicationWillEnterForeground
{
    if (!self.oneTimeConfiguration.trackApplicationLifecycleEvents) {
        return;
    }
    NSString *currentVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
    NSString *currentBuild = [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"];
    [self track:@"Application Opened" properties:@{
        @"from_background" : @YES,
        @"version" : currentVersion ?: @"",
        @"build" : currentBuild ?: @"",
    }];
    
    [[SnapyrState sharedInstance].context updateStaticContext];
}

- (void)_applicationDidEnterBackground
{
  if (!self.oneTimeConfiguration.trackApplicationLifecycleEvents) {
    return;
  }
  [self track: @"Application Backgrounded"];
}


#pragma mark - Public API

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%p:%@, %@>", self, [self class], [self dictionaryWithValuesForKeys:@[ @"configuration" ]]];
}

- (nullable SnapyrSDKConfiguration *)configuration
{
    // Remove deprecated configuration on 4.2+
    return nil;
}

#pragma mark - Identify

- (void)identify:(NSString *)userId
{
    [self identify:userId traits:nil options:nil];
}

- (void)identify:(NSString *)userId traits:(NSDictionary *)traits
{
    [self identify:userId traits:traits options:nil];
}

- (void)identify:(NSString *)userId traits:(NSDictionary *)traits options:(NSDictionary *)options
{
    NSCAssert2(userId.length > 0 || traits.count > 0, @"either userId (%@) or traits (%@) must be provided.", userId, traits);
    
    // this is done here to match functionality on android where these are inserted BEFORE being spread out amongst destinations.
    // it will be set globally later when it runs through SnapyrIntegrationManager.identify.
    NSString *anonId = [options objectForKey:@"anonymousId"];
    if (anonId == nil) {
        anonId = [self getAnonymousId];
    }
    // configure traits to match what is seen on android.
    NSMutableDictionary *existingTraitsCopy = [[SnapyrState sharedInstance].userInfo.traits mutableCopy];
    NSMutableDictionary *traitsCopy = [traits mutableCopy];
    // if no traits were passed in, need to create.
    if (existingTraitsCopy == nil) {
        existingTraitsCopy = [[NSMutableDictionary alloc] init];
    }
    if (traitsCopy == nil) {
        traitsCopy = [[NSMutableDictionary alloc] init];
    }
    traitsCopy[@"anonymousId"] = anonId;
    if (userId != nil) {
        traitsCopy[@"userId"] = userId;
        [SnapyrState sharedInstance].userInfo.userId = userId;
    }
    // merge w/ existing traits and set them.
    [existingTraitsCopy addEntriesFromDictionary:traitsCopy];
    [SnapyrState sharedInstance].userInfo.traits = existingTraitsCopy;
    
    [self run:SnapyrEventTypeIdentify payload:
                                       [[SnapyrIdentifyPayload alloc] initWithUserId:userId
                                                                         anonymousId:anonId
                                                                              traits:snapyrCoerceDictionary(existingTraitsCopy)
                                                                             context:snapyrCoerceDictionary([options objectForKey:@"context"])
                                                                        integrations:[options objectForKey:@"integrations"]]];
    
    if ([SnapyrState sharedInstance].userInfo.hasUnregisteredDeviceToken == YES
        && [SnapyrState sharedInstance].userInfo.userId != nil) {
        // Device push token was set before we had a user ID to attach it to. Now that we have a user ID, send the token to backend
        NSMutableDictionary *properties = [NSMutableDictionary dictionaryWithCapacity:1];
        properties[@"token"] = [SnapyrState sharedInstance].context.deviceToken;
        [self track:@"snapyr.hidden.apnsTokenSet" properties:properties];
        [SnapyrState sharedInstance].userInfo.hasUnregisteredDeviceToken = NO;
        DLog(@"SnapyrSDK.identify: registered push token: [%@]", [SnapyrState sharedInstance].context.deviceToken);
    }
}

#pragma mark - Track

- (void)track:(NSString *)event
{
    [self track:event properties:nil options:nil];
}

- (void)track:(NSString *)event properties:(NSDictionary *)properties
{
    [self track:event properties:properties options:nil];
}

- (void)track:(NSString *)event properties:(NSDictionary *)properties options:(NSDictionary *)options
{
    NSCAssert1(event.length > 0, @"event (%@) must not be empty.", event);
    [self run:SnapyrEventTypeTrack payload:
                                    [[SnapyrTrackPayload alloc] initWithEvent:event
                                                                   properties:snapyrCoerceDictionary(properties)
                                                                      context:snapyrCoerceDictionary([options objectForKey:@"context"])
                                                                 integrations:[options objectForKey:@"integrations"]]];
}

#pragma mark - Push Notifications

- (void)setPushNotificationTokenData:(NSData*)tokenData
{
    NSUInteger length = tokenData.length;
    if (length == 0) {
        DLog(@"SnapyrSDK setPushNotificationTokenData: Invalid token data, length is zero");
        return;
    }
    
    const unsigned char *tokenBytes = (const unsigned char *)tokenData.bytes;
    NSMutableString *tokenString  = [NSMutableString stringWithCapacity:(length * 2)];
    for (int i = 0; i < length; ++i) {
        [tokenString appendFormat:@"%02x", tokenBytes[i]];
    }
    NSString *resultTokenString = [tokenString copy];
    [self setPushNotificationToken:resultTokenString];
}

- (void)setPushNotificationToken:(NSString*)token
{
    [SnapyrState sharedInstance].context.deviceToken = token;
    if ([SnapyrState sharedInstance].userInfo.userId != nil) {
        NSMutableDictionary *properties = [NSMutableDictionary dictionaryWithCapacity:1];
        properties[@"token"] = token;
        [self track:@"snapyr.hidden.apnsTokenSet" properties:properties];
        DLog(@"SnapyrSDK.setPushNotificationToken: registered push token: [%@]", token);
    } else {
        [SnapyrState sharedInstance].userInfo.hasUnregisteredDeviceToken = YES;
        DLog(@"SnapyrSDK.setPushNotificationToken: received push token, but no user yet: [%@]", token);
    }
}

+ (void)appDidReceiveRemoteNotification:(NSDictionary *)userInfo
{
    SnapyrNotification *snapyrNotif;
    @try {
        snapyrNotif = [[SnapyrNotification alloc] initWithNotifUserInfo:userInfo];
    } @catch (NSException *e) {
        if ([e.name isEqualToString:@"nonSnapyrNotification"]) {
            DLog(@"SnapyrSDK.appDidReceiveRemoteNotification: Received non-Snapyr notification; skipping");
        } else {
            DLog(@"SnapyrSDK.appDidReceiveRemoteNotification: Error parsing notification: [%@]", e);
        }
        return;
    }
    
    // Track receipt (if SDK instance has been initialized)
    NSDictionary<NSString *, NSObject *> *snapyrData = userInfo[@"snapyr"];
    if (snapyrData) {
        [__sharedInstance pushNotificationReceived:snapyrData];
    }
    
    // Notify any listeners for this event, e.g. React Native SDK
    [[NSNotificationCenter defaultCenter]
     postNotificationName:@"snapyr.didReceiveNotification"
     object:nil
     userInfo:@{@"snapyrNotification": snapyrNotif}];
}

+ (void)appDidReceiveNotificationResponse:(UNNotificationResponse *)response
{
    SnapyrNotification *snapyrNotif;
    @try {
        snapyrNotif = [[SnapyrNotification alloc] initWithNotifUserInfo:response.notification.request.content.userInfo];
    } @catch (NSException *e) {
        if ([e.name isEqualToString:@"nonSnapyrNotification"]) {
            DLog(@"SnapyrSDK.appDidReceiveRemoteNotification: Received non-Snapyr notification; skipping");
        } else {
            DLog(@"SnapyrSDK.appDidReceiveRemoteNotification: Error parsing notification: [%@]", e);
        }
        return;
    }
    
    // Track response (if SDK instance has been initialized)
    NSDictionary<NSString *, NSObject *> *snapyrData = response.notification.request.content.userInfo[@"snapyr"];
    if (snapyrData) {
        [__sharedInstance pushNotificationTapped:snapyrData];
    }
    
    [self openNotificationDeeplinkUrl:snapyrNotif];
    
    // Notify any listeners for this event, e.g. React Native SDK
    NSString *actionIdentifier = response.actionIdentifier;
    [[NSNotificationCenter defaultCenter]
     postNotificationName:@"snapyr.didReceiveNotificationResponse"
     object:nil
     userInfo:@{@"actionIdentifier": actionIdentifier, @"snapyrNotification": snapyrNotif}];
}

+ (void)openNotificationDeeplinkUrl:(SnapyrNotification *)snapyrNotif NS_EXTENSION_UNAVAILABLE("Cannot be used from within app extensions.")
{
    if (snapyrNotif.deepLinkUrl != nil) {
        UIApplication *sharedApp = getSharedUIApplication();
        if (sharedApp != nil) {
            if ([sharedApp canOpenURL:snapyrNotif.deepLinkUrl]) {
                DLog(@"SnapyrSDK.appDidReceiveNotificationResponse: opening deepLinkUrl: [%@]", snapyrNotif.deepLinkUrl);
                [sharedApp openURL:snapyrNotif.deepLinkUrl options:@{} completionHandler:nil];
            } else {
                DLog(@"SnapyrSDK.appDidReceiveNotificationResponse: ERROR: unable to open deepLinkUrl (no app matches url scheme?) url: [%@] scheme: [%@]", snapyrNotif.deepLinkUrl, [snapyrNotif.deepLinkUrl scheme]);
            }
        } else {
            DLog(@"SnapyrSDK.appDidReceiveNotificationResponse: ERROR: found deepLinkUrl, but couldn't get sharedApplication! [%@]", snapyrNotif.deepLinkUrl);
        }
    }
}

+ (void)appRegisteredForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    NSParameterAssert(deviceToken != nil);
    NSString *tokenString = deviceTokenToString(deviceToken);
    
    // Track token (if SDK instance has been initialized)
    [__sharedInstance setPushNotificationToken:tokenString];
    
    // Notify any listeners for this event, e.g. React Native SDK
    [[NSNotificationCenter defaultCenter]
     postNotificationName:@"snapyr.registeredForRemoteNotificationsWithDeviceToken"
     object:nil
     userInfo:@{@"tokenString": tokenString}];
}

- (void)pushNotificationReceivedWithResponse:(UNNotificationResponse *)response
{
    [self pushNotificationReceivedWithNotification: response.notification];
}

- (void)pushNotificationReceivedWithNotification:(UNNotification *)notification
{
    [self pushNotificationReceived: notification.request.content.userInfo];
}

- (void)pushNotificationReceived:(NSDictionary *)info
{
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    
    NSDictionary *snapyrData = info;
    if (!snapyrData) {
        DLog(@"SnapyrSDK pushNotificationReceived: Not a Snapyr notification (no Snapyr payload); returning.");
        return;
    }
    
    properties[@"actionToken"] = snapyrData[@"actionToken"];
    properties[@"deepLinkUrl"] = snapyrData[@"deepLinkUrl"];
    
    [self track:@"snapyr.observation.event.Impression" properties:properties];
}

- (void)pushNotificationTappedWithResponse:(UNNotificationResponse*)response
{
    [self pushNotificationTappedWithNotification:response.notification];
}

- (void)pushNotificationTappedWithResponse:(UNNotificationResponse*)response actionId:(NSString* _Nullable)actionId
{
    [self pushNotificationTappedWithNotification:response.notification actionId:actionId];
}

- (void)pushNotificationTappedWithNotification:(UNNotification*)notification
{
    [self pushNotificationTappedWithNotification:notification actionId:nil];
}

- (void)pushNotificationTappedWithNotification:(UNNotification*)notification actionId:(NSString* _Nullable)actionId
{
    [self pushNotificationTapped:notification.request.content.userInfo actionId:actionId];
}

- (void)pushNotificationTapped:(NSDictionary *)info
{
    [self pushNotificationTapped:info actionId:nil];
}

- (void)pushNotificationTapped:(SERIALIZABLE_DICT _Nullable)info actionId:(NSString* _Nullable)actionId
{
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    
    NSDictionary *snapyrData = info;
    if (!snapyrData) {
        DLog(@"SnapyrSDK pushNotificationTapped: Not a Snapyr notification (no Snapyr payload); returning.");
        return;
    }
    
    properties[@"actionToken"] = info[@"actionToken"];
    properties[@"deepLinkUrl"] = info[@"deepLinkUrl"];
    properties[@"actionId"] = actionId;
    
    [self track:@"snapyr.observation.event.Behavior" properties:properties];
}

- (void)trackInAppMessageImpressionWithActionToken:(NSString *)actionToken
{
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];

    properties[@"actionToken"] = actionToken;
    properties[@"platform"] = @"ios";
    
    [self track:@"snapyr.observation.event.Impression" properties:properties];
    [self track:@"test_impression" properties:properties];
}

- (void)trackInAppMessageClickWithActionToken:(NSString *)actionToken
{
    NSDictionary *properties = [NSDictionary dictionary];
    [self trackInAppMessageClickWithActionToken:actionToken withProperties:properties];
}

- (void)trackInAppMessageClickWithActionToken:(NSString *)actionToken withProperties:(NSDictionary *)baseProperties
{
    NSMutableDictionary *properties = [NSMutableDictionary dictionaryWithDictionary:baseProperties];

    properties[@"actionToken"] = actionToken;
    properties[@"platform"] = @"ios";
    properties[@"interactionType"] = @"click";
    
    [self track:@"snapyr.observation.event.Behavior" properties:properties];
    [self track:@"test_behavior" properties:properties];
}

- (void)trackInAppMessageDismissWithActionToken:(NSString *)actionToken
{
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];

    properties[@"actionToken"] = actionToken;
    properties[@"platform"] = @"ios";
    properties[@"interactionType"] = @"dismiss";
    
    [self track:@"snapyr.observation.event.Behavior" properties:properties];
    [self track:@"test_behavior" properties:properties];
}


#pragma mark - Screen

- (void)screen:(NSString *)screenTitle
{
    [self screen:screenTitle category:nil properties:nil options:nil];
}

- (void)screen:(NSString *)screenTitle category:(NSString *)category
{
    [self screen:screenTitle category:category properties:nil options:nil];
}

- (void)screen:(NSString *)screenTitle properties:(NSDictionary *)properties
{
    [self screen:screenTitle category:nil properties:properties options:nil];
}

- (void)screen:(NSString *)screenTitle category:(NSString *)category properties:(SERIALIZABLE_DICT _Nullable)properties
{
    [self screen:screenTitle category:category properties:properties options:nil];
}

- (void)screen:(NSString *)screenTitle properties:(NSDictionary *)properties options:(NSDictionary *)options
{
    [self screen:screenTitle category:nil properties:properties options:options];
}

- (void)screen:(NSString *)screenTitle category:(NSString *)category properties:(SERIALIZABLE_DICT _Nullable)properties options:(SERIALIZABLE_DICT _Nullable)options
{
    NSCAssert1(screenTitle.length > 0, @"screen name (%@) must not be empty.", screenTitle);

    [self run:SnapyrEventTypeScreen payload:
                                     [[SnapyrScreenPayload alloc] initWithName:screenTitle
                                                                      category:category
                                                                    properties:snapyrCoerceDictionary(properties)
                                                                       context:snapyrCoerceDictionary([options objectForKey:@"context"])
                                                                  integrations:[options objectForKey:@"integrations"]]];
}

#pragma mark - Group

- (void)group:(NSString *)groupId
{
    [self group:groupId traits:nil options:nil];
}

- (void)group:(NSString *)groupId traits:(NSDictionary *)traits
{
    [self group:groupId traits:traits options:nil];
}

- (void)group:(NSString *)groupId traits:(NSDictionary *)traits options:(NSDictionary *)options
{
    [self run:SnapyrEventTypeGroup payload:
                                    [[SnapyrGroupPayload alloc] initWithGroupId:groupId
                                                                         traits:snapyrCoerceDictionary(traits)
                                                                        context:snapyrCoerceDictionary([options objectForKey:@"context"])
                                                                   integrations:[options objectForKey:@"integrations"]]];
}

#pragma mark - Alias

- (void)alias:(NSString *)newId
{
    [self alias:newId options:nil];
}

- (void)alias:(NSString *)newId options:(NSDictionary *)options
{
    [self run:SnapyrEventTypeAlias payload:
                                    [[SnapyrAliasPayload alloc] initWithNewId:newId
                                                                      context:snapyrCoerceDictionary([options objectForKey:@"context"])
                                                                 integrations:[options objectForKey:@"integrations"]]];
}

- (void)trackPushNotification:(NSDictionary *)properties fromLaunch:(BOOL)launch
{
    if (launch) {
        [self track:@"Push Notification Tapped" properties:properties];
    } else {
        [self track:@"Push Notification Received" properties:properties];
    }
}

- (void)receivedRemoteNotification:(NSDictionary *)userInfo
{
    if (self.oneTimeConfiguration.trackPushNotifications) {
        [self trackPushNotification:userInfo fromLaunch:NO];
    }
    SnapyrRemoteNotificationPayload *payload = [[SnapyrRemoteNotificationPayload alloc] init];
    payload.userInfo = userInfo;
    [self run:SnapyrEventTypeReceivedRemoteNotification payload:payload];
}

- (void)failedToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    SnapyrRemoteNotificationPayload *payload = [[SnapyrRemoteNotificationPayload alloc] init];
    payload.error = error;
    [self run:SnapyrEventTypeFailedToRegisterForRemoteNotifications payload:payload];
}

- (void)registeredForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    NSParameterAssert(deviceToken != nil);
    SnapyrRemoteNotificationPayload *payload = [[SnapyrRemoteNotificationPayload alloc] init];
    payload.deviceToken = deviceToken;
    [SnapyrState sharedInstance].context.deviceToken = deviceTokenToString(deviceToken);
    [self run:SnapyrEventTypeRegisteredForRemoteNotifications payload:payload];
}

- (void)handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo
{
    SnapyrRemoteNotificationPayload *payload = [[SnapyrRemoteNotificationPayload alloc] init];
    payload.actionIdentifier = identifier;
    payload.userInfo = userInfo;
    [self run:SnapyrEventTypeHandleActionWithForRemoteNotification payload:payload];
}

- (void)continueUserActivity:(NSUserActivity *)activity
{
    SnapyrContinueUserActivityPayload *payload = [[SnapyrContinueUserActivityPayload alloc] init];
    payload.activity = activity;
    [self run:SnapyrEventTypeContinueUserActivity payload:payload];

    if (!self.oneTimeConfiguration.trackDeepLinks) {
        return;
    }

    if ([activity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb]) {
        NSString *urlString = activity.webpageURL.absoluteString;
        [SnapyrState sharedInstance].context.referrer = @{
            @"url" : urlString,
        };

        NSMutableDictionary *properties = [NSMutableDictionary dictionaryWithCapacity:activity.userInfo.count + 2];
        [properties addEntriesFromDictionary:activity.userInfo];
        properties[@"url"] = urlString;
        properties[@"title"] = activity.title ?: @"";
        properties = [SnapyrUtils traverseJSON:properties
                         andReplaceWithFilters:self.oneTimeConfiguration.payloadFilters];
        [self track:@"Deep Link Opened" properties:[properties copy]];
    }
}

- (void)openURL:(NSURL *)url options:(NSDictionary *)options
{
    SnapyrOpenURLPayload *payload = [[SnapyrOpenURLPayload alloc] init];
    payload.url = [NSURL URLWithString:[SnapyrUtils traverseJSON:url.absoluteString
                                           andReplaceWithFilters:self.oneTimeConfiguration.payloadFilters]];
    payload.options = options;
    [self run:SnapyrEventTypeOpenURL payload:payload];

    if (!self.oneTimeConfiguration.trackDeepLinks) {
        return;
    }
    
    NSString *urlString = url.absoluteString;
    [SnapyrState sharedInstance].context.referrer = @{
        @"url" : urlString,
    };

    NSMutableDictionary *properties = [NSMutableDictionary dictionaryWithCapacity:options.count + 2];
    [properties addEntriesFromDictionary:options];
    properties[@"url"] = urlString;
    properties = [SnapyrUtils traverseJSON:properties
                     andReplaceWithFilters:self.oneTimeConfiguration.payloadFilters];
    [self track:@"Deep Link Opened" properties:[properties copy]];
}

- (void)reset
{
    @try {
        [self run:SnapyrEventTypeReset payload:nil];
    } @catch (NSException *exception) {
        DLog(@"SnapyrSDK: Failed to reset");
    }
}

- (void)flush
{
    [self run:SnapyrEventTypeFlush payload:nil];
}

- (void)enable
{
    _enabled = YES;
}

- (void)disable
{
    _enabled = NO;
}

- (NSString *)getAnonymousId
{
    return [SnapyrState sharedInstance].userInfo.anonymousId;
}

- (NSString *)getDeviceToken
{
    return [SnapyrState sharedInstance].context.deviceToken;
}

- (NSDictionary *)bundledIntegrations
{
    return [self.integrationsManager.integrations copy];
}

- (void)refreshSettings
{
    return [self.integrationsManager refreshSettings];
}

#pragma mark - Class Methods

+ (instancetype)sharedSDK
{
    NSCAssert(__sharedInstance != nil, @"library must be initialized before calling this method.");
    return __sharedInstance;
}

+ (void)debug:(BOOL)showDebugLogs
{
    SnapyrSetShowDebugLogs(showDebugLogs);
}

+ (NSString *)version
{
    // this has to match the actual version, NOT what's in info.plist
    // because Apple only accepts X.X.X as versions in the review process.
    return @"1.1.1";
}

// Following 2 methods are for internal test use and intentionally excluded from header to make them non-public/non-documented
+ (NSString *)marketingVersion
{
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    return [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]; // "Marketing version" in project settings
}

+ (NSDate *)buildDate
{
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    return [bundle objectForInfoDictionaryKey:@"SnapyrBuildDate"];
}

#pragma mark - Helpers

- (void)run:(SnapyrEventType)eventType payload:(SnapyrPayload *)payload
{
    if (!self.enabled) {
        return;
    }
    DLog(@"SnapyrSDK.payload");
    if (self.oneTimeConfiguration.experimental.nanosecondTimestamps) {
        payload.timestamp = iso8601NanoFormattedString([NSDate date]);
    } else {
        payload.timestamp = iso8601FormattedString([NSDate date]);
    }
    
    SnapyrContext *context = [[[SnapyrContext alloc] initWithSDK:self] modify:^(id<SnapyrMutableContext> _Nonnull ctx) {
        ctx.eventType = eventType;
        ctx.payload = payload;
        ctx.payload.messageId = GenerateUUIDString();
        if (ctx.payload.userId == nil) {
            ctx.payload.userId = [SnapyrState sharedInstance].userInfo.userId;
        }
        if (ctx.payload.anonymousId == nil) {
            ctx.payload.anonymousId = [SnapyrState sharedInstance].userInfo.anonymousId;
        }
    }];
    
    // Could probably do more things with callback later, but we don't use it yet.
    [self.runner run:context callback:nil];
}

@end
