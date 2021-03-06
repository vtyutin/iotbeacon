//
//  AppDelegate.m
//  iotbeacon
//
//  Created by Vladimir on 24/12/15.
//  Copyright © 2015 BIS. All rights reserved.
//

#import "AppDelegate.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import "UserData.h"
#import "MainController.h"
#import <objc/runtime.h>
#import <CoreLocation/CLLocation.h>
#import <CoreLocation/CLBeaconRegion.h>
#import "AFHTTPRequestOperationManager.h"
#import <Google/CloudMessaging.h>
#import "S2MNotificationHelper.h"
#import "ActiveRegion.h"

@interface AppDelegate ()<CBCentralManagerDelegate>
@property (strong, nonatomic) CBCentralManager *bluetoothManager;
@property (strong, nonatomic) CLLocationManager *manager;
@property (strong, nonatomic) UserData *user;
@property (strong, nonatomic) NSMutableArray *activeRegions;
@property (strong, nonatomic) ActiveRegion *currentActiveRegion;
@property (strong, nonatomic) NSTimer *sessionTimer;

@property(nonatomic, strong) void (^registrationHandler)
(NSString *registrationToken, NSError *error);
@property(nonatomic, assign) BOOL connectedToGCM;
@property(nonatomic, strong) NSString* registrationToken;
@property(nonatomic, strong) NSString* registrationKey;
@property(nonatomic, strong) NSString* messageKey;
@property(nonatomic, strong) NSString* gcmSenderID;
@property(nonatomic, strong) NSDictionary* registrationOptions;
@property(nonatomic, assign) BOOL subscribedToTopic;
@end

@implementation AppDelegate
@synthesize beacons;
@synthesize manager;
@synthesize currentRegions;
@synthesize bluetoothManager;
@synthesize user;
@synthesize uuid;
@synthesize activeRegions;
@synthesize currentActiveRegion;
@synthesize sessionTimer;

BOOL isApplicationActive = NO;

#define TEST_ENTERING_ZONE 0
#define SHOW_DEFAULT_NOTIFICATIONS 0
#define MINIMUM_BEACON_GATE_SIGNAL 75

BOOL isTestEntering = YES;
int testRegionIndex = 1;

NSString *const SubscriptionTopicAll = @"/topics/all";
NSString *const SubscriptionTopicMessage = @"/topics/message";
NSString *const SubscriptionTopicDevice = @"/topics/%@";

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    UILocalNotification* localNotification = [[UILocalNotification alloc] init];
    localNotification.applicationIconBadgeNumber = 0;
    
    self.uuid = nil;
    _connectedToGCM = false;
#if TARGET_IPHONE_SIMULATOR
    self.uuid = [[NSUUID alloc] initWithUUIDString:@"SIMULATOR"];
#else
    self.uuid = [UIDevice currentDevice].identifierForVendor;
