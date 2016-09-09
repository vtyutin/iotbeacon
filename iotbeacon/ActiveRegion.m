//
//  ActiveRegion.m
//  BIShop
//
//  Created by Vladimir on 30/08/16.
//  Copyright © 2016 BIS. All rights reserved.
//

#import "ActiveRegion.h"
#import "AppDelegate.h"

@interface ActiveRegion()
@property (nonatomic, strong) NSMutableArray *measures;
@property (nonatomic, strong) NSTimer *lostTimer;
@property (nonatomic, strong) NSTimer *loosingTimer;
@property (nonatomic, strong) NSNumber *loosingOffset;
@end

@implementation ActiveRegion
@synthesize beacon;
@synthesize region;
@synthesize measures;
@synthesize lostTimer;
@synthesize loosingTimer;
@synthesize isUpdated;
@synthesize loosingOffset;

#define AMOUNT_OF_MEASURES 3
#define LOST_TIMER_PERIOD 60

- (id) init {
    // Call superclass's initializer
    self = [super init];
    if( !self ) return nil;

    self.measures = [NSMutableArray array];
    self.loosingOffset = [NSNumber numberWithInteger:0];
    
    return self;
}

-(void)signalReceivedWithSsid:(NSInteger)ssid andAccurancy:(double)accurancy {
    if (ssid == 0) {
        return;
    }
    [lostTimer invalidate];
    [loosingTimer invalidate];
    self.loosingOffset = [NSNumber numberWithInteger:0];
    self.isUpdated = YES;
    if ([measures count] == AMOUNT_OF_MEASURES) {
        for (int index = 1; index < [measures count]; index++) {
            [measures replaceObjectAtIndex:index - 1 withObject:[measures objectAtIndex:index]];
        }
        [measures replaceObjectAtIndex:[measures count] - 1 withObject:[NSNumber numberWithInteger:ssid]];
    } else {
        [measures addObject:[NSNumber numberWithInteger:ssid]];
    }
    self.lostTimer = [NSTimer scheduledTimerWithTimeInterval:LOST_TIMER_PERIOD target:self selector:@selector(startLoosingBeacon) userInfo:nil repeats:NO];
}
                      
-(void)startLoosingBeacon {
    //[((AppDelegate*)[[UIApplication sharedApplication] delegate]) didLostRegion:self];
    self.loosingTimer = [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(loosingBeacon) userInfo:nil repeats:YES];
}

-(void)loosingBeacon {
    NSInteger loosing = [loosingOffset integerValue];
    loosing += 2;
    if ((-[[measures lastObject] integerValue] + loosing) >= 100) {
        //loosing = 0;
        [loosingTimer invalidate];
        [((AppDelegate*)[[UIApplication sharedApplication] delegate]) didExitBeaconRegion:self];
    }
    self.loosingOffset = [NSNumber numberWithInteger:loosing];
}

-(NSInteger)latestSignal {
    return [measures count] == 0 ? 0 : -[[measures lastObject] integerValue] + [loosingOffset integerValue];
}

-(NSInteger)measuredSignal {
    NSInteger signal = 0;
    if ([measures count] == 0) {
        return signal;
    }
    for (NSNumber *number in measures) {
        signal += -[number integerValue];
    }
    return signal / (AMOUNT_OF_MEASURES - ([measures count] - 1));
}

-(BOOL)isCompleteMeasurement {
    return [measures count] == AMOUNT_OF_MEASURES ? YES : NO;
}
@end
