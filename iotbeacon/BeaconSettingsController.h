//
//  BeaconSettingsController.h
//  iotbeacon
//
//  Created by Vladimir on 29/02/16.
//  Copyright © 2016 BIS. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BeaconSettingsController : UIViewController <UITextFieldDelegate>
@property (weak, nonatomic) IBOutlet UITextField *udidTextField;
@property (weak, nonatomic) IBOutlet UITextField *majorTextField;
@property (weak, nonatomic) IBOutlet UITextField *minorTextField;
@property (weak, nonatomic) IBOutlet UITextField *enterURLTextField;
@property (weak, nonatomic) IBOutlet UITextField *enterMessageTextField;
@property (weak, nonatomic) IBOutlet UITextField *exitUrlTextField;
@property (weak, nonatomic) IBOutlet UITextField *exitMessageTextField;
@property (strong, nonatomic) NSDictionary *beaconDictionary;
@property (strong, nonatomic) NSIndexPath* indexPath;
- (IBAction)cancelButtonPressed:(id)sender;
- (IBAction)okButtonPressed:(id)sender;
@end
