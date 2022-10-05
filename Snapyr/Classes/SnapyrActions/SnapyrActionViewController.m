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

- (void)showHtmlMessage
{
    _msgView = [[SnapyrActionMessageView alloc] initWithHTML:_htmlPayload withMessageHandler:self];
    self.view.alpha = 0;
    [self.view addSubview:_msgView];
    // Center the modal both horizontally and vertically
    [_msgView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor].active = YES;
    [_msgView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor].active = YES;

    // Create new window with size set to match that of the device screen
    _uiWindow = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    _uiWindow.alpha = 0;
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

- (void)onWebViewDidFinishNavigation
{
    [self finishDisplayingWebViewIfReady];
}

- (void)onJsLoadedEvent:(NSNumber *)height
{
    if (height) {
        [_msgView reportContentHeight:height];
    }
}

- (void)finishDisplayingWebViewIfReady
{
    [self.view layoutIfNeeded];
    self.uiWindow.alpha = 1.0;
    [_uiWindow makeKeyAndVisible];
    self.view.transform = CGAffineTransformMakeScale(0.7, 0.7);
    [UIView animateWithDuration:0.3f animations:^{
        self.view.transform = CGAffineTransformMakeScale(1.0, 1.0);
        self.view.alpha = 1.0;
        [self.view layoutIfNeeded];
    }];
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
        [self onJsLoadedEvent:decodedMsg[@"height"]];
    } else if ([decodedMsg[@"type"] isEqual:@"click"]) {
        [self handleClickWithPayload:decodedMsg];
    } else {
        DLog(@"SnapyrActionViewController.didReceiveScriptMessage: Other message type: %@", decodedMsg);
    }
    
}

- (void)addCloseButton
{
    CGFloat buttonSize = DEFAULT_MARGIN * 1.8;
    
    UIButton *_closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    // Note for future updates: `overlay_close` image is stored in the Asset Catalog, `Media.xcassets` - open this in the top level of this Xcode project. To change, must update the item in the Asset Catalog. It needs to be a PDF - you can use an SVG to PDF converter (this worked the first time: https://cloudconvert.com/svg-to-pdf). After adding to Asset Catalog, rename to `overlay_close` (or change name below), select the image and open the Attributes Inspector. Check `Resizing -> Preserve Vector Data`, and select `Single Scale` under `Scales`. Leave other settings at defaults.
    
    // NB by default iOS will look for the image in the customer app's bundle, even though this code is running from within our SDK framework. The following line gets the bundle for the SDK framework so it can find the included assets.
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    UIImage *buttonImg = [UIImage imageNamed:@"overlay_close" inBundle:bundle compatibleWithTraitCollection:nil];
    if (buttonImg != nil) {
        CGFloat scaleFactor = buttonSize / buttonImg.size.width;
        [_closeButton setImage:buttonImg forState:UIControlStateNormal];
        _closeButton.imageEdgeInsets = UIEdgeInsetsMake(buttonSize, buttonSize, buttonSize, buttonSize);
    } else {
        // Shouldn't happen, but fall back to basic text-based button if image couldn't be loaded
        [_closeButton setTitle:@"×" forState:UIControlStateNormal];
        // Make the button round and nice looking
        [_closeButton.layer setCornerRadius:(buttonSize / 2)];
        [_closeButton.layer setBorderColor:[[UIColor whiteColor] CGColor]];
        [_closeButton.layer setBorderWidth:buttonSize * 0.1];

        [_closeButton setBackgroundColor:[UIColor blackColor]];
        [_closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _closeButton.titleLabel.font = [UIFont boldSystemFontOfSize:buttonSize * 0.8];
    }
    
    // We'll be setting our own constraints later, disable auto ones as they make the button look wrong
    _closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    // Trigger close when button is tapped
    [_closeButton addTarget:self action:@selector(handleDismiss) forControlEvents:UIControlEventTouchUpInside];
    
    // Add it to the actual view so it renders. NB we add the button to the outer controller view, rather than to _msgView,
    // to ensure that taps on the outer edge of the button aren't clipped
    [self.view addSubview:_closeButton];
    
    // NB constraints relative to another view (in this case, _msgView) can only be applied after
    // connecting the button to that view. i.e. be sure to add these AFTER adding button as subview

    // Center the button around the right corner of the message view - it will partly overlap and partly overflow the message
    [_closeButton.centerYAnchor constraintEqualToAnchor:_msgView.topAnchor].active = YES;
    [_closeButton.centerXAnchor constraintEqualToAnchor:_msgView.rightAnchor].active = YES;
    // Enforce button size to keep it round
    [_closeButton.widthAnchor constraintEqualToConstant:buttonSize].active = YES;
    [_closeButton.heightAnchor constraintEqualToConstant:buttonSize].active = YES;
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
