#import "SnapyrSnapyrIntegrationFactory.h"
#import "SnapyrSnapyrIntegration.h"


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
    return [[SnapyrSnapyrIntegration alloc] initWithAnalytics:analytics httpClient:self.client fileStorage:self.fileStorage userDefaultsStorage:self.userDefaultsStorage];
}

- (NSString *)key
{
    return @"Snapyr";
}

@end
