//
//  BluetoothManager.m
//  ceilingFan
//
//  Created by zhiweiMiao on 16/3/3.
//  Copyright © 2016年 zhiwei Miao. All rights reserved.
//

#import "ZWBluetoothManager.h"
#import "ER.h"

//#define STATE @"00010203-0405-0607-0809-0A0B0C0D1911"

//#define OTA @"00010203-0405-0607-0809-0A0B0C0D1913"
//#define PAIR @"00010203-0405-0607-0809-0a0b0c0d1914"

// 服务码
#define SERVE @"FFF0"
// 获取和写入分数的特征码
#define COMMAND @"FFF1"


@interface ZWBluetoothManager () <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (nonatomic, strong) NSMutableArray *delegateArr;

@property (nonatomic, strong) NSTimer *connectTimer;
@property (nonatomic, assign) BOOL disConnetByUser;
@property (nonatomic, strong) CBCentralManager *manager;
//@property (nonatomic, strong) CBCharacteristic *ERcharacteristic;
@property (nonatomic, strong) CBCharacteristic *commandCharacteristic;
@property (nonatomic, strong) CBCharacteristic *stateCharacteristic;
@property (nonatomic, strong) NSTimer *timerForGetEquipmentState;

@end

@implementation ZWBluetoothManager

#pragma mark - 单例
/*
 *
 *创建BluetoothManager单例
 *可以根据情况, 使用被注释的代码, 将CBCentralManager放进子线程
 *如果这样做, 回调的时候记得返回子线程
 *
 */

+ (instancetype)shareBluetoothManager {
    static ZWBluetoothManager *bluetoothManager = nil;
    static dispatch_once_t onceTask;
    dispatch_once(&onceTask, ^{
        if (bluetoothManager == nil) {
            bluetoothManager = [[ZWBluetoothManager alloc] init];
//            dispatch_queue_t queue = dispatch_queue_create("queue", DISPATCH_QUEUE_SERIAL);
            bluetoothManager.manager = [[CBCentralManager alloc] initWithDelegate:bluetoothManager queue:nil];
        }
    });
    return bluetoothManager;
}

#pragma mark - 连接流程
#pragma mark -- 扫描设备
/*
 *通知CBCentralManager扫描设备
 *
 *
 */

- (void)scanEquipment {
//    [self.allEquipmentsArr removeAllObjects];
//    if (self.connectedEquipment) {
//        [self.allEquipmentsArr addObject:self.connectedEquipment];
//    }
    [self.manager scanForPeripheralsWithServices:nil options:nil];
}

- (void)stopScan {
    [self.manager stopScan];
}

#pragma mark -- 发现设备的回调
/*
 *
 *发现设备的回调方法
 *平时使用peripheral操作蓝牙, 使用mac区分设备
 *所以创建设备Model的时候保存这两个属性
 *方法里面添加了多次扫描时, 获得相同设备的过滤代码, 确保allEquipmentsArr里面不会同一个设备出现两次
 *在这里使用(发现设备)的代理方法 bluetoothManager:didDiscoverEquipment:
 *
 */

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
    if ([(NSString *)advertisementData[@"kCBAdvDataLocalName"] isEqualToString:@"ScoreBoard"]) {
        NSString *mac = [self stringFromData:advertisementData[@"kCBAdvDataManufacturerData"]];
        BOOL isUseable = 1;
        for (Equipment *equipment in self.allEquipmentsArr) {
            if ([equipment.mac isEqualToString:mac]) {
                isUseable = 0;
                break;
            }
        }
        if (isUseable) {
            Equipment *equipment = [[Equipment alloc] init];
            equipment.macData = advertisementData[@"kCBAdvDataManufacturerData"];
//            if (equipment.macData == nil) {
//                int g = 0;
//                equipment.macData = [NSData dataWithBytes:&g length:6];
//            }
            equipment.mac = mac;
            equipment.name = advertisementData[@"kCBAdvDataLocalName"];
            equipment.peripheral = peripheral;
            [self.allEquipmentsArr addObject:equipment];
            
            for (id<ZWBluetoothManagerDelegate> delegate in self.delegateArr) {
                if (delegate && [delegate respondsToSelector:@selector(bluetoothManager:didDiscoverEquipment:)]) {
                    [delegate bluetoothManager:self didDiscoverEquipment:equipment];
                }
            }
        }
    }
}


#pragma mark -- 连接设备
/*
 *通知CBCentralManager连接设备
 *并且开启定时器, 如果4秒内没有连接成功, 代表连接超时, 使用(连接超时)的代理方法:bluetoothManager:connectTimeoutWithEquipment:
 *
 */

- (void)connect:(Equipment *)equipment {
    [self disConnect];
    [self.manager connectPeripheral:equipment.peripheral options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey]];
    self.connectTimer = [NSTimer scheduledTimerWithTimeInterval:4 target:self selector:@selector(connectTimeOut:) userInfo:equipment repeats:NO];
