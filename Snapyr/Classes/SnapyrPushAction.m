//
//  SnapyrPushAction.m
//  Snapyr
//
//  Created by Brian O'Neill on 5/27/21.
//  Copyright © 2021 Snapyr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SnapyrPushAction.h"

@implementation SnapyrPushAction

- (id)initWithTitle:(NSString *)title actionId:(NSString *)actionId
{
    self.title = title;
    self.actionId = actionId;
    return self;
}

@end
