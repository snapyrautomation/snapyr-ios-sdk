#if !TARGET_OS_OSX && !TARGET_OS_TV

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import "SnapyrActionViewHandler.h"

NS_ASSUME_NONNULL_BEGIN

extern CGFloat const DEFAULT_MARGIN;

@interface SnapyrActionMessageView : UIView <WKNavigationDelegate, WKUIDelegate>

- (instancetype _Nonnull)initWithHTML:(NSString *)htmlPayload withMessageHandler:(id <WKScriptMessageHandler, SnapyrActionViewHandler>)scriptMessageHandler;
- (void)reportContentHeight:(NSNumber *)height;
- (void)doCleanup;

@end

NS_ASSUME_NONNULL_END

#endif
