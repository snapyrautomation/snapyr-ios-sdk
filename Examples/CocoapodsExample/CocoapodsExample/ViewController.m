//
//  ViewController.m
//  CocoapodsExample
//
//  Created by Tony Xiao on 11/28/16.
//  Copyright © 2016 Segment. All rights reserved.
//

#import <Snapyr/SnapyrAnalytics.h>
#import "ViewController.h"


@interface ViewController ()

@end


@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    NSUserActivity *userActivity = [[NSUserActivity alloc] initWithActivityType:NSUserActivityTypeBrowsingWeb];
    userActivity.webpageURL = [NSURL URLWithString:@"http://www.segment.com"];
    [[SnapyrAnalytics sharedAnalytics] continueUserActivity:userActivity];
    [[SnapyrAnalytics sharedAnalytics] track:@"test"];
    [[SnapyrAnalytics sharedAnalytics] flush];
}

- (IBAction)fireEvent:(id)sender
{
    [[SnapyrAnalytics sharedAnalytics] track:@"Cocoapods Example Button"];
    [[SnapyrAnalytics sharedAnalytics] flush];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
