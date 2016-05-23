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

@interface MainController : UIViewController <UIWebViewDelegate, UIAlertViewDelegate>

#define GET_VERSION_SERVICE_URL @"http://uliyneron.no-ip.org/ibeacon_pass/version.php"
#define MAIN_PAGE_URL @"http://uliyneron.no-ip.org/ibeacon_pass"
#define GET_BEACON_SERVICE_URL @"http://uliyneron.no-ip.org/ibeacon_pass/ibeacon.php"
#define LOGIN @"app";
#define PASSWORD @"51rUQHeVWk";

@property (strong) NSString* consumerId;
@property (strong) NSArray* zones;
@property (assign) IB2ZoneSortRule sortRule;
@property (weak, nonatomic) IBOutlet UIButton *zoneButton;
@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *loadingIndicator;
@property (weak, nonatomic) IBOutlet UIView *buttonsView;

- (IBAction)settingButtonPressed:(id)sender;
- (IBAction)registryButtonPressed:(id)sender;
@property (weak, nonatomic) IBOutlet UIView *messageView;
- (IBAction)zoneButtonPressed:(id)sender;
- (void)leavingZone:(id<IBZone>)zone;
- (void)enteringZone:(id<IBZone>)zone;
- (void)leavingRegion:(CLBeaconRegion*)region;
- (void)enteringRegion:(CLBeaconRegion*)region;
- (IBAction)homeButtonPressed:(id)sender;
- (IBAction)beaconButtonPressed:(id)sender;
- (void)loadUrl:(NSString*)url;
- (void)resetToHomePage;
-(void) showRegionUrl:(CLBeaconRegion *)region;
@end
