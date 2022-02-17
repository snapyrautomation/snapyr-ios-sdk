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

static SnapyrSDK *__sharedInstance = nil;


@interface SnapyrSDK ()

@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, strong) SnapyrSDKConfiguration *oneTimeConfiguration;
@property (nonatomic, strong) SnapyrStoreKitTracker *storeKitTracker;
@property (nonatomic, strong) SnapyrIntegrationsManager *integrationsManager;
@property (nonatomic, strong) SnapyrMiddlewareRunner *runner;
@end


@implementation SnapyrSDK

+ (void)setupWithConfiguration:(SnapyrSDKConfiguration *)configuration;
{
    DLog(@"SnapyrSDK.setupWithConfiguration");
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __sharedInstance = [[self alloc] initWithConfiguration:configuration];
    });
}

+ (void)handleNoticationExtensionRequestWithWriteKey:(NSString *)writeKey bestAttemptContent:(UNMutableNotificationContent * _Nonnull)bestAttemptContent originalRequest:(UNNotificationRequest *_Nonnull)originalRequest contentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler
{
    [SnapyrSDK handleNoticationExtensionRequestWithWriteKey:writeKey bestAttemptContent:bestAttemptContent originalRequest:originalRequest contentHandler:contentHandler devMode:NO];
}

+ (void)handleNoticationExtensionRequestWithWriteKey:(NSString *)writeKey bestAttemptContent:(UNMutableNotificationContent * _Nonnull)bestAttemptContent originalRequest:(UNNotificationRequest *_Nonnull)originalRequest contentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler devMode:(BOOL)enableDevMode
{
    NSDictionary *snapyrData = originalRequest.content.userInfo[@"snapyr"];
    if (!snapyrData) {
        DLog(@"SnapyrSDK NotifExt: Not a Snapyr notification (no Snapyr payload); returning.");
        contentHandler(bestAttemptContent);
        return;
    }
    NSDictionary *payloadTemplate = snapyrData[@"pushTemplate"];
    if (!payloadTemplate || !payloadTemplate[@"id"] || !payloadTemplate[@"modified"]) {
        DLog(@"SnapyrSDK NotifExt: Missing template data on payload; returning.");
        contentHandler(bestAttemptContent);
        return;
    }
    
    // Always set category id to template ID - if this template has no actions (no category registered) it will simply be ignored
    bestAttemptContent.categoryIdentifier = payloadTemplate[@"id"];
    
    SnapyrSDKConfiguration *oneOffConfig = [SnapyrSDKConfiguration configurationWithWriteKey:writeKey];
    oneOffConfig.enableDevEnvironment = enableDevMode;
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
                UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
                [center getNotificationCategoriesWithCompletionHandler:^(NSSet<UNNotificationCategory *> *categories) {
                    NSDictionary *newCachedTemplate = [integrationsManager getCachedPushDataForTemplateId:payloadTemplate[@"id"]];
                    if (newCachedTemplate == nil) {
                        DLog(@"SnapyrSDK NotifExt: Template on payload still missing from updated settings.");
                    } else {
                        DLog(@"SnapyrSDK NotifExt: Template data found after settings refresh.");
                    }
                    
                    contentHandler(bestAttemptContent);
                }];
            } else {
                DLog(@"SnapyrSDK NotifExt: Failed attempt to refresh template data.");
                // Nothing further we can do, let the service extension finish processing
                contentHandler(bestAttemptContent);
            }
        }];
    } else {
        // Cached template data is up-to-date - no further work to do
        DLog(@"SnapyrSDK NotifExt: Using cached template data.");
        contentHandler(bestAttemptContent);
        return;
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
    } else {
        [SnapyrState sharedInstance].userInfo.hasUnregisteredDeviceToken = YES;
    }
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
    
    NSDictionary *snapyrData = info[@"snapyr"];
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
    [self pushNotificationTappedWithNotification:notification];
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
    
    NSDictionary *snapyrData = info[@"snapyr"];
    if (!snapyrData) {
        DLog(@"SnapyrSDK pushNotificationTapped: Not a Snapyr notification (no Snapyr payload); returning.");
        return;
    }
    
    properties[@"actionToken"] = info[@"actionToken"];
    properties[@"deepLinkUrl"] = info[@"deepLinkUrl"];
    properties[@"actionId"] = actionId;
    
    [self track:@"snapyr.observation.event.Behavior" properties:properties];
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
    [self run:SnapyrEventTypeReset payload:nil];
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
    return @"1.0.1";
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
