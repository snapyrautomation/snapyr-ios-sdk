#import "SnapyrHTTPClient.h"
#import "NSData+SnapyrGZIP.h"
#import "SnapyrSDKUtils.h"
#import "SnapyrUtils.h"

#define SNAPYR_CDN_BASE [NSURL URLWithString:@"https://api.snapyr.com/sdk"]
#define SNAPYR_CDN_BASE_DEV [NSURL URLWithString:@"https://dev-api.snapyrdev.net/sdk"]
#define SNAPYR_CDN_BASE_STAGE [NSURL URLWithString:@"https://stage-api.snapyrdev.net/sdk"]

static const NSUInteger kMaxBatchSize = 475000; // 475KB

NSString * const kSnapyrAPIBaseHost = @"https://engine.snapyr.com/v1";
NSString * const kSnapyrAPIBaseHostDev = @"https://dev-engine.snapyrdev.net/v1";
NSString * const kSnapyrAPIBaseHostStage = @"https://stage-engine.snapyrdev.net/v1";


@implementation SnapyrHTTPClient

+ (NSMutableURLRequest * (^)(NSURL *))defaultRequestFactory
{
    return ^(NSURL *url) {
        return [NSMutableURLRequest requestWithURL:url];
    };
}

+ (NSString *)authorizationHeader:(NSString *)writeKey
{
    NSString *rawHeader = [writeKey stringByAppendingString:@":"];
    NSData *userPasswordData = [rawHeader dataUsingEncoding:NSUTF8StringEncoding];
    return [userPasswordData base64EncodedStringWithOptions:0];
}


- (instancetype)initWithRequestFactory:(SnapyrRequestFactory)requestFactory
                         configuration: (SnapyrSDKConfiguration *)configuration
{
    if (self = [self init]) {
        if (requestFactory == nil) {
            self.requestFactory = [SnapyrHTTPClient defaultRequestFactory];
        } else {
            self.requestFactory = requestFactory;
        }
        self.configuration = configuration;
        _sessionsByWriteKey = [NSMutableDictionary dictionary];
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.HTTPAdditionalHeaders = @{
            @"Accept-Encoding" : @"gzip",
            @"User-Agent" : [NSString stringWithFormat:@"sdk-ios/%@", [SnapyrSDK version]],
        };
        config.timeoutIntervalForRequest = 4;
        config.timeoutIntervalForResource = 4;
        _genericSession = [NSURLSession sessionWithConfiguration:config];
    }
    return self;
}

- (NSURLSession *)sessionForWriteKey:(NSString *)writeKey
{
    NSURLSession *session = self.sessionsByWriteKey[writeKey];
    if (!session) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.HTTPAdditionalHeaders = @{
            @"Accept-Encoding" : @"gzip",
            // TODO: enable gzipping once it's accepted by server
            //@"Content-Encoding" : @"gzip",
            @"Content-Type" : @"application/json",
            @"Authorization" : [@"Basic " stringByAppendingString:[[self class] authorizationHeader:writeKey]],
            @"User-Agent" : [NSString stringWithFormat:@"sdk-ios/%@", [SnapyrSDK version]],
        };
        session = [NSURLSession sessionWithConfiguration:config delegate:self.httpSessionDelegate delegateQueue:NULL];
        self.sessionsByWriteKey[writeKey] = session;
    }
    return session;
}

- (void)dealloc
{
    for (NSURLSession *session in self.sessionsByWriteKey.allValues) {
        [session finishTasksAndInvalidate];
    }
    [self.genericSession finishTasksAndInvalidate];
}


