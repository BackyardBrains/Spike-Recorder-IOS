//
//  BBBTManager.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 5/24/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "BBBTManager.h"
#import "RingBuffer.h"
//#define BT_PROTOCOL_STRING @"com.AmpedRFTech.Demo"
#define BT_PROTOCOL_STRING @"com.backyardbrains.ext.bt"
#define EAD_INPUT_BUFFER_SIZE 16384
#define NUMBER_OF_SECONDS_DELAY 1

static BBBTManager *btManager = nil;

@interface BBBTManager ()
{
    EAAccessory *_accessory;
    EASession *_session;
    NSMutableData *_readData;
    
    dispatch_source_t _baudRateTimer;
    int numberOfBytesReceivedInLastSec;
    float bitsPerSec;
    
    bool sendConfigData;
    int _confNumberOfChannels;
    int _confSamplingRate;
    bool connectToDevice; //Did we just connected to device
    bool deviceAlreadyDisconnected;
    RingBuffer *ringBuffer;
    bool bufferIsReady;
    BOOL measurementTimerShouldBeActive;
}

@end

@implementation BBBTManager

#pragma mark - Singleton Methods
+ (BBBTManager *) btManager
{
	@synchronized(self)
	{
		if (btManager == nil) {
			btManager = [[BBBTManager alloc] init];
		}
	}
    return btManager;
}

+ (id)allocWithZone:(NSZone *)zone {
    @synchronized(self) {
        if (btManager == nil) {
            btManager = [super allocWithZone:zone];
            return btManager;  // assignment and return on first allocation
        }
    }
    return nil; // on subsequent allocation attempts return nil
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)retain {
    return self;
}

- (unsigned)retainCount {
    return UINT_MAX;  // denotes an object that cannot be released
}

- (oneway void)release {
    //do nothing
}

#pragma mark - Initialization

- (id)init
{
    if (self = [super init])
    {
        ringBuffer = nil;
        self.inputBlock = nil;
        bufferIsReady = false;
        deviceAlreadyDisconnected = NO;
        measurementTimerShouldBeActive = NO;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_accessoryDidConnect:) name:EAAccessoryDidConnectNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_accessoryDidDisconnect:) name:EAAccessoryDidDisconnectNotification object:nil];
        [[EAAccessoryManager sharedAccessoryManager] registerForLocalNotifications];
        
        //Make timer for calculation of average baudrate
        _baudRateTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        if (_baudRateTimer)
        {
            numberOfBytesReceivedInLastSec = 0;
            dispatch_source_set_timer(_baudRateTimer, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), NSEC_PER_SEC, (1ull * NSEC_PER_SEC) / 10);
            dispatch_source_set_event_handler(_baudRateTimer, ^{

                bitsPerSec = ((float)numberOfBytesReceivedInLastSec)/1.0;
                //NSLog(@"Number of Bytes : %d", numberOfBytesReceivedInLastSec);
                if(numberOfBytesReceivedInLastSec>3000)
                {
                    measurementTimerShouldBeActive = YES;
                }
                if(measurementTimerShouldBeActive)
                {
                    if(numberOfBytesReceivedInLastSec<2000 && !deviceAlreadyDisconnected)
                    {
                        NSNotification *notification = [NSNotification notificationWithName:BT_SLOW_CONNECTION object:self];
                        [[NSNotificationCenter defaultCenter] postNotification:notification];
                    }
                }
                numberOfBytesReceivedInLastSec = 0;
                
                
            });
            dispatch_resume(_baudRateTimer);
        }
    }
    
    return self;
}


- (float) currentBaudRate
{
    return bitsPerSec;
}

#pragma mark - BT controll functions

//
// Start bluetooth procedure
//
-(void) startBluetooth
{
    connectToDevice = NO;
    _session = [self openSessionForProtocol:BT_PROTOCOL_STRING];
    numberOfBytesReceivedInLastSec = 0;
}

//
// Call for configuring BT sampling rate and number of channels on local and on remote BT
//
-(void) configBluetoothWithChannels:(int)inNumOfChannels andSampleRate:(int) inSampleRate
{
    _confSamplingRate = inSampleRate;
    _confNumberOfChannels = inNumOfChannels;

    NSLog(@"Start bluetooth with Num of channels: %d and Sample rate: %d", inNumOfChannels, inSampleRate);
    if(ringBuffer)
    {
        delete ringBuffer;
    }
    
    bufferIsReady = false;
    ringBuffer = new RingBuffer(2*NUMBER_OF_SECONDS_DELAY*inSampleRate, _confNumberOfChannels);
    sendConfigData = YES;
    [self writeDataFunc];
}

