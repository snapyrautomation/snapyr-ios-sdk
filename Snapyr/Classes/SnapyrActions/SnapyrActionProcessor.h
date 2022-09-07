#import <Foundation/Foundation.h>
#import "SnapyrHTTPClient.h"
#import "SnapyrStorage.h"

#if !TARGET_OS_OSX && !TARGET_OS_TV
#import "SnapyrActionViewController.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SnapyrActionProcessor : NSObject

- (instancetype)initWithSDK:(SnapyrSDK *)sdk httpClient:(SnapyrHTTPClient *)httpClient;
- (void)processAction:(NSDictionary*)actionData;

@end

NS_ASSUME_NONNULL_END
