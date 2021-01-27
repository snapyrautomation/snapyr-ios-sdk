#import "SnapyrSnapyrIntegrationFactory.h"
#import "SnapyrSegmentIntegration.h"


@implementation SnapyrSnapyrIntegrationFactory

- (id)initWithHTTPClient:(SnapyrHTTPClient *)client fileStorage:(id<SnapyrStorage>)fileStorage userDefaultsStorage:(id<SnapyrStorage>)userDefaultsStorage
{
    if (self = [super init]) {
        _client = client;
        _userDefaultsStorage = userDefaultsStorage;
        _fileStorage = fileStorage;
    }
    return self;
}

- (id<SnapyrIntegration>)createWithSettings:(NSDictionary *)settings forAnalytics:(SnapyrAnalytics *)analytics
{
    return [[SnapyrSegmentIntegration alloc] initWithAnalytics:analytics httpClient:self.client fileStorage:self.fileStorage userDefaultsStorage:self.userDefaultsStorage];
}

- (NSString *)key
{
    return @"Segment.io";
}

@end
