#import <Foundation/Foundation.h>
#import "SnapyrPayload.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(GroupPayload)
@interface SnapyrGroupPayload : SnapyrPayload

@property (nonatomic, readonly) NSString *groupId;

@property (nonatomic, readonly, nullable) JSON_DICT traits;

- (instancetype)initWithGroupId:(NSString *)groupId
                         traits:(JSON_DICT _Nullable)traits
                        context:(JSON_DICT)context
                   integrations:(JSON_DICT)integrations;

@end

NS_ASSUME_NONNULL_END