//    self.connectTimer = [NSTimer timerWithTimeInterval:4 target:self selector:@selector(connectTimeOut:) userInfo:equipment repeats:NO];
//    [[NSRunLoop mainRunLoop] addTimer:self.connectTimer forMode:NSRunLoopCommonModes];
}


#pragma mark -- 设备 被连接 的回调
/*
 *
 *CBCentralManager成功连接设备的回调方法
 *关闭连接定时器
 *通知CBCentralManager停止扫描
 *保存被连接设备到connectedEquipment
 *使用(设备连接成功)的代理方法: bluetoothManager:didConnectEquipment:
 *开始扫描服务discoverServices
 *
 */

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    [self.connectTimer invalidate];
    
    [self.manager stopScan];
    peripheral.delegate = self;
    [peripheral discoverServices:nil];
    
    self.disConnetByUser = NO;
    
    for (Equipment *equipment in self.allEquipmentsArr) {
        if ([equipment.peripheral isEqual:peripheral]) {
            self.connectedEquipment = equipment;
            break;
        }
    }
    
    for (id<ZWBluetoothManagerDelegate> delegate in self.delegateArr) {
        if (delegate && [delegate respondsToSelector:@selector(bluetoothManager:didConnectEquipment:)]) {
            [delegate bluetoothManager:self didConnectEquipment:self.connectedEquipment];
        }
    }

}


#pragma mark -- 发现服务 的回调
/*
 *
 *CBCentralManager(发现服务)的回调方法
 *匹配UUID, 找到我们需要的服务后, 让CBCentralManager发现特征码
 *
 *
 */

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    for (CBService *service in peripheral.services) {
        if ([service.UUID isEqual:[CBUUID UUIDWithString:SERVE]]) {
            [peripheral discoverCharacteristics:nil forService:service];
            break;
        }
    }
}


#pragma mark -- 发现 特征码 的回调
/*
 *
 *CBCentralManager(发现特征码)的回调方法
 *匹配UUID, 找到我们需要的接口保存下来, 以后发送指令
 *PAIR为我使用的加密接口, COMMAND为我使用的公共指令接口, STATE为我使用的获取状态接口, 按需修改
 *
 */

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    for (CBCharacteristic *characteristic in service.characteristics) {
//        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:PAIR]]) {
//            self.ERcharacteristic = characteristic;
//            [peripheral writeValue:[[ER shareER] preER:@"telink_mesh1"] forCharacteristic:self.ERcharacteristic type:CBCharacteristicWriteWithResponse];
////            [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(preER:) userInfo:peripheral repeats:YES];
//        }
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:COMMAND]]) {
            self.commandCharacteristic = characteristic;
            [peripheral setNotifyValue:YES forCharacteristic:self.commandCharacteristic];
            [peripheral readValueForCharacteristic:self.commandCharacteristic];
        }
//        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:STATE]]) {
//            self.stateCharacteristic = characteristic;
//            [peripheral setNotifyValue:YES forCharacteristic:self.stateCharacteristic];
//        }
    }
}


/*
 *
 *加密注册不成功时设置的循环注册, 一般情况下不需要
 *
 */


//- (void)preER:(NSTimer *)timer {
//    [timer.userInfo writeValue:[[ER shareER] preER:@"telink_mesh1"] forCharacteristic:self.ERcharacteristic type:CBCharacteristicWriteWithResponse];
//}


#pragma mark -- 设备 状态发生改变 时 的回调
/*
 *
 *该方法不是实现会崩溃
 *设备状态(是否被连接)更新时的回调, 按需要添加代码
 *
 */
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    
}


#pragma mark -- 连接超时 的回调
/*
 *
 *定时器的绑定方法, 如果4秒内没有连接成功, 代表连接超时, 使用(连接超时)的代理方法:bluetoothManager:connectTimeoutWithEquipment:
 *
 */

- (void)connectTimeOut:(NSTimer *)timer {
    for (id<ZWBluetoothManagerDelegate> delegate in self.delegateArr) {
        if (delegate && [delegate respondsToSelector:@selector(bluetoothManager:connectTimeoutWithEquipment:)]) {
            [self.manager cancelPeripheralConnection:((Equipment *)timer.userInfo).peripheral];
            [delegate bluetoothManager:self connectTimeoutWithEquipment:timer.userInfo];
        }
    }
}


#pragma mark -- 用户 主动断开连接
/*
 *
 *用户主动断开连接
 *设置标志位, 与意外断开区分开来
 *
 */
- (void)disConnect {
    self.disConnetByUser = YES;
    if (self.connectedEquipment.peripheral) {
        [self.manager cancelPeripheralConnection:self.connectedEquipment.peripheral];
    }
}


