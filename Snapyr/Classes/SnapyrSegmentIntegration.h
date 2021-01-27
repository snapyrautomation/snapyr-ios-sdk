@import Foundation;
#import "SnapyrIntegration.h"
#import "SnapyrHTTPClient.h"
#import "SnapyrStorage.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const SEGSegmentDidSendRequestNotification;
extern NSString *const SEGSegmentRequestDidSucceedNotification;
extern NSString *const SEGSegmentRequestDidFailNotification;

/**
 * Filenames of "Application Support" files where essential data is stored.
 */
extern NSString *const kSEGUserIdFilename;
extern NSString *const kSEGQueueFilename;
extern NSString *const kSEGTraitsFilename;


NS_SWIFT_NAME(SegmentIntegration)
@interface SnapyrSegmentIntegration : NSObject <SnapyrIntegration>

- (id)initWithAnalytics:(SnapyrAnalytics *)analytics httpClient:(SnapyrHTTPClient *)httpClient fileStorage:(id<SnapyrStorage>)fileStorage userDefaultsStorage:(id<SnapyrStorage>)userDefaultsStorage;

@end

NS_ASSUME_NONNULL_END
