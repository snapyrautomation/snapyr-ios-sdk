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

- (NSSet<UNNotificationCategory*> *_Nonnull)configureCategories:(NSDictionary *_Nonnull)settings
     withNotificationCenter:(UNUserNotificationCenter *_Nullable)notificationCenter{
    
    NSMutableSet<UNNotificationCategory*> *apnCategories = [NSMutableSet new];
    NSArray *pushCategories =[settings valueForKeyPath:@"pushCategories"];
    if (pushCategories != nil) {
        for (NSDictionary* category in pushCategories) {
            NSMutableArray<UNNotificationAction*> *actions = [NSMutableArray new];
            // NSString *categoryId =[category valueForKeyPath:@"id"];
            NSString *categoryName =[category valueForKeyPath:@"category"];
            NSArray *pushActions = [category valueForKeyPath:@"actions"];
            
            NSMutableArray *apnActions = [NSMutableArray new];
            for (NSDictionary* action in pushActions) {
                // NSString *actionId =[action valueForKeyPath:@"actionId"];
                NSString *title =[action valueForKeyPath:@"title"];
                UNNotificationAction* apnAction = [UNNotificationAction
                                                   actionWithIdentifier:title
                                                   title:title
                                                   options:UNNotificationActionOptionNone];
                [apnActions addObject:apnAction];
            }
            UNNotificationCategory* apnCategory = [UNNotificationCategory
                                                   categoryWithIdentifier:categoryName
                                                   actions:apnActions
                                                   intentIdentifiers:@[]
                                                   options:UNNotificationCategoryOptionNone];
            [apnCategories addObject:apnCategory];
        }
        [notificationCenter setNotificationCategories:apnCategories];
    }
    return apnCategories;
}
@end


// --------------------------------------------------------------------------------------------------------------
// R.I.P.
// --------------------------------------------------------------------------------------------------------------
//
//NSMutableArray *snapyrCategories = [NSMutableArray new];
//NSDictionary *metadata =[settings valueForKeyPath:@"metadata"];
//if (metadata != nil) {
//    NSArray *pushCategories =[metadata valueForKeyPath:@"pushCategories"];
//    if (pushCategories != nil) {
//        for (NSDictionary* category in pushCategories) {
//            NSString *categoryId =[category valueForKeyPath:@"id"];
//            NSString *categoryName =[category valueForKeyPath:@"category"];
//            NSArray *pushActions = [category valueForKeyPath:@"actions"];
//            NSMutableArray *snapyrActions = [NSMutableArray new];
//            for (NSDictionary* action in pushActions) {
//                NSString *actionId =[action valueForKeyPath:@"actionId"];
//                NSString *title =[action valueForKeyPath:@"title"];
//                SnapyrPushAction* snapyrAction = [[SnapyrPushAction alloc] initWithTitle:title actionId:actionId];
//                [snapyrActions addObject:snapyrAction];
//            }
//            SnapyrPushCategory *snapyrCategory = [[SnapyrPushCategory alloc] initWithName:categoryName categoryId:categoryName actions:snapyrActions];
//            [snapyrCategories addObject:snapyrCategory];
//        }
//    }
//}
//return snapyrCategories;


//NSMutableSet *apnCategories = [NSMutableSet new];
//for (SnapyrPushCategory* category in categories) {
//    NSMutableArray *actions = [NSMutableArray new];
//    for (SnapyrPushAction* action in category.actions){
//        UNNotificationAction* apnAction = [UNNotificationAction
//                                           actionWithIdentifier:action.title
//                                           title:action.title
//                                           options:UNNotificationActionOptionNone];
//        [actions addObject:apnAction];
//    }
//    UNNotificationCategory* apnCategory = [UNNotificationCategory
//                                        categoryWithIdentifier:category.name
//                                        actions:actions
//                                        intentIdentifiers:@[]
//                                        options:UNNotificationCategoryOptionNone];
//    [apnCategories addObject:apnCategory];
//
//}
//[notificationCenter setNotificationCategories:apnCategories];


//    UNNotificationCategory* generalCategory = [UNNotificationCategory
//                                               categoryWithIdentifier:@"GENERAL"
//                                               actions:@[]
//                                               intentIdentifiers:@[]
//                                               options:UNNotificationCategoryOptionCustomDismissAction];
//
//    // Create the custom actions for expired timer notifications.
//    UNNotificationAction* snoozeAction = [UNNotificationAction
//                                          actionWithIdentifier:@"SNOOZE_ACTION"
//                                          title:@"It"
//                                          options:UNNotificationActionOptionNone];
//
//    UNNotificationAction* stopAction = [UNNotificationAction
//                                        actionWithIdentifier:@"STOP_ACTION"
//                                        title:@"Worked"
//                                        options:UNNotificationActionOptionForeground];
//
//    // Create the category with the custom actions.
//    UNNotificationCategory* expiredCategory = [UNNotificationCategory
//                                               categoryWithIdentifier:@"buttons_galore"
//                                               actions:@[snoozeAction, stopAction]
//                                               intentIdentifiers:@[]
//                                               options:UNNotificationCategoryOptionNone];
//
//    [notificationCenter setNotificationCategories:[NSSet setWithObjects:generalCategory, expiredCategory, nil]];

