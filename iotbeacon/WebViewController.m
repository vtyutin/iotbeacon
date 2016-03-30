//
//  WebViewController.m
//  iotbeacon
//
//  Created by Vladimir on 14/01/16.
//  Copyright © 2016 BIS. All rights reserved.
//

#import "WebViewController.h"

@implementation WebViewController
@synthesize url;

-(void)viewDidLoad {
    [super viewDidLoad];
    NSURL *nsurl = [NSURL URLWithString:url];
    NSURLRequest *requestObj = [NSURLRequest requestWithURL:nsurl];
    [((UIWebView*)self.view) setScalesPageToFit:YES];
    [((UIWebView*)self.view) loadRequest:requestObj];
    
}

@end
