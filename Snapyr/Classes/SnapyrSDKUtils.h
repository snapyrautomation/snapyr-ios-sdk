#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Logging

void SnapyrSetShowDebugLogs(BOOL showDebugLogs);
void SLog(NSString *format, ...);


#pragma mark - Serialization Extensions

NS_SWIFT_NAME(SnapyrSerializable)
@protocol SnapyrSerializable
/**
 Serialize objects to a type supported by NSJSONSerializable.  Objects that conform to this protocol should
 return values of type NSArray, NSDictionary, NSString, NSNumber.  Useful for extending objects of your own
 such that they can be serialized on the way to Snapyr and destinations.
 */
- (id)serializeToAppropriateType;
@end


NS_ASSUME_NONNULL_END

#ifdef DEBUG
#define DLog(...) NSLog(@"%s(%p) %@", __PRETTY_FUNCTION__, self, [NSString stringWithFormat:__VA_ARGS__])
#else
#define DLog(...)
#endif

// ALog will always output like NSLog
#define ALog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);

// ULog will show the UIAlertView only when the DEBUG variable is set
#ifdef DEBUG
#   define ULog(fmt, ...)  { UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"%s\n [Line %d] ", __PRETTY_FUNCTION__, __LINE__] message:[NSString stringWithFormat:fmt, ##__VA_ARGS__]  delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil]; [alert show]; }
#else
#   define ULog(...)
#endif
