//
//  SnapyrIntegrationsManager.h
//  Analytics
//
//  Created by Tony Xiao on 9/20/16.
//  Copyright © 2016 Segment. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SnapyrMiddleware.h"

/**
 * Filenames of "Application Support" files where essential data is stored.
 */
extern NSString *_Nonnull const kSnapyrAnonymousIdFilename;
extern NSString *_Nonnull const kSnapyrCachedSettingsFilename;

/**
 * NSNotification name, that is posted after integrations are loaded.
 */
extern NSString *_Nonnull SnapyrSDKIntegrationDidStart;

@class SnapyrSDK;

NS_SWIFT_NAME(IntegrationsManager)
@interface SnapyrIntegrationsManager : NSObject

// Exposed for testing.
+ (BOOL)isIntegration:(NSString *_Nonnull)key enabledInOptions:(NSDictionary *_Nonnull)options;
+ (BOOL)isTrackEvent:(NSString *_Nonnull)event enabledForIntegration:(NSString *_Nonnull)key inPlan:(NSDictionary *_Nonnull)plan;

// @Deprecated - Exposing for backward API compat reasons only
@property (nonatomic, readonly) NSMutableDictionary *_Nonnull integrations;

- (nullable NSURL *)getDeepLinkForActionId:(NSString *_Nonnull)actionId;
- (instancetype _Nonnull)initWithSDK:(SnapyrSDK *_Nonnull)sdk;
- (instancetype _Nonnull)initForExtensionWithConfig:(SnapyrSDKConfiguration *_Nonnull)configuration;
- (nullable NSDictionary *)getCachedPushDataForTemplateId: (NSString *_Nonnull)templateId;

// @Deprecated - Exposing for backward API compat reasons only
- (NSString *_Nonnull)getAnonymousId;
- (void)refreshSettings;
- (void)refreshSettingsWithCompletionHandler:(void (^_Nonnull)(BOOL success, JSON_DICT _Nullable settings))completionHandler;

@end


@interface SnapyrIntegrationsManager (SnapyrMiddleware) <SnapyrMiddleware>

@end