#endif
    
    self.user = [[UserData alloc] init];
    user.userId = [NSNumber numberWithInt:0];
    
    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main" bundle: nil];
    
    UINavigationController* mainController = (UINavigationController*)self.window.rootViewController;
    [mainController setNavigationBarHidden:YES];
        [mainController pushViewController:[mainStoryboard instantiateViewControllerWithIdentifier:@"MainController"] animated:NO];
    
    self.bluetoothManager = [[CBCentralManager alloc] init];
    
    self.bluetoothManager.delegate = self;
    self.sessionTimer = nil;
    
    UIUserNotificationType types = UIUserNotificationTypeBadge |
    UIUserNotificationTypeSound | UIUserNotificationTypeAlert;
    
    UIUserNotificationSettings *mySettings =
    [UIUserNotificationSettings settingsForTypes:types categories:nil];
    
    [[UIApplication sharedApplication] registerUserNotificationSettings:mySettings];
    [[UIApplication sharedApplication] registerForRemoteNotifications];
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
    [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
    
    
    self.activeRegions = [NSMutableArray array];
    self.currentRegions = [NSMutableArray array];
    self.currentActiveRegion = nil;
    
    self.manager = [[CLLocationManager alloc] init];
    [manager setPausesLocationUpdatesAutomatically:NO];
    //if (floor(NSFoundationVersionNumber) >= NSFoundationVersionNumber_iOS_8_4) {
    //    manager.allowsBackgroundLocationUpdates = YES;
    //}
    [manager setDelegate:self];
    
    NSData *storedData = [[NSUserDefaults standardUserDefaults] objectForKey:@"beacons_data"];
    self.beacons = [NSMutableArray arrayWithArray:[NSKeyedUnarchiver unarchiveObjectWithData:storedData]];
    
    if ((beacons == nil) || ([beacons count] == 0)) {
        NSString* arrayPath;
        arrayPath = [[NSBundle mainBundle] pathForResource:@"settings" ofType:@"plist"];
        self.beacons = [NSMutableArray arrayWithArray:[NSArray arrayWithContentsOfFile:arrayPath]];
    }
    
    if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorizedAlways) {
        [manager requestAlwaysAuthorization];
    } else {
        [self reinitBeaconApi];
    }
    
    // Google Cloud Messaging
    _registrationKey = @"onRegistrationCompleted";
    _messageKey = @"onMessageReceived";
    // Configure the Google context: parses the GoogleService-Info.plist, and initializes
    // the services that have entries in the file
    NSError* configureError;
    [[GGLContext sharedInstance] configureWithError:&configureError];
    NSAssert(!configureError, @"Error configuring Google services: %@", configureError);
    _gcmSenderID = [[[GGLContext sharedInstance] configuration] gcmSenderID];
    NSLog(@"sender id: %@", _gcmSenderID);
    // Register for remote notifications
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_7_1) {
        // iOS 7.1 or earlier
        UIRemoteNotificationType allNotificationTypes =
        (UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeBadge);
        [application registerForRemoteNotificationTypes:allNotificationTypes];
    } else {
        // iOS 8 or later
        // [END_EXCLUDE]
        UIUserNotificationType allNotificationTypes =
        (UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge);
        UIUserNotificationSettings *settings =
        [UIUserNotificationSettings settingsForTypes:allNotificationTypes categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    }
    // [END register_for_remote_notifications]
    // [START start_gcm_service]
    GCMConfig *gcmConfig = [GCMConfig defaultConfig];
    gcmConfig.receiverDelegate = self;
    [[GCMService sharedInstance] startWithConfig:gcmConfig];
    // [END start_gcm_service]
    NSString *const topic = [NSString stringWithFormat:@"/topics/%@", [uuid UUIDString]];
    __weak typeof(self) weakSelf = self;
    // Handler for registration token request
    _registrationHandler = ^(NSString *registrationToken, NSError *error){
        if (registrationToken != nil) {
            weakSelf.registrationToken = registrationToken;
            NSLog(@"Registration Token: %@", registrationToken);
            [weakSelf subscribeToTopic:SubscriptionTopicAll];
            [weakSelf subscribeToTopic:SubscriptionTopicMessage];
            if (uuid != nil) {
                [weakSelf subscribeToTopic:topic];
            }
            NSDictionary *userInfo = @{@"registrationToken":registrationToken};
            [[NSNotificationCenter defaultCenter] postNotificationName:weakSelf.registrationKey
                                                                object:nil
                                                              userInfo:userInfo];
        } else {
            NSLog(@"Registration to GCM failed with error: %@", error.localizedDescription);
            NSDictionary *userInfo = @{@"error":error.localizedDescription};
            [[NSNotificationCenter defaultCenter] postNotificationName:weakSelf.registrationKey
                                                                object:nil
                                                              userInfo:userInfo];
        }
    };
    
    return YES;
}

