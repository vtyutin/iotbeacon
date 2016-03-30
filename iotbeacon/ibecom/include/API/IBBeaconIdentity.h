//
//  IBBeaconIdentity.h
//  IBApi
//
//  Created by Alexey Shcherbinin on 27.10.14.
//  Copyright (c) 2014 iBecom. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol IBBeaconIdentity <NSObject>
@property NSString* identifier;
@property NSUUID* proximityUUID;
@property NSNumber* major;
@property NSNumber* minor;
@end
