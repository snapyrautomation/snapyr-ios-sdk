#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>
#import "SnapyrIntegrationFactory.h"
#import "SnapyrCrypto.h"
#import "SnapyrSDKConfiguration.h"
#import "SnapyrSerializableValue.h"
#import "SnapyrMiddleware.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * This object provides an API for recording events.
 */
@class SnapyrSDKConfiguration;

NS_SWIFT_NAME(Snapyr)
@interface SnapyrSDK : NSObject
/**
 * Used by the sdk to configure various options.
 */
@property (nullable, nonatomic, strong, readonly) SnapyrSDKConfiguration *configuration;

/**
 * Setup this sdk instance.
 *
 * @param configuration The configuration used to setup the client.
 */
- (instancetype)initWithConfiguration:(SnapyrSDKConfiguration *)configuration;

#if !TARGET_OS_OSX
/**
 * DEV ONLY - remove before release
 *
 * Trigger an SDK-handled in-app message popup with the provided HTML string.
 */
- (void)triggerTestInAppPopupWithHtml:(NSString *)htmlContent;
#endif

/**
 * Setup the sdk.
 *
 * @param configuration The configuration used to setup the client.
 */
+ (void)setupWithConfiguration:(SnapyrSDKConfiguration *)configuration;

/**
 * Handle incoming notification from a notification service extension. Adds category data, and updates template/category config
 * when necessary.
 *
 * @param bestAttemptContent the mutable copy of notifcation content, which will be written to here and passed to callback
 * @param originalRequest the original notification request received by the extension, used for referencing data on the notification
 * @param contentHandler the content handler callback from the notification service extension, used to tell the OS that this request is complete.
 */
+ (void)handleNoticationExtensionRequestWithBestAttemptContent:(UNMutableNotificationContent * _Nonnull)bestAttemptContent originalRequest:(UNNotificationRequest * _Nonnull)originalRequest contentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler API_UNAVAILABLE(tvos);

/**
 * Handle incoming notification from a notification service extension. Adds category data, and updates template/category config
 * when necessary.
 *
 * @param writeKey the Snapyr write key
 * @param bestAttemptContent the mutable copy of notifcation content, which will be written to here and passed to callback
 * @param originalRequest the original notification request received by the extension, used for referencing data on the notification
 * @param contentHandler the content handler callback from the notification service extension, used to tell the OS that this request is complete.
 */
+ (void)handleNoticationExtensionRequestWithWriteKey:(NSString *)writeKey bestAttemptContent:(UNMutableNotificationContent * _Nonnull)bestAttemptContent originalRequest:(UNNotificationRequest * _Nonnull)originalRequest contentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler API_UNAVAILABLE(tvos);

/**
 * An extension of the above for internal use/testing, allowed dev mode to be enabled (use dev endpoints rather than prod).
 */
+ (void)handleNoticationExtensionRequestWithBestAttemptContent:(UNMutableNotificationContent * _Nonnull)bestAttemptContent originalRequest:(UNNotificationRequest * _Nonnull)originalRequest contentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler snapyrEnvironment:(SnapyrEnvironment)snapyrEnvironment API_UNAVAILABLE(tvos);

/**
 * An extension of the above for internal use/testing, allowed dev mode to be enabled (use dev endpoints rather than prod).
 */
+ (void)handleNoticationExtensionRequestWithWriteKey:(NSString *)writeKey bestAttemptContent:(UNMutableNotificationContent * _Nonnull)bestAttemptContent originalRequest:(UNNotificationRequest * _Nonnull)originalRequest contentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler snapyrEnvironment:(SnapyrEnvironment)snapyrEnvironment API_UNAVAILABLE(tvos);

/**
 * Enabled/disables debug logging to trace your data going through the SDK.
 *
 * @param showDebugLogs `YES` to enable logging, `NO` otherwise. `NO` by default.
 */
+ (void)debug:(BOOL)showDebugLogs;

/**
 * Returns the shared sdk.
 *
 * @see -setupWithConfiguration:
 */
+ (instancetype)sharedSDK;

/**
 * Push: call from your App Delegate's `application:didReceiveRemoteNotification:fetchCompletionHandler:` method to wire up push-receive data.
 * This is a static (class) method. If it is called before initializing the SDK instance, it will fire off internal events that may be used by consuming SDKs (e.g. React Native),
 * but can only track message receipt after SDK initialization.
 */
