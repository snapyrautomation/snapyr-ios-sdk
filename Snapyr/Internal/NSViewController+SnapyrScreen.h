//
//  NSViewController+SEGScreen.h
//  Analytics
//
//  Created by Cody Garvin on 7/8/20.
//  Copyright © 2020 Segment. All rights reserved.
//

#import "SnapyrSerializableValue.h"

#if TARGET_OS_OSX
@import Cocoa;

@interface NSViewController (SnapyrScreen)

+ (void)snapyr_swizzleViewDidAppear;
+ (NSViewController *)snapyr_rootViewControllerFromView:(NSView *)view;

@end

#endif