- (void)reinitBeaconApi {
    for (CLRegion *region in [manager monitoredRegions]) {
        [manager stopMonitoringForRegion:region];
    }
    
    int index = 0;
    for (NSDictionary *dict in beacons) {
        NSString *identifier = [NSString stringWithFormat:@"%d", index];
        NSUUID *uid = [[NSUUID alloc] initWithUUIDString:[[[dict valueForKey:@"udid"] uppercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
        CLBeaconMajorValue major = [[dict valueForKey:@"major"] integerValue];
        CLBeaconMinorValue minor = [[dict valueForKey:@"minor"] integerValue];
        
        CLBeaconRegion *region = [[CLBeaconRegion alloc] initWithProximityUUID:uid major:major minor:minor identifier:identifier];
        if (region != nil) {
            NSLog(@"start monitoring region: %@", region);
            [manager startMonitoringForRegion:region];
            [manager requestStateForRegion:region];
            [manager startRangingBeaconsInRegion:region];
        } else {
            NSLog(@"can't start monitoring region: %@", dict);
        }
        index++;
    }
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    NSLog(@"didChangeAuthorizationStatus: %d", status);
    [self reinitBeaconApi];
}

- (void)sessionTimerExpired {
    [sessionTimer invalidate];
    self.sessionTimer = nil;
    
    for (ActiveRegion *active in activeRegions) {
        if ([active isUpdated] == NO) {
            [self didExitBeaconRegion:active];
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager
        didRangeBeacons:(NSArray<CLBeacon *> *)bcns inRegion:(CLBeaconRegion *)region {
    //NSLog(@"didRangeBeacons: %@", bcns);
    for (CLBeacon *beacon in bcns) {
        NSLog(@"### beacon %@-%@ prox: %ld accur: %f rssi: %ld", beacon.major, beacon.minor, beacon.proximity, beacon.accuracy, beacon.rssi);
    }
    
    CLBeacon *beacon = [bcns firstObject];
    if (beacon != nil) {
        
        if ((beacon.rssi != 0) && ((-beacon.rssi) < MINIMUM_BEACON_GATE_SIGNAL)) {
            [self didEnterBeaconRegion:region];
        }
        
        /*if (sessionTimer == nil) {
            self.sessionTimer = [NSTimer scheduledTimerWithTimeInterval:15 target:self selector:@selector(sessionTimerExpired) userInfo:nil repeats:NO];
            for (ActiveRegion *active in activeRegions) {
                [active setIsUpdated:NO];
            }
        }*/
        /*
        BOOL isUpdated = NO;
        for (ActiveRegion *active in activeRegions) {
            if ([self isRegion:active.region identicalTo:region]) {
                [active signalReceivedWithSsid:beacon.rssi andAccurancy:beacon.accuracy];
                isUpdated = YES;
                break;
            }
        }
        if (isUpdated == NO) {
            ActiveRegion *active = [[ActiveRegion alloc] init];
            [active setBeacon:beacon];
            [active setRegion:region];
            [active signalReceivedWithSsid:beacon.rssi andAccurancy:beacon.accuracy];
            [activeRegions addObject:active];
            [currentRegions addObject:region];
        }
        
        NSInteger maxSignal = 1000;
        int index = 0;
        int maxRegionIndex = -1;
        NSString *debugInfo = @"";
        for (ActiveRegion *active in activeRegions) {
            NSLog(@"### Signal strenght for region %@ = %ld   isComplete: %d", active.region.major, [active latestSignal], [active isCompleteMeasurement]);
            debugInfo = [NSString stringWithFormat:@"%@beacon %@-%@ rssi = %ld \n\r", debugInfo, active.region.major, active.region.minor, [active latestSignal]];
            
            if (([active latestSignal] > 0) && ([active latestSignal] <= MINIMUM_BEACON_GATE_SIGNAL) && ([active latestSignal] < maxSignal)) {
                maxSignal = [active latestSignal];
                maxRegionIndex = index;
            }
            index++;
        }
        
        if (maxRegionIndex >= 0) {
        NSLog(@"### Max region %@ = %ld", ((ActiveRegion*)[activeRegions objectAtIndex:maxRegionIndex]).region.major, maxSignal);
        NSLog(@"### Current region %@ = %ld", currentActiveRegion.region.major, [currentActiveRegion latestSignal]);
            ActiveRegion *maxRegion = [activeRegions objectAtIndex:maxRegionIndex];
            
            if ((currentActiveRegion == nil) || (currentActiveRegion.latestSignal == 0)) {
                self.currentActiveRegion = maxRegion;
                [self didEnterBeaconRegion:currentActiveRegion.region];
            } else {
                if ((maxRegion != nil) && ([self isRegion:maxRegion.region identicalTo:currentActiveRegion.region] == NO) && ([maxRegion latestSignal] <= [currentActiveRegion latestSignal])) {
                    self.currentActiveRegion = maxRegion;
                    [self didEnterBeaconRegion:currentActiveRegion.region];
                }
            }
        }
        if (currentActiveRegion != nil) {
            debugInfo = [NSString stringWithFormat:@"%@ active beacon %@-%@\n\r", debugInfo, currentActiveRegion.region.major, currentActiveRegion.region.minor];
        }
        UINavigationController* mainController = (UINavigationController*)self.window.rootViewController;
        MainController *controller = (MainController*)[[mainController viewControllers] firstObject];
        [controller updateBeaconInfoLabel:debugInfo];
         */
    }
}

- (void)locationManager:(CLLocationManager *)manager
rangingBeaconsDidFailForRegion:(CLBeaconRegion *)region
              withError:(NSError *)error {
    NSLog(@"rangingBeaconsDidFailForRegion: %@", error.localizedDescription);
}

- (void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region {
    //NSLog(@"did change region: %@ with state: %d", region, state);
    
    if (state == CLRegionStateInside) {
        [self didEnterRegion:region];
    } else if (state == CLRegionStateOutside) {
        [self didExitRegion:region];
    }
    
}

- (void)didEnterRegion:(CLRegion *)region {
    NSLog(@"did enter region: %@", region);
}

- (void)didExitRegion:(CLRegion *)region {
    NSLog(@"did exit region: %@", region);
    if ([region isKindOfClass:CLBeaconRegion.class]) {
        BOOL isFound = NO;
        if ([region isKindOfClass:CLBeaconRegion.class]) {
            for (ActiveRegion *active in activeRegions) {
                if ([self isRegion:(CLBeaconRegion*)region identicalTo:active.region]) {
                    //[self didExitBeaconRegion:active];
                    [self performSelector:@selector(didExitBeaconRegion:) withObject:active afterDelay:2];
                    isFound = YES;
                    break;
                }
            }
        }
        if (!isFound) {
            ActiveRegion *active = [[ActiveRegion alloc] init];
            [active setRegion:(CLBeaconRegion*)region];
            [self performSelector:@selector(didExitBeaconRegion:) withObject:active afterDelay:2];
            //[self didExitBeaconRegion:active];
        }
    }
}

- (void)didEnterBeaconRegion:(CLRegion *)region {
    NSLog(@"didEnterBeaconRegion: %@", region);
    if ([region isKindOfClass:CLBeaconRegion.class]) {
        if ([self isRegion:[currentRegions lastObject] identicalTo:region] == NO) {
            for (CLBeaconRegion *current in currentRegions) {
                NSLog(@"current: %@, new: %@", current.identifier, region.identifier);
                //if ([self isRegion:current identicalTo:(CLBeaconRegion*)region] == NO) {
                //    [manager stopMonitoringForRegion:current];
                //    [manager startMonitoringForRegion:current];
                //}
                if ([self isRegion:current identicalTo:(CLBeaconRegion*)region]) {
                    [currentRegions removeObject:current];
                    break;
                }
            }
            [currentRegions addObject:region];
            
            if ([self isRegion:(CLBeaconRegion*)region identicalTo:currentActiveRegion.region] == NO) {
                for (ActiveRegion *active in activeRegions) {
                    if ([self isRegion:(CLBeaconRegion*)region identicalTo:active.region]) {
                        self.currentActiveRegion = active;
                        break;
                    }
                }
            }
            
            NSLog(@"currentRegions: %@", currentRegions);
            
            [self sendNotificationEnteringRegion:(CLBeaconRegion*)region];
        }
    }
}

-(void)didExitBeaconRegion:(ActiveRegion*)region {
    
     NSLog(@"didExitBeaconRegion: %@", region);

     if (([currentRegions count] == 1) && ([self isRegion:[currentRegions firstObject] identicalTo:(CLBeaconRegion*)region.region])){
         [self sendNotificationLeavingRegion:(CLBeaconRegion*)region.region];
     }
     for (CLBeaconRegion *current in currentRegions) {
         if ([self isRegion:current identicalTo:(CLBeaconRegion*)region.region]) {
             [currentRegions removeObject:current];
             break;
         }
     }
     
     if ([self isRegion:(CLBeaconRegion*)region.region identicalTo:currentActiveRegion.region]) {
         self.currentActiveRegion = nil;
     }
     for (ActiveRegion *active in activeRegions) {
         if ([self isRegion:(CLBeaconRegion*)region.region identicalTo:active.region]) {
             [activeRegions removeObject:active];
             break;
         }
     }
     
     NSLog(@"currentRegions: %@", currentRegions);
}

- (BOOL)isRegion:(CLBeaconRegion*)regionOne identicalTo:(CLBeaconRegion*)regionTwo {
    return (([[regionOne.proximityUUID.UUIDString lowercaseString] compare:[regionTwo.proximityUUID.UUIDString lowercaseString]] == NSOrderedSame) &&
            ([regionOne.major intValue] == [regionTwo.major intValue]) && ([regionOne.minor intValue] == [regionTwo.minor intValue]));
}

- (BOOL)isBeacon:(CLBeacon*)beaconOne identicalTo:(CLBeacon*)beaconTwo {
    return (([[beaconOne.proximityUUID.UUIDString lowercaseString] compare:[beaconTwo.proximityUUID.UUIDString lowercaseString]] == NSOrderedSame) &&
            ([beaconOne.major intValue] == [beaconTwo.major intValue]) && ([beaconOne.minor intValue] == [beaconTwo.minor intValue]));
}

- (BOOL)isBeacon:(CLBeacon*)beacon belongsTo:(CLBeaconRegion*)region {
    return (([[beacon.proximityUUID.UUIDString lowercaseString] compare:[region.proximityUUID.UUIDString lowercaseString]] == NSOrderedSame) &&
            ([beacon.major intValue] == [region.major intValue]) && ([beacon.minor intValue] == [region.minor intValue]));
}


- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    isApplicationActive = NO;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    isApplicationActive = YES;
    NSLog(@"### applicationWillEnterForeground");
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber: 0];
    /*
    if ([currentRegions count] > 0) {
        UINavigationController* mainController = (UINavigationController*)self.window.rootViewController;
        
        for (UIViewController *controller in [mainController viewControllers]) {
            if ([controller isKindOfClass:MainController.class]) {
                [((MainController*)controller) showRegionUrl:(CLBeaconRegion*)[currentRegions lastObject]];
                break;
            }
        }
    }
    */
    // Connect to the GCM server to receive non-APNS notifications
    if (_connectedToGCM == false) {
        [[GCMService sharedInstance] connectWithHandler:^(NSError *error) {
            if (error) {
                NSLog(@"Could not connect to GCM: %@", error.localizedDescription);
            } else {
                _connectedToGCM = true;
                NSLog(@"Connected to GCM");
                // [START_EXCLUDE]
                NSString *const topic = [NSString stringWithFormat:@"/topics/%@", [uuid UUIDString]];
                [self subscribeToTopic:SubscriptionTopicAll];
                [self subscribeToTopic:SubscriptionTopicMessage];
                if (uuid != nil) {
                    [self subscribeToTopic:topic];
                }
                // [END_EXCLUDE]
            }
        }];
    }
    
    if (TEST_ENTERING_ZONE == 1) {
        [NSTimer scheduledTimerWithTimeInterval:15 target:self selector:@selector(sendTestNotification) userInfo:nil repeats:YES];
    }
}

- (void)sendTestNotification {
    //if (isTestEntering) {
        NSInteger oldIndex = testRegionIndex;
        testRegionIndex++;
        if (testRegionIndex >= [[[manager monitoredRegions] allObjects] count]) {
            testRegionIndex = 0;
        }
        //[self didEnterRegion:[[[manager monitoredRegions] allObjects] objectAtIndex:testRegionIndex]];
    
        //[self didExitRegion:[[[manager monitoredRegions] allObjects] objectAtIndex:oldIndex]];
    /*    isTestEntering = NO;
    } else {
        [self didExitRegion:[[[manager monitoredRegions] allObjects] objectAtIndex:testRegionIndex]];
        isTestEntering = YES;
    }
     */
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark CBCentralManagerDelegate
- (void)centralManagerDidUpdateState:(CBCentralManager *)central{
    if (central.state != CBCentralManagerStatePoweredOn) {
        UIAlertView *allert = [[UIAlertView alloc] initWithTitle:@"Ошибка" message:@"Bluetooth выключен. Включите его в настройках." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
        [allert show];
    }
}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        NSString *url = objc_getAssociatedObject(alertView, @"url");
        if (url != nil) {
            UINavigationController* mainController = (UINavigationController*)self.window.rootViewController;
            MainController *controller = (MainController*)[[mainController viewControllers] firstObject];
            [controller loadUrl:url];
        }
    }
}

- (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forLocalNotification:(UILocalNotification *)notification completionHandler:(void(^)())completionHandler {
    NSLog(@"### Notification clicked");
    
    NSString *url = [[notification userInfo] objectForKey:@"url"];
    if ((url != nil) && (![url isEqual:[NSNull null]])) {
        UINavigationController* mainController = (UINavigationController*)self.window.rootViewController;
        MainController *controller = (MainController*)[[mainController viewControllers] firstObject];
        [controller loadUrl:url];
    }
}

- (void) application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
    if ( application.applicationState == UIApplicationStateActive ) {
        NSLog(@"### Inside App");
        return;
    } else {
        NSLog(@"### Outside App");
    }
    NSString *url = [[notification userInfo] objectForKey:@"url"];
    if ((url != nil) && (![url isEqual:[NSNull null]])) {
        UINavigationController* mainController = (UINavigationController*)self.window.rootViewController;
        MainController *controller = (MainController*)[[mainController viewControllers] firstObject];
        [controller loadUrl:url];
    }
}

-(void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    //Tell the system that you ar done.
    NSLog(@"##### FETCH DATA VERSION #####");
    [self checkDataVersionWithCompletionHandler:completionHandler];
    
    if (TEST_ENTERING_ZONE == 1) {
        [self sendTestNotification];
    }
}

-(void) sendNotificationLeavingRegion:(CLBeaconRegion *)region {
    AFSecurityPolicy *policy = [[AFSecurityPolicy alloc] init];
    [policy setAllowInvalidCertificates:YES];
    AFHTTPRequestOperationManager *operationManager = [AFHTTPRequestOperationManager manager];
    [operationManager setSecurityPolicy:policy];
    operationManager.requestSerializer = [AFJSONRequestSerializer serializer];
    operationManager.responseSerializer = [AFJSONResponseSerializer serializer];
    operationManager.responseSerializer.acceptableContentTypes = [operationManager.responseSerializer.acceptableContentTypes setByAddingObject:@"application/json"];
    NSString *login = LOGIN;
    NSString *pass = PASSWORD;
    [operationManager.requestSerializer setAuthorizationHeaderFieldWithUsername:login password:pass];
    
    NSDictionary *requestDict = [NSDictionary dictionaryWithObjectsAndKeys:region.major, @"major", region.minor, @"minor", [region.proximityUUID.UUIDString lowercaseString], @"udid", user.userId, @"uid", nil];
    
    NSLog(@"request data: %@", requestDict);
    [operationManager POST:GET_BEACON_SERVICE_URL
                parameters: requestDict
                   success:^(AFHTTPRequestOperation *operation, id responseObject) {
                       NSLog(@"response: %@", responseObject);
                       NSInteger code = [[responseObject valueForKey:@"result"] integerValue];
                       NSString *message = [responseObject valueForKey:@"message"];
                       NSDictionary *data = [responseObject valueForKey:@"data"];
                       NSLog(@"message: %@", message);
                       NSLog(@"data: %@", data);
                       
                       switch (code) {
                           case 200: {
                               if(![data isEqual:[NSNull null]]) {
                                   NSString *message = [data objectForKey:@"leaving_message"];
                                   NSString *url = [data objectForKey:@"leaving_url"];
                                   if (((url != nil) && (![url isEqual:[NSNull null]])) && ((message != nil) && (![message isEqual:[NSNull null]]))) {
                                       [self sendLocalNotificationWithMessage:message andUrl:url];
                                       UINavigationController* mainController = (UINavigationController*)self.window.rootViewController;
                                       MainController *controller = (MainController*)[[mainController viewControllers] firstObject];
                                       [controller updateButtonState];
                                   } else {
                                       if (SHOW_DEFAULT_NOTIFICATIONS) {
                                           [self sendLocalNotificationWithMessage:[NSString stringWithFormat:@"выход маяка %@ - %@", region.major, region.minor] andUrl:@"google.com"];
                                       }
                                   }
                               }
                           }
                           break;
                           default:
                           {
                               NSLog(@"######## Error response code: %ld", (long)code);
                           }
                           break;
                       }
                   }
                   failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                       NSLog(@"######## Error: %@", [error description]);
                   }
     ];
}

-(void) sendNotificationEnteringRegion:(CLBeaconRegion*)region {
    AFSecurityPolicy *policy = [[AFSecurityPolicy alloc] init];
    [policy setAllowInvalidCertificates:YES];
    AFHTTPRequestOperationManager *operationManager = [AFHTTPRequestOperationManager manager];
    [operationManager setSecurityPolicy:policy];
    operationManager.requestSerializer = [AFJSONRequestSerializer serializer];
    operationManager.responseSerializer = [AFJSONResponseSerializer serializer];
    operationManager.responseSerializer.acceptableContentTypes = [operationManager.responseSerializer.acceptableContentTypes setByAddingObject:@"application/json"];
    NSString *login = LOGIN;
    NSString *pass = PASSWORD;
    [operationManager.requestSerializer setAuthorizationHeaderFieldWithUsername:login password:pass];
    
    NSDictionary *requestDict = [NSDictionary dictionaryWithObjectsAndKeys:region.major, @"major", region.minor, @"minor", [region.proximityUUID.UUIDString lowercaseString], @"udid", user.userId, @"uid", nil];
    
    NSLog(@"request data: %@", requestDict);
    [operationManager POST:GET_BEACON_SERVICE_URL
                parameters: requestDict
                   success:^(AFHTTPRequestOperation *operation, id responseObject) {
                       NSLog(@"response data: %@", [[NSString alloc] initWithData:operation.responseData encoding:NSUTF8StringEncoding]);
                       NSLog(@"response: %@", responseObject);
                       NSInteger code = [[responseObject valueForKey:@"result"] integerValue];
                       NSString *message = [responseObject valueForKey:@"message"];
                       NSDictionary *data = [responseObject valueForKey:@"data"];
                       NSLog(@"message: %@", message);
                       NSLog(@"data: %@", data);
                       
                       switch (code) {
                           case 200: {
                               if(![data isEqual:[NSNull null]]) {
                                   NSString *message = [data objectForKey:@"enter_message"];
                                   NSLog(@"enter: %@", message);
                                   NSString *url = [data objectForKey:@"enter_url"];
                                   if (((url != nil) && (![url isEqual:[NSNull null]])) && ((message != nil) && (![message isEqual:[NSNull null]]))) {
                                       [self sendLocalNotificationWithMessage:message andUrl:url];
                                       UINavigationController* mainController = (UINavigationController*)self.window.rootViewController;
                                       MainController *controller = (MainController*)[[mainController viewControllers] firstObject];
                                       [controller updateButtonState];
                                       [controller showEnterAlertWithMessage:message andURL:url];
                                   } else {
                                       if (SHOW_DEFAULT_NOTIFICATIONS) {
                                           [self sendLocalNotificationWithMessage:[NSString stringWithFormat:@"вход маяка %@ - %@", region.major, region.minor] andUrl:@"yandex.ru"];
                                       }
                                   }
                               }
                           }
                           break;
                           default:
                           {
                                NSLog(@"######## Error response code: %ld", (long)code);
                           }
                           break;
                       }
                   }
                   failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                       NSLog(@"######## Error: %@", [error description]);
                   }
     ];
}


- (void)checkDataVersionWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    AFSecurityPolicy *policy = [[AFSecurityPolicy alloc] init];
    [policy setAllowInvalidCertificates:YES];
    
    AFHTTPRequestOperationManager *operationManager = [AFHTTPRequestOperationManager manager];
    [operationManager setSecurityPolicy:policy];
    operationManager.requestSerializer = [AFJSONRequestSerializer serializer];
    operationManager.responseSerializer = [AFJSONResponseSerializer serializer];
    operationManager.responseSerializer.acceptableContentTypes = [operationManager.responseSerializer.acceptableContentTypes setByAddingObject:@"text/html"];
    NSString *login = LOGIN;
    NSString *pass = PASSWORD;
    [operationManager.requestSerializer setAuthorizationHeaderFieldWithUsername:login password:pass];
    [operationManager GET:GET_VERSION_SERVICE_URL
               parameters: nil
                  success:^(AFHTTPRequestOperation *operation, id responseObject) {
                      NSLog(@"response: %@", responseObject);
                      NSInteger version = [[responseObject valueForKey:@"version"] integerValue];
                      NSString *pathToVersion = [responseObject valueForKey:@"data_file"];
                      
                      NSNumber *storedVersion = [[NSUserDefaults standardUserDefaults] objectForKey:@"data_version"];
                      if ((storedVersion == nil) || ((storedVersion != nil) && ([storedVersion integerValue] != version))) {
                          [self loadNewData:pathToVersion forVersion:version withCompletionHandler:completionHandler];
                      } else {
                          completionHandler(UIBackgroundFetchResultNewData);
                      }
                  }
                  failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                      NSLog(@"######## Error: %@", [error description]);
                      completionHandler(UIBackgroundFetchResultNewData);
                  }
     ];
}

- (void)loadNewData:(NSString*)pathToData forVersion:(NSInteger)version withCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    AFSecurityPolicy *policy = [[AFSecurityPolicy alloc] init];
    [policy setAllowInvalidCertificates:YES];
    
    AFHTTPRequestOperationManager *operationManager = [AFHTTPRequestOperationManager manager];
    [operationManager setSecurityPolicy:policy];
    operationManager.requestSerializer = [AFJSONRequestSerializer serializer];
    operationManager.responseSerializer = [AFJSONResponseSerializer serializer];
    operationManager.responseSerializer.acceptableContentTypes = [operationManager.responseSerializer.acceptableContentTypes setByAddingObject:@"text/html"];
    NSString *login = LOGIN;
    NSString *pass = PASSWORD;
    [operationManager.requestSerializer setAuthorizationHeaderFieldWithUsername:login password:pass];
    [operationManager GET:pathToData
               parameters: nil
                  success:^(AFHTTPRequestOperation *operation, id responseObject) {
                      NSLog(@"response: %@", responseObject);
                      NSMutableArray *newBeaconsArray = [NSMutableArray array];
                      NSArray *responseData = (NSArray*)responseObject;
                      for (NSDictionary *dict in responseData) {
                          NSMutableDictionary *beacon = [NSMutableDictionary dictionary];
                          [beacon setValue:[dict valueForKey:@"udid"] forKey:@"udid"];
                          [beacon setValue:[dict valueForKey:@"major"] forKey:@"major"];
                          [beacon setValue:[dict valueForKey:@"minor"] forKey:@"minor"];
                          [beacon setValue:[dict valueForKey:@"enter_url"] forKey:@"url"];
                          [beacon setValue:[dict valueForKey:@"enter_message"] forKey:@"message"];
                          [beacon setValue:[dict valueForKey:@"leaving_url"] forKey:@"leaving_url"];
                          [beacon setValue:[dict valueForKey:@"leaving_message"] forKey:@"leaving_message"];
                          [beacon setValue:[dict valueForKey:@"id"] forKey:@"id"];
                          [newBeaconsArray addObject:beacon];
                      }
                      [self storeData:newBeaconsArray forVersion:version withCompletionHandler:completionHandler];
                  }
                  failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                      NSLog(@"######## Error: %@", [error description]);
                      completionHandler(UIBackgroundFetchResultNewData);
                  }
     ];
}

