#import "SnapyrProxyImplementations.h"

#ifndef SnapyrMockProxyImplementations_h
#define SnapyrMockProxyImplementations_h

NS_SWIFT_NAME(MockProxyImplementations)
@interface SnapyrMockProxyImplementations : SnapyrProxyImplementations
@property (strong, nonatomic) void (^didRegisteredForAPNS)(void);
@property (strong, nonatomic) void (^continueUserActivity)(void);
@property (strong, nonatomic) void (^didFailToRegisterForAPNS)(void);
@property (strong, nonatomic) void (^openURL)(void);
@end

#endif /* SnapyrMockProxyImplementations_h */
