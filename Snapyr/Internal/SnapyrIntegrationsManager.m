//
//  SnapyrIntegrationsManager.m
//  Analytics
//
//  Created by Tony Xiao on 9/20/16.
//  Copyright © 2016 Segment. All rights reserved.
//

#if TARGET_OS_IPHONE
@import UIKit;
#endif
#import <objc/runtime.h>
#import "SnapyrSDKUtils.h"
#import "SnapyrSDK.h"
#import "SnapyrIntegrationFactory.h"
#import "SnapyrIntegration.h"
#import "SnapyrPushAdaptor.h"
#import "SnapyrHTTPClient.h"
#import "SnapyrStorage.h"
#import "SnapyrFileStorage.h"
#import "SnapyrUserDefaultsStorage.h"
#import "SnapyrIntegrationsManager.h"
#import "SnapyrSnapyrIntegrationFactory.h"
#import "SnapyrPayload.h"
#import "SnapyrIdentifyPayload.h"
#import "SnapyrTrackPayload.h"
#import "SnapyrGroupPayload.h"
#import "SnapyrScreenPayload.h"
#import "SnapyrAliasPayload.h"
#import "SnapyrUtils.h"
#import "SnapyrState.h"

NSString *SnapyrSDKIntegrationDidStart = @"com.snapyr.sdk.integration.did.start";
NSString *const SnapyrAnonymousIdKey = @"SnapyrAnonymousId";
NSString *const kSnapyrAnonymousIdFilename = @"snapyr.anonymousId";
NSString *const kSnapyrCachedSettingsFilename = @"sdk.settings.v2.plist";


@interface SnapyrIdentifyPayload (AnonymousId)
@property (nonatomic, readwrite, nullable) NSString *anonymousId;
@end


@interface SnapyrPayload (Options)
@property (readonly) NSDictionary *options;
@end
@implementation SnapyrPayload (Options)
// Combine context and integrations to form options
- (NSDictionary *)options
{
    return @{
        @"context" : self.context ?: @{},
        @"integrations" : self.integrations ?: @{}
    };
}
@end


@interface SnapyrSDKConfiguration (Private)
@property (nonatomic, strong) NSArray *factories;
@end


@interface SnapyrIntegrationsManager ()

@property (nonatomic, strong) SnapyrSDK *sdk;
@property (nonatomic, strong) NSDictionary *cachedSettings;
@property (nonatomic, strong) SnapyrSDKConfiguration *configuration;
@property (nonatomic, strong) SnapyrPushAdaptor *pushAdaptor;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) NSMutableArray *messageQueue;
@property (nonatomic, strong) NSArray *factories;
@property (nonatomic, strong) NSMutableDictionary *integrations;
@property (nonatomic, strong) NSMutableDictionary *registeredIntegrations;
@property (nonatomic, strong) NSMutableDictionary *integrationMiddleware;
@property (nonatomic) volatile BOOL initialized;
@property (nonatomic, copy) NSString *cachedAnonymousId;
@property (nonatomic, strong) SnapyrHTTPClient *httpClient;
@property (nonatomic, strong) NSURLSessionDataTask *settingsRequest;
@property (nonatomic, strong) id<SnapyrStorage> userDefaultsStorage;
@property (nonatomic, strong) id<SnapyrStorage> fileStorage;

@end

@interface SnapyrSDK ()
@property (nullable, nonatomic, strong, readonly) SnapyrSDKConfiguration *oneTimeConfiguration;
@end


@implementation SnapyrIntegrationsManager

@dynamic cachedAnonymousId;
@synthesize cachedSettings = _cachedSettings;

