#import <Foundation/Foundation.h>
#import "SnapyrSerializableValue.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Payload)
@interface SnapyrPayload : NSObject

@property (nonatomic, readonly) JSON_DICT context;
@property (nonatomic, readonly) JSON_DICT integrations;
@property (nonatomic, strong) NSString *timestamp;
@property (nonatomic, strong) NSString *messageId;
@property (nonatomic, strong) NSString *anonymousId;
@property (nonatomic, strong) NSString *userId;

- (instancetype)initWithContext:(JSON_DICT)context integrations:(JSON_DICT)integrations;

@end


NS_SWIFT_NAME(ApplicationLifecyclePayload)
@interface SnapyrApplicationLifecyclePayload : SnapyrPayload

@property (nonatomic, strong) NSString *notificationName;

// ApplicationDidFinishLaunching only
@property (nonatomic, strong, nullable) NSDictionary *launchOptions;

@end


NS_SWIFT_NAME(ContinueUserActivityPayload)
@interface SnapyrContinueUserActivityPayload : SnapyrPayload

@property (nonatomic, strong) NSUserActivity *activity;

@end

NS_SWIFT_NAME(OpenURLPayload)
@interface SnapyrOpenURLPayload : SnapyrPayload

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSDictionary *options;

@end

NS_ASSUME_NONNULL_END


NS_SWIFT_NAME(RemoteNotificationPayload)
@interface SnapyrRemoteNotificationPayload : SnapyrPayload

// SnapyrEventTypeHandleActionWithForRemoteNotification
@property (nonatomic, strong, nullable) NSString *actionIdentifier;

// SnapyrEventTypeHandleActionWithForRemoteNotification
// SnapyrEventTypeReceivedRemoteNotification
@property (nonatomic, strong, nullable) NSDictionary *userInfo;

// SnapyrEventTypeFailedToRegisterForRemoteNotifications
@property (nonatomic, strong, nullable) NSError *error;

// SnapyrEventTypeRegisteredForRemoteNotifications
@property (nonatomic, strong, nullable) NSData *deviceToken;

@end