- (void)storeData:(NSMutableArray*)updatedBeacons forVersion:(NSInteger)version withCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    self.beacons = updatedBeacons;
    
    [((AppDelegate*)[[UIApplication sharedApplication] delegate]) reinitBeaconApi];
    
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:version] forKey:@"data_version"];
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:beacons];
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"beacons_data"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    if (completionHandler != nil) {
        completionHandler(UIBackgroundFetchResultNewData);
    }
}


- (void)subscribeToTopic:(NSString*)topic {
    // If the app has a registration token and is connected to GCM, proceed to subscribe to the
    // topic
    if (_registrationToken && _connectedToGCM) {
        [[GCMPubSub sharedInstance] subscribeWithToken:_registrationToken
                                                 topic:topic
                                               options:nil
                                               handler:^(NSError *error) {
                                                   if (error) {
                                                       // Treat the "already subscribed" error more gently
                                                       if (error.code == 3001) {
                                                           NSLog(@"Already subscribed to %@",
                                                                 topic);
                                                       } else {
                                                           NSLog(@"Subscription failed: %@",
                                                                 error.localizedDescription);
                                                       }
                                                   } else {
                                                       self.subscribedToTopic = true;
                                                       NSLog(@"Subscribed to %@", topic);
                                                   }
                                               }];
    }
}

