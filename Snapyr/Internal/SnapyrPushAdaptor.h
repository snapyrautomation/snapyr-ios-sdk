//
//  SnapyrPushAdaptor.h
//  Snapyr
//
//  Created by Brian O'Neill on 5/27/21.
//  Copyright © 2021 Snapyr. All rights reserved.
//

@import Foundation;
#import "SnapyrPushAdaptor.h"

#ifndef SnapyrPushAdaptor_h
#define SnapyrPushAdaptor_h

NS_SWIFT_NAME(FileStorage)
@interface SnapyrPushAdaptor : NSObject

- (void)configureCategories:(NSDictionary *_Nonnull)settings;

@end

#endif /* SnapyrPushAdaptor_h */
