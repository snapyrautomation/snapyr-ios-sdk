#include <sys/sysctl.h>

#import "SnapyrSDK.h"
#import "SnapyrUtils.h"
#import "SnapyrSnapyrIntegration.h"
#import "SnapyrActions/SnapyrActionProcessor.h"
#import "SnapyrReachability.h"
#import "SnapyrHTTPClient.h"
#import "SnapyrStorage.h"
#import "SnapyrMacros.h"
#import "SnapyrState.h"
#import <pthread.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

dispatch_once_t onlyOnce;
pthread_mutex_t mutex;

NSString *const SnapyrDidSendRequestNotification = @"SnapyrDidSendRequest";
NSString *const SnapyrRequestDidSucceedNotification = @"SnapyrRequestDidSucceed";
NSString *const SnapyrRequestDidFailNotification = @"SnapyrRequestDidFail";

NSString *const SnapyrUserIdKey = @"snapyrUserId";
NSString *const SnapyrQueueKey = @"snapyrQueue";
NSString *const SnapyrTraitsKey = @"snapyrTraits";

NSString *const kSnapyrUserIdFilename = @"snapyr.userId";
NSString *const kSnapyrQueueFilename = @"snapyr.queue.plist";
NSString *const kSnapyrTraitsFilename = @"snapyr.traits.plist";

// Equiv to UIBackgroundTaskInvalid.
NSUInteger const kSnapyrBackgroundTaskInvalid = 0;

@interface SnapyrSnapyrIntegration ()

@property (nonatomic, strong) NSMutableArray *queue;
@property (nonatomic, strong) NSURLSessionUploadTask *batchRequest;
@property (nonatomic, strong) SnapyrReachability *reachability;
@property (nonatomic, strong) NSTimer *flushTimer;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) dispatch_queue_t backgroundTaskQueue;
@property (nonatomic, strong) NSDictionary *traits;
@property (nonatomic, assign) SnapyrSDK *sdk;
@property (nonatomic, assign) SnapyrSDKConfiguration *configuration;
@property (nonatomic, strong) SnapyrActionProcessor *actionProcessor;
@property (nonatomic, strong) NSDictionary *meta;
@property (atomic, copy) NSDictionary *referrer;
@property (nonatomic, copy) NSString *userId;
@property (nonatomic, strong) SnapyrHTTPClient *httpClient;
@property (nonatomic, strong) id<SnapyrStorage> fileStorage;
@property (nonatomic, strong) id<SnapyrStorage> userDefaultsStorage;

#if TARGET_OS_IPHONE
@property (nonatomic, assign) UIBackgroundTaskIdentifier flushTaskID;
#else
@property (nonatomic, assign) NSUInteger flushTaskID;
#endif

@end

@interface SnapyrSDK ()
@property (nonatomic, strong, readonly) SnapyrSDKConfiguration *oneTimeConfiguration;
@end

@implementation SnapyrSnapyrIntegration

- (id)initWithSDK:(SnapyrSDK *)sdk httpClient:(SnapyrHTTPClient *)httpClient fileStorage:(id <SnapyrStorage>)fileStorage userDefaultsStorage:(id<SnapyrStorage>)userDefaultsStorage settings:(NSDictionary *)settings;
{
    if (self = [super init]) {
        self.sdk = sdk;
        self.configuration = sdk.oneTimeConfiguration;
        self.meta = [settings[@"metadata"] copy];
        DLog(@"SnapyrSnapyrIntegration.initwithsdk: meta is [%@]", self.meta);
        self.httpClient = httpClient;
        self.httpClient.httpSessionDelegate = sdk.oneTimeConfiguration.httpSessionDelegate;
        self.fileStorage = fileStorage;
        self.userDefaultsStorage = userDefaultsStorage;
        self.reachability = [SnapyrReachability reachabilityWithHostname:@"google.com"];
        [self.reachability startNotifier];
        self.serialQueue = snapyr_dispatch_queue_create_specific("com.snapyr.sdk.snapyr", DISPATCH_QUEUE_SERIAL);
        self.backgroundTaskQueue = snapyr_dispatch_queue_create_specific("com.snapyr.sdk.backgroundTask", DISPATCH_QUEUE_SERIAL);
        self.actionProcessor = [[SnapyrActionProcessor alloc] initWithSDK:sdk httpClient:httpClient];
#if TARGET_OS_IPHONE
        self.flushTaskID = UIBackgroundTaskInvalid;
#else
        self.flushTaskID = 0; // the actual value of UIBackgroundTaskInvalid
#endif
        
        // load traits & user from disk.
        [self loadUserId];
        [self loadTraits];

        [self dispatchBackground:^{
            // Check for previous queue data in NSUserDefaults and remove if present.
            if ([getGroupUserDefaults() objectForKey:SnapyrQueueKey]) {
                [getGroupUserDefaults() removeObjectForKey:SnapyrQueueKey];
            }
#if !TARGET_OS_TV
            // Check for previous track data in NSUserDefaults and remove if present (Traits still exist in NSUserDefaults on tvOS)
            if ([getGroupUserDefaults() objectForKey:SnapyrTraitsKey]) {
                [getGroupUserDefaults() removeObjectForKey:SnapyrTraitsKey];
            }
#endif
        }];

        self.flushTimer = [NSTimer timerWithTimeInterval:self.configuration.flushInterval
                                                  target:self
                                                selector:@selector(flush)
                                                userInfo:nil
                                                 repeats:YES];
        
        [NSRunLoop.mainRunLoop addTimer:self.flushTimer
                                forMode:NSDefaultRunLoopMode];        
    }
    return self;
}