//
// Try to find accessory with our protocol. If it finds it it opens session if it doesn't find it
// than it opens accessory picker that shows paired (not connected) bluetooth accessories
// After user choses to connect to accessory it will open config popup
//
- (EASession *)openSessionForProtocol:(NSString *)protocolString
{
    NSArray *accessories = [[EAAccessoryManager sharedAccessoryManager]
                            connectedAccessories];
    
    NSLog(@"Enter open session for protocol");

    EASession *session = nil;
    BOOL foundAccessory = NO;
    //Try to find accessory that has our protocol
    for (EAAccessory *obj in accessories)
    {
        NSLog(@"We have accessory");
        NSLog(@"%@",obj);
        if ([[obj protocolStrings] containsObject:protocolString])
        {
            //if this accessory is the same accessory that we have been previously connected to
            //than... TODO: probably this is not needed now that we reset session
            if(_accessory == obj)
            {
                NSLog(@"Open same accessory");
                sendConfigData = YES;
            }
            NSLog(@"Did not open same accessory");
            _accessory = obj;
            foundAccessory = YES;
            //notify rest of the program that we have bluetooth. It will open config popup
            NSNotification *notification = [NSNotification notificationWithName:FOUND_BT_CONNECTION object:self];
            [[NSNotificationCenter defaultCenter] postNotification:notification];
            break;
        }
    }
    
    if (foundAccessory)
    {
        NSLog(@"Open new BT session **************************************");
        
        //If we found accessory create new sesion with it
        session = [[EASession alloc] initWithAccessory:_accessory
                                           forProtocol:protocolString];
        _session = session;
        
        //add run loop and init streams for the session
        if (session)
        {
            [[session inputStream] setDelegate:self];
            [[session inputStream] scheduleInRunLoop:[NSRunLoop currentRunLoop]
                                             forMode:NSDefaultRunLoopMode];
            [[session inputStream] open];
            
            [[session outputStream] setDelegate:self];
            [[session outputStream] scheduleInRunLoop:[NSRunLoop currentRunLoop]
                                              forMode:NSDefaultRunLoopMode];
            [[session outputStream] open];
        }
    }
    else
    {
        NSLog(@"No accessory found");
        
        //If we didn't find connected accessory that has our protocol
        //open picker that weill allow user to connect to paired devices
        connectToDevice = YES;
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"self CONTAINS 'BYB'"];
        [[EAAccessoryManager sharedAccessoryManager] showBluetoothAccessoryPickerWithNameFilter:nil completion:^(NSError *error) {
            //We don't do anything with response, just log
            //BT will dispatch connected event and than we will continue with creating session
            // and configuration popup
            if(error != nil)
            {
                if([error code] == EABluetoothAccessoryPickerResultCancelled)
                {
                    NSLog(@"Canceled accessory chooser.");
                }
                else if([error code] == EABluetoothAccessoryPickerResultNotFound)
                {
                    NSLog(@"Error EABluetoothAccessoryPickerResultNotFound  %@",[error description]);
                    NSNotification *notification = [NSNotification notificationWithName:BT_BAD_CONNECTION object:self];
                    [[NSNotificationCenter defaultCenter] postNotification:notification];
                }
                else
                {
                    NSLog(@"Error accessory chooser %@",[error description]);
                }
            }
            else
            {
                NSLog(@"Accessory chooser should connect on BT.....");
                //TODO: add notification that will inform rest of programm that we are waiting for connection
                // some view should display some spinner: connecting ... etc.
                
            }
        }];
        
    }
    
    return session;
}


