//
//  SnapyrPushAction.h
//  Snapyr
//
//  Created by Brian O'Neill on 5/27/21.
//  Copyright © 2021 Snapyr. All rights reserved.
//
@import Foundation;

#ifndef SnapyrPushAction_h
#define SnapyrPushAction_h

NS_SWIFT_NAME(PushAction)
@interface SnapyrPushAction : NSObject

@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *actionId;

- (id)initWithTitle:(NSString *)title actionId:(NSString *)actionId;

@end

#endif /* SnapyrPushAction_h */
