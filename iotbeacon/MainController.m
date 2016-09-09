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
#import "SettingsController.h"
#import "AFHTTPRequestOperationManager.h"
#import "Reachability.h"

@interface MainController ()
@property (strong, nonatomic) UIAlertView *alert;
@property (strong, nonatomic) NSString *currentRegionURL;
@property (strong, nonatomic) UIAlertController *alertController;
@end

@implementation MainController
@synthesize zoneButton;
@synthesize messageView;
@synthesize webView;
@synthesize loadingIndicator;
@synthesize buttonsView;
@synthesize alert;
@synthesize navigationButton;
@synthesize currentRegionURL;
@synthesize beaconInfoLabel;
@synthesize alertController;

#define BUTTONS_VIEW_OFFSET 15
#define ALLWAYS_LOAD_DATA 0
#define SHOW_DEBUG_DATA 0

int buttonState;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    for (id subview in webView.subviews) {
        if ([[subview class] isSubclassOfClass: [UIScrollView class]]) {
            ((UIScrollView *)subview).bounces = NO;
            ((UIScrollView *)subview).delegate = self;
        }
        if ([subview respondsToSelector:@selector(setMultipleTouchEnabled:)]) {
            [subview setMultipleTouchEnabled:NO];
        }
    }
    webView.scalesPageToFit = NO;
    webView.multipleTouchEnabled = NO;
    
    [loadingIndicator setColor:[UIColor lightGrayColor]];
    
    [beaconInfoLabel setText:@""];
    [beaconInfoLabel setNumberOfLines:100];
    [beaconInfoLabel setHidden:SHOW_DEBUG_DATA == 0 ? YES : NO];
    
    [zoneButton setHidden:YES];
    self.alert = nil;
    self.alertController = nil;
    [self checkConnection:nil];
    [navigationButton setHidden:YES];
    buttonState = 0;
    [buttonsView setHidden:YES];
    
    UISwipeGestureRecognizer* rightSwipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipedForward:)];
    rightSwipe.direction = UISwipeGestureRecognizerDirectionLeft;
    //[webView addGestureRecognizer:rightSwipe];
    
    UISwipeGestureRecognizer* leftSwipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipedBack:)];
    leftSwipe.direction = UISwipeGestureRecognizerDirectionRight;
    //[webView addGestureRecognizer:leftSwipe];
    
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(navigationButtonPressed:)];
    [navigationButton addGestureRecognizer:tapRecognizer];
    [navigationButton setUserInteractionEnabled:YES];
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return nil;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (void)updateBeaconInfoLabel:(NSString*)text {
    [self.beaconInfoLabel setText:text];
}

- (void)navigationButtonPressed:(UITapGestureRecognizer*)recognizer {
    AppDelegate *app = ((AppDelegate*)[[UIApplication sharedApplication] delegate]);
    switch ([navigationButton tag]) {
        case 1:
            if ([app.currentRegions count] > 0) {
                [self showRegionUrl:(CLBeaconRegion*)[app.currentRegions lastObject]];
            }
            break;
        case 2:
            [self resetToHomePage];
            break;
    }
}

- (void)swipedBack:(UISwipeGestureRecognizer*)recognizer {
    if ([webView canGoBack]) {
        [webView goBack];
    }
}

- (void)swipedForward:(UISwipeGestureRecognizer*)recognizer {
    if ([webView canGoForward]) {
        [webView goForward];
    }
}

- (void)loadUrl:(NSString*)url {
    if ((url != nil) && (![url isEqual:[NSNull null]])) {
        self.currentRegionURL = url;
        NSURL *nsurl = [NSURL URLWithString:url];
        NSMutableURLRequest *requestObj = [NSMutableURLRequest requestWithURL:nsurl];
        [requestObj setTimeoutInterval:30];
        [webView setScalesPageToFit:YES];
        [webView setDelegate:self];
        [webView loadRequest:requestObj];
    }
}

- (void)checkConnection:(NSString*)url
{
    //Reachability* reachability = [Reachability reachabilityWithHostName:MAIN_PAGE_URL];
    Reachability* reachability = [Reachability reachabilityForInternetConnection];
    NetworkStatus remoteHostStatus = [reachability currentReachabilityStatus];
    if (remoteHostStatus == NotReachable) {
        if (alert == nil) {
            [loadingIndicator stopAnimating];
            [self hideButtons];
            self.alert = [[UIAlertView alloc] initWithTitle:@"" message:@"Проверьте соединение с интернетом. Повторить попытку." delegate:self cancelButtonTitle:@"ok" otherButtonTitles:@"отмена", nil];
            [alert show];
        }
    } else {
        if (url != nil) {
            [self loadUrl:url];
        } else {
            [self resetToHomePage];
        }
    }
}

