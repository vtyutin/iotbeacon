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

@interface AppDelegate ()<CBCentralManagerDelegate>
@property (strong, nonatomic)CBCentralManager *bluetoothManager;
@property (strong, nonatomic) CLLocationManager *manager;
@property (strong, nonatomic) UserData *user;

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

BOOL isApplicationActive = NO;

#define TEST_ENTERING_ZONE 0
BOOL isTestEntering = YES;
int testRegionIndex = 1;

NSString *const SubscriptionTopicAll = @"/topics/all";
NSString *const SubscriptionTopicDevice = @"/topics/%@";

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    UILocalNotification* localNotification = [[UILocalNotification alloc] init];
    localNotification.applicationIconBadgeNumber = 0;
    
    self.uuid = nil;
    self.connectedToGCM = false;
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
    
    UIUserNotificationType types = UIUserNotificationTypeBadge |
    UIUserNotificationTypeSound | UIUserNotificationTypeAlert;
    
    UIUserNotificationSettings *mySettings =
    [UIUserNotificationSettings settingsForTypes:types categories:nil];
    
    [[UIApplication sharedApplication] registerUserNotificationSettings:mySettings];
    [[UIApplication sharedApplication] registerForRemoteNotifications];
    
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
    
    [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
    
    self.currentRegions = [NSMutableArray array];
    
    self.manager = [[CLLocationManager alloc] init];
    [manager setPausesLocationUpdatesAutomatically:NO];
    if (floor(NSFoundationVersionNumber) >= NSFoundationVersionNumber_iOS_8_4) {
        manager.allowsBackgroundLocationUpdates = YES;
    }
    [manager setDelegate:self];
    
    NSString* arrayPath;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if ([paths count] > 0)
    {
        arrayPath = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"updated_settings.plist"];
        self.beacons = [NSMutableArray arrayWithArray:[NSArray arrayWithContentsOfFile:arrayPath]];
    }
    
    if ((beacons == nil) || ([beacons count] == 0)) {
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
        NSString *identifier = [NSString stringWithFormat:@"%d#%@", index, [dict valueForKey:@"url"]];
        CLRegion *region = [[CLBeaconRegion alloc] initWithProximityUUID:[[NSUUID alloc] initWithUUIDString:[dict valueForKey:@"udid"]] major:[[dict valueForKey:@"major"] integerValue] minor:[[dict valueForKey:@"minor"] integerValue] identifier:identifier];
        if (region != nil) {
            [manager startMonitoringForRegion:region];
            [manager requestStateForRegion:region];
        }
        index++;
    }
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    NSLog(@"didChangeAuthorizationStatus: %d", status);
    [self reinitBeaconApi];
}

- (void)locationManager:(CLLocationManager *)manager
        didRangeBeacons:(NSArray<CLBeacon *> *)bcns inRegion:(CLBeaconRegion *)region {
    NSLog(@"didRangeBeacons: %@", bcns);
}

- (void)locationManager:(CLLocationManager *)manager
rangingBeaconsDidFailForRegion:(CLBeaconRegion *)region
              withError:(NSError *)error {
    NSLog(@"rangingBeaconsDidFailForRegion: %@", error.localizedDescription);
}