- (nullable NSURLSessionUploadTask *)upload:(NSDictionary *)batch forWriteKey:(NSString *)writeKey completionHandler:(void (^)(BOOL retry, NSInteger code, NSData *_Nullable data))completionHandler
{
    //    batch = snapyrCoerceDictionary(batch);
    NSURLSession *session = [self sessionForWriteKey:writeKey];
    
    NSURL *url = [[SnapyrUtils getAPIHostURL:self.configuration.snapyrEnvironment] URLByAppendingPathComponent:@"batch"];
    NSMutableURLRequest *request = self.requestFactory(url);
    
    // This is a workaround for an IOS 8.3 bug that causes Content-Type to be incorrectly set
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    [request setHTTPMethod:@"POST"];
    
    NSError *error = nil;
    NSException *exception = nil;
    NSData *payload = nil;
    @try {
        payload = [NSJSONSerialization dataWithJSONObject:batch options:0 error:&error];
    }
    @catch (NSException *exc) {
        exception = exc;
    }
    if (error || exception) {
        SLog(@"Error serializing JSON for batch upload %@", error);
        completionHandler(NO, -1, nil); // Don't retry this batch.
        return nil;
    }
    if (payload.length >= kMaxBatchSize) {
        SLog(@"Payload exceeded the limit of %luKB per batch", kMaxBatchSize / 1000);
        completionHandler(NO, -1, nil);
        return nil;
    }
    
    // TODO: enable gzip once it's accepted by server
    // payload = [payload snapyr_gzippedData];
    
    NSURLSessionUploadTask *task = [session uploadTaskWithRequest:request fromData:payload completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
        
        if (error) {
            // Network error. Retry.
            SLog(@"Error uploading request %@.", error);
            completionHandler(YES, -1, nil);
            return;
        }
        
        NSInteger code = ((NSHTTPURLResponse *)response).statusCode;
        if (code < 300) {
            // 2xx response codes. Don't retry.
            completionHandler(NO, code, data);
            return;
        }
        if (code < 400) {
            // 3xx response codes. Retry.
            SLog(@"Server responded with unexpected HTTP code %d.", code);
            completionHandler(YES, code, nil);
            return;
        }
        if (code == 429) {
            // 429 response codes. Retry.
            SLog(@"Server limited client with response code %d.", code);
            completionHandler(YES, code, nil);
            return;
        }
        if (code < 500) {
            // non-429 4xx response codes. Don't retry.
            SLog(@"Server rejected payload with HTTP code %d.", code);
            completionHandler(NO, code, nil);
            if (self.configuration.errorHandler != NULL) {
                self.configuration.errorHandler(code, @"error in httpclient", data);
            }
            return;
        }
        
        // 5xx response codes. Retry.
        SLog(@"Server error with HTTP code %d.", code);
        completionHandler(YES, code, nil);
    }];
    [task resume];
    return task;
}

- (NSURLSessionDataTask *)settingsForWriteKey:(NSString *)writeKey completionHandler:(void (^)(BOOL success, JSON_DICT _Nullable settings))completionHandler
{
    
    NSURLSession *session = self.genericSession;
    NSURL *urlBase;
    switch (self.configuration.snapyrEnvironment) {
        case SnapyrEnvironmentDev: {
            urlBase = SNAPYR_CDN_BASE_DEV;
            break;
        }
        case SnapyrEnvironmentStage: {
            urlBase = SNAPYR_CDN_BASE_STAGE;
            break;
        }
        case SnapyrEnvironmentDefault:
        default: {
            urlBase = SNAPYR_CDN_BASE;
        }
    }
    NSURL *url = [urlBase URLByAppendingPathComponent:[NSString stringWithFormat:@"/%@", writeKey]];
    NSMutableURLRequest *request = self.requestFactory(url);
    NSDictionary *meta = @{ @"defaults": @"true" };
    NSDictionary *defaultSettings = @{ @"metadata" : meta};
    DLog(@"SnapyrHTTPClient.settingsForWriteKey: fetching settings from [%@]", url);
    [request setHTTPMethod:@"GET"];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
        if (error != nil) {
            DLog(@"error fetching settings %@.", error);
            completionHandler(NO, defaultSettings);
            return;
        }
        NSInteger code = ((NSHTTPURLResponse *)response).statusCode;
        if (code >= 300) {
            DLog(@"SnapyrHTTPClient.settingsForWriteKey: server responded with unexpected HTTP code [%li]", code);
            
            completionHandler(NO, defaultSettings);
            return;
        }
        
        NSError *jsonError = nil;
        id responseJson = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError != nil) {
            DLog(@"SnapyrHTTPClient.settingsForWriteKey: error deserializing response body [%@]", jsonError);
            completionHandler(NO, defaultSettings);
            return;
        }
        DLog(@"SnapyrHTTPClient.settingsForWriteKey: successfully fetched settings");
        completionHandler(YES, responseJson);
    }];
    [task resume];
    return task;
}

- (nullable NSURLSessionUploadTask *)uploadLogData:(NSData*)batch forWriteKey:(NSString *)writeKey completionHandler:(void (^)(BOOL retry, NSInteger code, NSData *_Nullable data))completionHandler
{
    // server isn't prepared yet for logs, so call completion immediately
    completionHandler(false, 0, batch);
    return NULL;
}

@end
