//
//  Equipment.h
//  ceilingFan
//
//  Created by zhiweiMiao on 16/3/4.
//  Copyright © 2016年 zhiwei Miao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface Equipment : NSObject

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *mac;
@property (nonatomic, strong) CBPeripheral *peripheral;
@property (nonatomic, strong) NSData *macData;

@end
