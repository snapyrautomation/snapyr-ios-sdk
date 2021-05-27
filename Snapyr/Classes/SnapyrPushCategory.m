//
//  SnapyrPushCategory.m
//  Snapyr
//
//  Created by Brian O'Neill on 5/27/21.
//  Copyright © 2021 Snapyr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SnapyrPushCategory.h"

@implementation SnapyrPushCategory

- (id)initWithName:(NSString *)name categoryId:(NSString *)categoryId actions:(NSArray *)actions;
{
    self.name = name;
    self.categoryId = categoryId;
    self.actions = actions;
    return self;
}

@end
