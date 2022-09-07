#import "SnapyrSDKUtils.h"
#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>


@interface SnapyrActionMessageView : UIView <WKNavigationDelegate, WKUIDelegate>

@property (strong, nonatomic, nonnull) NSString *htmlPayload;
@property (strong, nonatomic) WKWebView *wkWebView;

@end


@implementation SnapyrActionMessageView

- (instancetype _Nonnull)initWithHTML:(NSString *)htmlPayload withMessageHandler:(id <WKScriptMessageHandler>)messageHandler {
    if (self = [super init]) {
        self.translatesAutoresizingMaskIntoConstraints = false;
    
        self.htmlPayload = htmlPayload;
        
        WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
        [configuration.userContentController addScriptMessageHandler:messageHandler name:@"snapyrMessageHandler"];
        
        CGFloat defaultMargin = 20.0;
        // Full screen in-app modal: webview size is ~ screen size minus margins...
        CGRect bounds = UIScreen.mainScreen.bounds;
        bounds.size.width -= (2 * defaultMargin);
        bounds.size.height -= (2 * defaultMargin);
        
        if (@available(iOS 11.0, *)) {
            // ... minus safe area insets, if applicable (safe area accounts for notches and such)
            UIEdgeInsets safeAreaInsets = [UIApplication sharedApplication].keyWindow.safeAreaInsets;
            bounds.size.height -= (safeAreaInsets.top + safeAreaInsets.bottom);
            bounds.size.width  -= (safeAreaInsets.left + safeAreaInsets.right);
        }
        
        _wkWebView = [[WKWebView alloc] initWithFrame:bounds configuration:configuration];

        _wkWebView.UIDelegate = self;
        _wkWebView.navigationDelegate = self;
        _wkWebView.scrollView.scrollEnabled = false;
        
        _wkWebView.clipsToBounds = true;
        _wkWebView.layer.cornerRadius = 20;
        
        [self addSubview:_wkWebView];
        // Center the webview within this (container) view
        [_wkWebView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor].active = true;
        [_wkWebView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor].active = true;
        
        // Load the HTML
        NSURL *baseUrl = [NSURL URLWithString:@"https://snapyr.com"]; // dummy value but required for HTML string
        [_wkWebView loadHTMLString:[_htmlPayload copy] baseURL:baseUrl];
    }
    
    return self;
}

- (void)doCleanup {
    // NB userContentController holds strong ref to script message handlers. We MUST call removeScriptMessageHandlerForName
    // or controller will never be released, causing memory leaks
    [_wkWebView.configuration.userContentController removeScriptMessageHandlerForName:@"snapyrMessageHandler"];
    _wkWebView = nil;
}

@end