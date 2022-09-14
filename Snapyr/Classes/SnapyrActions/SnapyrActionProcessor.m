#include <sys/sysctl.h>

#import "SnapyrSDK.h"
#import "SnapyrUtils.h"
#import "SnapyrActionProcessor.h"
#import "SnapyrInAppMessage.h"
#import "SnapyrHTTPClient.h"
#import "SnapyrMacros.h"
#import "SnapyrState.h"
#import <pthread.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

@interface SnapyrActionProcessor ()

@property (nonatomic, strong) NSTimer *actionPollTimer;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) dispatch_queue_t backgroundTaskQueue;

@property (nonatomic, strong) NSMutableDictionary *actionProcessedData;
@property (nonatomic, assign) NSUInteger lastActionTimestamp;

@property (nonatomic, assign) SnapyrSDK *sdk;
@property (nonatomic, assign) SnapyrSDKConfiguration *configuration;
@property (nonatomic, copy) NSString *userId;
@property (nonatomic, strong) SnapyrHTTPClient *httpClient;
#if !TARGET_OS_OSX && !TARGET_OS_TV
@property (nonatomic, strong) SnapyrActionViewController *inAppViewController;
#endif

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
        self.httpClient = httpClient;
        self.httpClient.httpSessionDelegate = sdk.oneTimeConfiguration.httpSessionDelegate;
        self.serialQueue = snapyr_dispatch_queue_create_specific("com.snapyr.sdk.snapyr", DISPATCH_QUEUE_SERIAL);
        
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

- (NSString *)userId
{
    return [SnapyrState sharedInstance].userInfo.userId;
}

- (void)triggerInAppPopupWithHtml:(NSString *)htmlContent
{
#if !TARGET_OS_OSX && !TARGET_OS_TV
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setInAppViewController:[[SnapyrActionViewController alloc] initWithHtml:htmlContent]];
        [self.inAppViewController setActionHandler:self.configuration.actionHandler];
        [self.inAppViewController showHtmlMessage];
    });
#endif
}

- (void)pollForActions
{
    [self dispatchBackground:^{
        NSString *userId = [self userId];
        if (!userId) {
            return;
        }
        [self.httpClient fetchActionsForUser:userId forWriteKey:self.configuration.writeKey completionHandler:^(BOOL success, NSArray *pendingActions) {
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
    
    SnapyrInAppMessage *message = nil;
    @try {
        message = [[SnapyrInAppMessage alloc] initWithActionPayload:actionData];
    } @catch (NSException *exception) {
        DLog(@"SnapyrActionProcessor: Failed to init SnapyrInAppMessage: %@", exception);
        return;
    }
    
    if ([self actionIdProcessed:message.actionToken]) {
        // this action has already been processed; don't re-process
        return;
    }
    
    self.actionProcessedData[message.actionToken] = @NO;
    
    [self markActionDelivered:message.actionToken userId:message.userId completionHandler:^(BOOL success) {
        // Engine successfully marked this action as delivered; now respond here in the client.
        self.actionProcessedData[message.actionToken] = @YES;
        
        if ([message displaysOverlay]) {
            [self triggerInAppPopupWithHtml:message.rawPayload];
        } else if (self.configuration.actionHandler != nil) {
            // NB: using `mainQueue` ensures client actionHandler callback is run on the main (UI) thread,
            // which is probably what the client expects. If they want to do things off the main thread they
            // can do so explicitly within the callback.
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                self.configuration.actionHandler(message);
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
