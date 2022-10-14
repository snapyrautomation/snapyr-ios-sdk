NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SnapyrInAppActionType) {
    SnapyrInAppActionTypeOverlay,
    SnapyrInAppActionTypeCustom
} NS_SWIFT_NAME(SnapyrInAppActionTypeCustom);

typedef NS_ENUM(NSInteger, SnapyrInAppContentType) {
    SnapyrInAppContentTypeJson,
    SnapyrInAppContentTypeHtml
} NS_SWIFT_NAME(SnapyrInAppContentType);

@interface SnapyrInAppMessage : NSObject

@property (strong, readonly) NSString *actionToken;
@property (strong, readonly) NSString *userId;
@property (readonly) SnapyrInAppActionType actionType;
@property (readonly) SnapyrInAppContentType contentType;
@property (strong, readonly) NSString *rawPayload;
@property (readonly) NSDate *timestamp;

- (instancetype)initWithActionPayload:(NSDictionary * _Nonnull)rawAction;
- (BOOL)displaysOverlay;
- (NSDictionary *)asDict;
- (NSString *)asJson;
- (NSDictionary *)getContent;

@end

NS_ASSUME_NONNULL_END
