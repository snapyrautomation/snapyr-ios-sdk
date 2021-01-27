#import <objc/runtime.h>
#import "SnapyrAnalyticsUtils.h"
#import "SnapyrAnalytics.h"
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

static SnapyrAnalytics *__sharedInstance = nil;


@interface SnapyrAnalytics ()

@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, strong) SnapyrAnalyticsConfiguration *oneTimeConfiguration;
@property (nonatomic, strong) SnapyrStoreKitTracker *storeKitTracker;
@property (nonatomic, strong) SnapyrIntegrationsManager *integrationsManager;
@property (nonatomic, strong) SnapyrMiddlewareRunner *runner;
@end


@implementation SnapyrAnalytics

+ (void)setupWithConfiguration:(SnapyrAnalyticsConfiguration *)configuration
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __sharedInstance = [[self alloc] initWithConfiguration:configuration];
    });
}

- (instancetype)initWithConfiguration:(SnapyrAnalyticsConfiguration *)configuration
{
    NSCParameterAssert(configuration != nil);

    if (self = [self init]) {
        self.oneTimeConfiguration = configuration;
        self.enabled = YES;

        // In swift this would not have been OK... But hey.. It's objc
        // TODO: Figure out if this is really the best way to do things here.
        self.integrationsManager = [[SnapyrIntegrationsManager alloc] initWithAnalytics:self];
        
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
            _storeKitTracker = [SnapyrStoreKitTracker trackTransactionsForAnalytics:self];
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
NSString *const SnapyrBuildKeyV1 = @"SnapyrBuildKey";
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
    // Previously SnapyrBuildKey was stored an integer. This was incorrect because the CFBundleVersion
    // can be a string. This migrates SnapyrBuildKey to be stored as a string.
    NSInteger previousBuildV1 = [[NSUserDefaults standardUserDefaults] integerForKey:SnapyrBuildKeyV1];
    if (previousBuildV1) {
        [[NSUserDefaults standardUserDefaults] setObject:[@(previousBuildV1) stringValue] forKey:SnapyrBuildKeyV2];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:SnapyrBuildKeyV1];
    }

    NSString *previousVersion = [[NSUserDefaults standardUserDefaults] stringForKey:SnapyrVersionKey];
    NSString *previousBuildV2 = [[NSUserDefaults standardUserDefaults] stringForKey:SnapyrBuildKeyV2];

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


    [[NSUserDefaults standardUserDefaults] setObject:currentVersion forKey:SnapyrVersionKey];
    [[NSUserDefaults standardUserDefaults] setObject:currentBuild forKey:SnapyrBuildKeyV2];

    [[NSUserDefaults standardUserDefaults] synchronize];
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

- (nullable SnapyrAnalyticsConfiguration *)configuration
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
    return [self.integrationsManager.registeredIntegrations copy];
}

#pragma mark - Class Methods

+ (instancetype)sharedAnalytics
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
    return @"4.1.2";
}

#pragma mark - Helpers

- (void)run:(SnapyrEventType)eventType payload:(SnapyrPayload *)payload
{
    if (!self.enabled) {
        return;
    }
    
    if (self.oneTimeConfiguration.experimental.nanosecondTimestamps) {
        payload.timestamp = iso8601NanoFormattedString([NSDate date]);
    } else {
        payload.timestamp = iso8601FormattedString([NSDate date]);
    }
    
    SnapyrContext *context = [[[SnapyrContext alloc] initWithAnalytics:self] modify:^(id<SnapyrMutableContext> _Nonnull ctx) {
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

- (id<SnapyrEdgeFunctionMiddleware>)edgeFunction
{
    return _oneTimeConfiguration.edgeFunctionMiddleware;
}

@end