// [START receive_apns_token]
- (void)application:(UIApplication *)application
didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    NSLog(@"didRegisterForRemoteNotificationsWithDeviceToken: %@", deviceToken);
    // [END receive_apns_token]
    // [START get_gcm_reg_token]
    // Create a config and set a delegate that implements the GGLInstaceIDDelegate protocol.
    GGLInstanceIDConfig *instanceIDConfig = [GGLInstanceIDConfig defaultConfig];
    instanceIDConfig.delegate = self;
    // Start the GGLInstanceID shared instance with the that config and request a registration
    // token to enable reception of notifications
    [[GGLInstanceID sharedInstance] startWithConfig:instanceIDConfig];
    _registrationOptions = @{kGGLInstanceIDRegisterAPNSOption:deviceToken,
                             kGGLInstanceIDAPNSServerTypeSandboxOption:@NO};
    [[GGLInstanceID sharedInstance] tokenWithAuthorizedEntity:_gcmSenderID
                                                        scope:kGGLInstanceIDScopeGCM
                                                      options:_registrationOptions
                                                      handler:_registrationHandler];
    // [END get_gcm_reg_token]
}

// [START receive_apns_token_error]
- (void)application:(UIApplication *)application
didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(@"Registration for remote notification failed with error: %@", error.localizedDescription);
    // [END receive_apns_token_error]
    NSDictionary *userInfo = @{@"error" :error.localizedDescription};
    [[NSNotificationCenter defaultCenter] postNotificationName:_registrationKey
                                                        object:nil
                                                      userInfo:userInfo];
}

