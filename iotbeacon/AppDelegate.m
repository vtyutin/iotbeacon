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
#import "RegistryController.h"
#import "WebViewController.h"
#import <objc/runtime.h>
#import "ZoneManagerConsumer.h"
#import <CoreLocation/CLLocation.h>
#import <CoreLocation/CLBeaconRegion.h>
#import "AFHTTPRequestOperationManager.h"

@interface AppDelegate ()<CBCentralManagerDelegate>
@property (strong, nonatomic)CBCentralManager *bluetoothManager;
@property (strong, nonatomic) CLLocationManager *manager;
@property (strong, nonatomic) NSMutableArray *currentRegions;
@property (strong, nonatomic) UserData *user;
@end

@implementation AppDelegate
@synthesize beacons;
@synthesize manager;
@synthesize currentRegions;
@synthesize bluetoothManager;
@synthesize user;
@synthesize uuid;

BOOL isApplicationActive = NO;
#define GET_VERSION_SERVICE_URL @"http://uliyneron.no-ip.org/ibeacon/version.php"
#define GET_BEACON_SERVICE_URL @"http://uliyneron.no-ip.org/ibeacon/ibeacon.php"

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    UILocalNotification* localNotification = [[UILocalNotification alloc] init];
    localNotification.applicationIconBadgeNumber = 0;
    
#if TARGET_IPHONE_SIMULATOR
    self.uuid = [[NSUUID alloc] initWithUUIDString:@"SIMULATOR"];
#else
    self.uuid = [UIDevice currentDevice].identifierForVendor;
#endif
    
    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main" bundle: nil];
    
    UINavigationController* mainController = (UINavigationController*)self.window.rootViewController;
    [mainController setNavigationBarHidden:YES];
    /*
    RegistryController* registryController = (RegistryController*)[mainStoryboard instantiateViewControllerWithIdentifier:@"RegistryController"];
    
    
    self.user = nil;
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"last_name"] != nil) {
        self.user = [[UserData alloc] init];
        user.lastName = [[NSUserDefaults standardUserDefaults] objectForKey:@"last_name"];
        user.firstName = [[NSUserDefaults standardUserDefaults] objectForKey:@"first_name"];
        user.middleName = [[NSUserDefaults standardUserDefaults] objectForKey:@"middle_name"];
        user.email = [[NSUserDefaults standardUserDefaults] objectForKey:@"email"];
        user.occupation = [[NSUserDefaults standardUserDefaults] objectForKey:@"occupation"];
        user.birthDate = [[NSUserDefaults standardUserDefaults] objectForKey:@"birthdate"];
        user.userId = [[NSUserDefaults standardUserDefaults] objectForKey:@"userId"];
        [registryController setUser:user];
    }
    
    [mainController pushViewController:registryController animated:NO];
    */
    //if (user != nil) {
        [mainController pushViewController:[mainStoryboard instantiateViewControllerWithIdentifier:@"MainController"] animated:NO];
    //}
    
    self.bluetoothManager = [[CBCentralManager alloc] init];
    
    NSLog(@"bluetooth state: %d", bluetoothManager.state);
    
    self.bluetoothManager.delegate = self;
    
    UIUserNotificationType types = UIUserNotificationTypeBadge |
    UIUserNotificationTypeSound | UIUserNotificationTypeAlert;
    
    UIUserNotificationSettings *mySettings =
    [UIUserNotificationSettings settingsForTypes:types categories:nil];
    
    [[UIApplication sharedApplication] registerUserNotificationSettings:mySettings];
    
    [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:10];
    
    self.currentRegions = [NSMutableArray array];
    
    self.manager = [[CLLocationManager alloc] init];
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
        CLRegion *regionToRemove = nil;
        for (CLBeaconRegion *current in currentRegions) {
            if ([self isRegion:current identicalTo:(CLBeaconRegion*)region]) {
                regionToRemove = current;
                break;
            }
        }
        if (regionToRemove != nil) {
            [self sendNotificationLeavingRegion:(CLBeaconRegion*)region];
            [currentRegions removeObject:regionToRemove];
        }
    }
}

