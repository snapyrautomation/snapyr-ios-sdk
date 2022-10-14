//
//  SnapyrUtils.m
//
//

#import "SnapyrUtils.h"
#import "SnapyrSDKConfiguration.h"
#import "SnapyrReachability.h"
#import "SnapyrSDK.h"
#import "SnapyrHTTPClient.h"

#include <sys/sysctl.h>

#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
static CTTelephonyNetworkInfo *_telephonyNetworkInfo;
#endif

const NSString *snapyr_apiHost = @"snapyr_apihost";
NSString * const kSnapyrWriteKey = @"snapyr_write_key";
NSString * const kSnapyrUseLSKey = @"snapyr_use_ls_key";
NSString * const kSnapyrAdTrackKey = @"snapyr_track_ads_key";
NSString * const kSnapyrFlushAtKey = @"snapyr_flush_at_key";
NSString * const kSnapyrUseMockKey = @"snapyr_use_mock_key";
NSString * const kSnapyrFlushIntervalKey = @"snapyr_flush_interval_key";
NSString * const kSnapyrMaxQueueSizeKey = @"snapyr_max_queue_size_key";
NSString * const kSnapyrTrackAppCycleEventsKey = @"snapyr_track_app_cycle_events_key";
NSString * const kSnapyrUseBTKey = @"snapyr_use_bt_key";
NSString * const kSnapyrRecordScreenViewsKey = @"snapyr_record_screen_views_key";
NSString * const kSnapyrTrackInAppPurchasesKey = @"snapyr_track_in_app_purchases_key";
NSString * const kSnapyrTrackPNKey = @"snapyr_track_pn_key";
NSString * const kSnapyrTrackDLKey = @"snapyr_track_dl_key";


@implementation SnapyrUtils

+ (void)setConfiguration:(SnapyrSDKConfiguration*) config
{
    [SnapyrUtils saveShouldUseLocationServices:config.shouldUseLocationServices];
    [SnapyrUtils saveEnabledAdTracking:config.enableAdvertisingTracking];
    [SnapyrUtils saveFlushAt:config.flushAt];
    [SnapyrUtils saveUseMock:config.useMocks];
    [SnapyrUtils saveFlushInterval:config.flushInterval];
    [SnapyrUtils saveMaxQueueSize:config.maxQueueSize];
    [SnapyrUtils saveTrackAppLifecycleEvents:config.trackApplicationLifecycleEvents];
    [SnapyrUtils saveShouldUseBluetooth:config.shouldUseBluetooth];
    [SnapyrUtils saveRecordScreenViews:config.recordScreenViews];
    [SnapyrUtils saveTrackInAppPurchases:config.trackInAppPurchases];
    [SnapyrUtils saveTrackPushNotifications:config.trackPushNotifications];
    [SnapyrUtils saveTrackDeepLinks:config.trackDeepLinks];
}

+ (SnapyrSDKConfiguration *)getSavedConfigurationWithEnvironment: (SnapyrEnvironment) env;
{
    NSURL *apiHost = [SnapyrUtils getAPIHostURL:env];
    NSString *writeKey = [SnapyrUtils getWriteKey];
    SnapyrSDKConfiguration *config = [SnapyrSDKConfiguration configurationWithWriteKey:writeKey defaultAPIHost:apiHost];
    
    config.snapyrEnvironment = env;
    config.shouldUseLocationServices = [SnapyrUtils getShouldUseLocationServices];
    config.enableAdvertisingTracking = [SnapyrUtils getEnabledAdTracking];
    config.flushAt = [SnapyrUtils getFlushAt];
    config.useMocks = [SnapyrUtils getUseMock];
    config.flushInterval = [SnapyrUtils getFlushInterval];
    config.maxQueueSize = [SnapyrUtils getMaxQueueSize];
    config.trackApplicationLifecycleEvents = [SnapyrUtils getTrackAppLifecycleEvents];
    config.shouldUseBluetooth = [SnapyrUtils getShouldUseBluetooth];
    config.recordScreenViews = [SnapyrUtils getRecordScreenViews];
    config.trackInAppPurchases = [SnapyrUtils getTrackInAppPurchases];
    config.trackPushNotifications = [SnapyrUtils getTrackPushNotifications];
    config.trackDeepLinks = [SnapyrUtils getTrackDeepLinks];
    
    return config;
}


