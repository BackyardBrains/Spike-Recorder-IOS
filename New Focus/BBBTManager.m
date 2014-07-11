//
//  BBBTManager.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 5/24/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "BBBTManager.h"

//#define BT_PROTOCOL_STRING @"com.AmpedRFTech.Demo"
#define BT_PROTOCOL_STRING @"com.backyardbrains.ext.bt"
#define EAD_INPUT_BUFFER_SIZE 16384

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
    bool connectToDevice;
    bool deviceAlreadyDisconnected;
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
        self.inputBlock = nil;
        deviceAlreadyDisconnected = NO;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_accessoryDidConnect:) name:EAAccessoryDidConnectNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_accessoryDidDisconnect:) name:EAAccessoryDidDisconnectNotification object:nil];
        [[EAAccessoryManager sharedAccessoryManager] registerForLocalNotifications];
        
        //Make timer that we are displaying while recording
        _baudRateTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        if (_baudRateTimer)
        {
            numberOfBytesReceivedInLastSec = 0;
            dispatch_source_set_timer(_baudRateTimer, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), NSEC_PER_SEC, (1ull * NSEC_PER_SEC) / 10);
            dispatch_source_set_event_handler(_baudRateTimer, ^{

                bitsPerSec = ((float)numberOfBytesReceivedInLastSec)/1.0;
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

#pragma mark - 




-(void) startBluetooth
{
    connectToDevice = NO;
    _session = [self openSessionForProtocol:BT_PROTOCOL_STRING];
    numberOfBytesReceivedInLastSec = 0;
}


-(void) configBluetoothWithChannels:(int)inNumOfChannels andSampleRate:(int) inSampleRate
{
    _confSamplingRate = inSampleRate;
    _confNumberOfChannels = inNumOfChannels;
    NSLog(@"Start bluetooth with Num of channels: %d and Sample rate: %d", inNumOfChannels, inSampleRate);
    sendConfigData = YES;
    [self writeDataFunc];
}

- (EASession *)openSessionForProtocol:(NSString *)protocolString
{
    NSArray *accessories = [[EAAccessoryManager sharedAccessoryManager]
                            connectedAccessories];
    
    NSLog(@"Enter open session for protocol");
    EASession *session = nil;
    BOOL foundAccessory = NO;
    for (EAAccessory *obj in accessories)
    {
        NSLog(@"We have accessory");
        NSLog(@"%@",obj);
        if ([[obj protocolStrings] containsObject:protocolString])
        {
            if(_accessory == obj)
            {
                NSLog(@"Open same accessory");
                sendConfigData = YES;
                [self writeDataFunc];
                NSNotification *notification = [NSNotification notificationWithName:FOUND_BT_CONNECTION object:self];
                [[NSNotificationCenter defaultCenter] postNotification:notification];
                return _session;
            }
            NSLog(@"Did not open same accessory");
            _accessory = obj;
            foundAccessory = YES;
            NSNotification *notification = [NSNotification notificationWithName:FOUND_BT_CONNECTION object:self];
            [[NSNotificationCenter defaultCenter] postNotification:notification];
            break;
        }
    }
    
    if (foundAccessory)
    {
        NSLog(@"Open new BT session");
        _session = session;
        session = [[EASession alloc] initWithAccessory:_accessory
                                           forProtocol:protocolString];
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
            [session autorelease];
        }
    }
    else
    {
        NSLog(@"No accessory found");
        NSNotification *notification = [NSNotification notificationWithName:NO_BT_CONNECTION object:self];
        [[NSNotificationCenter defaultCenter] postNotification:notification];
        
       /* connectToDevice = YES;
        [[EAAccessoryManager sharedAccessoryManager] showBluetoothAccessoryPickerWithNameFilter:nil completion:^(NSError *error) {
            if(error != nil && [error code] == EABluetoothAccessoryPickerResultCancelled)
            {
                //if canceled
                
            }
            else
            {
                //_session = [self openSessionForProtocol:BT_PROTOCOL_STRING];
                //numberOfBytesReceivedInLastSec = 0;
            }
            
        }];*/
    
    }
    
    return session;
}


-(void) stopCurrentBluetoothConnection
{
    NSLog(@"stopCurrentBluetoothConnection");
    if(_session)
    {
        
       /* [[_session inputStream] removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [[_session inputStream] setDelegate:nil];
        [[_session inputStream] close];
        
        
        [[_session outputStream] removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [[_session outputStream] setDelegate:nil];
       // [[_session outputStream] close];
        
        _session = nil;
        [_readData release];
        _readData = nil;
        
        [_accessory setDelegate:nil];
        [_accessory release];
        _accessory = nil;*/
    }
}

- (void)_accessoryDidDisconnect:(NSNotification *)notification {
    
    NSLog(@"Accessory disconnected");
    if(!deviceAlreadyDisconnected)
    {
        deviceAlreadyDisconnected = YES;
        NSNotification *newnotification = [NSNotification notificationWithName:BT_DISCONNECTED object:self];
        [[NSNotificationCenter defaultCenter] postNotification:newnotification];
    }
}

- (void)_accessoryDidConnect:(NSNotification *)notification {
    deviceAlreadyDisconnected = NO;
    NSLog(@"Accessory connected");
   /* if(connectToDevice)
    {
        _session = [self openSessionForProtocol:BT_PROTOCOL_STRING];
        numberOfBytesReceivedInLastSec = 0;
    }*/
    
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
        
        if(self.inputBlock!=nil)
        {
            self.inputBlock(dataToLoad, [arrayOfFloats count]/_confNumberOfChannels, _confNumberOfChannels);//TODO: make it multy channel
        }
        [arrayOfFloats removeAllObjects];
        [arrayOfFloats release];
        free(dataToLoad);
    }
}

-(void) writeDataFunc
{
    if(sendConfigData)
    {
        sendConfigData = NO;
        int tempCounterNum = 16000000/_confSamplingRate;
        NSString *yourString  = [NSString stringWithFormat:@"conf s:%d;c:%d;",tempCounterNum,_confNumberOfChannels];
        
        NSData *data = [yourString dataUsingEncoding:NSUTF8StringEncoding];

        
        
        NSInteger bytesWritten = [[_session outputStream] write:[data bytes] maxLength:[data length]];
        
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

-(int) numberOfChannels
{
    return _confNumberOfChannels;
}
-(int) samplingRate
{
    return _confSamplingRate;
}




@end
