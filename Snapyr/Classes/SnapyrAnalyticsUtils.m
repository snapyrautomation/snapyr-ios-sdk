#import "SnapyrAnalyticsUtils.h"
#import "SnapyrAnalytics.h"
#import "SnapyrUtils.h"

static BOOL kAnalyticsLoggerShowLogs = NO;

#pragma mark - Logging

void SnapyrSetShowDebugLogs(BOOL showDebugLogs)
{
    kAnalyticsLoggerShowLogs = showDebugLogs;
}

void SLog(NSString *format, ...)
{
    if (!kAnalyticsLoggerShowLogs)
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