- (instancetype _Nonnull)initWithSDK:(SnapyrSDK *_Nonnull)sdk
{
    SnapyrSDKConfiguration *configuration = sdk.oneTimeConfiguration;
    NSCParameterAssert(configuration != nil);
    
    DLog(@"SnapyrIntegrationsManager.initWithSDK");
    if (self = [super init]) {
        self.sdk = sdk;
        self.configuration = configuration;
        self.serialQueue = snapyr_dispatch_queue_create_specific("com.snapyr.sdk", DISPATCH_QUEUE_SERIAL);
        self.messageQueue = [[NSMutableArray alloc] init];
        
        self.httpClient = [[SnapyrHTTPClient alloc] initWithRequestFactory:configuration.requestFactory configuration:configuration];
        
        
        self.userDefaultsStorage = [[SnapyrUserDefaultsStorage alloc] initWithDefaults:[NSUserDefaults standardUserDefaults] namespacePrefix:nil crypto:configuration.crypto];
#if TARGET_OS_TV
        self.fileStorage = [[SnapyrFileStorage alloc] initWithFolder:[SnapyrFileStorage cachesDirectoryURL] crypto:configuration.crypto];
#else
        self.fileStorage = [[SnapyrFileStorage alloc] initWithFolder:[SnapyrFileStorage applicationSupportDirectoryURL] crypto:configuration.crypto];
#endif
        
        self.cachedAnonymousId = [self loadOrGenerateAnonymousID:NO];
        NSMutableArray *factories = [[configuration factories] mutableCopy];
        [factories addObject:[[SnapyrSnapyrIntegrationFactory alloc] initWithHTTPClient:self.httpClient fileStorage:self.fileStorage userDefaultsStorage:self.userDefaultsStorage]];
        self.factories = [factories copy];
        self.integrations = [NSMutableDictionary dictionaryWithCapacity:factories.count];
        // Update settings on each integration immediately
        [self refreshSettings];
        
        // Update settings on foreground
        id<SnapyrApplicationProtocol> application = configuration.application;
        if (application) {
            // Attach to application state change hooks
            NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
#if TARGET_OS_IPHONE
            [nc addObserver:self selector:@selector(onAppForeground:) name:UIApplicationWillEnterForegroundNotification object:application];
#elif TARGET_OS_OSX
            [nc addObserver:self selector:@selector(onAppForeground:) name:NSApplicationWillBecomeActiveNotification object:application];
#endif
        }
    }
    return self;
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setCachedAnonymousId:(NSString *)cachedAnonymousId
{
    [SnapyrState sharedInstance].userInfo.anonymousId = cachedAnonymousId;
}

- (NSString *)cachedAnonymousId
{
    NSString *value = [SnapyrState sharedInstance].userInfo.anonymousId;
    return value;
}

- (void)onAppForeground:(NSNotification *)note
{
    [self refreshSettings];
}

- (void)handleAppStateNotification:(NSString *)notificationName
{
    SLog(@"Application state change notification: %@", notificationName);
    static NSDictionary *selectorMapping;
    static dispatch_once_t selectorMappingOnce;
    dispatch_once(&selectorMappingOnce, ^{
#if TARGET_OS_IPHONE
        
        selectorMapping = @{
            UIApplicationDidFinishLaunchingNotification :
                NSStringFromSelector(@selector(applicationDidFinishLaunching:)),
            UIApplicationDidEnterBackgroundNotification :
                NSStringFromSelector(@selector(applicationDidEnterBackground)),
            UIApplicationWillEnterForegroundNotification :
                NSStringFromSelector(@selector(applicationWillEnterForeground)),
            UIApplicationWillTerminateNotification :
                NSStringFromSelector(@selector(applicationWillTerminate)),
            UIApplicationWillResignActiveNotification :
                NSStringFromSelector(@selector(applicationWillResignActive)),
            UIApplicationDidBecomeActiveNotification :
                NSStringFromSelector(@selector(applicationDidBecomeActive))
        };
#elif TARGET_OS_OSX
        selectorMapping = @{
            NSApplicationDidFinishLaunchingNotification :
                NSStringFromSelector(@selector(applicationDidFinishLaunching:)),
            NSApplicationDidResignActiveNotification :
                NSStringFromSelector(@selector(applicationDidEnterBackground)),
            NSApplicationWillBecomeActiveNotification :
                NSStringFromSelector(@selector(applicationWillEnterForeground)),
            NSApplicationWillTerminateNotification :
                NSStringFromSelector(@selector(applicationWillTerminate)),
        };
#endif
        
    });
    SEL selector = NSSelectorFromString(selectorMapping[notificationName]);
    if (selector) {
        [self callIntegrationsWithSelector:selector arguments:nil options:nil sync:true];
    }
}

#pragma mark - Public API

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%p:%@, %@>", self, [self class], [self dictionaryWithValuesForKeys:@[ @"configuration" ]]];
}

#pragma mark - API