- (void)dispatchBackground:(void (^)(void))block
{
    snapyr_dispatch_specific_async(_serialQueue, block);
}

- (void)dispatchBackgroundAndWait:(void (^)(void))block
{
    snapyr_dispatch_specific_sync(_serialQueue, block);
}

- (void)beginBackgroundTask
{
    [self endBackgroundTask];

    snapyr_dispatch_specific_sync(_backgroundTaskQueue, ^{
        
        id<SnapyrApplicationProtocol> application = [self.sdk oneTimeConfiguration].application;
        if (application && [application respondsToSelector:@selector(snapyr_beginBackgroundTaskWithName:expirationHandler:)]) {
            self.flushTaskID = [application snapyr_beginBackgroundTaskWithName:@"Snapyr.Flush"
                                                          expirationHandler:^{
                                                              [self endBackgroundTask];
                                                          }];
        }
    });
}

- (void)endBackgroundTask
{
    // endBackgroundTask and beginBackgroundTask can be called from main thread
    // We should not dispatch to the same queue we use to flush events because it can cause deadlock
    // inside @synchronized(self) block for SnapyrIntegrationsManager as both events queue and main queue
    // attempt to call forwardSelector:arguments:options:
    // See https://github.com/segmentio/analytics-ios/issues/683
    snapyr_dispatch_specific_sync(_backgroundTaskQueue, ^{
        if (self.flushTaskID != kSnapyrBackgroundTaskInvalid) {
            id<SnapyrApplicationProtocol> application = [self.sdk oneTimeConfiguration].application;
            if (application && [application respondsToSelector:@selector(snapyr_endBackgroundTask:)]) {
                [application snapyr_endBackgroundTask:self.flushTaskID];
            }

            self.flushTaskID = kSnapyrBackgroundTaskInvalid;
        }
    });
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%p:%@, %@>", self, self.class, self.configuration.writeKey];
}

- (NSString *)userId
{
    return [SnapyrState sharedInstance].userInfo.userId;
}

- (void)setUserId:(NSString *)userId
{
    [self dispatchBackground:^{
        [SnapyrState sharedInstance].userInfo.userId = userId;
#if TARGET_OS_TV
        [self.userDefaultsStorage setString:userId forKey:SnapyrUserIdKey];
#else
        [self.fileStorage setString:userId forKey:kSnapyrUserIdFilename];
#endif
    }];
}

- (NSDictionary *)traits
{
    return [SnapyrState sharedInstance].userInfo.traits;
}

- (void)setTraits:(NSDictionary *)traits
{
    [self dispatchBackground:^{
        [SnapyrState sharedInstance].userInfo.traits = traits;
#if TARGET_OS_TV
        [self.userDefaultsStorage setDictionary:[self.traits copy] forKey:SnapyrTraitsKey];
#else
        [self.fileStorage setDictionary:[self.traits copy] forKey:kSnapyrTraitsFilename];
#endif
    }];
}

#pragma mark - API