- (void)resetToHomePage {
    NSUUID *uuid = ((AppDelegate*)[[UIApplication sharedApplication] delegate]).uuid;
    NSString *username = LOGIN;
    NSString *password = PASSWORD;
    NSString *postString = [NSString stringWithFormat:@"%@:%@",username, password];
    NSString *authString = [NSString stringWithFormat: @"Basic %@", postString];
    NSString *url = [NSString stringWithFormat:@"%@?uid=%@", MAIN_PAGE_URL, [uuid UUIDString]];
    NSMutableURLRequest *mutableRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url]];
    [mutableRequest setValue:authString forHTTPHeaderField:@"Authorization"];
    NSURLCredential *newCredential = [NSURLCredential credentialWithUser:username password:password persistence:NSURLCredentialPersistenceForSession];
    NSURLCredentialStorage *credentialStorage = [NSURLCredentialStorage sharedCredentialStorage];
    [credentialStorage setCredential:newCredential forProtectionSpace:[[NSURLProtectionSpace alloc] initWithHost:@"uliyneron.no-ip.org" port:80 protocol:@"http" realm:@"NNBIS Server login" authenticationMethod:NSURLAuthenticationMethodHTTPBasic]];
    
    [mutableRequest setTimeoutInterval:30];
    [webView setScalesPageToFit:YES];
    [webView setDelegate:self];
    [webView loadRequest:mutableRequest];
    
}

- (void)viewWillAppear:(BOOL)animated {
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat screenWidth = screenRect.size.width;
    CGFloat screenHeight = screenRect.size.height;
    CGFloat frameW, frameH, frameX, frameY;
    frameW = screenWidth / 7.0;
    frameH = frameW * 3.0;
    frameX = screenWidth - BUTTONS_VIEW_OFFSET;
    frameY = (screenHeight / 2.0) - (frameH / 2.0);
    [buttonsView setFrame:CGRectMake(frameX, frameY, frameW, frameH)];
    
    if ([[buttonsView gestureRecognizers] count] == 0) {
        UITapGestureRecognizer *recognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(buttonsViewPressed)];
        [buttonsView addGestureRecognizer:recognizer];
    }
    buttonsView.userInteractionEnabled = YES;
    

}

- (void)buttonsViewPressed {
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat screenWidth = screenRect.size.width;
    if (buttonsView.frame.origin.x == (screenWidth - BUTTONS_VIEW_OFFSET)) {
        [self showButtons];
    } else {
        [self hideButtons];
    }
}

- (void)hideButtons {
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat screenWidth = screenRect.size.width;
    buttonsView.userInteractionEnabled = NO;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.5];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(viewAnimationDidStop:finished:context:)];
    buttonsView.frame = CGRectMake(screenWidth - BUTTONS_VIEW_OFFSET, buttonsView.frame.origin.y, buttonsView.frame.size.width, buttonsView.frame.size.height);
    [UIView commitAnimations];
}

- (void)showButtons {
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat screenWidth = screenRect.size.width;
    buttonsView.userInteractionEnabled = NO;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.5];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(viewAnimationDidStop:finished:context:)];
    buttonsView.frame = CGRectMake(screenWidth - buttonsView.frame.size.width, buttonsView.frame.origin.y, buttonsView.frame.size.width, buttonsView.frame.size.height);
    [UIView commitAnimations];
}

- (void)viewAnimationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
    buttonsView.userInteractionEnabled = YES;
}

-(void)webViewDidStartLoad:(UIWebView *)webView {
    [loadingIndicator startAnimating];
    [self hideButtons];
}

- (void)webViewDidFinishLoad:(UIWebView *)wView
{
    if (!wView.isLoading) {
        [loadingIndicator stopAnimating];
        [self hideButtons];
        
        [self updateButtonState];
    }
    // Disable user selection
    [webView stringByEvaluatingJavaScriptFromString:@"document.documentElement.style.webkitUserSelect='none';"];
    // Disable callout
    [webView stringByEvaluatingJavaScriptFromString:@"document.documentElement.style.webkitTouchCallout='none';"];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    [loadingIndicator stopAnimating];
    [self hideButtons];
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
                      if ((storedVersion == nil) || ((storedVersion != nil) && ([storedVersion integerValue] != version)) || (ALLWAYS_LOAD_DATA == 1)) {
                          [self loadNewData:pathToVersion forVersion:version];
                      }
                  }
                  failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                      NSLog(@"######## Error: %@", [error description]);
                  }
     ];
}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) {
        [self checkConnection:nil];
    }
    self.alert = nil;
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
                      
                      [self storeData:newBeaconsArray forVersion:version];
                  }
                  failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                      [messageView setHidden:YES];
                      NSLog(@"######## Error: %@", [error description]);                      
                  }
     ];
}

