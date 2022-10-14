#if !TARGET_OS_OSX && !TARGET_OS_TV

#import <Foundation/Foundation.h>
#import "SnapyrSDK.h"
#import "SnapyrSDKConfiguration.h"
#import "SnapyrActionMessageView.h"

NS_ASSUME_NONNULL_BEGIN

@interface SnapyrActionViewController : UIViewController <WKScriptMessageHandler, SnapyrActionViewHandler>

@property (strong, nonatomic, nonnull) SnapyrInAppMessage *message;
@property (strong, atomic, nullable) SnapyrActionMessageView *msgView;
@property (strong, atomic, nullable) UIWindow *uiWindow;
@property (nonatomic, strong, nullable) SnapyrActionHandlerBlock actionHandler;

- (instancetype)initWithSDK:(SnapyrSDK *)sdk withMessage:(SnapyrInAppMessage *)message;
- (void)showHtmlMessage;
- (void)onWebViewDidFinishNavigation;

@end

NS_ASSUME_NONNULL_END

#endif