+ (void)saveShouldUseLocationServices:( BOOL )value
{
    NSUserDefaults *defaults = getGroupUserDefaults();
    [defaults setBool:value forKey:[kSnapyrUseLSKey copy]];
}

+ (BOOL)getShouldUseLocationServices
{
    NSUserDefaults *defaults = getGroupUserDefaults();
    BOOL result = [defaults boolForKey:[kSnapyrUseLSKey copy]];
    return result;
}


+ (void)saveEnabledAdTracking:( BOOL )value
{
    NSUserDefaults *defaults = getGroupUserDefaults();
    [defaults setBool:value forKey:[kSnapyrAdTrackKey copy]];
}

+ ( BOOL )getEnabledAdTracking
{
    NSUserDefaults *defaults = getGroupUserDefaults();
    BOOL result = [defaults boolForKey:[kSnapyrAdTrackKey copy]];
    return result;
}


+ (void)saveFlushAt:( NSUInteger )value
{
    NSUserDefaults *defaults = getGroupUserDefaults();
    [defaults setInteger:value forKey:[kSnapyrFlushAtKey copy]];
}

+ ( NSUInteger )getFlushAt
{
    NSUserDefaults *defaults = getGroupUserDefaults();
    NSUInteger result = [defaults integerForKey:[kSnapyrFlushAtKey copy]];
    return result;
}


+ (void)saveUseMock:( BOOL )value
{
    NSUserDefaults *defaults = getGroupUserDefaults();
    [defaults setBool:value forKey:[kSnapyrUseMockKey copy]];
}

+ ( BOOL )getUseMock
{
    NSUserDefaults *defaults = getGroupUserDefaults();
    BOOL result = [defaults boolForKey:[kSnapyrUseMockKey copy]];
    return result;
}


+ (void)saveFlushInterval:(NSTimeInterval)value
{
    NSUserDefaults *defaults = getGroupUserDefaults();
    [defaults setDouble:value forKey:[kSnapyrFlushIntervalKey copy]];
}

+ (NSTimeInterval)getFlushInterval
{
    NSUserDefaults *defaults = getGroupUserDefaults();
    NSTimeInterval result = (NSTimeInterval)[defaults doubleForKey:[kSnapyrFlushIntervalKey copy]];
    return result;
}


+ (void)saveMaxQueueSize:( NSUInteger )value
{
    NSUserDefaults *defaults = getGroupUserDefaults();
    [defaults setInteger:value forKey:[kSnapyrMaxQueueSizeKey copy]];
}

+ ( NSUInteger )getMaxQueueSize
{
    NSUserDefaults *defaults = getGroupUserDefaults();
    NSUInteger result = [defaults integerForKey:[kSnapyrMaxQueueSizeKey copy]];
    return result;
}


+ (void)saveTrackAppLifecycleEvents:( BOOL )value
{
    NSUserDefaults *defaults = getGroupUserDefaults();
    [defaults setBool:value forKey:[kSnapyrTrackAppCycleEventsKey copy]];
}

+ ( BOOL )getTrackAppLifecycleEvents
{
    NSUserDefaults *defaults = getGroupUserDefaults();
    BOOL result = [defaults boolForKey:[kSnapyrTrackAppCycleEventsKey copy]];
    return result;
}


+ (void)saveShouldUseBluetooth:( BOOL )value
{
    NSUserDefaults *defaults = getGroupUserDefaults();
    [defaults setBool:value forKey:[kSnapyrUseBTKey copy]];
}

+ ( BOOL )getShouldUseBluetooth
{
    NSUserDefaults *defaults = getGroupUserDefaults();
    BOOL result = [defaults boolForKey:[kSnapyrUseBTKey copy]];
    return result;
}


+ (void)saveRecordScreenViews:( BOOL )value
{
    NSUserDefaults *defaults = getGroupUserDefaults();
    [defaults setBool:value forKey:[kSnapyrRecordScreenViewsKey copy]];
}

+ ( BOOL )getRecordScreenViews
{
    NSUserDefaults *defaults = getGroupUserDefaults();
    BOOL result = [defaults boolForKey:[kSnapyrRecordScreenViewsKey copy]];
    return result;
}


