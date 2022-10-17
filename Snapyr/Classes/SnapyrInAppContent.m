#import <Foundation/Foundation.h>
#import "SnapyrUtils.h"
#import "SnapyrInAppContent.h"
#import "SnapyrInAppMessage.h"


@interface SnapyrInAppContent ()
@property (readonly) NSString *rawPayload;
@property (readonly) NSDictionary *jsonPayload;
@property (readonly) NSString *htmlPayload;
@end


@implementation SnapyrInAppContent

- (SnapyrInAppContent *) initWithRawContent:(NSDictionary * _Nonnull)rawContent {
    if (self = [super init]) {
    
        NSString *rawPayload = rawContent[@"payload"];
        if ([rawPayload length] == 0) {
            @throw [NSException exceptionWithName:@"Bad Initialization"
                                           reason:@"Missing `content.payload`."
                                         userInfo:nil];
        }
        _rawPayload = [rawPayload copy];
        
        NSString *payloadType = rawContent[@"payloadType"];
        if ([payloadType isEqualToString:kPayloadTypeJson]) {
            _payloadType = SnapyrInAppPayloadTypeJson;
            
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
        } else if ([payloadType isEqualToString:kPayloadTypeHtml]) {
            _payloadType = SnapyrInAppPayloadTypeHtml;
            _htmlPayload = _rawPayload;
        } else {
            @throw [NSException exceptionWithName:@"Bad Initialization"
                                           reason:@"Invalid or missing `content.payloadType`."
                                         userInfo:nil];
        }
    }
    
    return self;
}

- (NSDictionary *)getJsonPayload
{
    if (_jsonPayload == nil) {
        @throw [NSException exceptionWithName:@"Incorrect Access"
                                       reason:@"Content is not json."
                                     userInfo:nil];
    }
    return _jsonPayload;
}

- (NSString *)getHtmlPayload
{
    if (_htmlPayload == nil) {
        @throw [NSException exceptionWithName:@"Incorrect Access"
                                       reason:@"Content is not html."
                                     userInfo:nil];
    }
    return _htmlPayload;
}

- (NSDictionary *)asDict
{
    if (_payloadType == SnapyrInAppPayloadTypeJson) {
        return @{@"payloadType": kPayloadTypeJson, @"payload": _jsonPayload};
    } else {
        return @{@"payloadType": kPayloadTypeHtml, @"payload": _htmlPayload};
    }
}

@end