+ (void)appDidReceiveRemoteNotification:(NSDictionary *)userInfo API_UNAVAILABLE(tvos);

/**
 * Push: call from your App Delegate's `userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:` method to wire up push-response data.
 * This is a static (class) method. If it is called before initializing the SDK instance, it will fire off internal events that may be used by consuming SDKs (e.g. React Native),
 * but can only track message receipt after SDK initialization.
 */
+ (void)appDidReceiveNotificationResponse:(UNNotificationResponse *)response API_UNAVAILABLE(tvos);

/**
 * Push: call from your App Delegate's `application:didRegisterForRemoteNotificationsWithDeviceToken:` method to wire up push-response data.
 * This is a static (class) method. If it is called before initializing the SDK instance, it will fire off internal events that may be used by consuming SDKs (e.g. React Native),
 * but can only track message receipt after SDK initialization.
 */
+ (void)appRegisteredForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken API_UNAVAILABLE(tvos);

/*!
 @method

 @abstract
 Associate a user with their unique ID and record traits about them.

 @param userId        A database ID (or email address) for this user. If you don't have a userId
 but want to record traits, you should pass nil. For more information on how we
 generate the UUID and Apple's policies on IDs.

 @param traits        A dictionary of traits you know about the user. Things like: email, name, plan, etc.

 @param options       A dictionary of options, such as the `@"anonymousId"` key. If no anonymous ID is specified one will be generated for you.

 @discussion
 When you learn more about who your user is, you can record that information with identify.

 */
- (void)identify:(NSString *_Nullable)userId traits:(SERIALIZABLE_DICT _Nullable)traits options:(SERIALIZABLE_DICT _Nullable)options;
- (void)identify:(NSString *_Nullable)userId traits:(SERIALIZABLE_DICT _Nullable)traits;
- (void)identify:(NSString *_Nullable)userId;


/*!
 @method

 @abstract
 Record the actions your users perform.

 @param event         The name of the event you're tracking. We recommend using human-readable names
 like `Played a Song` or `Updated Status`.

 @param properties    A dictionary of properties for the event. If the event was 'Added to Shopping Cart', it might
 have properties like price, productType, etc.

 @discussion
 When a user performs an action in your app, you'll want to track that action for later analysis. Use the event name to say what the user did, and properties to specify any interesting details of the action.

 */
- (void)track:(NSString *)event properties:(SERIALIZABLE_DICT _Nullable)properties options:(SERIALIZABLE_DICT _Nullable)options;
- (void)track:(NSString *)event properties:(SERIALIZABLE_DICT _Nullable)properties;
- (void)track:(NSString *)event;

- (void)setPushNotificationToken:(NSString*)token;
- (void)setPushNotificationTokenData:(NSData*)tokenData;

- (void)pushNotificationReceivedWithResponse:(UNNotificationResponse *)response API_UNAVAILABLE(tvos);
- (void)pushNotificationReceivedWithNotification:(UNNotification *)notification API_UNAVAILABLE(tvos);
- (void)pushNotificationReceived:(SERIALIZABLE_DICT _Nullable)info;

- (void)pushNotificationTappedWithResponse:(UNNotificationResponse*)response API_UNAVAILABLE(tvos);
- (void)pushNotificationTappedWithResponse:(UNNotificationResponse*)response actionId:(NSString* _Nullable)actionId API_UNAVAILABLE(tvos);
- (void)pushNotificationTappedWithNotification:(UNNotification*)notification API_UNAVAILABLE(tvos);
- (void)pushNotificationTappedWithNotification:(UNNotification*)notification actionId:(NSString* _Nullable)actionId API_UNAVAILABLE(tvos);
- (void)pushNotificationTapped:(SERIALIZABLE_DICT _Nullable)info;
- (void)pushNotificationTapped:(SERIALIZABLE_DICT _Nullable)info actionId:(NSString* _Nullable)actionId;

- (void)trackInAppMessageImpressionWithActionToken:(NSString *)actionToken;
- (void)trackInAppMessageClickWithActionToken:(NSString *)actionToken;
- (void)trackInAppMessageClickWithActionToken:(NSString *)actionToken withProperties:(NSDictionary *_Nullable)baseProperties;
- (void)trackInAppMessageDismissWithActionToken:(NSString *)actionToken;

