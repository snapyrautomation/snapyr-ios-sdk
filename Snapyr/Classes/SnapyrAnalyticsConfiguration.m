//
//  SnapyrIntegrationsManager.h
//  Analytics
//
//  Created by Tony Xiao on 9/20/16.
//  Copyright © 2016 Segment. All rights reserved.
//

#import "SnapyrAnalyticsConfiguration.h"
#import "SnapyrAnalytics.h"
#import "SnapyrMiddleware.h"
#import "SnapyrCrypto.h"
#import "SnapyrHTTPClient.h"
#import "SnapyrUtils.h"
#if TARGET_OS_IPHONE
@import UIKit;
#elif TARGET_OS_OSX
@import Cocoa;
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

@implementation SnapyrAnalyticsExperimental
@end

@interface SnapyrAnalyticsConfiguration ()

@property (nonatomic, copy, readwrite) NSString *writeKey;
@property (nonatomic, strong, readonly) NSMutableArray *factories;
@property (nonatomic, strong) SnapyrAnalyticsExperimental *experimental;

- (instancetype)initWithWriteKey:(NSString *)writeKey defaultAPIHost:(NSURL * _Nullable)defaultAPIHost;

@end


@implementation SnapyrAnalyticsConfiguration

+ (instancetype)configurationWithWriteKey:(NSString *)writeKey
{
    return [[SnapyrAnalyticsConfiguration alloc] initWithWriteKey:writeKey defaultAPIHost:nil];
}

+ (instancetype)configurationWithWriteKey:(NSString *)writeKey defaultAPIHost:(NSURL * _Nullable)defaultAPIHost
{
    return [[SnapyrAnalyticsConfiguration alloc] initWithWriteKey:writeKey defaultAPIHost:defaultAPIHost];
}

- (instancetype)initWithWriteKey:(NSString *)writeKey defaultAPIHost:(NSURL * _Nullable)defaultAPIHost
{
    if (self = [self init]) {
        self.writeKey = writeKey;
        
        // get the host we have stored
        NSString *host = [SnapyrUtils getAPIHost];
        if ([host isEqualToString:kSegmentAPIBaseHost]) {
            // we're getting the generic host back.  have they
            // supplied something other than that?
            if (defaultAPIHost && ![host isEqualToString:defaultAPIHost.absoluteString]) {
                // we should use the supplied default.
                host = defaultAPIHost.absoluteString;
                [SnapyrUtils saveAPIHost:host];
            }
        }
    }
    return self;
}

- (instancetype)init
{
    if (self = [super init]) {
        self.experimental = [[SnapyrAnalyticsExperimental alloc] init];
        self.shouldUseLocationServices = NO;
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
    return [SnapyrUtils getAPIHostURL];
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
