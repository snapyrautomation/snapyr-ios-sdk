@import Foundation;
#import "SnapyrIntegration.h"
#import "SnapyrHTTPClient.h"
#import "SnapyrStorage.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const SnapyrDidSendRequestNotification;
extern NSString *const SnapyrRequestDidSucceedNotification;
extern NSString *const SnapyrRequestDidFailNotification;

/**
 * Filenames of "Application Support" files where essential data is stored.
 */
extern NSString *const kSnapyrUserIdFilename;
extern NSString *const kSnapyrQueueFilename;
extern NSString *const kSnapyrTraitsFilename;


NS_SWIFT_NAME(SnapyrIntegration)
@interface SnapyrSnapyrIntegration : NSObject <SnapyrIntegration>

- (id)initWithSDK:(SnapyrSDK *)sdk httpClient:(SnapyrHTTPClient *)httpClient fileStorage:(id <SnapyrStorage>)fileStorage userDefaultsStorage:(id<SnapyrStorage>)userDefaultsStorage settings:(NSDictionary *)settings;

@end

NS_ASSUME_NONNULL_END
