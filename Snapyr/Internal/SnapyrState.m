//
//  SnapyrState.m
//  Analytics
//
//  Created by Brandon Sneed on 6/9/20.
//  Copyright © 2020 Segment. All rights reserved.
//

#import "SnapyrState.h"
#import "SnapyrAnalytics.h"
#import "SnapyrAnalyticsUtils.h"
#import "SnapyrReachability.h"
#import "SnapyrUtils.h"

typedef void (^SnapyrStateSetBlock)(void);
typedef _Nullable id (^SnapyrStateGetBlock)(void);


@interface SnapyrState()
// State Objects
@property (nonatomic, nonnull) SnapyrUserInfo *userInfo;
@property (nonatomic, nonnull) SnapyrPayloadContext *context;
// State Accessors
- (void)setValueWithBlock:(SnapyrStateSetBlock)block;
- (id)valueWithBlock:(SnapyrStateGetBlock)block;
@end


@protocol SnapyrStateObject
@property (nonatomic, weak) SnapyrState *state;
- (instancetype)initWithState:(SnapyrState *)aState;
@end


@interface SnapyrUserInfo () <SnapyrStateObject>
@end

@interface SnapyrPayloadContext () <SnapyrStateObject>
@property (nonatomic, strong) SnapyrReachability *reachability;
@property (nonatomic, strong) NSDictionary *cachedStaticContext;
@end

#pragma mark - SnapyrUserInfo

@implementation SnapyrUserInfo

@synthesize state;

@synthesize anonymousId = _anonymousId;
@synthesize userId = _userId;
@synthesize traits = _traits;

- (instancetype)initWithState:(SnapyrState *)aState
{
    if (self = [super init]) {
        self.state = aState;
    }
    return self;
}

- (NSString *)anonymousId
{
    return [state valueWithBlock: ^id{
        return self->_anonymousId;
    }];
}

- (void)setAnonymousId:(NSString *)anonymousId
{
    [state setValueWithBlock: ^{
        self->_anonymousId = [anonymousId copy];
    }];
}

- (NSString *)userId
{
    return [state valueWithBlock: ^id{
        return self->_userId;
    }];
}

- (void)setUserId:(NSString *)userId
{
    [state setValueWithBlock: ^{
        self->_userId = [userId copy];
    }];
}

- (NSDictionary *)traits
{
    return [state valueWithBlock:^id{
        return self->_traits;
    }];
}

- (void)setTraits:(NSDictionary *)traits
{
    [state setValueWithBlock: ^{
        self->_traits = [traits serializableDeepCopy];
    }];
}

@end


#pragma mark - SnapyrPayloadContext

@implementation SnapyrPayloadContext

@synthesize state;
@synthesize reachability;

@synthesize referrer = _referrer;
@synthesize cachedStaticContext = _cachedStaticContext;
@synthesize deviceToken = _deviceToken;

- (instancetype)initWithState:(SnapyrState *)aState
{
    if (self = [super init]) {
        self.state = aState;
        self.reachability = [SnapyrReachability reachabilityWithHostname:@"google.com"];
        [self.reachability startNotifier];
    }
    return self;
}

- (void)updateStaticContext
{
    self.cachedStaticContext = getStaticContext(state.configuration, self.deviceToken);
}

- (NSDictionary *)payload
{
    NSMutableDictionary *result = [self.cachedStaticContext mutableCopy];
    [result addEntriesFromDictionary:getLiveContext(self.reachability, self.referrer, state.userInfo.traits)];
    return result;
}

- (NSDictionary *)referrer
{
    return [state valueWithBlock:^id{
        return self->_referrer;
    }];
}

- (void)setReferrer:(NSDictionary *)referrer
{
    [state setValueWithBlock: ^{
        self->_referrer = [referrer serializableDeepCopy];
    }];
}

- (NSString *)deviceToken
{
    return [state valueWithBlock:^id{
        return self->_deviceToken;
    }];
}

- (void)setDeviceToken:(NSString *)deviceToken
{
    [state setValueWithBlock: ^{
        self->_deviceToken = [deviceToken copy];
    }];
    [self updateStaticContext];
}

@end


#pragma mark - SnapyrState

@implementation SnapyrState {
    dispatch_queue_t _stateQueue;
}

// TODO: Make this not a singleton.. :(
+ (instancetype)sharedInstance
{
    static SnapyrState *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    if (self = [super init]) {
        _stateQueue = dispatch_queue_create("com.snapyr.state.queue", DISPATCH_QUEUE_CONCURRENT);
        self.userInfo = [[SnapyrUserInfo alloc] initWithState:self];
        self.context = [[SnapyrPayloadContext alloc] initWithState:self];
    }
    return self;
}

- (void)setValueWithBlock:(SnapyrStateSetBlock)block
{
    dispatch_barrier_async(_stateQueue, block);
}

- (id)valueWithBlock:(SnapyrStateGetBlock)block
{
    __block id value = nil;
    dispatch_sync(_stateQueue, ^{
        value = block();
    });
    return value;
}

@end
