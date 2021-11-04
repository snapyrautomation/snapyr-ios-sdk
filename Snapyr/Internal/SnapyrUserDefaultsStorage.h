//
//  SnapyrUserDefaultsStorage.h
//  Analytics
//
//  Created by Tony Xiao on 8/24/16.
//  Copyright © 2016 Segment. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SnapyrStorage.h"


NS_SWIFT_NAME(UserDefaultsStorage)
@interface SnapyrUserDefaultsStorage : NSObject <SnapyrStorage>

@property (nonatomic, strong, nullable) id<SnapyrCrypto> crypto;
@property (nonnull, nonatomic, readonly) NSUserDefaults *defaults;
@property (nullable, nonatomic, readonly) NSString *namespacePrefix;

- (instancetype _Nonnull)initWithDefaults:(NSUserDefaults *_Nonnull)defaults namespacePrefix:(NSString *_Nullable)namespacePrefix crypto:(id<SnapyrCrypto> _Nullable)crypto;

@end
