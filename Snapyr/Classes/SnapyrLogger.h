
#import <Foundation/Foundation.h>
#import "SnapyrHTTPClient.h"

@interface SnapyrLogger : NSObject
NS_ASSUME_NONNULL_BEGIN
- (void) setHTTPClient: (SnapyrHTTPClient*) client;
- (void) setWriteLogsToFile:(BOOL) writeLogsToFile;
- (void) setShowDebugLogs:(BOOL) showDebugLogs;
- (void) logDLog:(NSString*) message;
- (void) logSLog:(NSString*) message;
- (nullable NSURL*) logFileUrl;
- (void) sendLatestLogFileToServerWithWriteKey: (NSString*) writeKey completionHandler:(void (^)(BOOL retry, NSInteger code, NSData *_Nullable data))completionHandler;
NS_ASSUME_NONNULL_END
@end
