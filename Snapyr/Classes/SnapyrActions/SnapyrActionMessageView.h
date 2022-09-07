#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SnapyrActionMessageView : UIView <WKNavigationDelegate>

- (instancetype _Nonnull)initWithHTML:(NSString *)htmlPayload withMessageHandler:(id <WKScriptMessageHandler>)scriptMessageHandler;
- (void)doCleanup;

@end

NS_ASSUME_NONNULL_END
