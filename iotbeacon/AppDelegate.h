//
//  AppDelegate.h
//  iotbeacon
//
//  Created by Vladimir on 24/12/15.
//  Copyright © 2015 BIS. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CLLocationManagerDelegate.h>
#import <Google/CloudMessaging.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate, UIAlertViewDelegate, CLLocationManagerDelegate, GCMReceiverDelegate, GGLInstanceIDDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (retain, nonatomic) NSMutableArray *beacons;
@property (strong, nonatomic) NSMutableArray *currentRegions;
@property (retain, nonatomic) NSUUID *uuid;

- (void)reinitBeaconApi;
- (void)storeData:(NSMutableArray*)updatedBeacons forVersion:(NSInteger)version withCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler;

@end

