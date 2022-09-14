NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SnapyrInAppActionType) {
    SnapyrInAppActionTypeCustom,
    SnapyrInAppActionTypeOverlay,
} NS_SWIFT_NAME(SnapyrInAppActionTypeCustom);

typedef NS_ENUM(NSInteger, SnapyrInAppContentType) {
    SnapyrInAppContentTypeJson,
    SnapyrInAppContentTypeHtml
} NS_SWIFT_NAME(SnapyrInAppContentType);

@interface SnapyrInAppMessage : NSObject

@property (strong, readonly) NSString *actionToken;
@property (strong, readonly) NSString *userId;
@property (readonly) NSDate *timestamp;
@property (readonly) SnapyrInAppActionType actionType;
@property (readonly) SnapyrInAppContentType contentType;
@property (strong, readonly) NSString *rawPayload;

- (instancetype)initWithActionPayload:(NSDictionary * _Nonnull)rawAction;
- (BOOL)displaysOverlay;
- (NSDictionary *)getContent;
- (NSDictionary *)asDict;
- (NSString *)asJson;

@end

NS_ASSUME_NONNULL_END
