#import <Foundation/Foundation.h>
//#import "SnapyrIntegration.h"
#import "SnapyrHTTPClient.h"
#import "SnapyrStorage.h"

NS_ASSUME_NONNULL_BEGIN

//extern NSString *const SnapyrDidSendRequestNotification;
//extern NSString *const SnapyrRequestDidSucceedNotification;
//extern NSString *const SnapyrRequestDidFailNotification;

/**
 * Filenames of "Application Support" files where essential data is stored.
 */
//extern NSString *const kSnapyrUserIdFilename;
//extern NSString *const kSnapyrQueueFilename;
//extern NSString *const kSnapyrTraitsFilename;


@interface SnapyrActionProcessor : NSObject

- (instancetype)initWithSDK:(SnapyrSDK *)sdk httpClient:(SnapyrHTTPClient *)httpClient;

- (void)processAction:(NSDictionary*) actionData;

@end

NS_ASSUME_NONNULL_END