- (BOOL)isRegion:(CLBeaconRegion*)regionOne identicalTo:(CLBeaconRegion*)regionTwo {
    if (([regionOne.proximityUUID.UUIDString compare:regionTwo.proximityUUID.UUIDString] == NSOrderedSame) &&
        ([regionOne.major intValue] == [regionTwo.major intValue]) && ([regionOne.minor intValue] == [regionTwo.minor intValue]) && ([regionOne.identifier compare:regionTwo.identifier] == NSOrderedSame)) {
        return YES;
    }
    return NO;
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
    UINavigationController* mainController = (UINavigationController*)self.window.rootViewController;
    
    for (UIViewController *controller in [mainController viewControllers]) {
        if ([controller isKindOfClass:MainController.class]) {
            [mainController popToViewController:controller animated:YES];
            break;
        }
    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber: 0];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark CBCentralManagerDelegate
- (void)centralManagerDidUpdateState:(CBCentralManager *)central{
    if (central.state != CBCentralManagerStatePoweredOn) {
        UIAlertView *allert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"bluetooth off" delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
        [allert show];
    }
}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        NSString *url = objc_getAssociatedObject(alertView, @"url");
        if (url != nil) {
            UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main" bundle: nil];
            UINavigationController* mainController = (UINavigationController*)self.window.rootViewController;
            WebViewController* webController = (WebViewController*)[mainStoryboard instantiateViewControllerWithIdentifier:@"WebViewController"];
            webController.url = url;
            [mainController popToViewController:[[mainController viewControllers] objectAtIndex:1] animated:NO];
            [mainController pushViewController:webController animated:NO];
        }
    }
}

/*
 - (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
 
 if (application.applicationState == UIApplicationStateInactive ) {
 //The application received the notification from an inactive state, i.e. the user tapped the "View" button for the alert.
 //If the visible view controller in your view controller stack isn't the one you need then show the right one.
 NSLog(@"### Notificztion clicked");
 }
 
 if(application.applicationState == UIApplicationStateActive ) {
 //The application received a notification in the active state, so you can display an alert view or do something appropriate.
 NSLog(@"### Just entered");
 }
 
 NSLog(@"### didReceiveLocalNotification: %@", notification);
 
 NSLog(@"### url: %@", [[notification userInfo] objectForKey:@"url"]);
 
 NSString *url = [[notification userInfo] objectForKey:@"url"];
 
 [[UIApplication sharedApplication] cancelAllLocalNotifications];
 
 if (isApplicationActive) {
 UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Внимание" message:@"Вы в зоне действия маяка. Хотите открыть страницу?" delegate:self cancelButtonTitle:@"Нет" otherButtonTitles:@"да", nil];
 objc_setAssociatedObject(alert, @"url", url, OBJC_ASSOCIATION_COPY);
 [alert show];
 return;
 }
 
 [[UIApplication sharedApplication] cancelAllLocalNotifications];
 
 if (url != nil) {
 UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main" bundle: nil];
 UINavigationController* mainController = (UINavigationController*)self.window.rootViewController;
 WebViewController* webController = (WebViewController*)[mainStoryboard instantiateViewControllerWithIdentifier:@"WebViewController"];
 webController.url = url;
 [mainController popToViewController:[[mainController viewControllers] objectAtIndex:1] animated:NO];
 [mainController pushViewController:webController animated:NO];
 }
 }
 */
- (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forLocalNotification:(UILocalNotification *)notification completionHandler:(void(^)())completionHandler {
    NSLog(@"### Notification clicked");
    
    NSString *url = [[notification userInfo] objectForKey:@"url"];
    if (url != nil) {
        UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main" bundle: nil];
        UINavigationController* mainController = (UINavigationController*)self.window.rootViewController;
        WebViewController* webController = (WebViewController*)[mainStoryboard instantiateViewControllerWithIdentifier:@"WebViewController"];
        webController.url = url;
        [mainController popToViewController:[[mainController viewControllers] objectAtIndex:1] animated:NO];
        [mainController pushViewController:webController animated:NO];
    }
}

- (void) application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
    [[UIApplication sharedApplication] cancelLocalNotification:notification];
    if ( application.applicationState == UIApplicationStateActive ) {
        NSLog(@"### Inside App");
        /*
         if ([notification.alertAction compare:@"Open URL"] == NSOrderedSame) {
         NSString *url = [[notification userInfo] objectForKey:@"url"];
         if (url != nil) {
         if ([notification.alertAction compare:@"Open URL"] == NSOrderedSame) {
         UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Внимание" message:@"Вы в зоне действия маяка. Хотите открыть страницу?" delegate:self cancelButtonTitle:@"Нет" otherButtonTitles:@"да", nil];
         objc_setAssociatedObject(alert, @"url", url, OBJC_ASSOCIATION_COPY);
         [alert show];
         }
         }
         } else {
         UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Внимание" message:@"Вы покинули зону действия маяка." delegate:nil cancelButtonTitle:@"ok" otherButtonTitles:nil];
         [alert show];
         }
         */
    } else {
        //if ([notification.alertAction compare:@"Open URL"] == NSOrderedSame) {
        NSString *url = [[notification userInfo] objectForKey:@"url"];
        if (url != nil) {
            UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main" bundle: nil];
            UINavigationController* mainController = (UINavigationController*)self.window.rootViewController;
            WebViewController* webController = (WebViewController*)[mainStoryboard instantiateViewControllerWithIdentifier:@"WebViewController"];
            webController.url = url;
            [mainController popToViewController:[[mainController viewControllers] objectAtIndex:1] animated:NO];
            [mainController pushViewController:webController animated:NO];
        }
        //}
    }
}

