#import <TargetConditionals.h>
#if !TARGET_OS_OSX && !TARGET_OS_TV

#import "SnapyrUtils.h"
#import "SnapyrActionViewHandler.h"
#import "SnapyrActionMessageView.h"
#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

CGFloat const DEFAULT_MARGIN = 20.0;

@interface SnapyrActionMessageView ()

@property (strong, nonatomic, nonnull) NSString *htmlPayload;
@property (strong, nonatomic) WKWebView *wkWebView;
@property (weak) id <SnapyrActionViewHandler> snapyrVC;

@end


@implementation SnapyrActionMessageView

- (instancetype _Nonnull)initWithHTML:(NSString *)htmlPayload withMessageHandler:(id <WKScriptMessageHandler, SnapyrActionViewHandler>)messageHandler {
    if (self = [super init]) {
        self.translatesAutoresizingMaskIntoConstraints = false;
    
        self.htmlPayload = htmlPayload;
        self.snapyrVC = messageHandler;
        
        WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
        [configuration.userContentController addScriptMessageHandler:messageHandler name:@"snapyrMessageHandler"];
        
        CGRect bounds = [self getStartingBounds];
        
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

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    [_snapyrVC onWebViewDidFinishNavigation];
}

- (CGRect)getStartingBounds {
    // Full screen in-app modal: webview size is ~ screen size minus margins...
    CGRect bounds = [UIScreen mainScreen].bounds;
    bounds.size.width -= (2 * DEFAULT_MARGIN);
    bounds.size.height -= (2 * DEFAULT_MARGIN);
    
    if (@available(iOS 11.0, *)) {
        UIApplication *sharedApp = getSharedUIApplication();
        if (sharedApp != nil) {
            // ... minus safe area insets, if applicable (safe area accounts for notches and such)
            UIEdgeInsets safeAreaInsets = sharedApp.keyWindow.safeAreaInsets;
            bounds.size.height -= (safeAreaInsets.top + safeAreaInsets.bottom);
            bounds.size.width  -= (safeAreaInsets.left + safeAreaInsets.right);
        }
    }
    return bounds;
}

- (void)reportContentHeight:(NSNumber *)height {
    float scaledHeight = [height floatValue] / [UIScreen mainScreen].scale;
    CGRect bounds = _wkWebView.bounds;
    bounds.size.height = scaledHeight + 8;
    CGRect maximumBounds = [self getStartingBounds];
    if (bounds.size.height > maximumBounds.size.height) {
        return;
    }
    
    [_wkWebView setFrame:bounds];
}

- (void)doCleanup {
    // NB userContentController holds strong ref to script message handlers. We MUST call removeScriptMessageHandlerForName
    // or controller will never be released, causing memory leaks
    [_wkWebView.configuration.userContentController removeScriptMessageHandlerForName:@"snapyrMessageHandler"];
    _wkWebView = nil;
}

@end

#endif
