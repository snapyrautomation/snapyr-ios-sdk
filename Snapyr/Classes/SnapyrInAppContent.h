NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SnapyrInAppPayloadType) {
    SnapyrInAppPayloadTypeJson,
    SnapyrInAppPayloadTypeHtml
} NS_SWIFT_NAME(SnapyrInAppPayloadType);

@interface SnapyrInAppContent : NSObject

@property (readonly) SnapyrInAppPayloadType payloadType;

- (instancetype)initWithRawContent:(NSDictionary * _Nonnull)rawContent;
- (NSDictionary *)getJsonPayload;
- (NSString *)getHtmlPayload;
- (NSDictionary *)asDict;

@end

NS_ASSUME_NONNULL_END
