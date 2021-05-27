//
//  SnapyrPushAdaptor.m
//  Snapyr
//
//  Created by Brian O'Neill on 5/27/21.
//  Copyright © 2021 Snapyr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SnapyrPushAdaptor.h"

@implementation SnapyrPushAdaptor

- (void)configureCategories:(NSDictionary *_Nonnull)settings withNotificationCenter:(UNUserNotificationCenter *_Nonnull)notificationCenter
{
    
    UNNotificationCategory* generalCategory = [UNNotificationCategory
          categoryWithIdentifier:@"GENERAL"
          actions:@[]
          intentIdentifiers:@[]
          options:UNNotificationCategoryOptionCustomDismissAction];
    
    // Create the custom actions for expired timer notifications.
    UNNotificationAction* snoozeAction = [UNNotificationAction
          actionWithIdentifier:@"SNOOZE_ACTION"
          title:@"It"
          options:UNNotificationActionOptionNone];
     
    UNNotificationAction* stopAction = [UNNotificationAction
          actionWithIdentifier:@"STOP_ACTION"
          title:@"Worked"
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