- (void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region {
    NSLog(@"did change region: %@ with state: %d", region, state);
    if (state == CLRegionStateInside) {
        [self didEnterRegion:region];
    } else if (state == CLRegionStateOutside) {
        [self didExitRegion:region];
    }
}

- (void)didEnterRegion:(CLRegion *)region {
    NSLog(@"did enter region: %@", region);
    if ([region isKindOfClass:CLBeaconRegion.class]) {
        BOOL isAlreadyExist = NO;
        for (CLBeaconRegion *current in currentRegions) {
            NSLog(@"current: %@, new: %@", current.identifier, region.identifier);
            if ([self isRegion:current identicalTo:(CLBeaconRegion*)region]) {
                isAlreadyExist = YES;
                break;
            }
        }
        if (isAlreadyExist == NO) {
            [currentRegions addObject:region];
            [self sendNotificationEnteringRegion:(CLBeaconRegion*)region];
        }
    }
}

- (void)didExitRegion:(CLRegion *)region {
    NSLog(@"did exit region: %@", region);
    if ([region isKindOfClass:CLBeaconRegion.class]) {
        if (([currentRegions count] == 1) && ([self isRegion:[currentRegions firstObject] identicalTo:(CLBeaconRegion*)region])) {
            [self sendNotificationLeavingRegion:(CLBeaconRegion*)region];
        }
        for (CLBeaconRegion *current in currentRegions) {
            if ([self isRegion:current identicalTo:(CLBeaconRegion*)region]) {
                [currentRegions removeObject:current];
                break;
            }
        }
    }
}

- (BOOL)isRegion:(CLBeaconRegion*)regionOne identicalTo:(CLBeaconRegion*)regionTwo {
    return (([[regionOne.proximityUUID.UUIDString lowercaseString] compare:[regionTwo.proximityUUID.UUIDString lowercaseString]] == NSOrderedSame) &&
            ([regionOne.major intValue] == [regionTwo.major intValue]) && ([regionOne.minor intValue] == [regionTwo.minor intValue]));
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
    
    if ([currentRegions count] > 0) {
        UINavigationController* mainController = (UINavigationController*)self.window.rootViewController;
        
        for (UIViewController *controller in [mainController viewControllers]) {
            if ([controller isKindOfClass:MainController.class]) {
                [((MainController*)controller) showRegionUrl:(CLBeaconRegion*)[currentRegions lastObject]];
                break;
            }
        }
    }
    
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
        [self didEnterRegion:[[[manager monitoredRegions] allObjects] objectAtIndex:testRegionIndex]];
    
        [self didExitRegion:[[[manager monitoredRegions] allObjects] objectAtIndex:oldIndex]];
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
    if (url != nil) {
        UINavigationController* mainController = (UINavigationController*)self.window.rootViewController;
        MainController *controller = (MainController*)[[mainController viewControllers] firstObject];
        [controller loadUrl:url];
    }
}

- (void) application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
    if ( application.applicationState == UIApplicationStateActive ) {
        NSLog(@"### Inside App");
    } else {
        NSLog(@"### Outside App");
    }
    NSString *url = [[notification userInfo] objectForKey:@"url"];
    if (url != nil) {
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
                                   [self sendLocalNotificationWithMessage:message andUrl:url];
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
                                   [self sendLocalNotificationWithMessage:message andUrl:url];
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
    AppDelegate* app = ((AppDelegate*)[[UIApplication sharedApplication] delegate]);
    
    app.beacons = updatedBeacons;
    
    NSString* arrayPath;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if ([paths count] > 0)
    {
        arrayPath = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"updated_settings.plist"];
        [updatedBeacons writeToFile:arrayPath atomically:YES];
    }
    [((AppDelegate*)[[UIApplication sharedApplication] delegate]) reinitBeaconApi];
    
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:version] forKey:@"data_version"];
    
    completionHandler(UIBackgroundFetchResultNewData);
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
    if ([[userInfo valueForKey:@"message"] compare:@"TEST_ENTER"] == NSOrderedSame) {
        [self didEnterRegion:[[[manager monitoredRegions] allObjects] firstObject]];
    } else if ([[userInfo valueForKey:@"message"] compare:@"TEST_EXIT"] == NSOrderedSame) {
        [self didExitRegion:[[[manager monitoredRegions] allObjects] firstObject]];
    } else if ([[userInfo valueForKey:@"message"] compare:@"TEST"] == NSOrderedSame) {
        [self sendTestNotification];
    } else {
        NSString *message = [userInfo valueForKey:@"message"];
        NSString *url = [userInfo valueForKey:@"url"];        
        if ((url != nil) && (message != nil)) {
            [self sendLocalNotificationWithMessage:message andUrl:url];
        }
    }
}

-(void)sendLocalNotificationWithMessage:(NSString*)message andUrl:(NSString*)url {
    if ((url != nil) && (![url isEqual:[NSNull null]]) && (message != nil)) {
        [S2MNotificationHelper removeAllNotifications];
        [NSThread sleepForTimeInterval:1];
        NSString *keyForCache = [@([[NSDate date] timeIntervalSince1970]) stringValue];
        UILocalNotification *notification = [UILocalNotification new];
        notification.alertAction = @"Let's Check";
        notification.alertBody = message;
        notification.soundName = UILocalNotificationDefaultSoundName;
        notification.timeZone = [NSTimeZone defaultTimeZone];
        notification.userInfo = [NSDictionary dictionaryWithObject:url forKey:@"url"];
        [notification setS2mKey:keyForCache];
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
