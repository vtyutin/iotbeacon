//
//  UserData.h
//  iotbeacon
//
//  Created by Vladimir on 14/01/16.
//  Copyright © 2016 BIS. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UserData : NSObject
@property (retain, nonatomic) NSString* lastName;
@property (retain, nonatomic) NSString* firstName;
@property (retain, nonatomic) NSString* middleName;
@property (retain, nonatomic) NSString* email;
@property (retain, nonatomic) NSString* occupation;
@property (retain, nonatomic) NSDate* birthDate;
@property (retain, nonatomic) NSNumber* userId;
@end
