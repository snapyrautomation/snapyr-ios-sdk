@import Foundation;
#import "SnapyrIntegration.h"
#import "SnapyrAnalytics.h"

NS_ASSUME_NONNULL_BEGIN

@class SnapyrAnalytics;

@protocol SnapyrIntegrationFactory

/**
 * Attempts to create an adapter with the given settings. Returns the adapter if one was created, or null
 * if this factory isn't capable of creating such an adapter.
 */
- (id<SnapyrIntegration>)createWithSettings:(NSDictionary *)settings forAnalytics:(SnapyrAnalytics *)analytics;

/** The key for which this factory can create an Integration. */
- (NSString *)key;

@end

NS_ASSUME_NONNULL_END
