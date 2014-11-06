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



#define STATE_NOT_CONNECTED 1
#define STATE_START_CONNECTION_PROCEDURE 2
#define STATE_FOUND_OLD_ACCESSORY 3
#define STATE_FOUND_NEW_ACCESSORY 4
#define STATE_DEVICE_CHOOSER_OPENED 5
#define STATE_DEVICE_CHOOSER_ERROR_OR_CANCELED 6
#define STATE_WHAITING_FOR_CONNECTION_AFTER_DEVICE_CHOOSER 7
#define STATE_TRY_TO_OPEN_STREAMS 8
#define STATE_ONE_STREAM_OPENED 9
#define STATE_SENDING_INQUIRY_FOR_CONFIG 10
#define STATE_WHAITING_FOR_RESPONSE_ON_CONFIG_INQUIRY 11
#define STATE_RECEIVED_AVAILABLE_CONFIGURATION 12
#define STATE_TRY_TO_SEND_CONFIG_TO_BT 13
#define STATE_CONFIG_SENT_TO_BT 14
#define STATE_DETECTED_SLOW_CONNECTION 15
#define STATE_RECEIVING_DATA 16
#define STATE_TRYING_TO_STOP_CONNECTION 17
#define STATE_TRYING_TO_CLOSE_SESSION 18
#define STATE_SESSION_CLOSED 19






static BBBTManager *btManager = nil;

@interface BBBTManager ()
{
    EAAccessory *_accessory;
    EASession *_session;
    NSMutableData *_readData;
    
    dispatch_source_t _baudRateTimer;
    int numberOfBytesReceivedInLastSec;
    float bitsPerSec;

    int _confNumberOfChannels;
    int _confSamplingRate;
    bool deviceAlreadyDisconnected;
    RingBuffer *ringBuffer;
    bool bufferIsReady;
    BOOL measurementTimerShouldBeActive;
    
    int _maxNumberOfChannelsForDevice;
    int _maxSamplingRateForDevice;
    NSMutableString * configurationBuffer;
    
    
    int _currentState;
    
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

-(int) maxNumberOfChannelsForDevice
{
    return _maxNumberOfChannelsForDevice;
}

-(int) maxSampleRateForDevice
{
    return _maxSamplingRateForDevice;
}

#pragma mark - Initialization


-(void) setCurrentState:(int) cs
{
    switch (cs) {
        case STATE_NOT_CONNECTED:
            NSLog(@"BT Manager State: STATE_NOT_CONNECTED");
            break;
        case STATE_DEVICE_CHOOSER_OPENED:
            NSLog(@"BT Manager State: STATE_DEVICE_CHOOSER_OPENED");
            break;
        case STATE_TRY_TO_SEND_CONFIG_TO_BT:
            NSLog(@"BT Manager State: STATE_TRY_TO_SEND_CONFIG_TO_BT");
            break;
        case STATE_SENDING_INQUIRY_FOR_CONFIG:
            NSLog(@"BT Manager State: STATE_SENDING_INQUIRY_FOR_CONFIG");
            break;
        case STATE_DETECTED_SLOW_CONNECTION:
            NSLog(@"BT Manager State: STATE_DETECTED_SLOW_CONNECTION");
            break;
        case STATE_RECEIVING_DATA:
            NSLog(@"BT Manager State: STATE_RECEIVING_DATA");
            break;
        case STATE_START_CONNECTION_PROCEDURE:
            NSLog(@"BT Manager State: STATE_START_CONNECTION_PROCEDURE");
            break;
        case STATE_FOUND_OLD_ACCESSORY:
            NSLog(@"BT Manager State: STATE_FOUND_OLD_ACCESSORY");
            break;
        case STATE_FOUND_NEW_ACCESSORY:
            NSLog(@"BT Manager State: STATE_FOUND_NEW_ACCESSORY");
            break;
        case STATE_DEVICE_CHOOSER_ERROR_OR_CANCELED:
            NSLog(@"BT Manager State: STATE_DEVICE_CHOOSER_ERROR_OR_CANCELED");
            break;
       case STATE_WHAITING_FOR_CONNECTION_AFTER_DEVICE_CHOOSER:
            NSLog(@"BT Manager State: STATE_WHAITING_FOR_CONNECTION_AFTER_DEVICE_CHOOSER");
            break;
       case STATE_TRY_TO_OPEN_STREAMS:
            NSLog(@"BT Manager State: STATE_TRY_TO_OPEN_STREAMS");
            break;
       case STATE_ONE_STREAM_OPENED:
            NSLog(@"BT Manager State: STATE_ONE_STREAM_OPENED");
            break;
       case STATE_WHAITING_FOR_RESPONSE_ON_CONFIG_INQUIRY:
            NSLog(@"BT Manager State: STATE_WHAITING_FOR_RESPONSE_ON_CONFIG_INQUIRY");
            break;
       case STATE_RECEIVED_AVAILABLE_CONFIGURATION:
            NSLog(@"BT Manager State: STATE_RECEIVED_AVAILABLE_CONFIGURATION");
            break;
       case STATE_CONFIG_SENT_TO_BT:
            NSLog(@"BT Manager State: STATE_CONFIG_SENT_TO_BT");
            break;
       case STATE_TRYING_TO_STOP_CONNECTION:
            NSLog(@"BT Manager State: STATE_TRYING_TO_STOP_CONNECTION");
            break;
        case STATE_TRYING_TO_CLOSE_SESSION:
            NSLog(@"BT Manager State: STATE_TRYING_TO_CLOSE_SESSION");
            break;
        case STATE_SESSION_CLOSED:
            NSLog(@"BT Manager State: STATE_SESSION_CLOSED");
            break;
        default:
            NSLog(@"BT Manager State: Undefined state");
            break;
    }
    _currentState = cs;
}


-(int) currentState
{
    return _currentState;
}


- (id)init
{
    if (self = [super init])
    {
        self.currentState = STATE_NOT_CONNECTED;
        
        ringBuffer = nil;
        self.inputBlock = nil;
        bufferIsReady = false;
        deviceAlreadyDisconnected = NO;
        measurementTimerShouldBeActive = NO;
        
        _maxNumberOfChannelsForDevice = 0;
        _maxSamplingRateForDevice = 0;
        configurationBuffer = [[NSMutableString alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_accessoryDidConnect:) name:EAAccessoryDidConnectNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_accessoryDidDisconnect:) name:EAAccessoryDidDisconnectNotification object:nil];
        [[EAAccessoryManager sharedAccessoryManager] registerForLocalNotifications];
        
        //define timer that will stop connection if it is too slow
        [self setupSlowConnectionTimer];
    }
    
