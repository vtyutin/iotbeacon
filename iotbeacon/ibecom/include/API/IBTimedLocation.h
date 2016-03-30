//
//  IBTimedLocation.h
//  IBApi
//
//  Created by Alexey Shcherbinin on 14.10.14.
//  Copyright (c) 2014 iBecom. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IBLocation.h"

@protocol IBTimedLocation <IBLocation>
@property long long timestamp;
@end
