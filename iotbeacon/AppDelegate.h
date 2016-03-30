//
//  AppDelegate.h
//  iotbeacon
//
//  Created by Vladimir on 24/12/15.
//  Copyright © 2015 BIS. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CLLocationManagerDelegate.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate, UIAlertViewDelegate, CLLocationManagerDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (retain, nonatomic) NSMutableArray *beacons;

- (void)reinitBeaconApi;

@end