+ (void)saveTrackInAppPurchases:( BOOL )value
{
    NSUserDefaults *defaults = getGroupUserDefaults();
    [defaults setBool:value forKey:[kSnapyrTrackInAppPurchasesKey copy]];
}

+ ( BOOL )getTrackInAppPurchases
{
    NSUserDefaults *defaults = getGroupUserDefaults();
    BOOL result = [defaults boolForKey:[kSnapyrTrackInAppPurchasesKey copy]];
    return result;
}


+ (void)saveTrackPushNotifications:( BOOL )value
{
    NSUserDefaults *defaults = getGroupUserDefaults();
    [defaults setBool:value forKey:[kSnapyrTrackPNKey copy]];
}

+ ( BOOL )getTrackPushNotifications
{
    NSUserDefaults *defaults = getGroupUserDefaults();
    BOOL result = [defaults boolForKey:[kSnapyrTrackPNKey copy]];
    return result;
}


+ (void)saveTrackDeepLinks:( BOOL )value
{
    NSUserDefaults *defaults = getGroupUserDefaults();
    [defaults setBool:value forKey:[kSnapyrTrackDLKey copy]];
}

+ ( BOOL )getTrackDeepLinks
{
    NSUserDefaults *defaults = getGroupUserDefaults();
    BOOL result = [defaults boolForKey:[kSnapyrTrackDLKey copy]];
    return result;
}


+ (void)saveAPIHost:(nonnull NSString *)apiHost
{
    if (!apiHost) {
        return;
    }
    if (![apiHost containsString:@"https://"]) {
        apiHost = [NSString stringWithFormat:@"https://%@", apiHost];
    }
    NSUserDefaults *defaults = getGroupUserDefaults();
    [defaults setObject:apiHost forKey:[snapyr_apiHost copy]];
}

+ (nonnull NSString *)getAPIHost:(SnapyrEnvironment) snapyrEnvironment
{
    NSUserDefaults *defaults = getGroupUserDefaults();
    NSString *result = [defaults stringForKey:[snapyr_apiHost copy]];
    if (!result) {
        result = [SnapyrUtils getDefaultAPIHostForEnvironment:snapyrEnvironment];
    }
    return result;
}

+ (nonnull NSString *)getDefaultAPIHostForEnvironment:(SnapyrEnvironment) snapyrEnvironment
{
    switch (snapyrEnvironment) {
        case SnapyrEnvironmentDev: {
            return kSnapyrAPIBaseHostDev;
        }
        case SnapyrEnvironmentStage: {
            return kSnapyrAPIBaseHostStage;
        }
        case SnapyrEnvironmentDefault:
        default: {
            return kSnapyrAPIBaseHost;
        }
    }
}

+ (nonnull NSString *)getAPIHost
{
    return [SnapyrUtils getAPIHost:NO];
}

//+ (nonnull NSString *)getAPIHost
//{
//    return kSnapyrAPIBaseHost;
//}

+ (nullable NSURL *)getAPIHostURL:(SnapyrEnvironment) snapyrEnvironment
{
    return [NSURL URLWithString:[SnapyrUtils getAPIHost:snapyrEnvironment]];
}

+ (nullable NSURL *)getAPIHostURL
{
    return [SnapyrUtils getAPIHostURL:NO];
}

+ (void) setWriteKey: (nonnull NSString*)writeKey
{
    [getGroupUserDefaults() setObject:writeKey forKey:[kSnapyrWriteKey copy]];
}

+ (nullable NSString *)getWriteKey
{
    return [getGroupUserDefaults() stringForKey: [kSnapyrWriteKey copy]];
}

+ (NSData *_Nullable)dataFromPlist:(nonnull id)plist
{
    NSError *error = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:plist
                                                              format:NSPropertyListXMLFormat_v1_0
                                                             options:0
                                                               error:&error];
    if (error) {
        SLog(@"Unable to serialize data from plist object", error, plist);
    }
    return data;
}

+ (id _Nullable)plistFromData:(NSData *_Nonnull)data
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