//
// Close current session
// It also calls for stoping transmission on BT side
//
-(void)CloseSession
{
    [self stopTransmision];
	if(_session)
	{
		[[_session inputStream] removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
		[[_session inputStream] setDelegate:nil];
        [[_session inputStream] close];
		
		
		[[_session outputStream] removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
		[[_session outputStream] setDelegate:nil];
        [[_session outputStream] close];
        NSLog(@"Close BT session *******************************************");
        [_session release];
        
        _session = nil;
	}
}

//
// Public function for quiting BT session
//
-(void) stopCurrentBluetoothConnection
{
    NSLog(@"stopCurrentBluetoothConnection");
    if(_session)
    {
        [self CloseSession];
    }
}


//
// Called when we loose BT in range or similar.
//
- (void)_accessoryDidDisconnect:(NSNotification *)notification {
    
    NSLog(@"Accessory disconnected");

    if(!deviceAlreadyDisconnected)
    {

        deviceAlreadyDisconnected = YES;
        [self CloseSession];
        NSNotification *newnotification = [NSNotification notificationWithName:BT_DISCONNECTED object:self];
        [[NSNotificationCenter defaultCenter] postNotification:newnotification];
    }
}

- (void)_accessoryDidConnect:(NSNotification *)notification {
    deviceAlreadyDisconnected = NO;
    NSLog(@"Accessory connected");
    
    
    //If we just connected to device that find connected accessory and try to initialize session
    if(connectToDevice)
    {
        NSArray *accessories = [[EAAccessoryManager sharedAccessoryManager]
                                connectedAccessories];
        
        NSLog(@"Test if we have protocol");

        for (EAAccessory *obj in accessories)
        {
            NSLog(@"Test:");
            NSLog(@"%@",obj);
            if ([[obj protocolStrings] containsObject:BT_PROTOCOL_STRING])
            {
                NSLog(@"We found one accessory with our protocol string");
                connectToDevice = NO;
                _session = [self openSessionForProtocol:BT_PROTOCOL_STRING];
                numberOfBytesReceivedInLastSec = 0;
            }
        }
    }
    
}

// asynchronous NSStream handleEvent method
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    switch (eventCode) {
        case NSStreamEventNone:
            break;
        case NSStreamEventOpenCompleted:
            NSLog(@"NSStreamEventOpenCompleted");
            break;
        case NSStreamEventHasBytesAvailable:
            [self readDataFunc];
            break;
        case NSStreamEventHasSpaceAvailable:
            [self writeDataFunc];
            break;
        case NSStreamEventErrorOccurred:
            NSLog(@"NSStreamEventErrorOccurred");
            break;
        case NSStreamEventEndEncountered:
            NSLog(@"NSStreamEventEndEncountered");
            break;
        default:
            break;
    }
}


//
// Stream receive handler.
// It receives data, unpack frames and put it in circular buffer
// from which other part of code will pick up data
// on external periodic "needData" function call
//
- (void) readDataFunc {

    uint8_t buf[EAD_INPUT_BUFFER_SIZE];
    while ([[_session inputStream] hasBytesAvailable])
    {
        NSInteger bytesRead = [[_session inputStream] read:buf maxLength:EAD_INPUT_BUFFER_SIZE];
        if (_readData == nil) {
            _readData = [[NSMutableData alloc] init];
        }
        [_readData appendBytes:(void *)buf length:bytesRead];
        
        unsigned char * allBytes = (unsigned char *)[_readData mutableBytes];
        int startIndex = 0;
        numberOfBytesReceivedInLastSec += bytesRead;
        
        //find begining of frame
        for(int i=0;i<[_readData length]-1;i++)
        {
            if(allBytes[i]>= 0x80)
            {
                startIndex = i;
                break;
            }
            
        }
        uint LSB;
        uint MSB;
        int finalIntMeasure;
        float finalFloat;
        int indexInData;
        NSMutableArray * arrayOfFloats = [[NSMutableArray alloc] init];
        for(indexInData=startIndex;indexInData<[_readData length];indexInData=indexInData)
        {
            if(allBytes[indexInData]>= 0x80)
            {
                int numberOfBytesToEnd = [_readData length] - indexInData;
                if(_confNumberOfChannels*2>numberOfBytesToEnd)
                {
                    unsigned char * lastTwoBytes = &(allBytes[[_readData length]-numberOfBytesToEnd]);
                    [_readData replaceBytesInRange:NSMakeRange(0, numberOfBytesToEnd) withBytes:lastTwoBytes];
                    [_readData setLength:numberOfBytesToEnd];
                    break;
                }
                allBytes[indexInData] = allBytes[indexInData] & 0x7F;
                for(int by=0;by<_confNumberOfChannels;by++)
                {
                    MSB = allBytes[indexInData] & 0x7F;//take bits without flag
                    MSB = MSB<<7;
                    LSB  = allBytes[indexInData+1] & 0x7F;
                    finalIntMeasure = (int)(MSB|LSB);
                    finalFloat = ((float)finalIntMeasure-512)* 0.00322265625f;//3.3/1024
                    [arrayOfFloats addObject:[NSNumber numberWithFloat:finalFloat]];
                    indexInData=indexInData+2;
                }
            }
            else
            {
                //if not start of frame search it
                indexInData++;
            }
            
            //test code
            ///////////////////////////////////////////////////////////////////////////////////////////
           /*    finalIntMeasure = (int)allBytes[indexInData];
             finalFloat = ((float)finalIntMeasure)* 0.00322265625f;//3.3/1024
             [arrayOfFloats addObject:[NSNumber numberWithFloat:finalFloat]];
             if(allBytes[indexInData+1] -1 == allBytes[indexInData])
             {
                LSB = LSB;
             }
             else
             {
                 if(allBytes[indexInData]!=0xFF)
                 {
                     LSB = LSB;
                     NSLog(@"%02x",allBytes[indexInData]);
                     NSLog(@"%02x",allBytes[indexInData+1]);
                     NSLog(@"--------");
                 }
                 else
                 {
                    LSB = LSB;
                 }
             }
             indexInData++;
            ///////////////////////////////////////////////////////////////////////////////////////////
            */
        }
        

        //transform from NSArray to array of floats
        float * dataToLoad = (float *)calloc([arrayOfFloats count], sizeof(float));
        for(int i=0;i<[arrayOfFloats count];i++)
        {
            dataToLoad[i] = [[arrayOfFloats objectAtIndex:i] floatValue];
        }
        if(ringBuffer)
        {
            ringBuffer->AddNewInterleavedFloatData(dataToLoad, [arrayOfFloats count]/_confNumberOfChannels, _confNumberOfChannels);
            
            if(((float)(ringBuffer->NumUnreadFrames())/(float)_confSamplingRate)>NUMBER_OF_SECONDS_DELAY)
            {
                bufferIsReady = true;
            }
        }
        
        [arrayOfFloats removeAllObjects];
        [arrayOfFloats release];
        free(dataToLoad);
    }
}

//
//This should be called periodicaly from external timer etc.
// When it is called this function calls external self.inputBlock
// render block of code
//
-(void) needData:(float) timePeriod
{
    
    //TODO: We should use here real sampling rate and not configured
    //since real sampling rate depends on timer precision on micro side
    //that precision depends on temperature and other factors. Or we should send
    //corection parameter to micro that will change number in counter compare register
    UInt32 numberOfFrames = timePeriod*_confSamplingRate;
    
    
    float * dataToLoad = (float *)calloc(numberOfFrames*_confNumberOfChannels, sizeof(float));
    
    if(self.inputBlock!=nil)
    {
        if(bufferIsReady)
        {
            ringBuffer->FetchInterleavedData(dataToLoad, numberOfFrames, _confNumberOfChannels);
            self.inputBlock(dataToLoad, numberOfFrames, _confNumberOfChannels);
        }
        else
        {
            memset(dataToLoad, 0, numberOfFrames*_confNumberOfChannels*sizeof(float));
            self.inputBlock(dataToLoad, numberOfFrames, _confNumberOfChannels);
        }
    }
    //NSLog(@"S: %d", (int)ringBuffer->NumUnreadFrames());
    if(ringBuffer->NumUnreadFrames()<=0)
    {
        bufferIsReady = false;
    }
    
    free(dataToLoad);
}


-(int) numberOfFramesBuffered
{
    if(ringBuffer)
    {
        return (int)ringBuffer->NumUnreadFrames();
    }
    else
    {
        return 0;
    }
}

//
// Sends config data to BT
//
-(void) writeDataFunc
{
    if(!deviceAlreadyDisconnected)
    {
        if(sendConfigData)
        {
            sendConfigData = NO;
            
            int tempCounterNum = 16000000/_confSamplingRate;
            NSString *configString  = [NSString stringWithFormat:@"conf s:%d;c:%d;",tempCounterNum,_confNumberOfChannels];
            
            NSData *data = [configString dataUsingEncoding:NSUTF8StringEncoding];

            NSInteger bytesWritten = [[_session outputStream] write:(uint8_t *)[data bytes] maxLength:[data length]];
            
            if (bytesWritten == -1)
            {
                NSLog(@"BT config write error");
                
            }
            else if (bytesWritten > 0)
            {
                bytesWritten =bytesWritten;
            }
        }
    }
}

//
// Sends command to BT that will stop sampling and sending of data. It is important since
// we can't stop session if we don't stop sampling. Not sure why
//
-(void) stopTransmision
{
    measurementTimerShouldBeActive = NO;
    if(!deviceAlreadyDisconnected)
    {
        NSLog(@"Aend stop to BT");
        NSString *configString  = @"h:;";//halt
        
        NSData *data = [configString dataUsingEncoding:NSUTF8StringEncoding];
        
        
        
        /*unsigned char* databytes= (unsigned char*)[data bytes];
        int databytesLen=[data length];


        while( [[_session outputStream] hasSpaceAvailable] )
        {
            
            unsigned char* senddatabytes=databytes + offset;
            int bytesWritten = [[_CurSession outputStream] write:senddatabytes maxLength:shouldSendLen ];
            if (bytesWritten == -1)
            {
                break;
            }
            if(offset >= databytesLen)
            {
                NSLog(@"BT stop write error");
                break;
            }
            //			[NSThread sleepForTimeInterval:0.001];
        }*/

        
        
        
        
        NSInteger bytesWritten = [[_session outputStream] write:(uint8_t *)[data bytes] maxLength:[data length]];
        if (bytesWritten == -1)
        {
            NSLog(@"BT stop write error");
        }
    }
}

-(int) numberOfChannels
{
    return _confNumberOfChannels;
}
-(int) samplingRate
{
    return _confSamplingRate;
}




@end
