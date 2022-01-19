//
//  SnapyrFileStorage.m
//  Analytics
//
//  Copyright © 2016 Segment. All rights reserved.
//

#import "SnapyrUtils.h"
#import "SnapyrFileStorage.h"
#import "SnapyrCrypto.h"


@interface SnapyrFileStorage ()

@property (nonatomic, strong, nonnull) NSURL *folderURL;

@end


@implementation SnapyrFileStorage

- (instancetype)initWithFolder:(NSURL *)folderURL crypto:(id<SnapyrCrypto>)crypto
{
    if (self = [super init]) {
        _folderURL = folderURL;
        _crypto = crypto;
        [self createDirectoryAtURLIfNeeded:folderURL];
        return self;
    }
    return nil;
}

- (void)removeKey:(NSString *)key
{
    NSURL *url = [self urlForKey:key];
    NSError *error = nil;
    if (![[NSFileManager defaultManager] removeItemAtURL:url error:&error]) {
        SLog(@"Unable to remove key %@ - error removing file at path %@", key, url);
    }
}

- (void)resetAll
{
    NSError *error = nil;
    if (![[NSFileManager defaultManager] removeItemAtURL:self.folderURL error:&error]) {
        SLog(@"ERROR: Unable to reset file storage. Path cannot be removed - %@", self.folderURL.path);
    }
    [self createDirectoryAtURLIfNeeded:self.folderURL];
}

- (void)setData:(NSData *)data forKey:(NSString *)key
{
    NSURL *url = [self urlForKey:key];
    
    // a nil value was supplied, remove the storage for said key.
    if (data == nil) {
        [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
        return;
    }
    
    if (self.crypto) {
        NSData *encryptedData = [self.crypto encrypt:data];
        [encryptedData writeToURL:url atomically:YES];
    } else {
        [data writeToURL:url atomically:YES];
    }

    NSError *error = nil;
    if (![url setResourceValue:@YES
                        forKey:NSURLIsExcludedFromBackupKey
                         error:&error]) {
        SLog(@"Error excluding %@ from backup %@", [url lastPathComponent], error);
    }
}

- (NSData *)dataForKey:(NSString *)key
{
    NSURL *url = [self urlForKey:key];
    DLog(@"SnapyrFileStorage.dataForKey [%@] at url [%@]", key, url);
    
    NSData *data = [NSData dataWithContentsOfURL:url];
    if (!data) {
        SLog(@"WARNING: No data file for key %@", key);
        return nil;
    }
    if (self.crypto) {
        return [self.crypto decrypt:data];
    }
    return data;
}

- (nullable NSDictionary *)dictionaryForKey:(NSString *)key
{
    return [self jsonForKey:key];
}

- (void)setDictionary:(nullable NSDictionary *)dictionary forKey:(NSString *)key
{
    [self setJSON:dictionary forKey:key];
}

- (nullable NSArray *)arrayForKey:(NSString *)key
{
    return [self jsonForKey:key];
}

- (void)setArray:(nullable NSArray *)array forKey:(NSString *)key
{
    [self setJSON:array forKey:key];
}

- (nullable NSString *)stringForKey:(NSString *)key
{
    id data = [self jsonForKey:key];

    if (data == nil) {
        return nil;
    }

    if ([data isKindOfClass:[NSString class]]) {
        return data;
    } else if ([data isKindOfClass:[NSDictionary class]]) {
        return data[key];
    }

    return nil;
}

- (void)setString:(nullable NSString *)string forKey:(NSString *)key
{
    [self setJSON:string forKey:key];
}

+ (NSURL *)applicationSupportDirectoryURL
{
    // If we can get a container URL for app group, use that. (used w/ notif extension, to share data w/ main app)
    NSString *appGroupID = getAppGroupName();
    NSURL *containerURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:appGroupID];
    
    if (containerURL) {
        DLog(@"SnapyrFileStorage: applicationSupportDirectoryURL found containerURL: %@", containerURL);
        return [containerURL URLByAppendingPathComponent:@"app"];
    } else {
        DLog(@"SnapyrFileStorage: applicationSupportDirectoryURL - no containerURL found, falling back to appGroupID: %@", appGroupID);
        // Probably no app group - default to the application support dir for this app
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
        NSString *storagePath = [paths firstObject];
        // will return ".../Application Support" because it's in a sandbox.
        return [NSURL fileURLWithPath:storagePath];
    }
}

