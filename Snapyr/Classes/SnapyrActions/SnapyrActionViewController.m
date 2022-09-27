#import <TargetConditionals.h>
#if !TARGET_OS_OSX && !TARGET_OS_TV

#import <Foundation/Foundation.h>
#import "SnapyrActionViewController.h"
#import "SnapyrActionMessageView.h"
#import "SnapyrUtils.h"
#import <UIKit/UIKit.h>


@implementation SnapyrActionViewController

- (instancetype)initWithHtml:(NSString *)htmlPayload
{
    if (self = [super init]) {
        NSLog(@"Controller INIT!!!");
        _htmlPayload = htmlPayload;
    }
    [self.view setNeedsLayout];
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)showHtmlMessage
{
    _msgView = [[SnapyrActionMessageView alloc] initWithHTML:_htmlPayload withMessageHandler:self];
    [self.view addSubview:_msgView];
    // Center the modal both horizontally and vertically
    [_msgView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor].active = YES;
    [_msgView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor].active = YES;

    // Create new window with size set to match that of the device screen
    _uiWindow = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Place it in front
    _uiWindow.windowLevel = UIWindowLevelAlert;
    // 50% transparent black - shadow background
    _uiWindow.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];

    // Setting self to be window's rootViewController is what attaches our views to the window
    _uiWindow.rootViewController = self;
    
    UIApplication *sharedApp = getSharedUIApplication();
    if (@available(iOS 13.0, *)) {
        if (sharedApp != nil) {
            // scene is required in iOS 13+ - without it, the window won't display with `makeKeyAndVisible`
            _uiWindow.windowScene = sharedApp.keyWindow.windowScene;
        }
    }
    // Window not yet displayed at this point - that will happen when `finishDisplayingWebView` is called
    
    

    
    
    [self addCloseButton];
}

- (void)finishDisplayingWebViewWithHeight:(NSNumber *)height
{
    if (height) {
        [_msgView reportContentHeight:height];
    }
    [_uiWindow makeKeyAndVisible];
}

- (void)handleClickWithPayload:(NSDictionary *)payload
{
    if (self.actionHandler != nil) {
        self.actionHandler(payload);
    }
}

- (void)userContentController:(nonnull WKUserContentController *)userContentController didReceiveScriptMessage:(nonnull WKScriptMessage *)message
{
    NSDictionary *decodedMsg;
    
    if ([message.body isKindOfClass:[NSDictionary class]]) {{
        decodedMsg = message.body;
    }} else if ([message.body isKindOfClass:[NSData class]]) {
        NSError *error;
        decodedMsg = [NSJSONSerialization
                                    JSONObjectWithData:message.body
                                    options:kNilOptions
                                    error:&error];
        if (error) {
            DLog(@"SnapyrActionViewController.didReceiveScriptMessage: error serializing to json: %@", error);
            return;
        }
    } else {
        DLog(@"SnapyrActionViewController.didReceiveScriptMessage: unexpected message type: %@", [message.body class]);
        return;
    }
    
    if ([decodedMsg[@"type"] isEqual: @"log"]) {
        DLog(@"SnapyrActionViewController JS %@: %@", decodedMsg[@"level"], decodedMsg[@"message"]);
    } else if ([decodedMsg[@"type"] isEqual: @"close"]) {
        DLog(@"SnapyrActionViewController.didReceiveScriptMessage: Closing...");
        [self handleDismiss];
    } else if ([decodedMsg[@"type"] isEqual:@"loaded"]) {
        [self finishDisplayingWebViewWithHeight:decodedMsg[@"height"]];
    } else if ([decodedMsg[@"type"] isEqual:@"click"]) {
        [self handleClickWithPayload:decodedMsg];
    } else {
        DLog(@"SnapyrActionViewController.didReceiveScriptMessage: Other message type: %@", decodedMsg);
    }
    
}

- (void)addCloseButton
{
    CGFloat buttonSize = 32;
    
    UIButton *_button = [UIButton buttonWithType:UIButtonTypeCustom];
    [_button setTitle:@"×" forState:UIControlStateNormal];
    
    // We'll be setting our own constraints later, disable auto ones as they make the button look wrong
    _button.translatesAutoresizingMaskIntoConstraints = NO;
    // Trigger close when button is tapped
    [_button addTarget:self action:@selector(handleDismiss) forControlEvents:UIControlEventTouchUpInside];

    // Make the button round and nice looking
    [_button.layer setCornerRadius:(buttonSize / 2)];
    [_button.layer setShadowColor:[[UIColor blackColor] CGColor]];
    [_button.layer setShadowRadius:5];
    [_button.layer setShadowOpacity:0.5];
    [_button.layer setBorderColor:[[UIColor colorWithWhite:0.0 alpha:0.25] CGColor]];
    [_button.layer setBorderWidth:1];

    [_button setBackgroundColor:[UIColor blackColor]];
    [_button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    
    // Add it to the actual view so it renders. NB we add the button to the outer controller view, rather than to _msgView,
    // to ensure that taps on the outer edge of the button aren't clipped
    [self.view addSubview:_button];
    
    // NB constraints relative to another view (in this case, _msgView) can only be applied after
    // connecting the button to that view. i.e. be sure to add these AFTER adding button as subview

    // Center the button around the left corner of the message view - it will partly overlap and partly overflow the message
    [_button.centerYAnchor constraintEqualToAnchor:_msgView.topAnchor].active = YES;
    [_button.centerXAnchor constraintEqualToAnchor:_msgView.leftAnchor].active = YES;
    // Enforce button size to keep it round
    [_button.widthAnchor constraintEqualToConstant:buttonSize].active = YES;
    [_button.heightAnchor constraintEqualToConstant:buttonSize].active = YES;
}

- (void)viewWillDisappear:(BOOL)animated
{
    // Ensure view teardown and free happens
    [_msgView doCleanup];
    [_msgView removeFromSuperview];
    _msgView = nil;
}

- (void)handleDismiss
{
    [self dismissViewControllerAnimated:false completion:^{
        // Hide the window, then remove refs to ensure controller/view memory gets freed up
        [self.uiWindow setHidden:true];
        self.uiWindow.rootViewController = nil;
        self.uiWindow = nil;
    }];
}

@end

#endif
