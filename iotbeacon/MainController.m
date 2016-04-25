//
//  MainController.m
//  iotbeacon
//
//  Created by Vladimir on 14/01/16.
//  Copyright © 2016 BIS. All rights reserved.
//

#import "MainController.h"
#import "AppDelegate.h"
#import <objc/runtime.h>
#import "WebViewController.h"
#import "ZoneManagerConsumer.h"
#import "SettingsController.h"
#import "AFHTTPRequestOperationManager.h"

@interface MainController ()
@end

@implementation MainController
@synthesize zoneButton;
@synthesize messageView;
@synthesize webView;
@synthesize loadingIndicator;


#define GET_VERSION_SERVICE_URL @"http://uliyneron.no-ip.org/ibeacon/version.php"
//#define MAIN_PAGE_URL @"http://smarthouse.gdknn.ru/nnbis/easyshop/appinterface.php"
#define MAIN_PAGE_URL @"http://uliyneron.no-ip.org/ibeacon"

- (void)viewDidLoad {
    [super viewDidLoad];        
    
    [zoneButton setHidden:YES];
    
    NSUUID *uuid = ((AppDelegate*)[[UIApplication sharedApplication] delegate]).uuid;
    NSLog(@"UUID: %@", [uuid UUIDString]);
    
    NSURL *nsurl = [NSURL URLWithString:[NSString stringWithFormat:@"%@?uid=%@", MAIN_PAGE_URL, [uuid UUIDString]]];
    NSURLRequest *requestObj = [NSURLRequest requestWithURL:nsurl];
    [webView setScalesPageToFit:YES];
    [webView setDelegate:self];
    [webView loadRequest:requestObj];
    [loadingIndicator startAnimating];
}

- (void)webViewDidFinishLoad:(UIWebView *)wView
{
    NSLog(@"is loading: %d", wView.isLoading);
    if (!wView.isLoading) {
        [loadingIndicator stopAnimating];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [self performSelectorInBackground:@selector(checkDataVersion) withObject:nil];
}

- (void)checkDataVersion {
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
                          [self loadNewData:pathToVersion forVersion:version];
                      }
                  }
                  failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                      NSLog(@"######## Error: %@", [error description]);
                      UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"can't connect server. Please check your network." delegate:nil cancelButtonTitle:@"ok" otherButtonTitles:nil];
                      [alert show];
                  }
     ];
}

- (void)loadNewData:(NSString*)pathToData forVersion:(NSInteger)version {
    [messageView setHidden:NO];
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
                      [self storeData:newBeaconsArray forVersion:version];
                  }
                  failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                      [messageView setHidden:YES];
                      NSLog(@"######## Error: %@", [error description]);
                      UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"can't connect server. Please check your network." delegate:nil cancelButtonTitle:@"ok" otherButtonTitles:nil];
                      [alert show];
                  }
     ];
}

- (void)storeData:(NSMutableArray*)updatedBeacons forVersion:(NSInteger)version {
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
    
    [messageView setHidden:YES];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (IBAction)settingButtonPressed:(id)sender {
    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main" bundle: nil];
    SettingsController* settingsController = (SettingsController*)[mainStoryboard instantiateViewControllerWithIdentifier:@"SettingsViewController"];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:settingsController];
    [navigation setNavigationBarHidden:YES];
    [navigation setModalTransitionStyle:UIModalTransitionStyleCoverVertical];
    [self presentViewController:navigation animated:YES completion:nil];
}

- (IBAction)registryButtonPressed:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)zoneButtonPressed:(id)sender {
    NSString *url = objc_getAssociatedObject(sender, @"url");
    if (url != nil) {
        UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main" bundle: nil];
        UINavigationController* mainController = self.navigationController;
        WebViewController* webController = (WebViewController*)[mainStoryboard instantiateViewControllerWithIdentifier:@"WebViewController"];
        webController.url = url;
        [mainController popToViewController:[[mainController viewControllers] objectAtIndex:1] animated:NO];
        [mainController pushViewController:webController animated:NO];
    }
}

- (void)leavingZone:(id<IBZone>)zone {
    [zoneButton setTitle:@"" forState:UIControlStateNormal];
    objc_setAssociatedObject(zoneButton, @"url", nil, OBJC_ASSOCIATION_COPY);
    [zoneButton setHidden:YES];
}

- (void)enteringZone:(id<IBZone>)zone {
    [zoneButton setTitle:[NSString stringWithFormat:@"Текущая зона: %@", [[zone.identifier componentsSeparatedByString:@"#"] objectAtIndex:0]] forState:UIControlStateNormal];
    objc_setAssociatedObject(zoneButton, @"url", [[zone.identifier componentsSeparatedByString:@"#"] objectAtIndex:1], OBJC_ASSOCIATION_COPY);
    [zoneButton setHidden:NO];

}

- (void)leavingRegion:(CLBeaconRegion*)region {/*
    [zoneButton setTitle:@"" forState:UIControlStateNormal];
    objc_setAssociatedObject(zoneButton, @"url", nil, OBJC_ASSOCIATION_COPY);
    [zoneButton setHidden:YES];*/
}

- (void)enteringRegion:(CLBeaconRegion*)region {
    /*
    [zoneButton setTitle:[NSString stringWithFormat:@"Текущая зона: %@", [[region.identifier componentsSeparatedByString:@"#"] objectAtIndex:0]] forState:UIControlStateNormal];
    objc_setAssociatedObject(zoneButton, @"url", [[region.identifier componentsSeparatedByString:@"#"] objectAtIndex:1], OBJC_ASSOCIATION_COPY);
    [zoneButton setHidden:NO];*/
}

@end
