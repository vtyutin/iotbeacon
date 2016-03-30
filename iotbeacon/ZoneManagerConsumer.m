//
//  ZoneManagerConsumer.m
//  iotbeacon
//
//  Created by Vladimir on 06/02/16.
//  Copyright © 2016 BIS. All rights reserved.
//

#import "ZoneManagerConsumer.h"
#import "IBBeacon.h"
#import "IBBeaconIdentity.h"

@implementation ZoneManagerConsumer

- (void) zoneManager:(id<IBZoneManager>)manager didChangedCurrentZone:(id<IBZone>)zone{
    NSLog(@"### zoneManager didChangedCurrentZone: %@ in state: %ld",zone, (long)zone.state);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"didChangedCurrentZone" object:zone];
}

- (void) zoneManager:(id<IBZoneManager>)manager didChangedCurrentZones:(NSArray*)zones{
    NSLog(@"### zoneManager didChangedCurrentZones %@",zones);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"didChangedCurrentZones" object:zones];
}

- (void) zoneManager:(id<IBZoneManager>)manager didFailWithError:(IBError*)error{
    //NSLog(@"### zoneManager didFailWithError %@",error);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"zoneManagerDidFailWithError" object:error];
}

- (void) zoneManager:(id<IBZoneManager>)manager didUpdateBeacons:(NSArray*)beacons {
    //NSLog(@"### zoneManager didUpdateBeacons count: %ld", (unsigned long)beacons.count);
    //[[NSNotificationCenter defaultCenter] postNotificationName:@"didUpdateBeacons" object:beacons];
}
@end
