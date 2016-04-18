//
//  MainController.h
//  iotbeacon
//
//  Created by Vladimir on 14/01/16.
//  Copyright © 2016 BIS. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "IBZoneManager.h"
#import "IBZone.h"
#import <CoreLocation/CLBeaconRegion.h>

@interface MainController : UIViewController <UIWebViewDelegate>

@property (strong) NSString* consumerId;
@property (strong) NSArray* zones;
@property (assign) IB2ZoneSortRule sortRule;
@property (weak, nonatomic) IBOutlet UIButton *zoneButton;
@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *loadingIndicator;

- (IBAction)settingButtonPressed:(id)sender;
- (IBAction)registryButtonPressed:(id)sender;
@property (weak, nonatomic) IBOutlet UIView *messageView;
- (IBAction)zoneButtonPressed:(id)sender;
- (void)leavingZone:(id<IBZone>)zone;
- (void)enteringZone:(id<IBZone>)zone;
- (void)leavingRegion:(CLBeaconRegion*)region;
- (void)enteringRegion:(CLBeaconRegion*)region;
@end
