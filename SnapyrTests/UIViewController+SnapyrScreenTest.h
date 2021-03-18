//
//  UIViewController+SegScreenTest.h
//  Analytics
//
//  Created by David Whetstone on 7/15/19.
//  Copyright © 2019 Segment. All rights reserved.
//

#ifndef UIViewController_SegScreenTest_h
#define UIViewController_SegScreenTest_h

#if !TARGET_OS_OSX
@interface UIViewController (SnapyrScreenTest)
/// We need to expose this normally private method to tests, as the public facing
/// `+ (UIViewController *)snapyr_topViewController` relies on the `application` property
/// of `SnapyrSDKConfiguration`, which won't be set in these tests.
+ (UIViewController *)snapyr_topViewController:(UIViewController *)rootViewController;
@end
#endif


#endif /* UIViewController_SegScreenTest_h */