+(id)traverseJSON:(id)object andReplaceWithFilters:(NSDictionary<NSString*, NSString*>*)patterns
{
    if ([object isKindOfClass:NSDictionary.class]) {
        NSDictionary* dict = object;
        NSMutableDictionary* newDict = [NSMutableDictionary dictionaryWithCapacity:dict.count];
        
        for (NSString* key in dict.allKeys) {
            newDict[key] = [self traverseJSON:dict[key] andReplaceWithFilters:patterns];
        }
        
        return newDict;
    }
    
    if ([object isKindOfClass:NSArray.class]) {
        NSArray* array = object;
        NSMutableArray* newArray = [NSMutableArray arrayWithCapacity:array.count];
        
        for (int i = 0; i < array.count; i++) {
            newArray[i] = [self traverseJSON:array[i] andReplaceWithFilters:patterns];
        }
        
        return newArray;
    }

    if ([object isKindOfClass:NSString.class]) {
        NSError* error = nil;
        NSMutableString* str = [object mutableCopy];
        
        for (NSString* pattern in patterns) {
            NSRegularExpression* re = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                                options:0
                                                                                  error:&error];
            
            if (error) {
                @throw error;
            }
            
            NSInteger matches = [re replaceMatchesInString:str
                                                   options:0
                                                     range:NSMakeRange(0, str.length)
                                              withTemplate:patterns[pattern]];
            
            if (matches > 0) {
                SLog(@"%@ Redacted value from action: %@", self, pattern);
            }
        }
        
        return str;
    }
    
    return object;
}

@end

BOOL isUnitTesting()
{
    static dispatch_once_t pred = 0;
    static BOOL _isUnitTesting = NO;
    dispatch_once(&pred, ^{
        NSDictionary *env = [NSProcessInfo processInfo].environment;
        _isUnitTesting = (env[@"XCTestConfigurationFilePath"] != nil);
    });
    return _isUnitTesting;
}

NSString *deviceTokenToString(NSData *deviceToken)
{
    if (!deviceToken) return nil;
    
    const unsigned char *buffer = (const unsigned char *)[deviceToken bytes];
    if (!buffer) {
        return nil;
    }
    NSMutableString *token = [NSMutableString stringWithCapacity:(deviceToken.length * 2)];
    for (NSUInteger i = 0; i < deviceToken.length; i++) {
        [token appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)buffer[i]]];
    }
    return token;
}

NSString *getDeviceModel()
{
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char result[size];
    sysctlbyname("hw.machine", result, &size, NULL, 0);
    NSString *results = [NSString stringWithCString:result encoding:NSUTF8StringEncoding];
    return results;
}

BOOL getAdTrackingEnabled(SnapyrSDKConfiguration *configuration)
{
    BOOL result = NO;
    if ((configuration.adSupportBlock != nil) && (configuration.enableAdvertisingTracking)) {
        result = YES;
    }
    return result;
}

NSDictionary *getStaticContext(SnapyrSDKConfiguration *configuration, NSString *deviceToken)
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];

    dict[@"library"] = @{
        @"name" : @"sdk-ios",
        @"version" : [SnapyrSDK version]
    };

    NSMutableDictionary *infoDictionary = [[[NSBundle mainBundle] infoDictionary] mutableCopy];
    [infoDictionary addEntriesFromDictionary:[[NSBundle mainBundle] localizedInfoDictionary]];
    if (infoDictionary.count) {
        dict[@"app"] = @{
            @"name" : infoDictionary[@"CFBundleDisplayName"] ?: @"",
            @"version" : infoDictionary[@"CFBundleShortVersionString"] ?: @"",
            @"build" : infoDictionary[@"CFBundleVersion"] ?: @"",
            @"namespace" : [[NSBundle mainBundle] bundleIdentifier] ?: @"",
        };
    }

    NSDictionary *settingsDictionary = nil;
#if TARGET_OS_IPHONE
    settingsDictionary = mobileSpecifications(configuration, deviceToken);
#elif TARGET_OS_OSX
    settingsDictionary = desktopSpecifications(configuration, deviceToken);
#endif
    
    if (settingsDictionary != nil) {
        dict[@"device"] = settingsDictionary[@"device"];
        dict[@"os"] = settingsDictionary[@"os"];
        dict[@"screen"] = settingsDictionary[@"screen"];
    }

    return dict;
}

