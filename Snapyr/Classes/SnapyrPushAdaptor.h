//
//  SnapyrPushAdaptor.h
//  Snapyr
//
//  Created by Brian O'Neill on 5/27/21.
//  Copyright © 2021 Snapyr. All rights reserved.
//

@import Foundation;
#import "SnapyrPushAdaptor.h"
#import <UserNotifications/UserNotifications.h>

#ifndef SnapyrPushAdaptor_h
#define SnapyrPushAdaptor_h

NS_SWIFT_NAME(PushAdaptor)
@interface SnapyrPushAdaptor : NSObject

- (NSSet<UNNotificationCategory*> *_Nonnull)configureCategories:(NSDictionary *_Nonnull)settings
     withNotificationCenter:(UNUserNotificationCenter *_Nullable)notificationCenter;

@end

#endif /* SnapyrPushAdaptor_h */
