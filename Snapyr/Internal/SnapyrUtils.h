//
//  SnapyrUtils.h
//
//

@import Foundation;
#import "SnapyrAnalyticsUtils.h"
#import "SnapyrSerializableValue.h"

NS_ASSUME_NONNULL_BEGIN

@class SnapyrAnalyticsConfiguration;
@class SnapyrReachability;

NS_SWIFT_NAME(Utilities)
@interface SnapyrUtils : NSObject

+ (void)saveAPIHost:(nonnull NSString *)apiHost;
+ (nonnull NSString *)getAPIHost;
+ (nullable NSURL *)getAPIHostURL;

+ (NSData *_Nullable)dataFromPlist:(nonnull id)plist;
+ (id _Nullable)plistFromData:(NSData *)data;

+ (id _Nullable)traverseJSON:(id _Nullable)object andReplaceWithFilters:(NSDictionary<NSString*, NSString*>*)patterns;

@end

BOOL isUnitTesting(void);

NSString * _Nullable deviceTokenToString(NSData * _Nullable deviceToken);
NSString *getDeviceModel(void);
BOOL getAdTrackingEnabled(SnapyrAnalyticsConfiguration *configuration);
NSDictionary *getStaticContext(SnapyrAnalyticsConfiguration *configuration, NSString * _Nullable deviceToken);
NSDictionary *getLiveContext(SnapyrReachability *reachability, NSDictionary * _Nullable referrer, NSDictionary * _Nullable traits);

NSString *GenerateUUIDString(void);

#if TARGET_OS_IPHONE
NSDictionary *mobileSpecifications(SnapyrAnalyticsConfiguration *configuration, NSString * _Nullable deviceToken);
#elif TARGET_OS_OSX
NSDictionary *desktopSpecifications(SnapyrAnalyticsConfiguration *configuration, NSString * _Nullable deviceToken);
#endif

// Date Utils
NSString *iso8601FormattedString(NSDate *date);
NSString *iso8601NanoFormattedString(NSDate *date);

void trimQueue(NSMutableArray *array, NSUInteger size);

// Async Utils
dispatch_queue_t snapyr_dispatch_queue_create_specific(const char *label,
                                                    dispatch_queue_attr_t _Nullable attr);
BOOL snapyr_dispatch_is_on_specific_queue(dispatch_queue_t queue);
void snapyr_dispatch_specific(dispatch_queue_t queue, dispatch_block_t block,
                           BOOL waitForCompletion);
void snapyr_dispatch_specific_async(dispatch_queue_t queue,
                                 dispatch_block_t block);
void snapyr_dispatch_specific_sync(dispatch_queue_t queue, dispatch_block_t block);

// JSON Utils

JSON_DICT SEGCoerceDictionary(NSDictionary *_Nullable dict);

NSString *_Nullable SEGIDFA(void);

NSString *SEGEventNameForScreenTitle(NSString *title);

@interface NSJSONSerialization (Serializable)
+ (BOOL)isOfSerializableType:(id)obj;
@end

// Deep copy and check NSCoding conformance
@protocol SEGSerializableDeepCopy <NSObject>
-(id _Nullable) serializableMutableDeepCopy;
-(id _Nullable) serializableDeepCopy;
@end

@interface NSDictionary(SerializableDeepCopy) <SEGSerializableDeepCopy>
@end

@interface NSArray(SerializableDeepCopy) <SEGSerializableDeepCopy>
@end


NS_ASSUME_NONNULL_END