+ (NSURL *)cachesDirectoryURL
{
    // If we can get a container URL for app group, use that. (used w/ notif extension, to share data w/ main app)
    NSString *appGroupID = getAppGroupName();
    NSURL *containerURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:appGroupID];
    if (containerURL) {
        DLog(@"SnapyrFileStorage: cachesDirectoryURL found containerURL: %@", containerURL);
        return [containerURL URLByAppendingPathComponent:@"cache"];
    } else {
        DLog(@"SnapyrFileStorage: cachesDirectoryURL - no containerURL found, falling back to appGroupID: %@", appGroupID);
        // Probably no app group - default to the cache dir for this app
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *storagePath = [paths firstObject];
        return [NSURL fileURLWithPath:storagePath];
    }
}

- (NSURL *)urlForKey:(NSString *)key
{
    return [self.folderURL URLByAppendingPathComponent:key];
}

#pragma mark - Helpers

- (id _Nullable)jsonForKey:(NSString *)key
{
    id result = nil;
    
    NSData *data = [self dataForKey:key];
    if (data) {
        BOOL needsConversion = NO;
        result = [self jsonFromData:data needsConversion:&needsConversion];
        if (needsConversion) {
            @try {
                [self setJSON:result forKey:key];
                // maybe a little repetitive, but we want to recreate the same path it would
                // take if it weren't being converted.
                data = [self dataForKey:key];
                result = [self jsonFromData:data needsConversion:&needsConversion];
            } @catch (NSException *e) {
                SLog(@"Unable to convert data from plist object to json; Exception: %@, data: %@", e, data);

                [self removeKey:key];
                result = nil;
            }
        }
    }
    return result;
}

- (void)setJSON:(id _Nonnull)json forKey:(NSString *)key
{
    NSDictionary *dict = nil;
    
    // json doesn't allow stand alone values like plist (previous storage format) does so
    // we need to massage it a little.
    if (json) {
        if ([json isKindOfClass:[NSDictionary class]] || [json isKindOfClass:[NSArray class]]) {
            dict = json;
        } else {
            dict = @{key: json};
        }
    }
    
    NSData *data = [self dataFromJSON:dict];
    [self setData:data forKey:key];
}

- (NSData *_Nullable)dataFromJSON:(id)json
{
    if (json == nil) {
        return nil;
    }
    
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:json options:0 error:&error];
    if (error) {
        SLog(@"Unable to serialize data from json object; %@, %@", error, json);
    }
    return data;
}

- (id _Nullable)jsonFromData:(NSData *_Nonnull)data needsConversion:(BOOL *)needsConversion
{
    NSError *error = nil;
    id result = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error) {
        // maybe it's a plist and needs to be converted.
        result = [self plistFromData:data];
        if (result != nil) {
            *needsConversion = YES;
        } else {
            SLog(@"Unable to parse json from data %@", error);
        }
    }
    return result;
}

- (void)createDirectoryAtURLIfNeeded:(NSURL *)url
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:url.path
                                              isDirectory:NULL]) {
        NSError *error = nil;
        if (![[NSFileManager defaultManager] createDirectoryAtPath:url.path
                                       withIntermediateDirectories:YES
                                                        attributes:nil
                                                             error:&error]) {
            SLog(@"error: %@", error.localizedDescription);
        }
    }
}

/// Deprecated
- (NSData *_Nullable)dataFromPlist:(nonnull id)plist
{
    NSError *error = nil;
    NSData *data = nil;
    // Temporary just-in-case fix for issue #846; Follow-on PR to move away from plist storage.
    @try {
        data = [NSPropertyListSerialization dataWithPropertyList:plist
                                                          format:NSPropertyListXMLFormat_v1_0
                                                         options:0
                                                           error:&error];
    } @catch (NSException *e) {
        SLog(@"Unable to serialize data from plist object; Exception: %@, plist: %@", e, plist);
    } @finally {
        if (error) {
            SLog(@"Unable to serialize data from plist object; Error: %@, plist: %@", error, plist);
        }
    }
    return data;
}

/// Deprecated
- (id _Nullable)plistFromData:(NSData *_Nonnull)data
{
    NSError *error = nil;
    id plist = [NSPropertyListSerialization propertyListWithData:data
                                                         options:0
                                                          format:nil
                                                           error:&error];
    if (error) {
        SLog(@"Unable to parse plist from data %@", error);
    }
    return plist;
}

@end
