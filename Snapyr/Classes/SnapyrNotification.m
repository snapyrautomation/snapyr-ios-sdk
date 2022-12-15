#import <Foundation/Foundation.h>
#import "SnapyrUtils.h"
#import "SnapyrNotification.h"

@implementation SnapyrNotification

- (instancetype)initWithNotifUserInfo:(NSDictionary * _Nonnull)userInfo {
    if (self = [super init]) {
        
        // TODO: might want to change this to account for silent/background push notifs in the future
        NSDictionary *apsAlert = userInfo[@"aps"][@"alert"];
        if (apsAlert == nil) {
            @throw [NSException exceptionWithName:@"badInitialization"
                                           reason:@"Invalid or missing `aps.alert`."
                                         userInfo:nil];
        }
        
        _titleText = apsAlert[@"title"];
        _contentText = apsAlert[@"body"];
        if (_titleText == nil || _contentText == nil) {
            @throw [NSException exceptionWithName:@"badInitialization"
                                           reason:@"Invalid message - missing required data."
                                         userInfo:nil];
        }
        _subtitleText = apsAlert[@"subtitle"];
        
        NSDictionary *snapyrData = userInfo[@"snapyr"];
        if (snapyrData == nil) {
            @throw [NSException exceptionWithName:@"nonSnapyrNotification"
                                           reason:@"Invalid or missing `snapyr`."
                                         userInfo:nil];
        }
        
        NSDictionary *template = snapyrData[@"pushTemplate"];
        if (template != nil) {
            NSString *templateId = template[@"id"];
            NSString *rawTimestamp = template[@"modified"];
            if ([templateId length] > 0 && [rawTimestamp length] > 0) {
                _templateModified = dateFromIso8601String(rawTimestamp);
                if (_templateModified != nil) {
                    _templateId = templateId;
                }
            }
        }
        
        _actionId = snapyrData[@"actionId"]; // nullable
        _actionToken = snapyrData[@"actionToken"];
        if (_actionToken == nil) {
            @throw [NSException exceptionWithName:@"badInitialization"
                                           reason:@"Invalid message - missing actionToken."
                                         userInfo:nil];
        }
        
        // Unique (enough) integer by hashing action token, which is itself already unique for every notification
        // This class cannot generate its own ID because iOS doesn't allow us to mutate an existing notification, so a generated ID might be different between e.g. a "receive" and "response" on the same actual notification.
        // TODO: see if we can have the notification service extension set an ID value, or have back end include it
        _notificationId = (UInt32)[_actionToken hash];
        
        NSString *deepLinkUrl = snapyrData[@"deepLinkUrl"];
        if ([deepLinkUrl length] > 0) {
            _deepLinkUrl = [NSURL URLWithString:deepLinkUrl];
        }
        
        _imageUrl = snapyrData[@"imageUrl"];
        
    }
    
    return self;
}

- (NSDictionary *)asDict
{
    NSDictionary *dict = @{
        @"notificationId": [NSNumber numberWithUnsignedLong:_notificationId],
        @"titleText": _titleText,
        @"contentText": _contentText,
        // NB dict value can't be literal `nil` (that's equivalent to not having key set). Set nullable fields to special [NSNull null] object so they'll be translated into JSON properly as `{"key": null}`
        @"subtitleText": _subtitleText ? _subtitleText : [NSNull null],
        @"deepLinkUrl": _deepLinkUrl ? [_deepLinkUrl absoluteString] : [NSNull null],
        @"imageUrl": _imageUrl ? _imageUrl : [NSNull null],
        @"actionToken": _actionToken,
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
