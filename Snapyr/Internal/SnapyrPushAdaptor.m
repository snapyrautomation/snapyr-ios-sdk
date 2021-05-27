//
//  SnapyrPushAdaptor.m
//  Snapyr
//
//  Created by Brian O'Neill on 5/27/21.
//  Copyright © 2021 Snapyr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SnapyrPushAdaptor.h"
#import <UserNotifications/UserNotifications.h>

@implementation SnapyrPushAdaptor

- (void)configureCategories:(NSDictionary *_Nonnull)settings{
    
    UNNotificationCategory* generalCategory = [UNNotificationCategory
          categoryWithIdentifier:@"GENERAL"
          actions:@[]
          intentIdentifiers:@[]
          options:UNNotificationCategoryOptionCustomDismissAction];
    
    // Create the custom actions for expired timer notifications.
    UNNotificationAction* snoozeAction = [UNNotificationAction
          actionWithIdentifier:@"SNOOZE_ACTION"
          title:@"Snooze"
          options:UNNotificationActionOptionNone];
     
    UNNotificationAction* stopAction = [UNNotificationAction
          actionWithIdentifier:@"STOP_ACTION"
          title:@"Stop"
          options:UNNotificationActionOptionForeground];
     
    // Create the category with the custom actions.
    UNNotificationCategory* expiredCategory = [UNNotificationCategory
          categoryWithIdentifier:@"TIMER_EXPIRED"
          actions:@[snoozeAction, stopAction]
          intentIdentifiers:@[]
          options:UNNotificationCategoryOptionNone];
    
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center setNotificationCategories:[NSSet setWithObjects:generalCategory, expiredCategory, nil]];
    
}

@end
