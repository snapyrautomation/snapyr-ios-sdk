//
//  SnapyrPushAdaptor.m
//  Snapyr
//
//  Created by Brian O'Neill on 5/27/21.
//  Copyright © 2021 Snapyr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SnapyrPushAdaptor.h"
#import "SnapyrPushAction.h"
#import "SnapyrPushCategory.h"


@implementation SnapyrPushAdaptor

- (void)configureNotificationsFromSettings:(NSDictionary *_Nonnull)settings withNotificationCenter:(UNUserNotificationCenter *_Nullable)notificationCenter{
    NSArray* categories = [self parseCategories:settings];
    [self configureCategories:categories withNotificationCenter:notificationCenter];
}

- (NSArray*)parseCategories:(NSDictionary *_Nonnull)settings
{
    NSMutableArray *snapyrCategories = [NSMutableArray new];
    NSDictionary *metadata =[settings valueForKeyPath:@"metadata"];
    if (metadata != nil) {
        NSArray *pushCategories =[metadata valueForKeyPath:@"pushCategories"];
        if (pushCategories != nil) {
            for (NSDictionary* category in pushCategories) {
                NSString *categoryId =[category valueForKeyPath:@"id"];
                NSLog(@"category.id = [%@]", categoryId);
                NSString *categoryName =[category valueForKeyPath:@"category"];
                NSLog(@"categor.name = [%@]", categoryName);
                
                NSArray *pushActions = [category valueForKeyPath:@"actions"];
                NSMutableArray *snapyrActions = [NSMutableArray new];
                for (NSDictionary* action in pushActions) {
                    NSString *actionId =[action valueForKeyPath:@"actionId"];
                    NSString *title =[action valueForKeyPath:@"title"];
                    SnapyrPushAction* snapyrAction = [[SnapyrPushAction alloc] initWithTitle:title actionId:actionId];
                    [snapyrActions addObject:snapyrAction];
                }
                SnapyrPushCategory *snapyrCategory = [[SnapyrPushCategory alloc] initWithName:categoryName categoryId:categoryId actions:snapyrActions];
                [snapyrCategories addObject:snapyrCategory];
            }
        }
    }
    return snapyrCategories;
}


- (void)configureCategories:(NSArray *_Nonnull)categories withNotificationCenter:(UNUserNotificationCenter *_Nullable)notificationCenter{
    //
    //    for (SnapyrPushCategory* category in pushCategories) {
    //        NSMutableArray *actions = [NSMutableArray alloc];
    //        for (SnapyrPushAction* action in category.actions){
    //
    //        }
    //    }
    //
    //
    //        UNNotificationCategory* generalCategory = [UNNotificationCategory
    //              categoryWithIdentifier:@"GENERAL"
    //              actions:@[]
    //              intentIdentifiers:@[]
    //              options:UNNotificationCategoryOptionCustomDismissAction];
    //
    //        // Create the custom actions for expired timer notifications.
    //        UNNotificationAction* snoozeAction = [UNNotificationAction
    //              actionWithIdentifier:@"SNOOZE_ACTION"
    //              title:@"It"
    //              options:UNNotificationActionOptionNone];
    //
    //        UNNotificationAction* stopAction = [UNNotificationAction
    //              actionWithIdentifier:@"STOP_ACTION"
    //              title:@"Worked"
    //              options:UNNotificationActionOptionForeground];
    //
    //        // Create the category with the custom actions.
    //        UNNotificationCategory* expiredCategory = [UNNotificationCategory
    //              categoryWithIdentifier:@"TIMER_EXPIRED"
    //              actions:@[snoozeAction, stopAction]
    //              intentIdentifiers:@[]
    //              options:UNNotificationCategoryOptionNone];
    //
    //        UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    //        [center setNotificationCategories:[NSSet setWithObjects:generalCategory, expiredCategory, nil]];
    
}

@end
