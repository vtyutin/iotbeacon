//
//  SettingsController.m
//  iotbeacon
//
//  Created by Vladimir on 18/01/16.
//  Copyright © 2016 BIS. All rights reserved.
//

#import "SettingsController.h"
#import "AppDelegate.h"
#import <stdlib.h>
#import <objc/runtime.h>
#import "AppDelegate.h"
#import "BeaconSettingsController.h"

@interface SettingsController ()
@property(weak, nonatomic) NSMutableArray *beacons;
@end

@implementation SettingsController
@synthesize beacons;
@synthesize settingsTable;

-(void)viewDidLoad {
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.beacons = ((AppDelegate*)[[UIApplication sharedApplication] delegate]).beacons;
    [settingsTable reloadData];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [beacons count];
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *tableIdentifier = @"BeaconTableCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:tableIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:tableIdentifier];
    }
    
    UILabel *label = (UILabel*)[cell viewWithTag:1];
    
    NSDictionary *dict = [beacons objectAtIndex:[indexPath row]];
    
    NSString *title = [NSString stringWithFormat:@"%@ (%d, %d)", [dict valueForKey:@"udid"], [[dict valueForKey:@"major"] intValue], [[dict valueForKey:@"minor"] intValue]];
    
    [label setText:title];
    [tableView setRowHeight:(label.frame.size.height + 15.0f)];
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *dict = [beacons objectAtIndex:[indexPath row]];
    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main" bundle: nil];
    
    //UIViewController *sourceViewController = self.parentViewController;
    UINavigationController* mainController = self.navigationController;
    
    BeaconSettingsController* beaconController = (BeaconSettingsController*)[mainStoryboard instantiateViewControllerWithIdentifier:@"BeaconSettingsController"];
    beaconController.beaconDictionary = dict;
    beaconController.indexPath = indexPath;
    [mainController pushViewController:beaconController animated:YES];
}

/*
-(void)textFieldDidEndEditing:(UITextField *)textField {
    int row = [objc_getAssociatedObject(textField, @"line_id") intValue];
    NSLog(@"row updated: %@", textField.text);
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[beacons objectAtIndex:row]];
    switch ([textField tag]) {
        case 1:
            [dict setValue:textField.text forKey:@"udid"];
            break;
        case 2:
            [dict setValue:[NSNumber numberWithInt:[textField.text intValue]] forKey:@"major"];
            break;
        case 3:
            [dict setValue:[NSNumber numberWithInt:[textField.text intValue]] forKey:@"minor"];
            break;
        case 4:
            [dict setValue:textField.text forKey:@"url"];
            break;
        case 5:
            [dict setValue:textField.text forKey:@"message"];
            break;
        case 6:
            [dict setValue:textField.text forKey:@"leaving_url"];
            break;
        case 7:
            [dict setValue:textField.text forKey:@"leaving_message"];
            break;
    }
    [beacons replaceObjectAtIndex:row withObject:dict];
    
    NSLog(@"updated settings: %@", beacons);
    
    NSString* arrayPath;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if ([paths count] > 0)
    {
        arrayPath = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"updated_settings.plist"];
        [beacons writeToFile:arrayPath atomically:YES];
    }
}
*/
@end
