NS_ASSUME_NONNULL_BEGIN

@interface SnapyrNotification : NSObject

@property (readonly) UInt32 notificationId;
@property (readonly) NSString *titleText;
@property (readonly) NSString *contentText;
@property (readonly, nullable) NSString *subtitleText;

@property (readonly, nullable) NSString *templateId;
@property (readonly, nullable) NSDate *templateModified;

@property (readonly, nullable) NSURL *deepLinkUrl;
@property (readonly, nullable) NSString *imageUrl;

@property (readonly, nullable) NSString *actionId;
@property (readonly) NSString *actionToken;

- (instancetype)initWithNotifUserInfo:(NSDictionary * _Nonnull)userInfo;
- (NSDictionary *)asDict;
- (NSString *)asJson;

@end

NS_ASSUME_NONNULL_END
