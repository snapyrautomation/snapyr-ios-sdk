@import Foundation;
@import StoreKit;
#import "SnapyrAnalytics.h"

NS_ASSUME_NONNULL_BEGIN


NS_SWIFT_NAME(StoreKitTracker)
@interface SnapyrStoreKitTracker : NSObject <SKPaymentTransactionObserver, SKProductsRequestDelegate>

+ (instancetype)trackTransactionsForAnalytics:(SnapyrAnalytics *)analytics;

@end

NS_ASSUME_NONNULL_END
