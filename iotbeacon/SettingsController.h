//
//  SettingsController.h
//  iotbeacon
//
//  Created by Vladimir on 18/01/16.
//  Copyright © 2016 BIS. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SettingsController : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (weak, nonatomic) IBOutlet UITableView *settingsTable;
@end
