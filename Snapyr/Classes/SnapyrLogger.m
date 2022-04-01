
#import <Foundation/Foundation.h>
#import "SnapyrLogger.h"
#import "SnapyrUtils.h"
#import "SnapyrHTTPClient.h"

@implementation SnapyrLogger : NSObject

BOOL snapyrLoggerShowSDKLogs = NO;
BOOL snapyrLoggerWriteSDKLogsToFile = YES;
NSString *snapyrLoggerLogFileName = NULL;
SnapyrHTTPClient *httpClient = NULL;

- (void) setHTTPClient: (SnapyrHTTPClient*) client
{
    httpClient = client;
}

- (void) setWriteLogsToFile:(BOOL) writeLogsToFile
{
    snapyrLoggerWriteSDKLogsToFile = writeLogsToFile;
}

- (void) setShowDebugLogs:(BOOL) showDebugLogs
{
    snapyrLoggerShowSDKLogs = showDebugLogs;
}

- (void) logDLog:(NSString*) message
{
#if DEBUG
    NSString *formattedMessage = [self formatMessage:message date:[[NSDate alloc] initWithTimeIntervalSinceNow:0] prefix:@"Debug Log"];
    NSLog(@"%s(%p) %@", __PRETTY_FUNCTION__, self, formattedMessage);
    if (snapyrLoggerWriteSDKLogsToFile) {
        [self saveMessageToLogFile:formattedMessage];
    }
#endif
}

- (void) logSLog:(NSString*) message
{
    NSString *formattedMessage = [self formatMessage:message date:[[NSDate alloc] initWithTimeIntervalSinceNow:0] prefix:@"SDK Log"];
    if (snapyrLoggerShowSDKLogs) {
        NSLog(@"%@", formattedMessage);
    }
    if (snapyrLoggerWriteSDKLogsToFile) {
        [self saveMessageToLogFile:formattedMessage];
    }
}

- (nullable NSURL*) logFileUrl
{
    if (!snapyrLoggerWriteSDKLogsToFile) {
        return NULL;
    }
    NSString *appGroupName = getAppGroupName();
    
    NSURL *groupDir = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:appGroupName];
    NSURL *logsFolderDir = [groupDir URLByAppendingPathComponent:@"snapyrLogs" isDirectory:YES];
    bool logsDirExists = [[NSFileManager defaultManager] fileExistsAtPath:[logsFolderDir path]];
    if (!logsDirExists) {
        NSError *error;
        [[NSFileManager defaultManager] createDirectoryAtPath:[logsFolderDir path] withIntermediateDirectories:NO attributes:NULL error:&error];
        if (error) {
            return NULL;
        }
    }
    if (!snapyrLoggerLogFileName) {
        NSLog(@"logg");
        snapyrLoggerLogFileName = [[NSString alloc] initWithFormat:@"%@.log", [[[NSUUID alloc] init] UUIDString]];
    }
    NSURL *currentLogURL = [logsFolderDir URLByAppendingPathComponent:snapyrLoggerLogFileName isDirectory:NO];
    return currentLogURL;
}

- (void) sendLatestLogFileToServerWithWriteKey: (NSString*) writeKey completionHandler:(void (^)(BOOL retry, NSInteger code, NSData *_Nullable data))completionHandler
{
    NSData *logFileData = [self getLogData];
    if (logFileData)
        return;
    
    [httpClient uploadLogData:logFileData forWriteKey:writeKey completionHandler:completionHandler];
}

// Internal

- (nullable NSData*) getLogData
{
    NSURL *logFileUrl = [self logFileUrl];
    if (logFileUrl) {
        @try {
            NSData *data = [[NSData alloc] initWithContentsOfURL:logFileUrl];
        } @catch (NSException *exception) {
            return NULL;
        }
    }
    return NULL;
}

- (NSString*) formatMessage: (NSString*) message date:(NSDate*) date prefix:(NSString*) prefix
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"; // ISO 8601 standard string date format
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.timeZone = [[NSTimeZone alloc] initWithName:@"GMT"];
    
    NSString *dateString = [formatter stringFromDate:date];
    NSString *formattedMessage = [[NSString alloc] initWithFormat:@"[%@ at %@] %@\n", prefix, dateString, message];
    return formattedMessage;
}

- (void) saveMessageToLogFile: (NSString*) message
{
    NSURL *fileUrl = [self logFileUrl];
    if (!fileUrl) {
        return;
    }
    
    [self createOrUpdateFileWithMessage:message at:fileUrl];
}

- (void) createOrUpdateFileWithMessage: (NSString*) message at:(NSURL*) fileUrl
{
    NSFileManager *fm = [NSFileManager defaultManager];
    bool fileExists = [fm fileExistsAtPath:[fileUrl path]];
    if (fileExists) {
        // file already exists, append new message with the help of `NSOutputStream`
        NSOutputStream *stream = [[NSOutputStream alloc] initToFileAtPath:[fileUrl path] append:YES];
        NSData *messageData = [message dataUsingEncoding:NSUTF8StringEncoding];
        if (stream && messageData) {
            UInt8 *bytesArray = (UInt8 *)messageData.bytes;
            [stream open];
            if ([stream hasSpaceAvailable]) {
                [stream write:bytesArray maxLength:messageData.length];
                [stream close];
            }
        }
    } else {
        // create file because file doesn't exist yet
        [fm createFileAtPath:[fileUrl path] contents:[message dataUsingEncoding:NSUTF8StringEncoding] attributes:NULL];
    }
}

@end