-(void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    //Tell the system that you ar done.
    NSLog(@"##### FETCH DATA VERSION #####");
    [self checkDataVersionWithCompletionHandler:completionHandler];
}

-(void) sendNotificationLeavingRegion:(CLBeaconRegion *)region {
    AFSecurityPolicy *policy = [[AFSecurityPolicy alloc] init];
    [policy setAllowInvalidCertificates:YES];
    AFHTTPRequestOperationManager *operationManager = [AFHTTPRequestOperationManager manager];
    [operationManager setSecurityPolicy:policy];
    operationManager.requestSerializer = [AFHTTPRequestSerializer serializer];
    [operationManager.requestSerializer setValue:@"*/*" forHTTPHeaderField:@"Accept"];
    [operationManager.requestSerializer setValue:@"gzip, deflate, utf8                            " forHTTPHeaderField:@"Accept-Encoding"];
    [operationManager.requestSerializer setValue:@"en-US,en;q=0.8,ru;q=0.6" forHTTPHeaderField:@"Accept-Language"];
    [operationManager.requestSerializer setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    operationManager.responseSerializer = [AFJSONResponseSerializer serializer];
    operationManager.responseSerializer.acceptableContentTypes = [operationManager.responseSerializer.acceptableContentTypes setByAddingObject:@"application/json"];
    
    NSString *requestData = [NSString stringWithFormat:@"major=%d&minor=%d&udid=%@&uid=%d", [region.major integerValue], [region.minor integerValue], [region.proximityUUID.UUIDString lowercaseString], [user.userId  integerValue]];
    
    NSLog(@"request data: %@", requestData);
    [operationManager GET:[NSString stringWithFormat:@"%@?%@", GET_BEACON_SERVICE_URL, requestData]
               parameters: nil
                   success:^(AFHTTPRequestOperation *operation, id responseObject) {
                       NSLog(@"response: %@", responseObject);
                       NSInteger code = [[responseObject valueForKey:@"result"] integerValue];
                       NSString *message = [responseObject valueForKey:@"message"];
                       NSDictionary *data = [responseObject valueForKey:@"data"];
                       NSLog(@"code: %d", code);
                       NSLog(@"message: %@", message);
                       NSLog(@"data: %@", data);
                       
                       switch (code) {
                           case 200: {
                               if(![data isEqual:[NSNull null]]) {
                                   UILocalNotification* localNotification = [[UILocalNotification alloc] init];
                                   NSString *message = [data objectForKey:@"leaving_message"];
                                   if ((message != nil) && ([message length] > 0)) {
                                       localNotification.alertBody = message;
                                   } else {
                                       localNotification.alertBody = [NSString stringWithFormat:@"Вы покинули зону действия маяка %@", [[region.identifier componentsSeparatedByString:@"#"] objectAtIndex:0]];
                                   }
                                   UINavigationController* mainController = (UINavigationController*)self.window.rootViewController;
                                   for (UIViewController *controller in [mainController childViewControllers]) {
                                       if ([controller isKindOfClass:MainController.class]) {
                                           [((MainController*)controller) enteringRegion:region];
                                       }
                                   }
                                   localNotification.alertAction = @"Open URL";
                                   NSLog(@"### zone id: %@", [[region.identifier componentsSeparatedByString:@"#"] objectAtIndex:1]);
                                   
                                   NSString *url = [data objectForKey:@"leaving_url"];
                                   if (url == nil) {
                                       localNotification.userInfo = [NSDictionary dictionaryWithObject:[[region.identifier componentsSeparatedByString:@"#"] objectAtIndex:1] forKey:@"url"];
                                   } else {
                                       localNotification.userInfo = [NSDictionary dictionaryWithObject:url forKey:@"url"];
                                   }
                                   
                                   localNotification.soundName = UILocalNotificationDefaultSoundName;
                                   localNotification.applicationIconBadgeNumber = 0;
                                   
                                   [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
                               }
                           }
                           break;
                           default:
                           {
                               NSLog(@"######## Error response code: %d", code);
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
    operationManager.requestSerializer = [AFHTTPRequestSerializer serializer];
    [operationManager.requestSerializer setValue:@"*/*" forHTTPHeaderField:@"Accept"];
    [operationManager.requestSerializer setValue:@"gzip, deflate, utf8                            " forHTTPHeaderField:@"Accept-Encoding"];
    [operationManager.requestSerializer setValue:@"en-US,en;q=0.8,ru;q=0.6" forHTTPHeaderField:@"Accept-Language"];
    [operationManager.requestSerializer setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    operationManager.responseSerializer = [AFJSONResponseSerializer serializer];
    operationManager.responseSerializer.acceptableContentTypes = [operationManager.responseSerializer.acceptableContentTypes setByAddingObject:@"application/json"];
    
    NSString *requestData = [NSString stringWithFormat:@"major=%d&minor=%d&udid=%@&uid=%d", [region.major integerValue], [region.minor integerValue], [region.proximityUUID.UUIDString lowercaseString], [user.userId  integerValue]];
    
    NSLog(@"request data: %@", requestData);
    [operationManager GET:[NSString stringWithFormat:@"%@?%@", GET_BEACON_SERVICE_URL, requestData]
                parameters: nil
                   success:^(AFHTTPRequestOperation *operation, id responseObject) {
                       NSLog(@"response data: %@", [[NSString alloc] initWithData:operation.responseData encoding:NSUTF8StringEncoding]);
                       NSLog(@"response: %@", responseObject);
                       NSInteger code = [[responseObject valueForKey:@"result"] integerValue];
                       NSString *message = [responseObject valueForKey:@"message"];
                       NSDictionary *data = [responseObject valueForKey:@"data"];
                       NSLog(@"code: %d", code);
                       NSLog(@"message: %@", message);
                       NSLog(@"data: %@", data);
                       
                       switch (code) {
                           case 200: {
                               if(![data isEqual:[NSNull null]]) {
                                   UILocalNotification* localNotification = [[UILocalNotification alloc] init];
                                   NSString *message = [data objectForKey:@"enter_message"];
                                   if ((message != nil) && (![message isEqual:[NSNull null]]) && ([message length] > 0)) {
                                       localNotification.alertBody = message;
                                   } else {
                                       localNotification.alertBody = [NSString stringWithFormat:@"Вы находитесь в зоне действия маяка %@", [[region.identifier componentsSeparatedByString:@"#"] objectAtIndex:0]];
                                   }
                                   UINavigationController* mainController = (UINavigationController*)self.window.rootViewController;
                                   for (UIViewController *controller in [mainController childViewControllers]) {
                                       if ([controller isKindOfClass:MainController.class]) {
                                           [((MainController*)controller) enteringRegion:region];
                                       }
                                   }
                                   localNotification.alertAction = @"Open URL";
                                   NSLog(@"### zone id: %@", [[region.identifier componentsSeparatedByString:@"#"] objectAtIndex:1]);
                                   
                                   NSString *url = [data objectForKey:@"enter_url"];
                                   if ((url == nil) || ([message isEqual:[NSNull null]])) {
                                       localNotification.userInfo = [NSDictionary dictionaryWithObject:[[region.identifier componentsSeparatedByString:@"#"] objectAtIndex:1] forKey:@"url"];
                                   } else {
                                       localNotification.userInfo = [NSDictionary dictionaryWithObject:url forKey:@"url"];
                                   }
                                   
                                   localNotification.soundName = UILocalNotificationDefaultSoundName;
                                   localNotification.applicationIconBadgeNumber = 0;
                                   
                                   [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
                               }
                           }
                           break;
                           default:
                           {
                                NSLog(@"######## Error response code: %d", code);
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

@end