- (void)storeData:(NSMutableArray*)updatedBeacons forVersion:(NSInteger)version {
    AppDelegate* app = ((AppDelegate*)[[UIApplication sharedApplication] delegate]);
    [app storeData:updatedBeacons forVersion:version withCompletionHandler:nil];
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
        [self checkConnection:url];
    }
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

- (IBAction)homeButtonPressed:(id)sender {
    [self checkConnection:nil];
}

- (IBAction)beaconButtonPressed:(id)sender {
    AppDelegate *app = ((AppDelegate*)[[UIApplication sharedApplication] delegate]);
    if ([app.currentRegions count] > 0) {
        [self showRegionUrl:(CLBeaconRegion*)[app.currentRegions lastObject]];
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Внимание" message:@"Вы вне зоны действия маяков iBeacon" preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                             handler:^(UIAlertAction * action)
                             {
                                 [alert dismissViewControllerAnimated:YES completion:nil];
                             }];
        [alert addAction:ok];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

-(void) showRegionUrl:(CLBeaconRegion *)region {
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
    
    NSDictionary *requestDict = [NSDictionary dictionaryWithObjectsAndKeys:region.major, @"major", region.minor, @"minor", [region.proximityUUID.UUIDString lowercaseString], @"udid", 0, @"uid", nil];
    
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
                                   NSString *url = [data objectForKey:@"enter_url"];
                                   if (url != nil) {
                                       [self checkConnection:url];
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

- (void)updateButtonState {
    
    if ([[[[webView request] URL] absoluteString] hasPrefix:@"http://uliyneron.no-ip.org/"]) {
        AppDelegate *app = ((AppDelegate*)[[UIApplication sharedApplication] delegate]);
        if ([app.currentRegions count] > 0) {
            [self showButton:YES];
        } else {
            [navigationButton setHidden:YES];
            buttonState = 0;
        }
    } else {
        if ([self.currentRegionURL length] > 0) {
            [self showButton:NO];
        }
    }
}

- (void)showButton:(BOOL)active {
    if ((active == YES) && (buttonState == 2)) {
        return;
    }
    if ((active == NO) && (buttonState == 1)) {
        return;
    }
    
    buttonState = active ? 2 : 1;
    
    NSMutableArray *images = [NSMutableArray array];
    if (active) {
        for (int index = 1; index <= 14; index++) {
            [images addObject:[UIImage imageNamed:[NSString stringWithFormat:@"btnBIShop%d", index]]];
        }
    } else {
        for (int index = 14; index >= 1; index--) {
            [images addObject:[UIImage imageNamed:[NSString stringWithFormat:@"btnBIShop%d", index]]];
        }
    }
    [navigationButton setAnimationImages:images];
    [navigationButton setAnimationDuration:1];
    [navigationButton setAnimationRepeatCount:1];
    [navigationButton setImage:[UIImage imageNamed:active ? @"btnBIShop14" : @"btnBIShop1"]];
    [navigationButton setTag:active ? 1 : 2];
    [navigationButton setHidden:NO];
    [navigationButton startAnimating];
}

- (void)showEnterAlertWithMessage:(NSString*) message andURL:(NSString*)url {
    if (alertController != nil) {
        [alertController dismissViewControllerAnimated:YES completion:^(void) {
            self.alertController = nil;
            [self showEnterAlertWithMessage:message andURL:url];
        }];
    }
    
    NSString *alertTitle = @"";
    NSString *alertMessage = @"";
    NSArray *components = [message componentsSeparatedByString:@":"];
    if (components.count >= 2) {
        alertTitle = components[0];
        alertMessage = components[1];
    } else {
        alertMessage = message;
    }
    
    self.alertController = [UIAlertController alertControllerWithTitle:alertTitle
                                        message:alertMessage
                                 preferredStyle:UIAlertControllerStyleAlert];
    NSMutableAttributedString *hogan = [[NSMutableAttributedString alloc] initWithString:@"Ok"];
    [hogan addAttribute:NSFontAttributeName
                  value:[UIFont systemFontOfSize:50.0]
                  range:NSMakeRange(0, 2)];
    
    UIAlertAction* yesButton = [UIAlertAction actionWithTitle:@"Ок" style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * action)
                                {
                                    [self loadUrl:url];
                                    [alertController dismissViewControllerAnimated:YES completion:^(void) {
                                        self.alertController = nil;
                                        [self showEnterAlertWithMessage:message andURL:url];
                                    }];
                                }];
    
    UIAlertAction* noButton = [UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * action)
                               {
                                   [alertController dismissViewControllerAnimated:YES completion:^(void) {
                                       self.alertController = nil;
                                       [self showEnterAlertWithMessage:message andURL:url];
                                   }];
                               }];
    [alertController addAction:noButton];
    [alertController addAction:yesButton];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

@end
