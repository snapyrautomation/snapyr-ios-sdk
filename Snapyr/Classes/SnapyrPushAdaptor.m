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
                NSString *categoryName =[category valueForKeyPath:@"category"];
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


- (void)configureCategories:(NSArray *_Nonnull)categories
     withNotificationCenter:(UNUserNotificationCenter *_Nullable)notificationCenter{
    NSMutableArray *apnCategories = [NSMutableArray new];
    for (SnapyrPushCategory* category in categories) {
        NSMutableArray *actions = [NSMutableArray new];
        for (SnapyrPushAction* action in category.actions){
            UNNotificationAction* apnAction = [UNNotificationAction
                                               actionWithIdentifier:action.actionId
                                               title:action.title
                                               options:UNNotificationActionOptionNone];
            [actions addObject:apnAction];
        }
        UNNotificationCategory* apnCategory = [UNNotificationCategory
                                            categoryWithIdentifier:category.categoryId
                                            actions:actions
                                            intentIdentifiers:@[]
                                            options:UNNotificationCategoryOptionNone];
        [apnCategories addObject:apnCategory];

    }
    [notificationCenter setNotificationCategories:[NSSet setWithObjects:apnCategories, nil]];
}

@end
