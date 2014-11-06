//
//  BBBTManager.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 5/24/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ExternalAccessory/ExternalAccessory.h>
#define NO_BT_CONNECTION @"noBtConnection"
#define BT_DISCONNECTED @"btDisconnected"
#define BT_SLOW_CONNECTION @"btSlowConnection"
#define BT_BAD_CONNECTION @"btBadConnection"
#define FOUND_BT_CONNECTION @"foundBtConnection"
#define BT_WAIT_TO_CONNECT @"btWhaitToConnect"

typedef void (^BBBTInputBlock)(float *data, UInt32 numFrames, UInt32 numChannels);

@interface BBBTManager : NSObject  <EAAccessoryDelegate, NSStreamDelegate>

+ (BBBTManager *) btManager; //singleton

- (void)setInputBlock:(BBBTInputBlock)block;
@property (nonatomic, copy) BBBTInputBlock inputBlock;

@property (nonatomic, assign) int currentState;

- (float) currentBaudRate;

-(void) startBluetooth;
-(void) stopCurrentBluetoothConnection;
-(void) configBluetoothWithChannels:(int)inNumOfChannels andSampleRate:(int) inSampleRate;
-(void) needData:(float) timePeriod;
-(int) numberOfChannels;
-(int) samplingRate;
-(int) numberOfFramesBuffered;
-(int) maxNumberOfChannelsForDevice;
-(int) maxSampleRateForDevice;

@end
