//
//  DemoProtocol.h
//  SilabsMfiDemo1
//
//  Copyright (c) 2013-2014 Silicon Labs. All rights reserved.
//
// This program and the accompanying materials are made available under the
// terms of the Silicon Laboratories Software License which accompanies this
// distribution.  Please refer to the License.txt file that is located in the
// root directory of this software package.
//

#import <Foundation/Foundation.h>
#import "DemoAccessory.h"

// The protocol extends the DemoAccessory base class
//  - The base clase controls the accessory and I/O streams
//  - The protocol implements the specific protocol on the I/O streams
@interface DemoProtocol : DemoAccessory

@property int adcValue;
@property uint8_t ledState;
@property uint8_t capVolumeState;

typedef void (^EAInputBlock)(float *data, UInt32 numFrames, UInt32 numChannels);
// Explicitly declaring the block setters will create the correct block signature for auto-complete.
// These will map to the setters for the block properties below.
+ (void)setInputBlock:(EAInputBlock)block;
+ (EAInputBlock)getInputBlock;

- (void)getGpioState;
- (void)setGpioState:(uint8_t)gpio;
- (void)setCapVolume:(uint8_t)volume andRelease:(uint8_t)release;
- (void)sendCommandGetAdc;

@end