#if TARGET_OS_IPHONE
NSDictionary *mobileSpecifications(SnapyrSDKConfiguration *configuration, NSString *deviceToken)
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    UIDevice *device = [UIDevice currentDevice];
    dict[@"device"] = ({
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        dict[@"manufacturer"] = @"Apple";
#if TARGET_OS_MACCATALYST
        dict[@"type"] = @"macos";
        dict[@"name"] = @"Macintosh";
#else
        dict[@"type"] = @"ios";
        dict[@"name"] = [device model];
#endif
        dict[@"model"] = getDeviceModel();
        dict[@"id"] = [[device identifierForVendor] UUIDString];
        if (getAdTrackingEnabled(configuration)) {
            NSString *idfa = configuration.adSupportBlock();
            // This isn't ideal.  We're doing this because we can't actually check if IDFA is enabled on
            // the customer device.  Apple docs and tests show that if it is disabled, one gets back all 0's.
            BOOL adTrackingEnabled = (![idfa isEqualToString:@"00000000-0000-0000-0000-000000000000"]);
            dict[@"adTrackingEnabled"] = @(adTrackingEnabled);

            if (adTrackingEnabled) {
                dict[@"advertisingId"] = idfa;
            }
        }
        if (deviceToken && deviceToken.length > 0) {
            dict[@"token"] = deviceToken;
        }
        dict;
    });

    dict[@"os"] = @{
        @"name" : device.systemName,
        @"version" : device.systemVersion
    };

    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    dict[@"screen"] = @{
        @"width" : @(screenSize.width),
        @"height" : @(screenSize.height)
    };
    
    // BKS: This bit below doesn't seem to be effective anymore.  Will investigate later.
    /*#if !(TARGET_IPHONE_SIMULATOR)
        Class adClient = NSClassFromString(SnapyrADClientClass);
        if (adClient) {
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            id sharedClient = [adClient performSelector:NSSelectorFromString(@"sharedClient")];
    #pragma clang diagnostic pop
            void (^completionHandler)(BOOL iad) = ^(BOOL iad) {
                if (iad) {
                    dict[@"referrer"] = @{ @"type" : @"iad" };
                }
            };
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [sharedClient performSelector:NSSelectorFromString(@"determineAppInstallationAttributionWithCompletionHandler:")
                               withObject:completionHandler];
    #pragma clang diagnostic pop
        }
    #endif*/

    return dict;
}
#endif

#if TARGET_OS_OSX
NSString *getMacUUID()
{
    char buf[512] = { 0 };
    int bufSize = sizeof(buf);
    io_registry_entry_t ioRegistryRoot = IORegistryEntryFromPath(kIOMasterPortDefault, "IOService:/");
    CFStringRef uuidCf = (CFStringRef) IORegistryEntryCreateCFProperty(ioRegistryRoot, CFSTR(kIOPlatformUUIDKey), kCFAllocatorDefault, 0);
    IOObjectRelease(ioRegistryRoot);
    CFStringGetCString(uuidCf, buf, bufSize, kCFStringEncodingMacRoman);
    CFRelease(uuidCf);
    return [NSString stringWithUTF8String:buf];
}

NSDictionary *desktopSpecifications(SnapyrSDKConfiguration *configuration, NSString *deviceToken)
{
    NSProcessInfo *deviceInfo = [NSProcessInfo processInfo];
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    dict[@"device"] = ({
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        dict[@"manufacturer"] = @"Apple";
        dict[@"type"] = @"macos";
        dict[@"model"] = getDeviceModel();
        dict[@"id"] = getMacUUID();
        dict[@"name"] = [deviceInfo hostName];
        
        if (getAdTrackingEnabled(configuration)) {
            NSString *idfa = configuration.adSupportBlock();
            // This isn't ideal.  We're doing this because we can't actually check if IDFA is enabled on
            // the customer device.  Apple docs and tests show that if it is disabled, one gets back all 0's.
            BOOL adTrackingEnabled = (![idfa isEqualToString:@"00000000-0000-0000-0000-000000000000"]);
            dict[@"adTrackingEnabled"] = @(adTrackingEnabled);

            if (adTrackingEnabled) {
                dict[@"advertisingId"] = idfa;
            }
        }
        if (deviceToken && deviceToken.length > 0) {
            dict[@"token"] = deviceToken;
        }
        dict;
    });

    dict[@"os"] = @{
        @"name" : deviceInfo.operatingSystemVersionString,
        @"version" : [NSString stringWithFormat:@"%ld.%ld.%ld",
                      deviceInfo.operatingSystemVersion.majorVersion,
                      deviceInfo.operatingSystemVersion.minorVersion,
                      deviceInfo.operatingSystemVersion.patchVersion]
    };

    CGSize screenSize = [NSScreen mainScreen].frame.size;
    dict[@"screen"] = @{
        @"width" : @(screenSize.width),
        @"height" : @(screenSize.height)
    };

    return dict;
}