- (void)identify:(SnapyrIdentifyPayload *)payload
{
    NSCAssert2(payload.userId.length > 0 || payload.traits.count > 0, @"either userId (%@) or traits (%@) must be provided.", payload.userId, payload.traits);
    
    NSString *anonymousId = payload.anonymousId;
    NSString *existingAnonymousId = self.cachedAnonymousId;
    
    if (anonymousId == nil) {
        payload.anonymousId = anonymousId;
    } else if (![anonymousId isEqualToString:existingAnonymousId]) {
        [self saveAnonymousId:anonymousId];
    }
    
    [self callIntegrationsWithSelector:NSSelectorFromString(@"identify:")
                             arguments:@[ payload ]
                               options:payload.options
                                  sync:false];
}

#pragma mark - Track

- (void)track:(SnapyrTrackPayload *)payload
{
    NSCAssert1(payload.event.length > 0, @"event (%@) must not be empty.", payload.event);
    DLog(@"SnapyrIntegrationsManager.payload: [%@]\n", payload.event);
    [self callIntegrationsWithSelector:NSSelectorFromString(@"track:")
                             arguments:@[ payload ]
                               options:payload.options
                                  sync:false];
}

#pragma mark - Screen

- (void)screen:(SnapyrScreenPayload *)payload
{
    NSCAssert1(payload.name.length > 0, @"screen name (%@) must not be empty.", payload.name);
    
    [self callIntegrationsWithSelector:NSSelectorFromString(@"screen:")
                             arguments:@[ payload ]
                               options:payload.options
                                  sync:false];
}

#pragma mark - Group

- (void)group:(SnapyrGroupPayload *)payload
{
    [self callIntegrationsWithSelector:NSSelectorFromString(@"group:")
                             arguments:@[ payload ]
                               options:payload.options
                                  sync:false];
}

#pragma mark - Alias

- (void)alias:(SnapyrAliasPayload *)payload
{
    [self callIntegrationsWithSelector:NSSelectorFromString(@"alias:")
                             arguments:@[ payload ]
                               options:payload.options
                                  sync:false];
}

- (void)receivedRemoteNotification:(NSDictionary *)userInfo
{
    [self callIntegrationsWithSelector:_cmd arguments:@[ userInfo ] options:nil sync:true];
}

- (void)failedToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    [self callIntegrationsWithSelector:_cmd arguments:@[ error ] options:nil sync:true];
}

- (void)registeredForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    NSParameterAssert(deviceToken != nil);
    
    [self callIntegrationsWithSelector:_cmd arguments:@[ deviceToken ] options:nil sync:true];
}

- (void)handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo
{
    [self callIntegrationsWithSelector:_cmd arguments:@[ identifier, userInfo ] options:nil sync:true];
}

- (void)continueUserActivity:(NSUserActivity *)activity
{
    [self callIntegrationsWithSelector:_cmd arguments:@[ activity ] options:nil sync:true];
}

- (void)openURL:(NSURL *)url options:(NSDictionary *)options
{
    [self callIntegrationsWithSelector:_cmd arguments:@[ url, options ] options:nil sync:true];
}

- (void)reset
{
    [self resetAnonymousId];
    [self callIntegrationsWithSelector:_cmd arguments:nil options:nil sync:false];
}

- (void)resetAnonymousId
{
    self.cachedAnonymousId = [self loadOrGenerateAnonymousID:YES];
}

- (NSString *)getAnonymousId;
{
    return self.cachedAnonymousId;
}

- (NSString *)loadOrGenerateAnonymousID:(BOOL)reset
{
#if TARGET_OS_TV
    NSString *anonymousId = [self.userDefaultsStorage stringForKey:SnapyrAnonymousIdKey];
#else
    NSString *anonymousId = [self.fileStorage stringForKey:kSnapyrAnonymousIdFilename];
#endif
    
    if (!anonymousId || reset) {
        // We've chosen to generate a UUID rather than use the UDID (deprecated in iOS 5),
        // identifierForVendor (iOS6 and later, can't be changed on logout),
        // or MAC address (blocked in iOS 7).
        anonymousId = GenerateUUIDString();
        SLog(@"New anonymousId: %@", anonymousId);
#if TARGET_OS_TV
        [self.userDefaultsStorage setString:anonymousId forKey:SnapyrAnonymousIdKey];
#else
        [self.fileStorage setString:anonymousId forKey:kSnapyrAnonymousIdFilename];
#endif
    }
    
    return anonymousId;
}

