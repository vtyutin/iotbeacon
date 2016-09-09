//
//  ActiveRegion.h
//  BIShop
//
//  Created by Vladimir on 30/08/16.
//  Copyright © 2016 BIS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CLBeaconRegion.h>

@interface ActiveRegion : NSObject
@property (strong, nonatomic) CLBeacon *beacon;
@property (strong, nonatomic) CLBeaconRegion *region;
@property (nonatomic) BOOL isUpdated;

-(void)signalReceivedWithSsid:(NSInteger)ssid andAccurancy:(double)accurancy;
-(NSInteger)latestSignal;
-(NSInteger)measuredSignal;
-(BOOL)isCompleteMeasurement;
@end
