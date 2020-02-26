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
#define PROTOCOL_PAYLOAD_SIZE   1024
#define PROTOCOL_PACKET_SIZE    (PROTOCOL_HEADER_SIZE + PROTOCOL_PAYLOAD_SIZE)

#define SIZE_OF_CIRC_BUFFER 4024
#define SIZE_OF_MESSAGES_BUFFER 64
#define ESCAPE_SEQUENCE_LENGTH 6

const uint8_t kHeaderBytes[] = {0xCA, 0x5C};

@implementation DemoProtocol {
    NSUInteger _packetLength;
    uint8_t _packet[PROTOCOL_PACKET_SIZE];
    float floatDataPacket[PROTOCOL_PACKET_SIZE];
    char circularBuffer[SIZE_OF_CIRC_BUFFER];
    float obuffer[PROTOCOL_PACKET_SIZE*2];
    bool weAreInsideEscapeSequence;
    char messagesBuffer[SIZE_OF_MESSAGES_BUFFER];//contains payload inside escape sequence
    int messageBufferIndex;
    unsigned int escapeSequence[ESCAPE_SEQUENCE_LENGTH];
    unsigned int endOfescapeSequence[ESCAPE_SEQUENCE_LENGTH];
    int escapeSequenceDetectorIndex;
    int _samplingRate;
    int _numberOfChannels;
    std::string firmwareVersion;
    std::string hardwareVersion;
    std::string hardwareType;
    
}
static  EAInputBlock inputBlock;

/*+ (void)setInputBlock:(EAInputBlock)block
{
    inputBlock = block;
}
+ (EAInputBlock)getInputBlock
{
    return inputBlock;
}*/
- (id)init
{
    self = [super init];//initWithProtocol:@"com.silabs.demo"];
   // DemoProtocol.inputBlock = nil;
    if (self) {
        escapeSequence[0] = 255;
        escapeSequence[1] = 255;
        escapeSequence[2] = 1;
        escapeSequence[3] = 1;
        escapeSequence[4] = 128;
        escapeSequence[5] = 255;
        
        endOfescapeSequence[0] = 255;
        endOfescapeSequence[1] = 255;
        endOfescapeSequence[2] = 1;
        endOfescapeSequence[3] = 1;
        endOfescapeSequence[4] = 129;
        endOfescapeSequence[5] = 255;
        weAreInsideEscapeSequence = false;
        messageBufferIndex =0;
        escapeSequenceDetectorIndex = 0;
        _samplingRate = 10000;
        _numberOfChannels = 2;
    }
    return self;
}

-(void) initProtocol
{
     [super initWithProtocol:@"com.backyardbrains.sbpro"];
    weAreInsideEscapeSequence = false;
    messageBufferIndex =0;
    escapeSequenceDetectorIndex = 0;
    _samplingRate = 10000;
    _numberOfChannels = 2;
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
    
    int numOfFrames = [self processData:bytes withSize:len];
    
    if(numOfFrames>0)
    {
       // [[BBAudioManager bbAudioManager] addNewData:obuffer frames:numOfFrames channels:2];
        self.inputBlock(obuffer,numOfFrames, 2);
    }
        //
    //}
    

}


