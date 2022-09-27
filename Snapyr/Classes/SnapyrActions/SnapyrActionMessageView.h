#if !TARGET_OS_OSX && !TARGET_OS_TV

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SnapyrActionMessageView : UIView <WKNavigationDelegate>

- (instancetype _Nonnull)initWithHTML:(NSString *)htmlPayload withMessageHandler:(id <WKScriptMessageHandler>)scriptMessageHandler;
- (void)reportContentHeight:(NSNumber *)height;
- (void)doCleanup;

@end

NS_ASSUME_NONNULL_END

#endif
