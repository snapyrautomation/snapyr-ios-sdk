//
//  SnapyrMockHTTPClient.m
//  Snapyr
//
//  Created by Brian O'Neill on 5/13/21.
//  Copyright © 2021 Snapyr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SnapyrMockHTTPClient.h"
#import "SnapyrSDKUtils.h"
#import "SnapyrUtils.h"
#import "OCMock/OCMock.h"

@implementation SnapyrMockHTTPClient 

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
                         configuration: (SnapyrSDKConfiguration* _Nonnull)configuration
{
    return self;
    
}

- (nullable NSURLSessionUploadTask *)upload:(NSDictionary *)batch forWriteKey:(NSString *)writeKey completionHandler:(void (^)(BOOL retry, NSInteger code, NSData *_Nullable data))completionHandler
{
    return [OCMockObject mockForClass:[NSURLSessionUploadTask class]];
}

- (NSURLSessionDataTask *)settingsForWriteKey:(NSString *)writeKey completionHandler:(void (^)(BOOL success, JSON_DICT _Nullable settings))completionHandler
{
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"sdk" ofType:@"json"];
    NSData *jsonData = [NSData dataWithContentsOfFile:path];
    SLog(@"loaded json [%@]", jsonData);
    
    NSError* error = nil;
    id dict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    if (dict != nil) {
        SLog(@"dict from json: %@", dict);
    } else {
        SLog(@"json error: %@", error);
    }
    
    completionHandler(true, dict);
    return [OCMockObject mockForClass:[NSURLSessionDataTask class]];
}

@end
