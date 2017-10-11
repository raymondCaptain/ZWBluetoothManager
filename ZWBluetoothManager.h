//
//  BluetoothManager.h
//  ceilingFan
//
//  Created by zhiweiMiao on 16/3/3.
//  Copyright © 2016年 zhiwei Miao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "Equipment.h"

@class ZWBluetoothManager;

@protocol ZWBluetoothManagerDelegate <NSObject>

@optional
// 发现到设备
// 只会发现之前没有被扫描到的设备(即只会回调新扫描到的设备), 因为方法中过滤了 allEquipmentsArr 中的设备
- (void)bluetoothManager:(ZWBluetoothManager *)bluetoothManager didDiscoverEquipment:(Equipment *)equipment;

// 连接上设备
- (void)bluetoothManager:(ZWBluetoothManager *)bluetoothManager didConnectEquipment:(Equipment *)equipment;

// 连接超时
- (void)bluetoothManager:(ZWBluetoothManager *)bluetoothManager connectTimeoutWithEquipment:(Equipment *)equipment;

// 断开设备后
- (void)bluetoothManager:(ZWBluetoothManager *)bluetoothManager didDisconnectEquipment:(Equipment *)equipment byUser:(BOOL)isByUser;

// 获取到数据
- (void)bluetoothManager:(ZWBluetoothManager *)bluetoothManager didGetEquipmentRedTeamScore:(int)redTeamScore blueTeamScore:(int)blueTeamScore progress:(int)progress;

@end

@interface ZWBluetoothManager : NSObject

//@property (nonatomic, weak) id<ZWBluetoothManagerDelegate> delegate;
@property (nonatomic, strong) NSMutableArray<Equipment *> *allEquipmentsArr;
@property (nonatomic, strong) Equipment *connectedEquipment;

// 添加代理之后需要移除, 否则会造成循环引用
- (void)addDelegate:(id<ZWBluetoothManagerDelegate>) delegate;
- (void)removeDelegate:(id<ZWBluetoothManagerDelegate>) delegate;
- (BOOL)isDelegateArrContains:(id<ZWBluetoothManagerDelegate>) delegate;

// 需要在 ZWBluetoothManager 初始化出来一段时间之后才可以 扫描设备, 否则扫描不到任何设备
+ (instancetype)shareBluetoothManager;

- (void)scanEquipment;
- (void)stopScan;
- (void)connect:(Equipment *)equipment;
- (void)disConnect;
- (void)writeValueWithHEXStr:(NSString *)HEXStr;
//- (void)writeValueWithHEXStr:(NSString *)HEXStr equipment:(Equipment *)equipment;
//- (void)refreshData;
//- (void)getEquipmentState;
@end
