//
//  ZoneManagerConsumer.h
//  iotbeacon
//
//  Created by Vladimir on 06/02/16.
//  Copyright © 2016 BIS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IBZoneManager.h"

@interface ZoneManagerConsumer : NSObject<IBZoneMonitoringConsumer>

@property (strong) NSString* consumerId;
@property (strong) NSArray* zones;

@property (assign) IB2ZoneSortRule sortRule;

@end