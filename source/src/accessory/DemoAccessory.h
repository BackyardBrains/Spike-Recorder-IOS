//
//  DemoAccessory.h
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
#import <ExternalAccessory/ExternalAccessory.h>


//#define DEBUG_MFI

@interface DemoAccessory : NSObject <NSStreamDelegate>

@property NSString *accessoryInfoString;
@property NSMutableString *debugString;

- (bool)isConnected;
- (id)initWithProtocol:(NSString *)protocol;
- (void)queueTxData:(NSData *)data;

- (void)addDebugString:(NSString *)string;

@end
