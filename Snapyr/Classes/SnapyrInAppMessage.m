#import <Foundation/Foundation.h>
#import "SnapyrUtils.h"
#import "SnapyrInAppMessage.h"

NSString *const kActionTypeOverlay = @"overlay";
NSString *const kActionTypeCustom  = @"custom";
NSString *const kPayloadTypeJson  = @"json";
NSString *const kPayloadTypeHtml  = @"html";

@interface SnapyrInAppMessage ()
@property (readonly) NSDictionary *jsonPayload;
@end


@implementation SnapyrInAppMessage

- (SnapyrInAppMessage *) initWithActionPayload:(NSDictionary * _Nonnull)rawAction {    
    if (self = [super init]) {
        
        NSString *type = rawAction[@"actionType"];
        if ([type isEqualToString:kActionTypeOverlay]) {
            _actionType = SnapyrInAppActionTypeOverlay;
        } else if ([type isEqualToString:kActionTypeCustom]) {
            _actionType = SnapyrInAppActionTypeCustom;
        } else {
            @throw [NSException exceptionWithName:@"Bad Initialization"
                                           reason:@"Invalid or missing `actionType`."
                                         userInfo:nil];
        }
        
        NSString *userId = rawAction[@"userId"];
        if ([userId length] == 0) {
            @throw [NSException exceptionWithName:@"Bad Initialization"
                                           reason:@"Missing `userId`."
                                         userInfo:nil];
        }
        _userId = [userId copy];
        
        NSString *actionToken = rawAction[@"actionToken"];
        if ([actionToken length] == 0) {
            @throw [NSException exceptionWithName:@"Bad Initialization"
                                           reason:@"Missing `actionToken`."
                                         userInfo:nil];
        }
        _actionToken = [actionToken copy];
        
        NSString *rawTimestamp = rawAction[@"timestamp"];
        if ([rawTimestamp length] == 0) {
            @throw [NSException exceptionWithName:@"Bad Initialization"
                                           reason:@"Missing `timestamp`."
                                         userInfo:nil];
        }
        _timestamp = dateFromIso8601String(rawTimestamp);
        if (_timestamp == nil) {
            @throw [NSException exceptionWithName:@"Bad Initialization"
                                           reason:@"Invalid `timestamp`."
                                         userInfo:nil];
        }
        
        NSDictionary *rawContent = rawAction[@"content"];
        if (rawContent == nil) {
            @throw [NSException exceptionWithName:@"Bad Initialization"
                                           reason:@"Missing `content` subobject."
                                         userInfo:nil];
        }
        _content = [[SnapyrInAppContent alloc] initWithRawContent:rawContent];
        
    }
    
    return self;
}

- (BOOL)displaysOverlay
{
    return (_actionType == SnapyrInAppActionTypeOverlay && _content.payloadType == SnapyrInAppPayloadTypeHtml);
}

- (NSDictionary *)asDict
{
    NSDictionary *dict = @{
        @"timestamp": iso8601FormattedString(_timestamp),
        @"userId": [_userId copy],
        @"actionToken": [_actionToken copy],
        @"actionType": (_actionType == SnapyrInAppActionTypeCustom) ? kActionTypeCustom : kActionTypeOverlay,
        @"content": [_content asDict],
    };

    return dict;
}

- (NSString *)asJson
{
    NSDictionary *dict = [self asDict];
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict
                                                       options:NSJSONWritingPrettyPrinted error:&error];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    return jsonString;
}

@end
