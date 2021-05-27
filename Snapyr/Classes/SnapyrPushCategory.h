//
//  SnapyrPushCategory.h
//  Snapyr
//
//  Created by Brian O'Neill on 5/27/21.
//  Copyright © 2021 Snapyr. All rights reserved.
//
@import Foundation;

#ifndef SnapyrPushCategory_h
#define SnapyrPushCategory_h

NS_SWIFT_NAME(PushAction)
@interface SnapyrPushCategory : NSObject

@property (nonatomic, strong) NSString *categoryId;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSArray *actions;

- (id)initWithName:(NSString *)name categoryId:(NSString *)categoryId actions:(NSArray *)actions;

@end

#endif /* SnapyrPushCategory_h */