//
// Process raw data from serial port
// Extract frames and extract samples from frames
//
-(int) processData:(uint8_t * ) buffer withSize:(int) size
{
    int numberOfFrames = 0;
    int obufferIndex = 0;
    int writeInteger = 0;
    // std::cout<<"------------------ Size: "<<size<<"\n";
    
    
    for(int i=0;i<size;i++)
    {
        if(weAreInsideEscapeSequence)
        {
            messagesBuffer[messageBufferIndex] = buffer[i];
            messageBufferIndex++;
        }
        else
        {
            circularBuffer[cBufHead++] = buffer[i];
            //uint debugMSB  = ((uint)(buffer[i])) & 0xFF;
            //std::cout<<"M: " << debugMSB<<"\n";
            
            if(cBufHead>=SIZE_OF_CIRC_BUFFER)
            {
                cBufHead = 0;
            }
        }
        [self testEscapeSequence:(((unsigned int) buffer[i]) & 0xFF) withOffset:((i/2)/_numberOfChannels)];
    }
    if(size==-1)
    {
        return -1;
    }
    uint LSB;
    uint MSB;
    bool haveData = true;
    bool weAlreadyProcessedBeginingOfTheFrame;
    int numberOfParsedChannels;
    while (haveData)
    {
        
        MSB  = ((uint)(circularBuffer[cBufTail])) & 0xFF;
        
        if(MSB > 127)//if we are at the begining of frame
        {
            weAlreadyProcessedBeginingOfTheFrame = false;
            numberOfParsedChannels = 0;
            if([self checkIfHaveWholeFrame])
            {
                //std::cout<<"Inside serial "<< numberOfFrames<<"\n";
                numberOfFrames++;
                while (1)
                {
                    //make sample value from two consecutive bytes
                    // std::cout<<"Tail: "<<cBufTail<<"\n";
                    //  MSB  = ((uint)(circularBuffer[cBufTail])) & 0xFF;
                    //std::cout<< cBufTail<<" -M "<<MSB<<"\n";
                    
                    
                    MSB  = ((uint)(circularBuffer[cBufTail])) & 0xFF;
                    if(weAlreadyProcessedBeginingOfTheFrame && MSB>127)
                    {
                        //we have begining of the frame inside frame
                        //something is wrong
                        numberOfFrames--;
                        break;//continue as if we have new frame
                    }
                    MSB  = ((uint)(circularBuffer[cBufTail])) & 0x7F;
                    weAlreadyProcessedBeginingOfTheFrame = true;
                    
                    cBufTail++;
                    if(cBufTail>=SIZE_OF_CIRC_BUFFER)
                    {
                        cBufTail = 0;
                    }
                    LSB  = ((uint)(circularBuffer[cBufTail])) & 0xFF;
                    //if we have error in frame (lost data)
                    if(LSB>127)
                    {
                        numberOfFrames--;
                        break;//continue as if we have new frame
                    }
                    // std::cout<< cBufTail<<" -L "<<LSB<<"\n";
                    LSB  = ((uint)(circularBuffer[cBufTail])) & 0x7F;
                    
                    MSB = MSB<<7;
                    writeInteger = LSB | MSB;
                    //  if(writeInteger>300)
                    //  {
                    //      logData = true;
                    //  }
                    
                    
                    numberOfParsedChannels++;
                    if(numberOfParsedChannels>2)
                    {
                        //we have more data in frame than we need
                        //something is wrong with this frame
                        numberOfFrames--;
                        break;//continue as if we have new frame
                    }
                    
                    obuffer[obufferIndex++] = ((float)(writeInteger-512))/512.0;
                    
                    
                    if([self areWeAtTheEndOfFrame])
                    {
                        break;
                    }
                    else
                    {
                        cBufTail++;
                        if(cBufTail>=SIZE_OF_CIRC_BUFFER)
                        {
                            cBufTail = 0;
                        }
                    }
                }
            }
            else
            {
                haveData = false;
                break;
            }
        }
        if(!haveData)
        {
            break;
        }
        cBufTail++;
        if(cBufTail>=SIZE_OF_CIRC_BUFFER)
        {
            cBufTail = 0;
        }
        if(cBufTail==cBufHead)
        {
            haveData = false;
            break;
        }
        
        
    }
    
    return numberOfFrames;
}


-(bool)checkIfNextByteExis
{
    int tempTail = cBufTail + 1;
    if(tempTail>= SIZE_OF_CIRC_BUFFER)
    {
        tempTail = 0;
    }
    if(tempTail==cBufHead)
    {
        return false;
    }
    return true;
}

-(bool) checkIfHaveWholeFrame
{
    int tempTail = cBufTail + 1;
    if(tempTail>= SIZE_OF_CIRC_BUFFER)
    {
        tempTail = 0;
    }
    while(tempTail!=cBufHead)
    {
        uint nextByte  = ((uint)(circularBuffer[tempTail])) & 0xFF;
        if(nextByte > 127)
        {
            return true;
        }
        tempTail++;
        if(tempTail>= SIZE_OF_CIRC_BUFFER)
        {
            tempTail = 0;
        }
    }
    return false;
}

-(bool) areWeAtTheEndOfFrame
{
    int tempTail = cBufTail + 1;
    if(tempTail>= SIZE_OF_CIRC_BUFFER)
    {
        tempTail = 0;
    }
    uint nextByte  = ((uint)(circularBuffer[tempTail])) & 0xFF;
    if(nextByte > 127)
    {
        return true;
    }
    return false;
}



// Detect start-of-message escape sequence and end-of-message sequence
// and set up weAreInsideEscapeSequence.
// When we detect end-of-message sequence call executeContentOfMessageBuffer()
//
-(void) testEscapeSequence:(unsigned int) newByte withOffset: (int) offset
{
    
    
    
    if(weAreInsideEscapeSequence)
    {
        
        if(messageBufferIndex>=SIZE_OF_MESSAGES_BUFFER)
        {
            weAreInsideEscapeSequence = false; //end of escape sequence
            [self executeContentOfMessageBuffer:offset];
            escapeSequenceDetectorIndex = 0;//prepare for detecting begining of sequence
        }
        else if(endOfescapeSequence[escapeSequenceDetectorIndex] == newByte)
        {
            escapeSequenceDetectorIndex++;
            if(escapeSequenceDetectorIndex ==  ESCAPE_SEQUENCE_LENGTH)
            {
                weAreInsideEscapeSequence = false; //end of escape sequence
                [self executeContentOfMessageBuffer:offset];
                escapeSequenceDetectorIndex = 0;//prepare for detecting begining of sequence
            }
        }
        else
        {
            escapeSequenceDetectorIndex = 0;
        }
        
    }
    else
    {
        if(escapeSequence[escapeSequenceDetectorIndex] == newByte)
        {
            escapeSequenceDetectorIndex++;
            if(escapeSequenceDetectorIndex ==  ESCAPE_SEQUENCE_LENGTH)
            {
                weAreInsideEscapeSequence = true; //found escape sequence
                for(int i=0;i<SIZE_OF_MESSAGES_BUFFER;i++)
                {
                    messagesBuffer[i] = 0;
                }
                messageBufferIndex = 0;//prepare for receiving message
                escapeSequenceDetectorIndex = 0;//prepare for detecting end of esc. sequence
                
                //rewind writing head and effectively delete escape sequence from data
                for(int i=0;i<ESCAPE_SEQUENCE_LENGTH;i++)
                {
                    cBufHead--;
                    if(cBufHead<0)
                    {
                        cBufHead = SIZE_OF_CIRC_BUFFER-1;
                    }
                }
            }
        }
        else
        {
            escapeSequenceDetectorIndex = 0;
        }
    }
    
}

