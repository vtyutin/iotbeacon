//
//  DismissSegue.m
//  iotbeacon
//
//  Created by Vladimir on 18/01/16.
//  Copyright © 2016 BIS. All rights reserved.
//

#import "DismissSegue.h"

@implementation DismissSegue

- (void)perform {
    UIViewController *sourceViewController = self.sourceViewController;
    [sourceViewController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

@end
