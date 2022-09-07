#if !TARGET_OS_OSX && !TARGET_OS_TV

#import <Foundation/Foundation.h>
#import "SnapyrSDKConfiguration.h"
#import "SnapyrActionMessageView.h"

NS_ASSUME_NONNULL_BEGIN

@interface SnapyrActionViewController : UIViewController <WKScriptMessageHandler>

@property (strong, nonatomic, nonnull) NSString *htmlPayload;
@property (strong, atomic, nullable) SnapyrActionMessageView *msgView;
@property (strong, atomic, nullable) UIWindow *uiWindow;
@property (nonatomic, strong, nullable) SnapyrActionHandlerBlock actionHandler;

- (instancetype)initWithHtml:(NSString *)htmlPayload;
- (void)showHtmlMessage;

@end

NS_ASSUME_NONNULL_END

#endif