#endif

NSDictionary *getLiveContext(SnapyrReachability *reachability, NSDictionary *referrer, NSDictionary *traits)
{
    NSMutableDictionary *context = [[NSMutableDictionary alloc] init];
    context[@"locale"] = [NSString stringWithFormat:
                                       @"%@-%@",
                                       [NSLocale.currentLocale objectForKey:NSLocaleLanguageCode],
                                       [NSLocale.currentLocale objectForKey:NSLocaleCountryCode]];

    context[@"timezone"] = [[NSTimeZone localTimeZone] name];

    context[@"network"] = ({
        NSMutableDictionary *network = [[NSMutableDictionary alloc] init];

        if (reachability.isReachable) {
            network[@"wifi"] = @(reachability.isReachableViaWiFi);
            network[@"cellular"] = @(reachability.isReachableViaWWAN);
        }

#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST
        static dispatch_once_t networkInfoOnceToken;
        dispatch_once(&networkInfoOnceToken, ^{
            _telephonyNetworkInfo = [[CTTelephonyNetworkInfo alloc] init];
        });

        CTCarrier *carrier = [_telephonyNetworkInfo subscriberCellularProvider];
        if (carrier.carrierName.length)
            network[@"carrier"] = carrier.carrierName;
#endif

        network;
    });

    context[@"traits"] = [traits copy];

    if (referrer) {
        context[@"referrer"] = [referrer copy];
    }
    
    return [context copy];
}

/**
 * Get the app group name used by Snapyr SDK convention: `group.{bundle ID}.snapyr`, e.g. `group.com.testorg.testapp.snapyr`
 */
NSString* getAppGroupName(void)
{
    // https://stackoverflow.com/a/27849695
    NSBundle *bundle = [NSBundle mainBundle];
    // Path extension is "appex" for extensions (in the case of notif service extension)
    // Remove it to get back to the main bundle ID which will be the same as that from the main app
    if ([[bundle.bundleURL pathExtension] isEqualToString:@"appex"]) {
        // Peel off two directory levels - MY_APP.app/PlugIns/MY_APP_EXTENSION.appex
        bundle = [NSBundle bundleWithURL:[[bundle.bundleURL URLByDeletingLastPathComponent] URLByDeletingLastPathComponent]];
    }
    
    NSString* bundleID = [bundle bundleIdentifier];
    return [NSString stringWithFormat:@"%@.%@.%@", @"group", bundleID, @"snapyr"];
}

/**
 * Get UserDefaults for shared app group, which is used to share data between main app and notification service extension.
 * If that doesn't work (because there's no app group by the expected name), fall back to standardUserDefaults
 */
NSUserDefaults* getGroupUserDefaults(void)
{
    
    @try {
        NSString *appGroupName = getAppGroupName();
        return [[NSUserDefaults alloc] initWithSuiteName:appGroupName];
    }
    @catch (NSException *exc) {
        return [NSUserDefaults standardUserDefaults];
    }
}

#if !TARGET_OS_OSX
/**
 * Get the shared application, if available. Equivalent to calling `[UIApplication sharedApplication]` but prevents errors building for app extensions.
 * Should never be used from within extension context, but if it is, it will return nil.
 */
UIApplication* getSharedUIApplication(void)
{
    UIApplication *sharedApp = nil;
    if ([UIApplication respondsToSelector:@selector(sharedApplication)]) {
        // sharedApplication is not available in App Extension context. Checking and running by selector
        // ensures we don't attempt this if in that context, and prevents build errors.
        sharedApp = [UIApplication performSelector:@selector(sharedApplication)];
    }
    return sharedApp;
}
#endif


@interface SnapyrISO8601NanosecondDateFormatter: NSDateFormatter
@end

