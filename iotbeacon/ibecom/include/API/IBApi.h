//
//  IBApi.h
//  IBApi
//
//  Created by Alexey Shcherbinin on 14.10.14.
//  Copyright (c) 2014 iBecom. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IBZoneManager.h"
#import "IBLocationManager.h"
#import "IBRangingManager.h"
#import "IBError.h"

@interface IBApi : NSObject
+ (NSString*) versionString;

+ (IBError*) initApiWithData:(id)data andKey:(NSString *)key;

+ (id<IBZoneManager>) zoneManager;
+ (id<IBLocationManager>) locationManager;
+ (id<IBRangingManager>) rangingManager;

+ (void)releaseApi;
+ (BOOL)isInitialized;
@end