- (void)identify:(SnapyrIdentifyPayload *)payload
{
    [self dispatchBackground:^{
        self.userId = payload.userId;
        self.traits = payload.traits;
    }];

    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:payload.traits forKey:@"traits"];
    [dictionary setValue:payload.timestamp forKey:@"timestamp"];
    [dictionary setValue:payload.messageId forKey:@"messageId"];
    [self enqueueAction:@"identify" dictionary:dictionary context:payload.context integrations:payload.integrations];
}

- (void)track:(SnapyrTrackPayload *)payload
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:payload.event forKey:@"event"];
    [dictionary setValue:payload.properties forKey:@"properties"];
    [dictionary setValue:payload.timestamp forKey:@"timestamp"];
    [dictionary setValue:payload.messageId forKey:@"messageId"];
        
    // Add in the meta for this channel
    NSDictionary *mutableContext = [[NSMutableDictionary alloc] initWithDictionary:payload.context copyItems:YES];

    DLog(@"SnapyrSnapyrIntegration.track : sdkmeta is %@", self.meta);
    [mutableContext setValue:self.meta forKey:@"sdkMeta"];
    [self enqueueAction:@"track" dictionary:dictionary context:mutableContext integrations:payload.integrations];
}

- (void)screen:(SnapyrScreenPayload *)payload
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:payload.name forKey:@"name"];
    [dictionary setValue:payload.properties forKey:@"properties"];
    [dictionary setValue:payload.timestamp forKey:@"timestamp"];
    [dictionary setValue:payload.messageId forKey:@"messageId"];

    [self enqueueAction:@"screen" dictionary:dictionary context:payload.context integrations:payload.integrations];
}

- (void)group:(SnapyrGroupPayload *)payload
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:payload.groupId forKey:@"groupId"];
    [dictionary setValue:payload.traits forKey:@"traits"];
    [dictionary setValue:payload.timestamp forKey:@"timestamp"];
    [dictionary setValue:payload.messageId forKey:@"messageId"];

    [self enqueueAction:@"group" dictionary:dictionary context:payload.context integrations:payload.integrations];
}

- (void)alias:(SnapyrAliasPayload *)payload
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:payload.theNewId forKey:@"userId"];
    [dictionary setValue:self.userId ?: [self.sdk getAnonymousId] forKey:@"previousId"];
    [dictionary setValue:payload.timestamp forKey:@"timestamp"];
    [dictionary setValue:payload.messageId forKey:@"messageId"];

    [self enqueueAction:@"alias" dictionary:dictionary context:payload.context integrations:payload.integrations];
}

#pragma mark - Queueing

// Merges user provided integration options with bundled integrations.
- (NSDictionary *)integrationsDictionary:(NSDictionary *)integrations
{
    NSMutableDictionary *dict = [integrations ?: @{} mutableCopy];
    for (NSString *integration in self.sdk.bundledIntegrations) {
        // Don't record Snapyr in the dictionary. It is always enabled.
        if ([integration isEqualToString:@"Snapyr"]) {
            continue;
        }
        dict[integration] = @NO;
    }
    return [dict copy];
}

- (void)enqueueAction:(NSString *)action dictionary:(NSMutableDictionary *)payload context:(NSDictionary *)context integrations:(NSDictionary *)integrations
{
    // attach these parts of the payload outside since they are all synchronous
    payload[@"type"] = action;

    [self dispatchBackground:^{
        // attach userId and anonymousId inside the dispatch_async in case
        // they've changed (see identify function)

        // Do not override the userId for an 'alias' action. This value is set in [alias:] already.
        if (![action isEqualToString:@"alias"]) {
            [payload setValue:[SnapyrState sharedInstance].userInfo.userId forKey:@"userId"];
        }
        [payload setValue:[self.sdk getAnonymousId] forKey:@"anonymousId"];

        [payload setValue:[self integrationsDictionary:integrations] forKey:@"integrations"];

        [payload setValue:[context copy] forKey:@"context"];

        DLog(@"SnapyrSnapyrIntegration.enqueueAction: enqueueing action [%@]", payload);
        
        NSDictionary *queuePayload = [payload copy];
        if (self.configuration.experimental.rawSnapyrModificationBlock != nil) {
            NSDictionary *tempPayload = self.configuration.experimental.rawSnapyrModificationBlock(queuePayload);
            if (tempPayload == nil) {
                SLog(@"rawSnapyrModificationBlock cannot be used to drop events!");
            } else {
                // prevent anything else from modifying it at this point.
                queuePayload = [tempPayload copy];
            }
        }
        [self queuePayload:queuePayload];
    }];
}

