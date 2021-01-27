#import "SnapyrIntegration.h"
#import "SnapyrIntegrationFactory.h"
#import "SnapyrHTTPClient.h"

NS_ASSUME_NONNULL_BEGIN
NS_SWIFT_NAME(WebhookIntegrationFactory)
@interface SnapyrWebhookIntegrationFactory : NSObject <SnapyrIntegrationFactory>

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *webhookUrl;

- (instancetype)initWithName:(NSString *)name webhookUrl:(NSString *)webhookUrl;

@end

NS_ASSUME_NONNULL_END