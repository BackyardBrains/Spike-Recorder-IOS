//
//  DemoAccessory.m
//  SilabsMfiDemo1
//
//  Copyright (c) 2013-2014 Silabs. All rights reserved.
//
// This program and the accompanying materials are made available under the
// terms of the Silicon Laboratories Software License which accompanies this
// distribution.  Please refer to the License.txt file that is located in the
// root directory of this software package.
//

#import "DemoAccessory.h"
#import "BBAudioManager.h"

// Set the size of the buffer used to receive data from the input stream
#define RX_BUFFER_SIZE 1024


@implementation DemoAccessory {
    EASession *_session;
    NSString *_protocol;
    NSMutableData *_txData;
    EAAccessory *lastAccessory;

}

// Adds a string to the end of a debug log.
- (void)addDebugString:(NSString *)string
{
#ifdef DEBUG_MFI
    [_debugString appendString:string];
#endif
}

// Dumps a buffer to the debug log.
- (void)addDebugBuffer:(const uint8_t *)buf length:(int)len prefixString:(NSString*)prefix
{
#ifdef DEBUG_MFI
    NSMutableString *hexString = [NSMutableString stringWithString:prefix];
    for (int i=0; i<len; i++) {
        [hexString appendFormat:@"%02x ", buf[i]];
    }
    [self addDebugString:[NSString stringWithFormat:@"%@\n", hexString]];
#endif
}

// Protocol implementation (subclass) must override this method which is called whenever
// bytes are received from the accessory.
- (void)processRxBytes:(uint8_t *)bytes length:(NSUInteger)len
{
}

// Handles input stream has bytes events. Receives data from the accessory input stream.
- (void)rxBytes
{
    uint8_t buffer[RX_BUFFER_SIZE];
    while ([[_session inputStream] hasBytesAvailable])
    {
        NSInteger bytesRead = [[_session inputStream] read:buffer maxLength:RX_BUFFER_SIZE];
        [self processRxBytes:buffer length:bytesRead];
        //[self addDebugBuffer:buffer length:bytesRead prefixString:@"RX: "];
    }
}

// Adds data to the transmit queue waiting to send to the accessory.
- (void)queueTxData:(NSData *)data
{
    // Ignore data if we are not connected to an accessory
    if ([self isConnected]) {
        [_txData appendData:data];
        [self txBytes];
    }
}

// Handles output stream has space events. Moves data from the transmit queue to the accessory output stream.
- (void)txBytes
{
    while (([[_session outputStream] hasSpaceAvailable]) && ([_txData length] > 0))
    {
        NSInteger bytesSent = [[_session outputStream] write:(const unsigned char *)[_txData bytes] maxLength:[_txData length]];
        if (bytesSent > 0)
        {
            //[self addDebugBuffer:[_txData bytes] length:bytesSent prefixString:@"TX: "];
            [_txData replaceBytesInRange:NSMakeRange(0, bytesSent) withBytes:NULL length:0];
        }
        else if (bytesSent == -1)
        {
            [self addDebugString:@"!outputStream error"];
            break;
        }
    }

}

// Stream delegate handles events from both streams.
- (void)stream:(NSStream*)stream handleEvent:(NSStreamEvent)streamEvent
{
    //[self addDebugString:[NSString stringWithFormat:@"Stream Event: %d\n", streamEvent]];

    switch (streamEvent) {
    case NSStreamEventHasBytesAvailable:
        [self rxBytes];
        break;

    case NSStreamEventHasSpaceAvailable:
        [self txBytes];
        break;

    case NSStreamEventErrorOccurred:
        [self addDebugString:@"!streamEvent error"];
        break;

    default:
        break;
    }
}

// Create a string with all of the accessory info properties listed.
- (void) gatherAccessoryInfo:(EAAccessory *)accessory
{
    NSMutableString *infoString = [NSMutableString stringWithString:@"Accessory Info:\n"];
    [infoString appendFormat:@"Name.... %@\n", accessory.name];
    [infoString appendFormat:@"Manufacturer.... %@\n", accessory.manufacturer];
    [infoString appendFormat:@"Model Number.... %@\n", accessory.modelNumber];
    [infoString appendFormat:@"Serial Number.... %@\n", accessory.serialNumber];
    [infoString appendFormat:@"Firmware Revision.... %@\n", accessory.firmwareRevision];
    [infoString appendFormat:@"Hardware Revision.... %@\n", accessory.hardwareRevision];
    _accessoryInfoString = infoString;
}


- (void) reAddExistingAccessory
{
    
    lastAccessory  = [self getCurrentAccessoryWithProtocol:_protocol];
    NSLog(@"lastAccessory - before");
    // If the requested protocol was found, open a session and hook up the related streams
    if (lastAccessory) {
        NSLog(@"lastAccessory - OK");
        //_session = [[EASession alloc] initWithAccessory:lastAccessory forProtocol:_protocol];
        
        if (_session) {
            NSLog(@"_session - OK");
            //change audio manager input to external accessory
            cBufHead=0;
            cBufTail=0;
            [[BBAudioManager bbAudioManager] addMfiDeviceWithModelNumber:lastAccessory.modelNumber andSerial:lastAccessory.serialNumber];
        }
    }
}