@implementation SnapyrISO8601NanosecondDateFormatter

- (id)init
{
    self = [super init];
    self.dateFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ss.SSS:'Z'";
    self.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    self.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    return self;
}

const NSInteger __SNAPYR_NANO_MAX_LENGTH = 9;
- (NSString * _Nonnull)stringFromDate:(NSDate *)date
{
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *dateComponents = [calendar components:NSCalendarUnitSecond | NSCalendarUnitNanosecond fromDate:date];
    NSString *genericDateString = [super stringFromDate:date];
    
    NSMutableArray *stringComponents = [[genericDateString componentsSeparatedByString:@"."] mutableCopy];
    NSString *nanoSeconds = [NSString stringWithFormat:@"%li", (long)dateComponents.nanosecond];
    
    if (nanoSeconds.length > __SNAPYR_NANO_MAX_LENGTH) {
        nanoSeconds = [nanoSeconds substringToIndex:__SNAPYR_NANO_MAX_LENGTH];
    } else {
        nanoSeconds = [nanoSeconds stringByPaddingToLength:__SNAPYR_NANO_MAX_LENGTH withString:@"0" startingAtIndex:0];
    }
    
    NSString *result = [NSString stringWithFormat:@"%@.%@Z", stringComponents[0], nanoSeconds];
    
    return result;
}

@end


NSString *GenerateUUIDString()
{
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    NSString *UUIDString = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, theUUID);
    CFRelease(theUUID);
    return UUIDString;
}


// Date Utils
NSString *iso8601NanoFormattedString(NSDate *date)
{
    static NSDateFormatter *dateFormatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [[SnapyrISO8601NanosecondDateFormatter alloc] init];
    });
    return [dateFormatter stringFromDate:date];
}

NSDate *dateFromIso8601String(NSString *string)
{
    static NSDateFormatter *wholeSecondsFormatter;
    static NSDateFormatter *fractionalSecondsFormatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        wholeSecondsFormatter = [[NSDateFormatter alloc] init];
        [wholeSecondsFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
        [wholeSecondsFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
        
        fractionalSecondsFormatter = [[NSDateFormatter alloc] init];
        [fractionalSecondsFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"];
        [fractionalSecondsFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
    });
    NSDate *result = [wholeSecondsFormatter dateFromString:string];
    if (result != nil) {
        return result;
    }
    return [fractionalSecondsFormatter dateFromString:string];
}

NSString *iso8601FormattedString(NSDate *date)
{
    static NSDateFormatter *dateFormatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        dateFormatter.dateFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ss.SSS'Z'";
        dateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    });
    return [dateFormatter stringFromDate:date];
}


/** trim the queue so that it contains only upto `max` number of elements. */
void trimQueue(NSMutableArray *queue, NSUInteger max)
{
    if (queue.count < max) {
        return;
    }

    // Previously we didn't cap the queue. Hence there are cases where
    // the queue may already be larger than 1000 events. Delete as many
    // events as required to trim the queue size.
    NSRange range = NSMakeRange(0, queue.count - max);
    [queue removeObjectsInRange:range];
}

// Async Utils
dispatch_queue_t
snapyr_dispatch_queue_create_specific(const char *label,
                                   dispatch_queue_attr_t attr)
{
    dispatch_queue_t queue = dispatch_queue_create(label, attr);
    dispatch_queue_set_specific(queue, (__bridge const void *)queue,
                                (__bridge void *)queue, NULL);
    return queue;
}

BOOL snapyr_dispatch_is_on_specific_queue(dispatch_queue_t queue)
{
    return dispatch_get_specific((__bridge const void *)queue) != NULL;
}

void snapyr_dispatch_specific(dispatch_queue_t queue, dispatch_block_t block,
                           BOOL waitForCompletion)
{
    

    dispatch_block_t autoreleasing_block = ^{
        @autoreleasepool
        {
            block();
        }
    };
    if (dispatch_get_specific((__bridge const void *)queue)) {
        autoreleasing_block();
    } else if (waitForCompletion) {
        dispatch_sync(queue, autoreleasing_block);
    } else {
        dispatch_async(queue, autoreleasing_block);
    }
}

void snapyr_dispatch_specific_async(dispatch_queue_t queue,
                                 dispatch_block_t block)
{
    snapyr_dispatch_specific(queue, block, NO);
}

