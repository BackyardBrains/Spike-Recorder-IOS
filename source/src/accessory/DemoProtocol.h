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

#define BOARD_WITH_EVENT_INPUTS 0
#define BOARD_WITH_ADDITIONAL_INPUTS 1
#define BOARD_WITH_HAMMER 4
#define BOARD_WITH_JOYSTICK 5

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
- (void)setInputBlock:(EAInputBlock)block;
//+ (EAInputBlock)getInputBlock;
-(void) initProtocol;
@property (atomic, copy) EAInputBlock inputBlock;
-(void) setSampleRate:(int) inSampleRate numberOfChannels:(int) inNumberOfChannels andResolution:(int) resolution;



- (void) sendCommandGetAdc;
- (void) askForBoardType;
- (void) setP300Active:(bool) active;
- (void) setP300AudioActive:(bool) active;
- (void) askForP300AudioState;
- (void) askForP300State;
- (void) askForImportantStates;
- (bool) getP300State;
- (bool) getP300AudioState;
- (int)  getCurrentExpansionBoard;
- (int)  numberOfChannels;
- (int)  sampleRate;
- (bool) shouldRestartDevice;
- (void) deviceRestarted;
- (void) setHardwareHighGainActive:(BOOL) state;
- (void) setHardwareHPFActive:(BOOL) state;

@end
