//
//  BeaconSettingsController.m
//  iotbeacon
//
//  Created by Vladimir on 29/02/16.
//  Copyright © 2016 BIS. All rights reserved.
//

#import "BeaconSettingsController.h"
#import "AppDelegate.h"

@implementation BeaconSettingsController

@synthesize beaconDictionary;
@synthesize indexPath;
@synthesize udidTextField;
@synthesize majorTextField;
@synthesize minorTextField;
@synthesize enterURLTextField;
@synthesize enterMessageTextField;
@synthesize exitUrlTextField;
@synthesize exitMessageTextField;

-(void)viewDidLoad {
    [udidTextField setText:[beaconDictionary valueForKey:@"udid"]];
    [majorTextField setText:[NSString stringWithFormat:@"%d", [[beaconDictionary valueForKey:@"major"] integerValue]]];
    [minorTextField setText:[NSString stringWithFormat:@"%d", [[beaconDictionary valueForKey:@"minor"] integerValue]]];
    [enterURLTextField setText:[beaconDictionary valueForKey:@"url"]];
    [enterMessageTextField setText:[beaconDictionary valueForKey:@"message"]];
    [exitUrlTextField setText:[beaconDictionary valueForKey:@"leaving_url"]];
    [exitMessageTextField setText:[beaconDictionary valueForKey:@"leaving_message"]];
    
    [udidTextField setDelegate:self];
    [majorTextField setDelegate:self];
    [minorTextField setDelegate:self];
    [enterURLTextField setDelegate:self];
    [enterMessageTextField setDelegate:self];
    [exitMessageTextField setDelegate:self];
    [exitUrlTextField setDelegate:self];
}

- (IBAction)cancelButtonPressed:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)okButtonPressed:(id)sender {
    NSMutableArray *beacons = ((AppDelegate*)[[UIApplication sharedApplication] delegate]).beacons;
    int row = [indexPath row];
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:udidTextField.text forKey:@"udid"];
    [dict setValue:[NSNumber numberWithInt:[majorTextField.text intValue]] forKey:@"major"];
    [dict setValue:[NSNumber numberWithInt:[minorTextField.text intValue]] forKey:@"minor"];
    [dict setValue:enterURLTextField.text forKey:@"url"];
    [dict setValue:enterMessageTextField.text forKey:@"message"];
    [dict setValue:exitUrlTextField.text forKey:@"leaving_url"];
    [dict setValue:exitMessageTextField.text forKey:@"leaving_message"];
    [beacons replaceObjectAtIndex:row withObject:dict];
    
    NSLog(@"updated settings: %@", beacons);
    
    NSString* arrayPath;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if ([paths count] > 0)
    {
        arrayPath = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"updated_settings.plist"];
        [beacons writeToFile:arrayPath atomically:YES];
    }
    [((AppDelegate*)[[UIApplication sharedApplication] delegate]) reinitBeaconApi];
    [self.navigationController popViewControllerAnimated:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == udidTextField) {
        [majorTextField becomeFirstResponder];
    } else if (textField == majorTextField) {
        [minorTextField becomeFirstResponder];
    } else if (textField == minorTextField) {
        [enterURLTextField becomeFirstResponder];
    } else if (textField == enterURLTextField) {
        [enterMessageTextField becomeFirstResponder];
    } else if (textField == enterMessageTextField) {
        [exitUrlTextField becomeFirstResponder];
    } else if (textField == exitUrlTextField) {
        [exitMessageTextField becomeFirstResponder];
    } else if (textField == exitMessageTextField) {
        [self.view endEditing:TRUE];
    }
    return YES;
}

@end
