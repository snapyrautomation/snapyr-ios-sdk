#import <Foundation/Foundation.h>
@import StoreKit;
#import "SnapyrSDK.h"

NS_ASSUME_NONNULL_BEGIN


NS_SWIFT_NAME(StoreKitTracker)
@interface SnapyrStoreKitTracker : NSObject <SKPaymentTransactionObserver, SKProductsRequestDelegate>

+ (instancetype)trackTransactionsForSDK:(SnapyrSDK *)sdk;

@end

NS_ASSUME_NONNULL_END