- (void)saveAnonymousId:(NSString *)anonymousId
{
    self.cachedAnonymousId = anonymousId;
#if TARGET_OS_TV
    [self.userDefaultsStorage setString:anonymousId forKey:SnapyrAnonymousIdKey];
#else
    [self.fileStorage setString:anonymousId forKey:kSnapyrAnonymousIdFilename];
#endif
}

- (void)flush
{
    [self callIntegrationsWithSelector:_cmd arguments:nil options:nil sync:false];
}

#pragma mark - Settings

- (NSDictionary *)cachedSettings
{
    if (!_cachedSettings) {
#if TARGET_OS_TV
        _cachedSettings = [self.userDefaultsStorage dictionaryForKey:kSnapyrCachedSettingsFilename] ?: @{};
#else
        _cachedSettings = [self.fileStorage dictionaryForKey:kSnapyrCachedSettingsFilename] ?: @{};
#endif
    }
    
    return _cachedSettings;
}

- (void)setCachedSettings:(NSDictionary *)settings
{
    _cachedSettings = [settings copy];
    if (!_cachedSettings) {
        // [@{} writeToURL:settingsURL atomically:YES];
        return;
    }
    
#if TARGET_OS_TV
    [self.userDefaultsStorage setDictionary:_cachedSettings forKey:kSnapyrCachedSettingsFilename];
#else
    [self.fileStorage setDictionary:_cachedSettings forKey:kSnapyrCachedSettingsFilename];
#endif
    
    [self updateIntegrationsWithSettings:settings];
}

- (nonnull NSArray<id<SnapyrMiddleware>> *)middlewareForIntegrationKey:(NSString *)key
{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    for (SnapyrDestinationMiddleware *container in self.configuration.destinationMiddleware) {
        if ([container.integrationKey isEqualToString:key]) {
            [result addObjectsFromArray:container.middleware];
        }
    }
    return result;
}

- (void)updateIntegrationsWithSettings:(NSDictionary *)projectSettings
{
    // see if we have a new snapyr API host and set it.
    NSString *apiHost = projectSettings[@"Snapyr"][@"apiHost"];
    if (apiHost) {
        [SnapyrUtils saveAPIHost:apiHost];
    }
    snapyr_dispatch_specific_sync(_serialQueue, ^{
        if (self.initialized) {
            DLog(@"SnapyrIntegrationsManager.updateIntegrationsWithSettings: already initialized, returning");
            return;
        }
        DLog(@"SnapyrIntegrationsManager.updateIntegrationsWithSettings: not initialized, using factories to create integrations");
        for (id<SnapyrIntegrationFactory> factory in self.factories) {
            NSString *key = [factory key];
            id<SnapyrIntegration> integration = [factory createWithSettings:projectSettings forSDK:self.sdk];
            if (integration != nil) {
                DLog(@"SnapyrIntegrationsManager.updateIntegrationsWithSettings: created integration [%@]", key);
                self.integrations[key] = integration;
                // setup integration middleware
                NSArray<id<SnapyrMiddleware>> *middleware = [self middlewareForIntegrationKey:key];
                self.integrationMiddleware[key] = [[SnapyrMiddlewareRunner alloc] initWithMiddleware:middleware];
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:SnapyrSDKIntegrationDidStart object:key userInfo:nil];
        }
        [self flushMessageQueue];
        self.initialized = true;
    });
}


