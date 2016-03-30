//
//  IBBeacon.h
//  IBApi
//
//  Created by Alexey Shcherbinin on 27.10.14.
//  Copyright (c) 2014 iBecom. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IBBeaconIdentity.h"

@protocol IBBeacon <NSObject>
@property (readonly) id<IBBeaconIdentity> identity;

@property (readonly) float distance;
@property (readonly) float rssi;

@property BOOL available;
@end
