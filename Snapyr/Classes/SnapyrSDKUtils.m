#import "SnapyrSDKUtils.h"
#import "SnapyrSDK.h"
#import "SnapyrUtils.h"

static BOOL kSDKLoggerShowLogs = NO;

#pragma mark - Logging

void SnapyrSetShowDebugLogs(BOOL showDebugLogs)
{
    kSDKLoggerShowLogs = showDebugLogs;
}

void SLog(NSString *format, ...)
{
    if (!kSDKLoggerShowLogs)
        return;

    va_list args;
    va_start(args, format);
    NSLogv(format, args);
    va_end(args);
}

#pragma mark - Serialization Extensions

@interface NSDate(SnapyrSerializable)<SnapyrSerializable>
- (id)serializeToAppropriateType;
@end

@implementation NSDate(SnapyrSerializable)
- (id)serializeToAppropriateType
{
    return iso8601FormattedString(self);
}
@end

@interface NSURL(SnapyrSerializable)<SnapyrSerializable>
- (id)serializeToAppropriateType;
@end

@implementation NSURL(SnapyrSerializable)
- (id)serializeToAppropriateType
{
    return [self absoluteString];
}
@end


