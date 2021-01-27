//
//  SnapyrFileStorage.h
//  Analytics
//
//  Copyright © 2016 Segment. All rights reserved.
//

@import Foundation;
#import "SnapyrStorage.h"


NS_SWIFT_NAME(FileStorage)
@interface SnapyrFileStorage : NSObject <SnapyrStorage>

@property (nonatomic, strong, nullable) id<SnapyrCrypto> crypto;

- (instancetype _Nonnull)initWithFolder:(NSURL *_Nonnull)folderURL crypto:(id<SnapyrCrypto> _Nullable)crypto;

- (NSURL *_Nonnull)urlForKey:(NSString *_Nonnull)key;

+ (NSURL *_Nullable)applicationSupportDirectoryURL;
+ (NSURL *_Nullable)cachesDirectoryURL;

@end
