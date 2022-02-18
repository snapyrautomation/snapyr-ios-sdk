//
//  SnapyrIntegrationsManager.h
//  Analytics
//
//  Created by Tony Xiao on 9/20/16.
//  Copyright © 2016 Segment. All rights reserved.
//

#import "SnapyrSDKConfiguration.h"
#import "SnapyrSDK.h"
#import "SnapyrMiddleware.h"
#import "SnapyrCrypto.h"
#import "SnapyrHTTPClient.h"
#import "SnapyrUtils.h"
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#elif TARGET_OS_OSX
#import <Cocoa/Cocoa.h>
#endif

#if TARGET_OS_IPHONE
@implementation UIApplication (SnapyrApplicationProtocol)

- (UIBackgroundTaskIdentifier)snapyr_beginBackgroundTaskWithName:(nullable NSString *)taskName expirationHandler:(void (^__nullable)(void))handler
{
    return [self beginBackgroundTaskWithName:taskName expirationHandler:handler];
}

- (void)snapyr_endBackgroundTask:(UIBackgroundTaskIdentifier)identifier
{
    [self endBackgroundTask:identifier];
}

@end
#endif

@implementation SnapyrSDKExperimental
@end

@interface SnapyrSDKConfiguration ()

@property (nonatomic, copy, readwrite) NSString *writeKey;
@property (nonatomic, strong, readonly) NSMutableArray *factories;
@property (nonatomic, strong) SnapyrSDKExperimental *experimental;

- (instancetype)initWithWriteKey:(NSString *)writeKey defaultAPIHost:(NSURL * _Nullable)defaultAPIHost;

@end


@implementation SnapyrSDKConfiguration

+ (instancetype)configurationWithWriteKey:(NSString *)writeKey
{
    return [[SnapyrSDKConfiguration alloc] initWithWriteKey:writeKey defaultAPIHost:nil];
}

+ (instancetype)configurationWithWriteKey:(NSString *)writeKey defaultAPIHost:(NSURL * _Nullable)defaultAPIHost
{
    return [[SnapyrSDKConfiguration alloc] initWithWriteKey:writeKey defaultAPIHost:defaultAPIHost];
}

- (instancetype)initWithWriteKey:(NSString *)writeKey defaultAPIHost:(NSURL * _Nullable)defaultAPIHost
{
    if (self = [self init]) {
        self.writeKey = writeKey;
        [SnapyrUtils setWriteKey:writeKey];
        DLog(@"SnapyrSDKConfiguration.initWithWriteKey");
        // get the host we have stored
        NSString *host = [SnapyrUtils getAPIHost:self.enableDevEnvironment];
        if ([host isEqualToString:(self.enableDevEnvironment) ? kSnapyrAPIBaseHostDev : kSnapyrAPIBaseHost]) {
            // we're getting the generic host back.  have they
            // supplied something other than that?
            if (defaultAPIHost && ![host isEqualToString:defaultAPIHost.absoluteString]) {
                // we should use the supplied default.
                host = defaultAPIHost.absoluteString;
                DLog(@"SnapyrSDKConfiguration init: host: [%@]", host);
                [SnapyrUtils saveAPIHost:host];
            }
        }
    }
    return self;
}

- (instancetype)init
{
    if (self = [super init]) {
        self.experimental = [[SnapyrSDKExperimental alloc] init];
        self.shouldUseLocationServices = NO;
        self.enableDevEnvironment = NO;
        self.enableAdvertisingTracking = YES;
        self.shouldUseBluetooth = NO;
        self.flushAt = 20;
        self.flushInterval = 30;
        self.maxQueueSize = 1000;
        self.payloadFilters = @{
            @"(fb\\d+://authorize#access_token=)([^ ]+)": @"$1((redacted/fb-auth-token))"
        };
        _factories = [NSMutableArray array];
#if TARGET_OS_IPHONE
        if ([UIApplication respondsToSelector:@selector(sharedApplication)]) {
            _application = [UIApplication performSelector:@selector(sharedApplication)];
        }
#elif TARGET_OS_OSX
        if ([NSApplication respondsToSelector:@selector(sharedApplication)]) {
            _application = [NSApplication performSelector:@selector(sharedApplication)];
        }
#endif
    }
    return self;
}

- (NSURL *)apiHost
{
    return [SnapyrUtils getAPIHostURL:self.enableDevEnvironment];
}

- (void)use:(id<SnapyrIntegrationFactory>)factory
{
    [self.factories addObject:factory];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%p:%@, %@>", self, self.class, [self dictionaryWithValuesForKeys:@[ @"writeKey", @"shouldUseLocationServices", @"flushAt" ]]];
}

// MARK: remove these when `middlewares` property is removed.

- (void)setMiddlewares:(NSArray<id<SnapyrMiddleware>> *)middlewares
{
    self.sourceMiddleware = middlewares;
}

- (NSArray<id<SnapyrMiddleware>> *)middlewares
{
    return self.sourceMiddleware;
}

- (void)setEdgeFunctionMiddleware:(id<SnapyrEdgeFunctionMiddleware>)edgeFunctionMiddleware
{
    _edgeFunctionMiddleware = edgeFunctionMiddleware;
    self.sourceMiddleware = edgeFunctionMiddleware.sourceMiddleware;
    self.destinationMiddleware = edgeFunctionMiddleware.destinationMiddleware;
}

@end
