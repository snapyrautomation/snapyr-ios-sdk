#import "SnapyrInAppContent.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString * const kActionTypeOverlay;
extern NSString * const kActionTypeCustom;
extern NSString * const kPayloadTypeJson;
extern NSString * const kPayloadTypeHtml;

typedef NS_ENUM(NSInteger, SnapyrInAppActionType) {
    SnapyrInAppActionTypeOverlay,
    SnapyrInAppActionTypeCustom
} NS_SWIFT_NAME(SnapyrInAppActionType);

@interface SnapyrInAppMessage : NSObject

@property (strong, readonly) NSString *actionToken;
@property (strong, readonly) NSString *userId;
@property (readonly) SnapyrInAppActionType actionType;
@property (readonly) SnapyrInAppContent *content;
@property (readonly) NSDate *timestamp;

- (instancetype)initWithActionPayload:(NSDictionary * _Nonnull)rawAction;
- (BOOL)displaysOverlay;
- (NSDictionary *)asDict;
- (NSString *)asJson;

@end

NS_ASSUME_NONNULL_END