#pragma mark -- 断开连接之后 的回调
/*
 *
 *设备断开时的回调方法
 *将被连接设备connectedEquipment置为空
 *使用(设备断开连接)的回调方法:bluetoothManager:didDisconnectEquipment:byUser:
 *
 */
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    self.connectedEquipment = nil;
    
    [self.manager scanForPeripheralsWithServices:nil options:nil];
    
    Equipment *disconnectEquipment;
    
    for (Equipment *equipment in self.allEquipmentsArr) {
        if ([equipment.peripheral isEqual:peripheral]) {
            disconnectEquipment = equipment;
        }
    }
    
    for (id<ZWBluetoothManagerDelegate> delegate in self.delegateArr) {
        if (delegate && [delegate respondsToSelector:@selector(bluetoothManager:didDisconnectEquipment:byUser:)]) {
            [delegate bluetoothManager:self didDisconnectEquipment:disconnectEquipment byUser:self.disConnetByUser];
        }
    }
    
}


#pragma mark - 数据处理部分
/*
 *
 *接收到数据的回调方法
 *根据不同的接口(UUID)做出不同的反应和操作
 *在该事例中ERcharacteristic接口用来接收加密通讯的密码, 用以以后通讯
 *stateCharacteristic接口用来接收回调的 状态数据, 并且使用(获取到状态的回调方法)
 *bluetoothManager:didGetEquipmentRedTeamScore:blueTeamScore:progress:
 *按需修改
 *
 */

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if ([characteristic.UUID isEqual:self.commandCharacteristic.UUID]) {
        
        NSData *stateData = characteristic.value;
        int redTeamScore = 0;
        [stateData getBytes:&redTeamScore range:NSMakeRange(0, 1)];
        int blueTeamScore = 0;
        [stateData getBytes:&blueTeamScore range:NSMakeRange(1, 1)];
        int progress = 0;
        [stateData getBytes:&progress range:NSMakeRange(2, 1)];
        
        for (id<ZWBluetoothManagerDelegate> delegate in self.delegateArr) {
            if (delegate && [delegate respondsToSelector:@selector(bluetoothManager:didGetEquipmentRedTeamScore:blueTeamScore:progress:)]) {
                [delegate bluetoothManager:self didGetEquipmentRedTeamScore:redTeamScore blueTeamScore:blueTeamScore progress:progress];
            }
        }
    }
}

/*
 *
 *写入数据后的回调方法
 *回调时主动读取加密接口的数据
 *部分接口返回数据需要主动去读取
 *
 *
 */
//- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
//    if ([characteristic.UUID isEqual:self.ERcharacteristic.UUID]) {
//        [peripheral readValueForCharacteristic:characteristic];
//    }
//}


/*
 *
 *向设备写入指令的方法, 按需修改
 *
 */

- (void)writeValueWithHEXStr:(NSString *)HEXStr {
//    long number1 = strtol([[HEXStr substringFromIndex:12] UTF8String], nil, 16);
//    long number2 = strtol([[HEXStr substringToIndex:12] UTF8String], nil, 16);
//    NSMutableData *data = [[NSMutableData alloc] init];
////    NSString *str = @"06010211e2000000001311";
//    static int a = 0;
//    [data appendBytes:&a length:1];
//    a++;
//    
//    [data appendBytes:&number1 length:6];
//    [data appendBytes:&number2 length:6];
    
    long longNumber = strtol([HEXStr UTF8String], nil, 16);
    NSData *data = [NSData dataWithBytes:&longNumber length:3];

    if (self.commandCharacteristic) {
        [self.connectedEquipment.peripheral writeValue:data forCharacteristic:self.commandCharacteristic type:CBCharacteristicWriteWithResponse];
    }
}

//- (void)refreshData {
//    [self.allEquipmentsArr removeAllObjects];
//}


#pragma mark - private methods

/*
 *
 *将 data类型的mac 转化为 String类型的mac 作为设备的唯一标示
 *
 */

- (NSString *)stringFromData:(NSData *)data {
    return [NSString stringWithFormat:@"%@", data];
}

/*
 *
 *为了方便使用调用, 提供多个页面同时使用该manager的机制
 *通过delegateArr实现同时有多个delegate的需求
 *
 */

- (void)addDelegate:(id<ZWBluetoothManagerDelegate>)delegate {
//    __weak typeof(delegate) weakDelegate = delegate;
    [self.delegateArr addObject:delegate];
}

/*
 *
 *从delegateArr中移除delegate, 解除强引用
 *
 *
 */

- (void)removeDelegate:(id<ZWBluetoothManagerDelegate>)delegate {
    if ([self.delegateArr containsObject:delegate]) {
        [self.delegateArr removeObject:delegate];
    }
}

- (BOOL)isDelegateArrContains:(id<ZWBluetoothManagerDelegate>)delegate {
    return [self.delegateArr containsObject:delegate];
}


#pragma mark - getter and setter
- (NSMutableArray *)allEquipmentsArr {
    if (!_allEquipmentsArr) {
        _allEquipmentsArr = [[NSMutableArray alloc] init];
    }
    return _allEquipmentsArr;
}

- (NSMutableArray *)delegateArr {
    if (!_delegateArr) {
        _delegateArr = [[NSMutableArray alloc] init];
    }
    return _delegateArr;
}


//- (void)setDelegate:(id<ZWBluetoothManagerDelegate>)delegate {
//    _delegate = delegate;
//}

@end