- (void)refreshSettings
{
    // look at our cache immediately, lets try to get things running
    DLog(@"SnapyrIntegrationsManager.refreshingSettings");
    
    // with the last values while we wait to see about any updates.
    NSDictionary *previouslyCachedSettings = [self cachedSettings];
    if (previouslyCachedSettings && [previouslyCachedSettings count] > 0) {
        DLog(@"SnapyrIntegrationsManager.refreshingSettings: using previously cached settings");
        [self setCachedSettings:previouslyCachedSettings];
    }
    
    snapyr_dispatch_specific_async(_serialQueue, ^{
        DLog(@"SnapyrIntegrationsManager.refreshingSettings: fetching new setttings");
        if (self.settingsRequest) {
            return;
        }
        self.settingsRequest = [self.httpClient settingsForWriteKey:self.configuration.writeKey completionHandler:^(BOOL success, NSDictionary *settings) {
            snapyr_dispatch_specific_async(self -> _serialQueue, ^{
                if (success) {
                    DLog(@"SnapyrIntegrationsManager.refreshingSettings: successfully received settings");
                    // [self.pushAdaptor configureCategories:settings];
                    [self setCachedSettings:settings];
                } else {
                    DLog(@"SnapyrIntegrationsManager.refreshingSettings: failed attempting to fetch settings, falling back to previously cached settings");
                    NSDictionary *previouslyCachedSettings = [self cachedSettings];
                    if (previouslyCachedSettings && [previouslyCachedSettings count] > 0) {
                        [self setCachedSettings:previouslyCachedSettings];
                    } else {
                        DLog(@"ERROR: SnapyrIntegrationsManager.refreshingSettings: failed to fetch settings and no previously cached settings");
                    }
                }
                self.settingsRequest = nil;
            });
        }];
    });
}

#pragma mark - Private

+ (BOOL)isIntegration:(NSString *)key enabledInOptions:(NSDictionary *)options
{
    // If the event is in the tracking plan, it should always be sent to api.segment.io.
    if ([@"Snapyr" isEqualToString:key]) {
        return YES;
    }
    if (options[key]) {
        id value = options[key];
        
        // it's been observed that customers sometimes override this with
        // value's that aren't bool types.
        if ([value isKindOfClass:[NSNumber class]]) {
            NSNumber *numberValue = (NSNumber *)value;
            return [numberValue boolValue];
        } if ([value isKindOfClass:[NSDictionary class]]) {
            return YES;
        } else {
            NSString *msg = [NSString stringWithFormat: @"Value for `%@` in integration options is supposed to be a boolean or dictionary and it is not!"
                             "This is likely due to a user-added value in `integrations` that overwrites a value received from the server", key];
            SLog(msg);
            NSAssert(NO, msg);
        }
    } else if (options[@"All"]) {
        return [options[@"All"] boolValue];
    } else if (options[@"all"]) {
        return [options[@"all"] boolValue];
    }
    return YES;
}

+ (BOOL)isTrackEvent:(NSString *)event enabledForIntegration:(NSString *)key inPlan:(NSDictionary *)plan
{
    // Whether the event is enabled or disabled, it should always be sent to api.segment.io.
    if ([key isEqualToString:@"Snapyr"]) {
        return YES;
    }
    
    if (plan[@"track"][event]) {
        if ([plan[@"track"][event][@"enabled"] boolValue]) {
            return [self isIntegration:key enabledInOptions:plan[@"track"][event][@"integrations"]];
        } else {
            return NO;
        }
    } else if (plan[@"track"][@"__default"]) {
        return [plan[@"track"][@"__default"][@"enabled"] boolValue];
    }
    
    return YES;
}

- (void)forwardSelector:(SEL)selector arguments:(NSArray *)arguments options:(NSDictionary *)options
{
    [self.integrations enumerateKeysAndObjectsUsingBlock:^(NSString *key, id<SnapyrIntegration> integration, BOOL *stop) {
        [self invokeIntegration:integration key:key selector:selector arguments:arguments options:options];
    }];
}

/*
 This kind of sucks, but we wrote ourselves into a corner here.  A larger refactor will need to happen.
 I also opted to not put this as a utility function because we shouldn't be doing this in the first place,
 so consider it a one-off.  If you find yourself needing to do this again, lets talk about a refactor.
 */
