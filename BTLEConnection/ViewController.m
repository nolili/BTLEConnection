//
//  ViewController.m
//  BTLEConnection
//
//  Created by nori on 2013/05/21.
//  Copyright (c) 2013年 nori. All rights reserved.
//

#import "ViewController.h"

@interface ViewController () <CBCentralManagerDelegate, CBPeripheralDelegate>
{
    CBCentralManager *_centralManager;
    NSMutableArray   *_discoverdPeriperal;
    NSTimer          *_connectionTimer;
    NSMutableArray   *_connectingPeripheral;
}

@end

@implementation ViewController

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    }
    return self;
}

- (void)startScan
{
    NR_LOG(@"*********スキャン開始***********");
    NR_LOG();
    
    // スキャン開始から10秒後までに見つかったデバイスに接続を試みる
    _connectionTimer  = [NSTimer scheduledTimerWithTimeInterval:10.0 target:self selector:@selector(connectDiscoverdPeripheral:) userInfo:nil repeats:NO];
    
    // コンテナの初期化
    if (!_discoverdPeriperal){
        _discoverdPeriperal = [[NSMutableArray alloc] init];
    }
    
    if (!_connectingPeripheral){
        _connectingPeripheral = [[NSMutableArray alloc] init];
    }
    
    [_discoverdPeriperal removeAllObjects];
    [_connectingPeripheral removeAllObjects];
    
    // デバイスを探索，ここではサービスは指定しない場合を想定．
    // UIBackgroundModesにbluetooth-centralを指定するのであれば，サービスを指定すること．
    [_centralManager scanForPeripheralsWithServices:nil
                                            options:@{CBCentralManagerScanOptionAllowDuplicatesKey: @NO }];
}

- (void)connectDiscoverdPeripheral:(NSTimer *)timer
{
    NR_LOG();
    
    // スキャンを停止
    [_centralManager stopScan];
    
    // 発見したperipheralに対して
    for (CBPeripheral *peripheral in _discoverdPeriperal) {
        
        // 未接続で，接続を試みていなければ
        if (!peripheral.isConnected && ![_connectingPeripheral containsObject:peripheral]){
            
            // コンテナに格納して接続
            [_connectingPeripheral addObject:peripheral];
            [_centralManager connectPeripheral:peripheral options:nil];
        }
    }
    
    // 10秒後に接続をキャンセル開始
    [NSTimer scheduledTimerWithTimeInterval:10.0 target:self selector:@selector(disconnectAllPeripheral:) userInfo:nil repeats:NO];
}

- (void)disconnectAllPeripheral:(NSTimer *)timer
{
   
    for (CBPeripheral *p in _connectingPeripheral) {
        [_centralManager cancelPeripheralConnection:p];
    }
    
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NR_LOG(@"%@", peripheral);
    peripheral.delegate = self;
    [peripheral discoverServices:nil];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    NR_LOG(@"%@ %@", peripheral, error);
    if (!error){
        for (CBService *aService in peripheral.services) {
            [peripheral discoverCharacteristics:nil forService:aService];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    NR_LOG(@"%@ %@", peripheral, error);
    if (!error){
        NR_LOG(@"Characteristics found");
        // do something
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NR_LOG("%@ %@", peripheral, error);
    
    // コンテナからperipheralを削除
    if ([_connectingPeripheral containsObject:peripheral]){
        peripheral.delegate = nil;
        [_connectingPeripheral removeObject:peripheral];
    }
    
    // コンテナが空になれば
    if ([_connectingPeripheral count] == 0){
        
        // 5秒後にスキャンを再開
        // FIXME:(ここのディレイは何秒必要？)
        NR_LOG(@"すべての_connectingPeripheralとの接続がキャンセルできました．5秒後に接続を再開します");
        double delayInSeconds =5.0;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self startScan];
        });
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    
    if ( ![_discoverdPeriperal containsObject:peripheral] ){
        NR_LOG(@"%@", peripheral);
        [_discoverdPeriperal addObject:peripheral];
    }
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    CBCentralManagerState state = central.state;
    switch (state) {
        case CBCentralManagerStatePoweredOn:
            NSLog(@"CBCentralManagerStatePoweredOn");
            [self startScan];
            break;
        case CBCentralManagerStateResetting:
            NSLog(@"CBCentralManagerStateResetting!");
            break;
            
        default:
            break;
    }
}

@end