- (void)queuePayload:(NSDictionary *)payload
{
    @try {
		_queue = [self storedQueue];
        SLog(@"Queue is at max capacity (%tu), removing oldest payload.", self.queue.count);
        // Trim the queue to maxQueueSize - 1 before we add a new element.
        trimQueue(self.queue, self.sdk.oneTimeConfiguration.maxQueueSize - 1);
        [self.queue addObject:payload];
        [self persistQueue];
        [self flushQueueByLength];
    }
    @catch (NSException *exception) {
        SLog(@"%@ Error writing payload: %@", self, exception);
    }
}

- (void)flush
{
    [self flushWithMaxSize:self.maxBatchSize];
}

- (void)flushWithMaxSize:(NSUInteger)maxBatchSize
{
    void (^startBatch)(void) = ^{
        NSArray *batch;
        if ([self.queue count] >= maxBatchSize) {
            batch = [self.queue subarrayWithRange:NSMakeRange(0, maxBatchSize)];
            SLog(@"Max Batch Size!");
        } else {
            batch = [NSArray arrayWithArray:self.queue];
            SLog(@"Below max batch size.");
        }
        [self sendData:batch];
    };
    
    [self dispatchBackground:^{
        if ([self.queue count] == 0) {
            SLog(@"%@ No queued API calls to flush.", self);
            [self endBackgroundTask];
            return;
        }
        if (self.batchRequest != nil) {
            SLog(@"%@ API request already in progress, not flushing again.", self);
            return;
        }
        // here
        startBatch();
    }];
}

- (void)flushQueueByLength
{
    [self dispatchBackground:^{
        SLog(@"%@ Length is %lu.", self, (unsigned long)self.queue.count);

        if (self.batchRequest == nil && [self.queue count] >= self.configuration.flushAt) {
            [self flush];
        }
    }];
}

- (void)reset
{
    [self dispatchBackgroundAndWait:^{
#if TARGET_OS_TV
        @try {
            [self.userDefaultsStorage removeKey:SnapyrUserIdKey];
        } @catch (NSException *exception) {
            DLog(@"SnapyrSnapyrIntegration.reset: Failed to remove user id");
        }
        @try {
            [self.userDefaultsStorage removeKey:SnapyrTraitsKey];
        } @catch (NSException *exception) {
            DLog(@"SnapyrSnapyrIntegration.reset: Failed to remove traits");
        }
#else
        @try {
            [self.fileStorage removeKey:kSnapyrUserIdFilename];
        } @catch (NSException *exception) {
            DLog(@"SnapyrSnapyrIntegration.reset: Failed to remove user id");
        }
        @try {
            [self.fileStorage removeKey:kSnapyrTraitsFilename];
        } @catch (NSException *exception) {
            DLog(@"SnapyrSnapyrIntegration.reset: Failed to remove traits");
        }
#endif
        self.userId = nil;
        self.traits = [NSMutableDictionary dictionary];
    }];
}

- (void)notifyForName:(NSString *)name userInfo:(id)userInfo
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:name object:userInfo];
        SLog(@"sent notification %@", name);
    });
}

- (void)sendData:(NSArray *)batch
{
    NSMutableDictionary *payload = [[NSMutableDictionary alloc] init];
    [payload setObject:iso8601FormattedString([NSDate date]) forKey:@"sentAt"];
    [payload setObject:batch forKey:@"batch"];

    DLog(@"SnapyrSnapyrIntegration.batch: flushing batch, %lu of %lu queued API calls.",
          (unsigned long)batch.count, (unsigned long)self.queue.count);

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload
                                                       options:NSJSONWritingPrettyPrinted  error:&error];
    if (! jsonData) {
        DLog(@"SnapyrSnapyrIntegration.batch: error serializing to json: %@", error);
    } else {
#ifdef DEBUG
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        DLog(@"SnapyrSnapyrIntegration.batch: body is:\n%@\n", jsonString);
#endif
    }
    
    self.batchRequest = [self.httpClient upload:payload forWriteKey:self.configuration.writeKey
                              completionHandler:^(BOOL retry, NSInteger code, NSData *_Nullable data) {
        void (^completion)(void) = ^{
            if (retry) {
                [self notifyForName:SnapyrRequestDidFailNotification userInfo:batch];
                self.batchRequest = nil;
                [self endBackgroundTask];
                return;
            }

            [self.queue removeObjectsInArray:batch];
            [self persistQueue];
            [self notifyForName:SnapyrRequestDidSucceedNotification userInfo:batch];
            self.batchRequest = nil;
            
            if (data != nil) {
                [self processResponseData:data];
            }
            
            [self endBackgroundTask];
        };
        
        [self dispatchBackground:completion];
    }];

    [self notifyForName:SnapyrDidSendRequestNotification userInfo:batch];
}
                         