- (SnapyrEventType)eventTypeFromSelector:(SEL)selector
{
    NSString *selectorString = NSStringFromSelector(selector);
    SnapyrEventType result = SnapyrEventTypeUndefined;
    
    if ([selectorString hasPrefix:@"identify"]) {
        result = SnapyrEventTypeIdentify;
    } else if ([selectorString hasPrefix:@"track"]) {
        result = SnapyrEventTypeTrack;
    } else if ([selectorString hasPrefix:@"screen"]) {
        result = SnapyrEventTypeScreen;
    } else if ([selectorString hasPrefix:@"group"]) {
        result = SnapyrEventTypeGroup;
    } else if ([selectorString hasPrefix:@"alias"]) {
        result = SnapyrEventTypeAlias;
    } else if ([selectorString hasPrefix:@"reset"]) {
        result = SnapyrEventTypeReset;
    } else if ([selectorString hasPrefix:@"flush"]) {
        result = SnapyrEventTypeFlush;
    } else if ([selectorString hasPrefix:@"receivedRemoteNotification"]) {
        result = SnapyrEventTypeReceivedRemoteNotification;
    } else if ([selectorString hasPrefix:@"failedToRegisterForRemoteNotificationsWithError"]) {
        result = SnapyrEventTypeFailedToRegisterForRemoteNotifications;
    } else if ([selectorString hasPrefix:@"registeredForRemoteNotificationsWithDeviceToken"]) {
        result = SnapyrEventTypeRegisteredForRemoteNotifications;
    } else if ([selectorString hasPrefix:@"handleActionWithIdentifier"]) {
        result = SnapyrEventTypeHandleActionWithForRemoteNotification;
    } else if ([selectorString hasPrefix:@"continueUserActivity"]) {
        result = SnapyrEventTypeContinueUserActivity;
    } else if ([selectorString hasPrefix:@"openURL"]) {
        result = SnapyrEventTypeOpenURL;
    } else if ([selectorString hasPrefix:@"application"]) {
        result = SnapyrEventTypeApplicationLifecycle;
    }
    
    return result;
}

- (void)invokeIntegration:(id<SnapyrIntegration>)integration key:(NSString *)key selector:(SEL)selector arguments:(NSArray *)arguments options:(NSDictionary *)options
{
    if (![integration respondsToSelector:selector]) {
        SLog(@"Not sending call to %@ because it doesn't respond to %@.", key, NSStringFromSelector(selector));
        return;
    }
    
    if (![[self class] isIntegration:key enabledInOptions:options[@"integrations"]]) {
        SLog(@"Not sending call to %@ because it is disabled in options.", key);
        return;
    }
    
    SnapyrEventType eventType = [self eventTypeFromSelector:selector];
    if (eventType == SnapyrEventTypeTrack) {
        SnapyrTrackPayload *eventPayload = arguments[0];
        BOOL enabled = [[self class] isTrackEvent:eventPayload.event enabledForIntegration:key inPlan:self.cachedSettings[@"plan"]];
        if (!enabled) {
            SLog(@"Not sending call to %@ because it is disabled in plan.", key);
            return;
        }
    }
    
    NSMutableArray *newArguments = [arguments mutableCopy];
    
    if (eventType != SnapyrEventTypeUndefined) {
        SnapyrMiddlewareRunner *runner = self.integrationMiddleware[key];
        if (runner.middlewares.count > 0) {
            SnapyrPayload *payload = nil;
            // things like flush have no args.
            if (arguments.count > 0) {
                payload = arguments[0];
            }
            SnapyrContext *context = [[[SnapyrContext alloc] initWithSDK:self.sdk] modify:^(id<SnapyrMutableContext> _Nonnull ctx) {
                ctx.eventType = eventType;
                ctx.payload = payload;
            }];
            
            context = [runner run:context callback:nil];
            // if we weren't given args, don't set them.
            if (arguments.count > 0) {
                newArguments[0] = context.payload;
            }
        }
    }
    
    DLog(@"SnapyrIntegrationsManager.invokeIntegration: running [%@] with arguments [%@] on integration [%@]",
         NSStringFromSelector(selector), newArguments, key);
    NSInvocation *invocation = [self invocationForSelector:selector arguments:newArguments];
    [invocation invokeWithTarget:integration];
}


- (NSInvocation *)invocationForSelector:(SEL)selector arguments:(NSArray *)arguments
{
    struct objc_method_description description = protocol_getMethodDescription(@protocol(SnapyrIntegration), selector, NO, YES);
    
    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:description.types];
    
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.selector = selector;
    for (int i = 0; i < arguments.count; i++) {
        id argument = (arguments[i] == [NSNull null]) ? nil : arguments[i];
        [invocation setArgument:&argument atIndex:i + 2];
    }
    return invocation;
}

- (void)queueSelector:(SEL)selector arguments:(NSArray *)arguments options:(NSDictionary *)options
{
    NSArray *obj = @[ NSStringFromSelector(selector), arguments ?: @[], options ?: @{} ];
    DLog(@"SnapyrIntegrationsManager.queueSelector: queueing object [%@] for selector [%@]", obj, NSStringFromSelector(selector));
    [_messageQueue addObject:obj];
}