//
// Parse and check what we need to do with message that we received
// from microcontroller
//
-(void) executeContentOfMessageBuffer:(int) offset
{
    bool stillProcessing = true;
    int currentPositionInString = 0;
    char message[SIZE_OF_MESSAGES_BUFFER];
    for(int i=0;i<SIZE_OF_MESSAGES_BUFFER;i++)
    {
        message[i] = 0;
    }
    int endOfMessage = 0;
    int startOfMessage = 0;
    
    
    
    while(stillProcessing)
    {
        //std::cout<<"----- MB: "<< currentPositionInString<<"     :"<<messagesBuffer<<"\n";
        if(messagesBuffer[currentPositionInString]==';')
        {
            //we have message, parse it
            for(int k=0;k<endOfMessage-startOfMessage;k++)
            {
                if(message[k]==':')
                {
                    
                    std::string typeOfMessage(message, k);
                    std::string valueOfMessage(message+k+1, (endOfMessage-startOfMessage)-k-1);
                    [self executeOneMessageWithType:typeOfMessage value:valueOfMessage offset:offset];
                    //executeOneMessage(typeOfMessage, valueOfMessage, offset);
                    break;
                }
            }
            startOfMessage = endOfMessage+1;
            currentPositionInString++;
            endOfMessage++;
            
        }
        else
        {
            message[currentPositionInString-startOfMessage] = messagesBuffer[currentPositionInString];
            currentPositionInString++;
            endOfMessage++;
            
        }
        
        if(currentPositionInString>=SIZE_OF_MESSAGES_BUFFER)
        {
            stillProcessing = false;
        }
    }
    
    //free(message);
    
}


-(void) executeOneMessageWithType: (std::string) typeOfMessage  value:(std::string) valueOfMessage offset: (int) offsetin
{

    if(typeOfMessage == "FWV")
    {
        firmwareVersion = valueOfMessage;
    }
    if(typeOfMessage == "HWT")
    {
        hardwareType = valueOfMessage;
    }
    
    if(typeOfMessage == "HWV")
    {
        hardwareVersion = valueOfMessage;
    }
    
    if(typeOfMessage == "PWR")
    {
       // _powerRailState = (int)((unsigned int)valueOfMessage[0]-48);
    }
    
    if(typeOfMessage == "EVNT")
    {
        int mnum = (int)((unsigned int)valueOfMessage[0]-48);
        int64_t offset = 0;
        /* if(!_manager.fileMode())
         {
         offset = _audioView->offset();
         }*/
        
       //[ _manager->addMarker(std::string(1, mnum+'0'), offset+offsetin);]
        [[BBAudioManager bbAudioManager] addEvent:mnum withOffset:offsetin];
        
    }
    if(typeOfMessage == "JOY")
    {
       

    }
    if(typeOfMessage == "BRD")
    {
       
     /*   currentAddOnBoard = (int)((unsigned int)valueOfMessage[0]-48);
        if(currentAddOnBoard == BOARD_WITH_ADDITIONAL_INPUTS)
        {
            //if(_samplingRate != 7500)
            //{
            _samplingRate = 5000;
            _numberOfChannels  =4;
            restartDevice = true;
            //}
        }
        else if(currentAddOnBoard == BOARD_WITH_HAMMER)
        {
            _samplingRate = 5000;
            _numberOfChannels  =3;
            restartDevice = true;
        }
        else if(currentAddOnBoard == BOARD_WITH_JOYSTICK)
        {
            _samplingRate = 5000;
            _numberOfChannels  =3;
            restartDevice = true;
        }
        else
        {
            
            
            if(_samplingRate != 10000)
            {
                _samplingRate = 10000;
                _numberOfChannels  =2;
                restartDevice = true;
            }
        }*/
    }
    if(typeOfMessage == "RTR")
    {
       /* if(((int)((unsigned int)valueOfMessage[0]-48)) == 1)
        {
            _rtReapeating = true;
        }
        else
        {
            _rtReapeating = false;
        }*/
    }
    if(typeOfMessage == "MSF")
    {
        //TODO: implement maximum sample rate
    }
    if(typeOfMessage == "MNC")
    {
        //TODO: implement maximum number of channels
    }
    
}









@end