    return self;
}

-(void) setupSlowConnectionTimer
{
    //Make timer for calculation of average baudrate
    _baudRateTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    if (_baudRateTimer)
    {
        numberOfBytesReceivedInLastSec = 0;
        dispatch_source_set_timer(_baudRateTimer, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), NSEC_PER_SEC, (1ull * NSEC_PER_SEC) / 10);
        dispatch_source_set_event_handler(_baudRateTimer, ^{
            
                bitsPerSec = ((float)numberOfBytesReceivedInLastSec)/1.0;

                //TODO: Eliminate measurementTimerShouldBeActive
                if(numberOfBytesReceivedInLastSec>3000)
                {
                    measurementTimerShouldBeActive = YES;
                }
                if(self.currentState==STATE_RECEIVING_DATA)
                {
                    if(numberOfBytesReceivedInLastSec<1300)
                    {
                        measurementTimerShouldBeActive = NO;
                        self.currentState = STATE_DETECTED_SLOW_CONNECTION;
                        NSNotification *notification = [NSNotification notificationWithName:BT_SLOW_CONNECTION object:self];
                        [[NSNotificationCenter defaultCenter] postNotification:notification];
                    }
                }
                numberOfBytesReceivedInLastSec = 0;
        });
        dispatch_resume(_baudRateTimer);
    }
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
    self.currentState = STATE_START_CONNECTION_PROCEDURE;
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
    self.currentState = STATE_TRY_TO_SEND_CONFIG_TO_BT;
    [self sendConfigurationToBT];
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
                self.currentState = STATE_FOUND_OLD_ACCESSORY;
                NSLog(@"Open same accessory");

                
                //this is old accessory so we have configuration for channels and sampling rate
                //if(_confNumberOfChannels!=0 && _maxSamplingRateForDevice!=0)
                //{
                //    weReceivedPossibleConfigurations = YES;
               // }
            }
            else
            {
                self.currentState = STATE_FOUND_NEW_ACCESSORY;
            }
            NSLog(@"Did not open same accessory");
            _accessory = obj;

            //If we dont have configuration for num. of channels
            //and sampling rate than don't open configuration chooser yet
            //whaite for possible connfigurations
      /*      if(weReceivedPossibleConfigurations)
            {
                
   //!!!!! testing without this 
                //notify rest of the program that we have bluetooth. It will open config popup
   //             NSNotification *notification = [NSNotification notificationWithName:FOUND_BT_CONNECTION object:self];
   //             [[NSNotificationCenter defaultCenter] postNotification:notification];
            }*/
            break;
        }
    }
    
    if (self.currentState==STATE_FOUND_NEW_ACCESSORY || self.currentState == STATE_FOUND_OLD_ACCESSORY)
    {
        //this notification just informs rest of the program that we are whaiting for connection
        // it opens the spinner. Now we whait for _accessoryDidConnect
        NSNotification *notification = [NSNotification notificationWithName:BT_WAIT_TO_CONNECT object:self];
        [[NSNotificationCenter defaultCenter] postNotification:notification];
        
        NSLog(@"Open new BT session **************************************");
        self.currentState = STATE_TRY_TO_OPEN_STREAMS;
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
        self.currentState = STATE_DEVICE_CHOOSER_OPENED;

       // NSPredicate *predicate = [NSPredicate predicateWithFormat:@"self CONTAINS 'BYB'"];
        [[EAAccessoryManager sharedAccessoryManager] showBluetoothAccessoryPickerWithNameFilter:nil completion:^(NSError *error) {
            //We don't do anything with response, just log
            //BT will dispatch connected event and than we will continue with creating session
            // and configuration popup
            if(error != nil)
            {
                self.currentState = STATE_DEVICE_CHOOSER_ERROR_OR_CANCELED;
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
                self.currentState = STATE_WHAITING_FOR_CONNECTION_AFTER_DEVICE_CHOOSER;
                
                
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

    if(_session)
    {
       // NSLog(@"Found session I will kill it");
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
    self.currentState = STATE_SESSION_CLOSED;
}


//
// Public function for quiting BT session
//
-(void) stopCurrentBluetoothConnection
{
    NSLog(@"stopCurrentBluetoothConnection");

    if(_session)
    {
        measurementTimerShouldBeActive = NO;
        self.currentState = STATE_TRYING_TO_STOP_CONNECTION;
        [self stopTransmision];
        
    }
}


//
// Called when we loose BT in range or similar.
//
- (void)_accessoryDidDisconnect:(NSNotification *)notification {
    
    NSLog(@"Accessory disconnected");
    measurementTimerShouldBeActive = NO;
    _maxNumberOfChannelsForDevice = 0;
    _maxSamplingRateForDevice = 0;
    configurationBuffer = [[NSMutableString alloc] init];
    if(self.currentState != STATE_TRYING_TO_STOP_CONNECTION &&
       self.currentState != STATE_SESSION_CLOSED &&
       self.currentState != STATE_TRYING_TO_CLOSE_SESSION &&
       self.currentState != STATE_WHAITING_FOR_CONNECTION_AFTER_DEVICE_CHOOSER)
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
    if(self.currentState == STATE_WHAITING_FOR_CONNECTION_AFTER_DEVICE_CHOOSER)
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
            if(aStream == [_session inputStream])
            {
                NSLog(@"Input stream opened");
            }
            if(aStream == [_session outputStream])
            {
                NSLog(@"Output stream opened");
            }
            if(self.currentState == STATE_TRY_TO_OPEN_STREAMS)
            {
                self.currentState = STATE_ONE_STREAM_OPENED;
            }
            else if(self.currentState == STATE_ONE_STREAM_OPENED)
            {
                NSLog(@"********* Ask for configuration ***************");
                self.currentState = STATE_SENDING_INQUIRY_FOR_CONFIG;
                [self askForPossibleconfigurations];

            }
            break;
        case NSStreamEventHasBytesAvailable:
            [self readDataFunc];
            break;
        case NSStreamEventHasSpaceAvailable:

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



-(void) askForPossibleconfigurations
{
    if(self.currentState == STATE_SENDING_INQUIRY_FOR_CONFIG)
    {
        NSLog(@"Try to ask for configurations");
        NSString *configString  = @"h:;?:;";//ask for configurations
        
        NSData *data = [configString dataUsingEncoding:NSUTF8StringEncoding];
        if([[_session outputStream] hasSpaceAvailable])
        {
            NSLog(@"Write to output buffer");
            self.currentState = STATE_WHAITING_FOR_RESPONSE_ON_CONFIG_INQUIRY;
            NSInteger bytesWritten = [[_session outputStream] write:(uint8_t *)[data bytes] maxLength:[data length]];
            if (bytesWritten == -1)
            {
                NSLog(@"BT stop write error!!!!!!");
            }
        }
        else
        {
            NSLog(@"No available space in sending buffer. Try in a 0.5sec");
            [self performSelector:@selector(askForPossibleconfigurations) withObject:nil afterDelay:0.5];
            
        }
    }
}


//
// Parse possible configuration (ex. "sr:4000;ch:2;\n\r") and set information
// into variables
//
-(void) processPossibleConfigurations:(NSString *) receivedConfigData
{
    if(self.currentState == STATE_WHAITING_FOR_RESPONSE_ON_CONFIG_INQUIRY)
    {
        NSLog(@"Config response from device: %@",receivedConfigData);
        [configurationBuffer appendString:receivedConfigData];
        
        //If we get to the end of config information
        if([configurationBuffer containsString:@"\n\r"])
        {
            [configurationBuffer containsString:@":"];;
            NSArray *components = [configurationBuffer componentsSeparatedByString:@";"];
            for(int i=0;i<[components count]-1;i++)
            {
                if([[self getParameterType:[components objectAtIndex:i]] isEqualToString:@"sr"])
                {
                    NSString * tempValue = [self getParameterValue:[components objectAtIndex:i]];
                    _maxSamplingRateForDevice = [tempValue intValue];
                
                }
                else if([[self getParameterType:[components objectAtIndex:i]] isEqualToString:@"ch"])
                {
                    NSString * tempValue = [self getParameterValue:[components objectAtIndex:i]];
                    _maxNumberOfChannelsForDevice = [tempValue intValue];
                }
                
            }
            
            self.currentState = STATE_RECEIVED_AVAILABLE_CONFIGURATION;
            //notify rest of the program that we have bluetooth. It will open config popup or automaticaly choose config
            NSNotification *notification = [NSNotification notificationWithName:FOUND_BT_CONNECTION object:self];
            [[NSNotificationCenter defaultCenter] postNotification:notification];
        }
    }
}

-(NSString *) getParameterType:(NSString*) stringToParse
{
    NSArray * components = [stringToParse componentsSeparatedByString:@":"];
    return [components objectAtIndex:0];
    //long timeStamp = [numberString longValue];
}

-(NSString *) getParameterValue:(NSString*) stringToParse
{
    NSArray * components = [stringToParse componentsSeparatedByString:@":"];
    return [components objectAtIndex:1];
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
        
        if(self.currentState == STATE_WHAITING_FOR_RESPONSE_ON_CONFIG_INQUIRY)
        {
            NSString * configData = [[NSString alloc] initWithData:_readData encoding:NSUTF8StringEncoding];
            if(configData==nil)
            {
                NSLog(@"Received non-UTF8 string. Try again to get description of capabilities.");
                self.currentState = STATE_SENDING_INQUIRY_FOR_CONFIG;
                [self performSelector:@selector(askForPossibleconfigurations) withObject:nil afterDelay:0.5];
            }
            else
            {
                [self processPossibleConfigurations:configData];
            }
            [_readData setLength:0];
            return;
        }
        
        if(self.currentState == STATE_CONFIG_SENT_TO_BT || self.currentState == STATE_RECEIVING_DATA)
        {
            if(self.currentState == STATE_CONFIG_SENT_TO_BT)
            {
                self.currentState = STATE_RECEIVING_DATA;
            }
            
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
        }//end of receive real data handling

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
-(void) sendConfigurationToBT
{
        NSLog(@"sendConfigurationToBT");
        if(self.currentState == STATE_TRY_TO_SEND_CONFIG_TO_BT)
        {
            int tempCounterNum = 16000000/_confSamplingRate;
            NSString *configString  = [NSString stringWithFormat:@"conf s:%d;c:%d;",tempCounterNum,_confNumberOfChannels];
            
            NSData *data = [configString dataUsingEncoding:NSUTF8StringEncoding];

            if([[_session outputStream] hasSpaceAvailable])
            {
                NSLog(@"Write config to output buffer");
                self.currentState = STATE_CONFIG_SENT_TO_BT;
                NSInteger bytesWritten = [[_session outputStream] write:(uint8_t *)[data bytes] maxLength:[data length]];
                
                if (bytesWritten == -1)
                {
                    NSLog(@"BT config write error");
                }
            }
            else
            {
                NSLog(@"No available space in sending buffer. Try in a 0.5sec");
                [self performSelector:@selector(sendConfigurationToBT) withObject:nil afterDelay:0.5];
                
            }
        }
}

//
// Sends command to BT that will stop sampling and sending of data. It is important since
// we can't stop session if we don't stop sampling. Not sure why
//
-(void) stopTransmision
{
    NSLog(@"stopTransmision");

    if(self.currentState == STATE_TRYING_TO_STOP_CONNECTION)
    {

        NSString *configString  = @"h:;";//halt
        
        NSData *data = [configString dataUsingEncoding:NSUTF8StringEncoding];

        if([[_session outputStream] hasSpaceAvailable])
        {
            NSLog(@"Write to output buffer");
            NSInteger bytesWritten = [[_session outputStream] write:(uint8_t *)[data bytes] maxLength:[data length]];
            if (bytesWritten == -1)
            {
                NSLog(@"BT stop write error!!!!!!");
                [self performSelector:@selector(stopTransmision) withObject:nil afterDelay:0.5];
                return;
            }
            self.currentState = STATE_TRYING_TO_CLOSE_SESSION;
            [self performSelector:@selector(CloseSession) withObject:nil afterDelay:0.5];
        }
        else
        {
            NSLog(@"No available space in sending buffer. Try in a 0.5sec");
            [self performSelector:@selector(stopTransmision) withObject:nil afterDelay:0.5];
            
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