- (void)flushMessageQueue
{
    DLog(@"SnapyrIntegrationsManager.flushMessageQueue");
    if (_messageQueue.count != 0) {
        for (NSArray *arr in _messageQueue)
            [self forwardSelector:NSSelectorFromString(arr[0]) arguments:arr[1] options:arr[2]];
        [_messageQueue removeAllObjects];
    }
}

- (void)callIntegrationsWithSelector:(SEL)selector arguments:(NSArray *)arguments options:(NSDictionary *)options sync:(BOOL)sync
{
    // TODO: Currently we ignore the `sync` argument and queue the event asynchronously.
    // For integrations that need events to be on the main thread, they'll have to do so
    // manually and hop back on to the main thread.
    // Eventually we should figure out a way to handle this in sdk itself.
    snapyr_dispatch_specific_async(_serialQueue, ^{
        if (self.initialized) {
            [self flushMessageQueue];
            [self forwardSelector:selector arguments:arguments options:options];
        } else {
            [self queueSelector:selector arguments:arguments options:options];
        }
    });
}

@end


@implementation SnapyrIntegrationsManager (SnapyrMiddleware)

- (void)context:(SnapyrContext *)context next:(void (^_Nonnull)(SnapyrContext *_Nullable))next
{
    switch (context.eventType) {
        case SnapyrEventTypeIdentify: {
            SnapyrIdentifyPayload *p = (SnapyrIdentifyPayload *)context.payload;
            [self identify:p];
            break;
        }
        case SnapyrEventTypeTrack: {
            SnapyrTrackPayload *p = (SnapyrTrackPayload *)context.payload;
            [self track:p];
            break;
        }
        case SnapyrEventTypeScreen: {
            SnapyrScreenPayload *p = (SnapyrScreenPayload *)context.payload;
            [self screen:p];
            break;
        }
        case SnapyrEventTypeGroup: {
            SnapyrGroupPayload *p = (SnapyrGroupPayload *)context.payload;
            [self group:p];
            break;
        }
        case SnapyrEventTypeAlias: {
            SnapyrAliasPayload *p = (SnapyrAliasPayload *)context.payload;
            [self alias:p];
            break;
        }
        case SnapyrEventTypeReset:
            [self reset];
            break;
        case SnapyrEventTypeFlush:
            [self flush];
            break;
        case SnapyrEventTypeReceivedRemoteNotification:
            [self receivedRemoteNotification:
             [(SnapyrRemoteNotificationPayload *)context.payload userInfo]];
            break;
        case SnapyrEventTypeFailedToRegisterForRemoteNotifications:
            [self failedToRegisterForRemoteNotificationsWithError:
             [(SnapyrRemoteNotificationPayload *)context.payload error]];
            break;
        case SnapyrEventTypeRegisteredForRemoteNotifications:
            [self registeredForRemoteNotificationsWithDeviceToken:
             [(SnapyrRemoteNotificationPayload *)context.payload deviceToken]];
            break;
        case SnapyrEventTypeHandleActionWithForRemoteNotification: {
            SnapyrRemoteNotificationPayload *payload = (SnapyrRemoteNotificationPayload *)context.payload;
            [self handleActionWithIdentifier:payload.actionIdentifier
                       forRemoteNotification:payload.userInfo];
            break;
        }
        case SnapyrEventTypeContinueUserActivity:
            [self continueUserActivity:
             [(SnapyrContinueUserActivityPayload *)context.payload activity]];
            break;
        case SnapyrEventTypeOpenURL: {
            SnapyrOpenURLPayload *payload = (SnapyrOpenURLPayload *)context.payload;
            [self openURL:payload.url options:payload.options];
            break;
        }
        case SnapyrEventTypeApplicationLifecycle:
            [self handleAppStateNotification:
             [(SnapyrApplicationLifecyclePayload *)context.payload notificationName]];
            break;
        default:
        case SnapyrEventTypeUndefined:
            NSAssert(NO, @"Received context with undefined event type %@", context);
            SLog(@"[ERROR]: Received context with undefined event type %@", context);
            break;
    }
    next(context);
}

@end
