NS_ASSUME_NONNULL_BEGIN

@interface SnapyrNotification : NSObject

@property (readonly) UInt32 notificationId;
@property (readonly) NSString *titleText;
@property (readonly) NSString *contentText;
@property (readonly) NSString *subtitleText;

@property (readonly) NSString *templateId;
@property (readonly) NSDate *templateModified;

@property (readonly) NSURL *deepLinkUrl;
@property (readonly) NSString *imageUrl;

@property (readonly) NSString *actionId;
@property (readonly) NSString *actionToken;

- (instancetype)initWithNotifUserInfo:(NSDictionary * _Nonnull)userInfo;
- (NSDictionary *)asDict;
- (NSString *)asJson;

@end

NS_ASSUME_NONNULL_END
