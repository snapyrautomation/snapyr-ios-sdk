#import <Foundation/Foundation.h>
#import "SnapyrHTTPClient.h"
#import "SnapyrStorage.h"
#import "SnapyrActionViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface SnapyrActionProcessor : NSObject

@property (nonatomic, strong) SnapyrActionViewController *inAppViewController;

- (instancetype)initWithSDK:(SnapyrSDK *)sdk httpClient:(SnapyrHTTPClient *)httpClient;
- (void)processAction:(NSDictionary*)actionData;

@end

NS_ASSUME_NONNULL_END