- (void)processResponseData:(NSData *)data
{
    NSError* dataParsingError = nil;
    NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    DLog(@"SnapyrSnapyrIntegration.processResponseData: response is:\n%@\n", responseString);
    
    id dataObj = [NSJSONSerialization
                  JSONObjectWithData:data
                  options:NSJSONReadingAllowFragments
                  error:&dataParsingError];
    if (dataParsingError != nil) {
        DLog(@"error parsing response json: %@", dataParsingError);
        self.configuration.errorHandler(-1, @"could not parse response from snapyr engine", data);
        return;
    }
    if ([dataObj isKindOfClass:[NSDictionary class]]){
        NSDictionary *deserializedDictionary = (NSDictionary *)dataObj;
        DLog(@"response received (dict) = %@", deserializedDictionary);
        [self handleEventActions:deserializedDictionary];
    } else if ([dataObj isKindOfClass:[NSArray class]]){
        NSArray *deserializedArray = (NSArray *)dataObj;
        DLog(@"response received (array) = %@", deserializedArray);
        for (int i = 0; i < [deserializedArray count]; i++) {
            NSDictionary *eventData = (NSDictionary*)[deserializedArray objectAtIndex:i];
            [self handleEventActions:eventData];
        }
    }
}

- (void)handleEventActions:(NSDictionary*) eventData
{
    if ([eventData objectForKey:@"actions"] != nil) {
        NSArray* actions = [eventData objectForKey:@"actions"];
        for (int i = 0; i < [actions count]; i++) {
            NSDictionary* actionData = (NSDictionary*)[actions objectAtIndex:i];
            [self.actionProcessor processAction:actionData];
        }
    }
}

- (void)applicationDidEnterBackground
{
    [self beginBackgroundTask];
    // We are gonna try to flush as much as we reasonably can when we enter background
    // since there is a chance that the user will never launch the app again.
    [self flush];
}

- (void)applicationWillTerminate
{
    [self dispatchBackgroundAndWait:^{
        if (self.queue.count)
            [self persistQueue];
    }];
}

#pragma mark - Private

- (NSMutableArray *)queue
{
    if (!_queue) {
        _queue = [self storedQueue];
    }

    return _queue;
}

- (NSMutableArray *)storedQueue
{
	return [[self.fileStorage arrayForKey:kSnapyrQueueFilename] ?: @[] mutableCopy];
}

- (void)loadTraits
{
    if (![SnapyrState sharedInstance].userInfo.traits) {
        NSDictionary *traits = nil;
#if TARGET_OS_TV
        traits = [[self.userDefaultsStorage dictionaryForKey:SnapyrTraitsKey] ?: @{} mutableCopy];
#else
        traits = [[self.fileStorage dictionaryForKey:kSnapyrTraitsFilename] ?: @{} mutableCopy];
#endif
        [SnapyrState sharedInstance].userInfo.traits = traits;
    }
}

- (NSUInteger)maxBatchSize
{
    return 100;
}

- (void)loadUserId
{
    NSString *result = nil;
#if TARGET_OS_TV
    result = [getGroupUserDefaults() valueForKey:SnapyrUserIdKey];
#else
    result = [self.fileStorage stringForKey:kSnapyrUserIdFilename];
#endif
    [SnapyrState sharedInstance].userInfo.userId = result;
}

- (void)persistQueue
{
    [self.fileStorage setArray:[self.queue copy] forKey:kSnapyrQueueFilename];
}

@end
