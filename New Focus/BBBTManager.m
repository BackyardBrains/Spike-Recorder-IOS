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
    NSMutableData *_writeData;
    NSMutableData *_readData;
    
    dispatch_source_t _baudRateTimer;
    int numberOfBytesReceivedInLastSec;
    float bitsPerSec;
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

                bitsPerSec = ((float)numberOfBytesReceivedInLastSec)/3.0;
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
    _session = [self openSessionForProtocol:BT_PROTOCOL_STRING];
    numberOfBytesReceivedInLastSec = 0;
}


- (EASession *)openSessionForProtocol:(NSString *)protocolString
{
    NSArray *accessories = [[EAAccessoryManager sharedAccessoryManager]
                            connectedAccessories];
    _accessory = nil;
    EASession *session = nil;
    
    for (EAAccessory *obj in accessories)
    {
        if ([[obj protocolStrings] containsObject:protocolString])
        {
            _accessory = obj;
            break;
        }
    }
    
    if (_accessory)
    {
        
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
    
    return session;
}

- (void)_accessoryDidDisconnect:(NSNotification *)notification {
    
    NSLog(@"Accessory disconnected");
}

- (void)_accessoryDidConnect:(NSNotification *)notification {
    
    NSLog(@"Accessory connected");
    
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
        numberOfBytesReceivedInLastSec += [_readData length];
        
        //find legal begining of first number
        for(int i=0;i<[_readData length]-1;i++)
        {
            if(allBytes[i] == 0xFF && allBytes[i+1] < 0xFF)
            {
                startIndex = i+1;
                break;
            }
            
        }
        uint LSB;
        uint MSB;
        int finalIntMeasure;
        float finalFloat;
        int indexInData;
        NSMutableArray * arrayOfFloats = [[NSMutableArray alloc] init];
        for(indexInData=startIndex;indexInData<[_readData length]-1;indexInData=indexInData)
        {
            //if(allBytes[indexInData-1] == 0xFF && allBytes[indexInData-2] == 0xFF && allBytes[indexInData]!= 0xFF)
            if(allBytes[indexInData-1] == 0xFF  && allBytes[indexInData]!= 0xFF)
            {
                MSB = allBytes[indexInData];
                MSB = MSB<<8;
                LSB  = allBytes[indexInData+1];
                finalIntMeasure = (int)(MSB|LSB);
                if(finalIntMeasure!=257)
                {
                    finalIntMeasure = finalIntMeasure;
                }
                finalFloat = ((float)finalIntMeasure)* 0.00322265625f;//3.3/1024
                [arrayOfFloats addObject:[NSNumber numberWithFloat:finalFloat]];
                indexInData=indexInData+3;
            }
            else
            {
                indexInData++;
                continue;
            }
            
            
            //test code
            ///////////////////////////////////////////////////////////////////////////////////////////
          /*     finalIntMeasure = (int)allBytes[indexInData];
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
             indexInData++;*/
            ///////////////////////////////////////////////////////////////////////////////////////////
            
        }
        
        //TODO: make it multy channel
        //keep last two bytes in buffer in case we cut the frame
        unsigned char * lastTwoBytes = &(allBytes[[_readData length]-2]);
        [_readData replaceBytesInRange:NSMakeRange(0, 2) withBytes:lastTwoBytes];
        [_readData setLength:2];
        
        //transform from NSArray to array of floats
        float * dataToLoad = (float *)calloc([arrayOfFloats count], sizeof(float));
        for(int i=0;i<[arrayOfFloats count];i++)
        {
            dataToLoad[i] = [[arrayOfFloats objectAtIndex:i] floatValue];
        }
        
        if(self.inputBlock!=nil)
        {
            self.inputBlock(dataToLoad, [arrayOfFloats count], 1);//TODO: make it multy channel
        }
        [arrayOfFloats removeAllObjects];
        [arrayOfFloats release];
        free(dataToLoad);
    }
}

-(void) closeBluetooth
{
    [[_session inputStream] close];
    [[_session inputStream] removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [[_session inputStream] setDelegate:nil];
    [[_session outputStream] close];
    [[_session outputStream] removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [[_session outputStream] setDelegate:nil];
    
    [_session release];
    _session = nil;
    
    [_writeData release];
    _writeData = nil;
    [_readData release];
    _readData = nil;
    
    
}




@end
