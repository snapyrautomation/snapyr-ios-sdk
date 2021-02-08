@import Foundation;
#import "SnapyrIntegration.h"
#import "SnapyrHTTPClient.h"
#import "SnapyrStorage.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const SnapyrSnapyrDidSendRequestNotification;
extern NSString *const SnapyrSnapyrRequestDidSucceedNotification;
extern NSString *const SnapyrSnapyrRequestDidFailNotification;

/**
 * Filenames of "Application Support" files where essential data is stored.
 */
extern NSString *const kSnapyrUserIdFilename;
extern NSString *const kSnapyrQueueFilename;
extern NSString *const kSnapyrTraitsFilename;


NS_SWIFT_NAME(SnapyrIntegration)
@interface SnapyrSnapyrIntegration : NSObject <SnapyrIntegration>

- (id)initWithAnalytics:(SnapyrAnalytics *)analytics httpClient:(SnapyrHTTPClient *)httpClient fileStorage:(id<SnapyrStorage>)fileStorage userDefaultsStorage:(id<SnapyrStorage>)userDefaultsStorage;

@end

NS_ASSUME_NONNULL_END
