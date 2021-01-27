@import Foundation;
#import "SnapyrIntegrationFactory.h"
#import "SnapyrHTTPClient.h"
#import "SnapyrStorage.h"

NS_ASSUME_NONNULL_BEGIN


NS_SWIFT_NAME(SegmentIntegrationFactory)
@interface SnapyrSnapyrIntegrationFactory : NSObject <SnapyrIntegrationFactory>

@property (nonatomic, strong) SnapyrHTTPClient *client;
@property (nonatomic, strong) id<SnapyrStorage> userDefaultsStorage;
@property (nonatomic, strong) id<SnapyrStorage> fileStorage;

- (instancetype)initWithHTTPClient:(SnapyrHTTPClient *)client fileStorage:(id<SnapyrStorage>)fileStorage userDefaultsStorage:(id<SnapyrStorage>)userDefaultsStorage;

@end

NS_ASSUME_NONNULL_END