void snapyr_dispatch_specific_sync(dispatch_queue_t queue,
                                dispatch_block_t block)
{
    snapyr_dispatch_specific(queue, block, YES);
}

NSDictionary *snapyrCoerceDictionary(NSDictionary *dict)
{
    // make sure that a new dictionary exists even if the input is null
    dict = dict ?: @{};
    // assert that the proper types are in the dictionary
    dict = [dict serializableDeepCopy];
    return dict;
}

NSString *snapyrEventNameForScreenTitle(NSString *title)
{
    return [[NSString alloc] initWithFormat:@"Viewed %@ Screen", title];
}

@implementation NSJSONSerialization(Serializable)
+ (BOOL)isOfSerializableType:(id)obj
{
    if ([obj conformsToProtocol:@protocol(SnapyrSerializable)])
        return YES;
    
    if ([obj isKindOfClass:[NSArray class]] ||
        [obj isKindOfClass:[NSDictionary class]] ||
        [obj isKindOfClass:[NSString class]] ||
        [obj isKindOfClass:[NSNumber class]] ||
        [obj isKindOfClass:[NSNull class]])
        return YES;
    return NO;
}
@end


@implementation NSDictionary(SerializableDeepCopy)

- (id)serializableDeepCopy:(BOOL)mutable
{
    NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithCapacity:self.count];
    NSArray *keys = [self allKeys];
    for (id key in keys) {
        id aValue = [self objectForKey:key];
        id theCopy = nil;
        
        if (![NSJSONSerialization isOfSerializableType:aValue]) {
            NSString *className = NSStringFromClass([aValue class]);
#ifdef DEBUG
            NSAssert(FALSE, @"key `%@` is a %@ and can't be serialized for delivery.", key, className);
#else
            SLog(@"key `%@` is a %@ and can't be serializaed for delivery.", key, className);
            // simply leave it out since we can't encode it anyway.
            continue;
#endif
        }
        
        if ([aValue conformsToProtocol:@protocol(SnapyrSerializableDeepCopy)]) {
            theCopy = [aValue serializableDeepCopy:mutable];
        } else if ([aValue conformsToProtocol:@protocol(SnapyrSerializable)]) {
            theCopy = [aValue serializeToAppropriateType];
        } else if ([aValue conformsToProtocol:@protocol(NSCopying)]) {
            theCopy = [aValue copy];
        } else {
            theCopy = aValue;
        }
        
        [result setValue:theCopy forKey:key];
    }
    
    if (mutable) {
        return result;
    } else {
        return [result copy];
    }
}

- (NSDictionary *)serializableDeepCopy {
    return [self serializableDeepCopy:NO];
}

- (NSMutableDictionary *)serializableMutableDeepCopy {
    return [self serializableDeepCopy:YES];
}

@end


@implementation NSArray(SerializableDeepCopy)

-(id)serializableDeepCopy:(BOOL)mutable
{
    NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:self.count];
    
    for (id aValue in self) {
        id theCopy = nil;
        
        if (![NSJSONSerialization isOfSerializableType:aValue]) {
            NSString *className = NSStringFromClass([aValue class]);
#ifdef DEBUG
            NSAssert(FALSE, @"found a %@ which can't be serialized for delivery.", className);
#else
            SLog(@"found a %@ which can't be serializaed for delivery.", className);
            // simply leave it out since we can't encode it anyway.
            continue;
#endif
        }

        if ([aValue conformsToProtocol:@protocol(SnapyrSerializableDeepCopy)]) {
            theCopy = [aValue serializableDeepCopy:mutable];
        } else if ([aValue conformsToProtocol:@protocol(SnapyrSerializable)]) {
            theCopy = [aValue serializeToAppropriateType];
        } else if ([aValue conformsToProtocol:@protocol(NSCopying)]) {
            theCopy = [aValue copy];
        } else {
            theCopy = aValue;
        }
        [result addObject:theCopy];
    }
    
    if (mutable) {
        return result;
    } else {
        return [result copy];
    }
}


- (NSArray *)serializableDeepCopy {
    return [self serializableDeepCopy:NO];
}

- (NSMutableArray *)serializableMutableDeepCopy {
    return [self serializableDeepCopy:YES];
}

@end
