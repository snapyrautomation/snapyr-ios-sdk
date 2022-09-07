#include <sys/sysctl.h>

#import "SnapyrSDK.h"
#import "SnapyrUtils.h"
#import "SnapyrActionProcessor.h"
#import "SnapyrReachability.h"
#import "SnapyrHTTPClient.h"
#import "SnapyrStorage.h"
#import "SnapyrMacros.h"
#import "SnapyrState.h"
#import <pthread.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

//dispatch_once_t onlyOnce;
//pthread_mutex_t mutex;

@interface SnapyrActionProcessor ()

//@property (nonatomic, strong) NSMutableArray *queue;
@property (nonatomic, strong) NSURLSessionUploadTask *batchRequest;
@property (nonatomic, strong) SnapyrReachability *reachability;
@property (nonatomic, strong) NSTimer *actionPollTimer;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) dispatch_queue_t backgroundTaskQueue;


@property (nonatomic, strong) NSMutableDictionary *actionProcessedData;
@property (nonatomic, assign) NSUInteger lastActionTimestamp;


@property (nonatomic, assign) SnapyrSDK *sdk;
@property (nonatomic, assign) SnapyrSDKConfiguration *configuration;
//@property (nonatomic, strong) NSDictionary *meta;
//@property (atomic, copy) NSDictionary *referrer;
@property (nonatomic, copy) NSString *userId;
@property (nonatomic, strong) SnapyrHTTPClient *httpClient;
//@property (nonatomic, strong) id<SnapyrStorage> fileStorage;
//@property (nonatomic, strong) id<SnapyrStorage> userDefaultsStorage;

@end

@interface SnapyrSDK ()
@property (nonatomic, strong, readonly) SnapyrSDKConfiguration *oneTimeConfiguration;
@end

@implementation SnapyrActionProcessor

- (instancetype)initWithSDK:(SnapyrSDK *)sdk httpClient:(SnapyrHTTPClient *)httpClient;
{
    if (self = [super init]) {
        self.sdk = sdk;
        self.configuration = sdk.oneTimeConfiguration;
//        DLog(@"SnapyrActionProcessor.initwithsdk: meta is [%@]", self.meta);
        self.httpClient = httpClient;
        self.httpClient.httpSessionDelegate = sdk.oneTimeConfiguration.httpSessionDelegate;
//        self.fileStorage = fileStorage;
//        self.userDefaultsStorage = userDefaultsStorage;
        self.serialQueue = snapyr_dispatch_queue_create_specific("com.snapyr.sdk.snapyr", DISPATCH_QUEUE_SERIAL);
        self.backgroundTaskQueue = snapyr_dispatch_queue_create_specific("com.snapyr.sdk.backgroundTask", DISPATCH_QUEUE_SERIAL);
        
        self.actionProcessedData = [[NSMutableDictionary alloc] init];
        self.lastActionTimestamp = 0;

        if (self.configuration.actionPollInterval > 0) {
            // Check for queued actions immediately, then poll on a timer
            [self pollForActions];
            self.actionPollTimer = [NSTimer timerWithTimeInterval:self.configuration.actionPollInterval
                                                      target:self
                                                    selector:@selector(pollForActions)
                                                    userInfo:nil
                                                     repeats:YES];

            [NSRunLoop.mainRunLoop addTimer:self.actionPollTimer
                                    forMode:NSDefaultRunLoopMode];
        }
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

- (NSString *)userId
{
    return [SnapyrState sharedInstance].userInfo.userId;
}

- (void)triggerInAppPopupWithHtml:(NSString *)htmlContent
{
    _inAppViewController = [[SnapyrActionViewController alloc] initWithHtml:htmlContent];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        _inAppViewController.actionHandler = self.configuration.actionHandler;
        [_inAppViewController showHtmlMessage];
    });
}

- (void)pollForActions
{
    [self dispatchBackground:^{
        [self.httpClient fetchActionsForUser:[self userId] forWriteKey:self.configuration.writeKey completionHandler:^(BOOL success, NSArray *pendingActions) {
            if (!success) {
                return;
            }
            DLog(@"SnapyrActionProcessor.pollForActions: response is [%@]", pendingActions);
            
            for (int i = 0; i < [pendingActions count]; i++) {
                NSDictionary *actionData = (NSDictionary*)[pendingActions objectAtIndex:i];
                [self processAction:actionData];
            }
        }];
    }];
}

- (void)markActionDelivered:(NSString *)actionToken userId:(NSString *)userId completionHandler:(void (^)(BOOL success))completionHandler
{
    DLog(@"SnapyrActionProcessor.markActionDelivered: sending delivered update.");
    
    [self dispatchBackground:^{
        NSLog(@"PAUL: dispatchBackground");
        NSURLSessionUploadTask *markDeliveredRequest = [self.httpClient markActionDelivered:actionToken forUserId:userId forWriteKey:self.configuration.writeKey completionHandler:^(BOOL retry, NSInteger code, NSData *_Nullable data) {
            void (^completion)(void) = ^{
                if (retry) {
                    completionHandler(NO);
                    return;
                }
                completionHandler(YES);
            };
            
            [self dispatchBackground:completion];
        }];
    }];
}
                        

- (void)processAction:(NSDictionary*)actionData
{
    // 1. Check if action token (or message id?) already in "the list"
    //    - if so: return immediately
    // 2. Add to "the list" - as incomplete?
    // 3. Mark as delivered (send request to Engine)
    // 4. Call user-provided actionHandler with data
    // 5. Mark as complete on "the list"
    // 6. ... after some amount of time? Clear from the list
    
    NSDictionary *actionContent = actionData[@"content"];
    
    if (!actionContent) {
        return;
    }
    
    NSString *userId = actionData[@"userId"];
    NSString *rawUserPayload = actionContent[@"payload"]; // stringified JSON - for now?
    NSString *actionToken = actionData[@"actionToken"];
    
    NSString *actionType = actionData[@"actionType"];
    NSString *payloadType = actionContent[@"payloadType"];
    
    NSError *jsonError = nil;
    NSData *payloadData = [rawUserPayload dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *payloadDict = [NSJSONSerialization JSONObjectWithData:payloadData
                                                                 options:kNilOptions
                                                                   error:&jsonError];
    if (error != jsonError) {
        DLog(@"SnapyrActionProcessor.processAction: error deserializing response body: [%@]", jsonError);
        return;
    }
    
    if ([self actionIdProcessed:actionToken]) {
        // this action has already been processed; don't re-process
        return;
    }
    
    self.actionProcessedData[actionToken] = @NO;
    
    [self markActionDelivered:actionToken userId:userId completionHandler:^(BOOL success) {
        // Engine successfully marked this action as delivered; now respond here in the client.
        self.actionProcessedData[actionToken] = @YES;
        
        if ([actionType isEqual:@"overlay"] && [payloadType isEqual: @"html"]) {
            [self triggerInAppPopupWithHtml:rawUserPayload];
        } else if (self.configuration.actionHandler != nil) {
            // NB: using `mainQueue` ensures client actionHandler callback is run on the main (UI) thread,
            // which is probably what the client expects. If they want to do things off the main thread they
            // can do so explicitly within the callback.
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                self.configuration.actionHandler(payloadDict);
            }];
        } else {
            SLog(@"action received, but no handler is configured");
        }
    }];
}

- (BOOL)actionIdProcessed:(NSString*) actionId
{
    if (self.actionProcessedData[actionId]) {
        return YES;
    }
    return NO;
}

@end
