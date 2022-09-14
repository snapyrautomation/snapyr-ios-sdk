#import <Foundation/Foundation.h>
#import "SnapyrInAppMessage.h"

NSString *const kActionTypeOverlay = @"overlay";
NSString *const kActionTypeCustom  = @"custom";
NSString *const kContentTypeJson  = @"json";
NSString *const kContentTypeHtml  = @"html";

@interface SnapyrInAppMessage ()
@property (readonly) NSDictionary *jsonPayload;
@end


@implementation SnapyrInAppMessage

- (SnapyrInAppMessage *) initWithActionPayload:(NSDictionary * _Nonnull)rawAction {    
    if (self = [super init]) {
    
        NSString *rawPayload = [rawAction valueForKeyPath:@"content.payload"];
        if ([rawPayload length] == 0) {
            @throw [NSException exceptionWithName:@"Bad Initialization"
                                           reason:@"Missing `content.payload`."
                                         userInfo:nil];
        }
        _rawPayload = [rawPayload copy];
        
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
        
        NSString *payloadType = [rawAction valueForKeyPath:@"content.payloadType"];
        if ([payloadType isEqualToString:kContentTypeJson]) {
            _contentType = SnapyrInAppContentTypeJson;
            
            NSError *jsonError = nil;
            NSData *payloadData = [_rawPayload dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *payloadDict = [NSJSONSerialization JSONObjectWithData:payloadData
                                                                         options:kNilOptions
                                                                           error:&jsonError];
            if (jsonError != nil) {
                @throw [NSException exceptionWithName:@"Bad Initialization"
                                               reason:@"`content.payload` could not be parsed as JSON."
                                             userInfo:nil];
            }
            _jsonPayload = payloadDict;
        } else if ([payloadType isEqualToString:kContentTypeHtml]) {
            _contentType = SnapyrInAppContentTypeHtml;
        } else {
            @throw [NSException exceptionWithName:@"Bad Initialization"
                                           reason:@"Invalid or missing `content.payloadType`."
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
        
        NSString *timestamp = rawAction[@"timestamp"];
        if ([timestamp length] == 0) {
            @throw [NSException exceptionWithName:@"Bad Initialization"
                                           reason:@"Missing `timestamp`."
                                         userInfo:nil];
        }
        _timestamp = iso8601TimestampToDate(timestamp);
        
    }
    
    return self;
}

- (BOOL)displaysOverlay
{
    return (_actionType == SnapyrInAppActionTypeOverlay && _contentType == SnapyrInAppContentTypeHtml);
}

- (NSDictionary *)getContent
{
    if (_contentType == SnapyrInAppContentTypeJson) {
        return @{@"payloadType": kContentTypeJson, @"payload": _jsonPayload};
    } else {
        return @{@"payloadType": kContentTypeHtml, @"payload": _rawPayload};
    }
}

- (NSDictionary *)asDict
{
    NSDictionary *dict = @{
        @"timestamp": iso8601FormattedString(_timestamp),
        @"userId": [_userId copy],
        @"actionToken": [_actionToken copy],
        @"actionType": (_actionType == SnapyrInAppActionTypeCustom) ? kActionTypeCustom : kActionTypeOverlay,
        @"content": @{
            @"payloadType": (_contentType == SnapyrInAppContentTypeJson) ? kContentTypeJson : kContentTypeJson,
            @"payload": [_rawPayload copy],
        },
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