// Search connected accessories for the requested protocol. If found, open a session
// and hook up the associated streams.
- (void) openSessionWithProtocol:(NSString *)protocolString
{
    
    NSLog(@"BYB log  - openSessionWithProtocol");
    _accessoryInfoString = @"Accessory Not Connected\n";
    //[self addDebugString:[NSString stringWithFormat:@"openSessionWithProtocol: %@\n", protocolString]];
    //[self addDebugString:[NSString stringWithFormat:@"%d connected accessories\n", [accessories count]]];

    lastAccessory  = [self getCurrentAccessoryWithProtocol:protocolString];

    // If the requested protocol was found, open a session and hook up the related streams
    if (lastAccessory) {
        [self gatherAccessoryInfo:lastAccessory];
        [self addDebugString:@"Opening session...\n"];
        _session = [[EASession alloc] initWithAccessory:lastAccessory forProtocol:protocolString];
        
        if (_session) {
            
            //change audio manager input to external accessory
            cBufHead=0;
            cBufTail=0;
            [[BBAudioManager bbAudioManager] addMfiDeviceWithModelNumber:lastAccessory.modelNumber andSerial:lastAccessory.serialNumber];
            
            
            
            [self addDebugString:@"Opening streams...\n"];
            [[_session inputStream] setDelegate:self];
            [[_session inputStream] scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
            [[_session inputStream] open];

            [[_session outputStream] setDelegate:self];
            [[_session outputStream] scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
            [[_session outputStream] open];
            
            [self setupProtocol];
        } else {
            [self addDebugString:@"Failed opening session\n"];
        }
        
        
    }
}

// Close an open session and disconnect the associated streams.
- (void)closeSession
{
    _accessoryInfoString = @"Accessory Not Connected\n";
    [self addDebugString:@"closeSession\n"];
    if (_session) {
        [[BBAudioManager bbAudioManager] removeMfiDeviceWithModelNumber:lastAccessory.modelNumber andSerial:lastAccessory.serialNumber];
        [[_session inputStream] close];
        [[_session inputStream] removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [[_session inputStream] setDelegate:nil];

        [[_session outputStream] close];
        [[_session outputStream] removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [[_session outputStream] setDelegate:nil];

        _session = nil;
    }
}

// Init instance with the requested accessory protocol. Open a session if the accessory is already
// connected and start listening for connect/disconnect events.
- (id)initWithProtocol:(NSString *)protocol
{
    
    if([[UIApplication sharedApplication] isProtectedDataAvailable])
    {
        NSLog(@"Device is unlocked! initWithProtocol");
    }
    else
    {
        NSLog(@"Device is locked! initWithProtocol");
    }
    self = [super init];
    if (self) {
        _debugString = [NSMutableString stringWithString:@"initWithProtocol:\n"];
        _txData = [[NSMutableData alloc] init];
        _protocol = protocol;

        // Start session if an accessory is already attached
        [self openSessionWithProtocol:_protocol];

        // Listen for connect/disconnect events
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(accessoryDidConnect:)
            name:EAAccessoryDidConnectNotification
            object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(accessoryDidDisconnect:)
            name:EAAccessoryDidDisconnectNotification
            object:nil];

        [[EAAccessoryManager sharedAccessoryManager] registerForLocalNotifications];
    }
    return self;
}


-(EAAccessory *) getCurrentAccessoryWithProtocol:(NSString *) protocol
{
    NSArray *accessories = [[EAAccessoryManager sharedAccessoryManager] connectedAccessories];
    EAAccessory *accessory = nil;

    // Search connected accessories for the requested protocol
    for (EAAccessory *nextAccessory in accessories) {
        if ([[nextAccessory protocolStrings] containsObject:protocol]) {
            accessory = nextAccessory;
            break;
        }
    }
    return accessory;
}


// On instance removal, stop listening for connect/disconnect events and close the session if
// there is one.
- (void)dealloc
{
    [[EAAccessoryManager sharedAccessoryManager] unregisterForLocalNotifications];
    [self closeSession];
    
}

// Checks if the accessory is currently connected.
- (bool)isConnected
{
    return [[_session accessory] isConnected];
}

#pragma mark - EAAccessory Notifications

// Observer method for accessory connect notifications posted by the EAAccessoryManager.
// Attemps to open a session with the desired protocol if one is not already open.
- (void)accessoryDidConnect:(NSNotification *)notification
{
    if([[UIApplication sharedApplication] isProtectedDataAvailable])
    {
        NSLog(@"Device is unlocked! accessoryDidConnect");
    }
    else
    {
        NSLog(@"Device is locked! accessoryDidConnect");
    }
    [self addDebugString:@"DidConnect:\n"];
    if (_session == nil) {
        [self openSessionWithProtocol:_protocol];
    }
}

// Observer method for accessory disconnect notifications posted by the EAAccessoryManager.
// Closes the session if our accessory disconnected.
- (void)accessoryDidDisconnect:(NSNotification *)notification
{
    EAAccessory *disconnectedAccessory = [[notification userInfo] objectForKey:EAAccessoryKey];
    NSArray *protocolStrings = [disconnectedAccessory protocolStrings];
    
    [self addDebugString:[NSString stringWithFormat:@"DidDisconnect: %@\n", protocolStrings]];
    if ([protocolStrings containsObject:_protocol]) {
        [self closeSession];
    }
}

- (void) setupProtocol
{
    //init all things that you need
}

@end