/*!
 @method

 @abstract
 Record the screens or views your users see.

 @param screenTitle   The title of the screen being viewed. We recommend using human-readable names
 like 'Photo Feed' or 'Completed Purchase Screen'.

 @param properties    A dictionary of properties for the screen view event. If the event was 'Added to Shopping Cart',
 it might have properties like price, productType, etc.

 @discussion
 When a user views a screen in your app, you'll want to record that here. For some tools like Google Analytics and Flurry, screen views are treated specially, and are different from "events" kind of like "page views" on the web. For services that don't treat "screen views" specially, we map "screen" straight to "track" with the same parameters. For example, Mixpanel doesn't treat "screen views" any differently. So a call to "screen" will be tracked as a normal event in Mixpanel, but get sent to Google Analytics and Flurry as a "screen".

 */
- (void)screen:(NSString *)screenTitle category:(NSString * _Nullable)category properties:(SERIALIZABLE_DICT _Nullable)properties options:(SERIALIZABLE_DICT _Nullable)options;
- (void)screen:(NSString *)screenTitle properties:(SERIALIZABLE_DICT _Nullable)properties options:(SERIALIZABLE_DICT _Nullable)options;
- (void)screen:(NSString *)screenTitle category:(NSString * _Nullable)category properties:(SERIALIZABLE_DICT _Nullable)properties;
- (void)screen:(NSString *)screenTitle properties:(SERIALIZABLE_DICT _Nullable)properties;
- (void)screen:(NSString *)screenTitle category:(NSString * _Nullable)category;
- (void)screen:(NSString *)screenTitle;


/*!
 @method

 @abstract
 Associate a user with a group, organization, company, project, or w/e *you* call them.

 @param groupId       A database ID for this group.
 @param traits        A dictionary of traits you know about the group. Things like: name, employees, etc.

 @discussion
 When you learn more about who the group is, you can record that information with group.

 */
- (void)group:(NSString *)groupId traits:(SERIALIZABLE_DICT _Nullable)traits options:(SERIALIZABLE_DICT _Nullable)options;
- (void)group:(NSString *)groupId traits:(SERIALIZABLE_DICT _Nullable)traits;
- (void)group:(NSString *)groupId;

/*!
 @method

 @abstract
 Merge two user identities, effectively connecting two sets of user data as one.
 This may not be supported by all integrations.

 @param newId         The new ID you want to alias the existing ID to. The existing ID will be either the
 previousId if you have called identify, or the anonymous ID.

 @discussion
 When you learn more about who the group is, you can record that information with group.

 */
- (void)alias:(NSString *)newId options:(SERIALIZABLE_DICT _Nullable)options;
- (void)alias:(NSString *)newId;

// todo: docs
- (void)receivedRemoteNotification:(NSDictionary *)userInfo;
- (void)failedToRegisterForRemoteNotificationsWithError:(NSError *)error;
- (void)registeredForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken;
- (void)handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo;
- (void)continueUserActivity:(NSUserActivity *)activity;
- (void)openURL:(NSURL *)url options:(NSDictionary *)options;

- (nullable NSURL *)getDeepLinkForActionId:(NSString *)actionId;

/*!
 @method

 @abstract
 Trigger an upload of all queued events.

 @discussion
 This is useful when you want to force all messages queued on the device to be uploaded. Please note that not all integrations
 respond to this method.
 */
- (void)flush;

/*!
 @method

 @abstract
 Reset any user state that is cached on the device.

 @discussion
 This is useful when a user logs out and you want to clear the identity. It will clear any
 traits or userId's cached on the device.
 */
- (void)reset;

/*!
 @method

 @abstract
 Enable the sending of data. Enabled by default.

 @discussion
 Occasionally used in conjunction with disable user opt-out handling.
 */
- (void)enable;


/*!
 @method

 @abstract
 Completely disable the sending of any data.

 @discussion
 If have a way for users to actively or passively (sometimes based on location) opt-out of
 data collection, you can use this method to turn off all data collection.
 */
- (void)disable;


/**
 * Version of the library.
 */
+ (NSString *)version;

/**
 * Returns a dictionary of integrations that are bundled. This is an internal Snapyr API, and may be removed at any time
 * without notice.
 */
- (NSDictionary *)bundledIntegrations;

- (void)refreshSettings;

/** Returns the anonymous ID of the current user. */
- (NSString *)getAnonymousId;

/** Returns the registered device token of this device */
- (NSString *)getDeviceToken;

@end

NS_ASSUME_NONNULL_END
