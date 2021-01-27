//
//  SnapyrState.h
//  Analytics
//
//  Created by Brandon Sneed on 6/9/20.
//  Copyright © 2020 Segment. All rights reserved.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@class SnapyrAnalyticsConfiguration;

@interface SnapyrUserInfo: NSObject
@property (nonatomic, strong) NSString *anonymousId;
@property (nonatomic, strong, nullable) NSString *userId;
@property (nonatomic, strong, nullable) NSDictionary *traits;
@end

@interface SnapyrPayloadContext: NSObject
@property (nonatomic, readonly) NSDictionary *payload;
@property (nonatomic, strong, nullable) NSDictionary *referrer;
@property (nonatomic, strong, nullable) NSString *deviceToken;

- (void)updateStaticContext;

@end



@interface SnapyrState : NSObject

@property (nonatomic, readonly) SnapyrUserInfo *userInfo;
@property (nonatomic, readonly) SnapyrPayloadContext *context;

@property (nonatomic, strong, nullable) SnapyrAnalyticsConfiguration *configuration;

+ (instancetype)sharedInstance;
- (instancetype)init __unavailable;

@end

NS_ASSUME_NONNULL_END
