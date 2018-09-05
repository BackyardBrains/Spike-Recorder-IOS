//
//  DemoProtocol.m
//  SilabsMfiDemo1
//
//  Copyright (c) 2013-2014 Silicon Labs. All rights reserved.
//
// This program and the accompanying materials are made available under the
// terms of the Silicon Laboratories Software License which accompanies this
// distribution.  Please refer to the License.txt file that is located in the
// root directory of this software package.
//

#import "DemoProtocol.h"
#import "BBAudioManager.h"

#define P1_CMD_SET_APP_REV      0
#define P1_RSP_RET_ACC_REV      1
#define P1_CMD_SET_GPIO         2
#define P1_CMD_GET_GPIO         3
#define P1_RSP_RET_GPIO         4
#define P1_CMD_GET_ADC          5
#define P1_RSP_RET_ADC          6
#define P1_CMD_SET_CAP_VOLUME   7
#define P1_CMD_GET_CAP_VOLUME   8
#define P1_RSP_RET_CAP_VOLUME   9
#define P1_CMD_SND_DATE        10
#define P1_CMD_SND_TIME        11

#define PROTOCOL_HEADER_SIZE    2
#define PROTOCOL_PAYLOAD_SIZE   6
#define PROTOCOL_PACKET_SIZE    (PROTOCOL_HEADER_SIZE + PROTOCOL_PAYLOAD_SIZE)

const uint8_t kHeaderBytes[] = {0xCA, 0x5C};

@implementation DemoProtocol {
    NSUInteger _packetLength;
    uint8_t _packet[PROTOCOL_PACKET_SIZE];
    float floatDataPacket[PROTOCOL_PACKET_SIZE];
    
}
static  EAInputBlock inputBlock;

+ (void)setInputBlock:(EAInputBlock)block
{
    inputBlock = block;
}
+ (EAInputBlock)getInputBlock
{
    return inputBlock;
}
- (id)init
{
    self = [super initWithProtocol:@"com.silabs.demo"];
   // DemoProtocol.inputBlock = nil;
    if (self) {
        // Initialize properties
    }
    return self;
}

// Adds protocol header to payload, then queues the packet on the accessory
- (void)queuePacket:(uint8_t *)payload length:(NSUInteger)len
{
    NSMutableData *packet = [NSMutableData dataWithCapacity:(PROTOCOL_HEADER_SIZE + len)];

    [packet appendBytes:kHeaderBytes length:PROTOCOL_HEADER_SIZE];
    [packet appendBytes:payload length:len];
    [self queueTxData:packet];
}

- (void)getGpioState;
{
    uint8_t cmd[PROTOCOL_PAYLOAD_SIZE] = {P1_CMD_GET_GPIO, 0, 0, 0, 0, 0};

    [self queuePacket:cmd length:sizeof(cmd)];
}

- (void)setGpioState:(uint8_t)gpio
{
    uint8_t cmd[PROTOCOL_PAYLOAD_SIZE] = {P1_CMD_SET_GPIO, 0, 0, 0, 0, 0};

    cmd[1] = gpio;

    [self queuePacket:cmd length:sizeof(cmd)];
    [self addDebugString:[NSString stringWithFormat:@"setGpio: %x\n", gpio]];
}

- (void)setCapVolume:(uint8_t)volume andRelease:(uint8_t)release
{
    uint8_t cmd[PROTOCOL_PAYLOAD_SIZE] = {P1_CMD_SET_CAP_VOLUME, 0, 0, 0, 0, 0};

    cmd[1] = volume;
    cmd[2] = release ? 1 : 0;
    self.capVolumeState = volume;
    
    [self queuePacket:cmd length:sizeof(cmd)];
    [self addDebugString:[NSString stringWithFormat:@"setCapVolume: %d: %d\n", volume, release]];
}

- (void)sendCommandGetAdc
{
    uint8_t cmd[PROTOCOL_PAYLOAD_SIZE] = {P1_CMD_GET_ADC, 0, 0, 0, 0, 0};
    
    [self queuePacket:cmd length:sizeof(cmd)];
}

- (void)receiveResponseGetAdc:(uint8_t *)buf
{
    int adc = buf[2] * 256 + buf[1];
    if (adc < 0) {
        adc = 0;
    }
    self.adcValue = adc;
    //NSLog(@"%i",adc);
    //[self addDebugString:[NSString stringWithFormat:@"ADC= %d\n", self.adcValue]];
}

- (void)receiveResponseGpio:(uint8_t *)buf
{
    self.ledState = buf[1];
    [self addDebugString:[NSString stringWithFormat:@"GPIO: %x\n", self.ledState]];
}

- (void)receiveResponseCapVolume:(uint8_t *)buf
{
    self.capVolumeState = buf[1];
    [self addDebugString:[NSString stringWithFormat:@"SLIDER: %d\n", buf[1]]];
}

// This function is called for each response packet received
- (void)processPacket:(uint8_t *)payload length:(NSUInteger)len
{
    NSLog(@"Size %i",(unsigned long)len);
    // Process packet payload received from the accessory
    switch (payload[0])
    {
    case P1_RSP_RET_ACC_REV: // Accessory Ready
        // AccStatus = buf[1];
        // AccMajor = buf[2];
        // AccMinor = buf[3];
        // AccRev = buf[4];
        // BoardID = buf[5];
        break;

    case P1_RSP_RET_GPIO: // Return GPIO
        [self receiveResponseGpio:payload];
        break;

    case P1_RSP_RET_ADC: // Return ADC
        [self receiveResponseGetAdc:payload];
        break;

    case P1_RSP_RET_CAP_VOLUME: // Cap Volume
        [self receiveResponseCapVolume:payload];
        break;

    default: // Unknown response, ignore packet
            NSLog(@"Unknown");
        break;
    }
}

// Gathers a complete protocol packet from the input stream
- (void)processRxBytes:(uint8_t *)bytes length:(NSUInteger)len
{
    NSLog(@"Main length %i",(int)len);
    //if(inputBlock!=nil)
    //{
        for(int i=0;i<len;i++)
        {
            floatDataPacket[i] = (((float)bytes[i])-128)/128.0;
        }
    [[BBAudioManager bbAudioManager] addNewData:floatDataPacket frames:len channels:1];
        //inputBlock(floatDataPacket,len, 1);
    //}
    
/*
    // Reset the packet length if it is out of range
    if (_packetLength >= PROTOCOL_PACKET_SIZE) {
        _packetLength = 0;
    }
    // Handle packet framing (ie. search stream for header bytes)
    for (int i=0; i < len; i++) {
        _packet[_packetLength++] = bytes[i];
        if (_packetLength == 1) {
            if (_packet[0] != kHeaderBytes[0]) {
                _packetLength = 0;
            }
        }
        else if (_packetLength == 2) {
            if (_packet[1] != kHeaderBytes[1]) {
                _packetLength = 0;
            }
        }
        else if (_packetLength == PROTOCOL_PACKET_SIZE) {
            [self processPacket:&_packet[2] length:PROTOCOL_PAYLOAD_SIZE];
            _packetLength = 0;
        }
    }
    */
}

@end