// [START ack_message_reception]
- (void)application:(UIApplication *)application
didReceiveRemoteNotification:(NSDictionary *)userInfo {
    NSLog(@"Notification received: %@", userInfo);
    [self handlePushNotificatio:userInfo];
}

- (void)application:(UIApplication *)application
didReceiveRemoteNotification:(NSDictionary *)userInfo
fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))handler {
    NSLog(@"Notification received: %@", userInfo);
    [self handlePushNotificatio:userInfo];
    handler(UIBackgroundFetchResultNoData);
}
// [END ack_message_reception]

-(void)handlePushNotificatio:(NSDictionary *)userInfo {
    NSString *message = [userInfo valueForKey:@"message"];
    NSString *url = [userInfo valueForKey:@"url"];        
    if ((url != nil) && (message != nil)) {
        [self sendLocalNotificationWithMessage:message andUrl:url];
    }
}

-(void)sendLocalNotificationWithMessage:(NSString*)message andUrl:(NSString*)url {
    if ((url != nil) && (![url isEqual:[NSNull null]]) && (message != nil)) {
        
        for (UILocalNotification *notification in [S2MNotificationHelper allNotifications]) {
            if (([notification.alertBody compare:message] == NSOrderedSame) && ([[notification.userInfo valueForKey:@"url"] compare:url] == NSOrderedSame)) {
                NSLog(@"Notification with message (%@) is already exists", notification.alertBody);
                return;
            }
        }
        
        [S2MNotificationHelper removeAllNotifications];
        //[NSThread sleepForTimeInterval:1];
        NSString *keyForCache = [@([[NSDate date] timeIntervalSince1970]) stringValue];
        UILocalNotification *notification = [UILocalNotification new];
        notification.alertAction = @"Let's Check";
        notification.alertBody = message;
        notification.soundName = UILocalNotificationDefaultSoundName;
        notification.timeZone = [NSTimeZone defaultTimeZone];
        notification.userInfo = [NSDictionary dictionaryWithObject:url forKey:@"url"];
        [notification setS2mKey:keyForCache];
        NSLog(@"show notification with message: %@ and url: %@", message, url);
        [S2MNotificationHelper showNotification:notification];
    }
}

// [START on_token_refresh]
- (void)onTokenRefresh {
    // A rotation of the registration tokens is happening, so the app needs to request a new token.
    NSLog(@"The GCM registration token needs to be changed.");
    [[GGLInstanceID sharedInstance] tokenWithAuthorizedEntity:_gcmSenderID
                                                        scope:kGGLInstanceIDScopeGCM
                                                      options:_registrationOptions
                                                      handler:_registrationHandler];
}
// [END on_token_refresh]

// [START upstream_callbacks]
- (void)willSendDataMessageWithID:(NSString *)messageID error:(NSError *)error {
    if (error) {
        // Failed to send the message.
    } else {
        // Will send message, you can save the messageID to track the message
    }
}

- (void)didSendDataMessageWithID:(NSString *)messageID {
    // Did successfully send message identified by messageID
}
// [END upstream_callbacks]

- (void)didDeleteMessagesOnServer {
    // Some messages sent to this device were deleted on the GCM server before reception, likely
    // because the TTL expired. The client should notify the app server of this, so that the app
    // server can resend those messages.
}

@end
