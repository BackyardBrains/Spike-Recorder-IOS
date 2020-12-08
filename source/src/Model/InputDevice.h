//
//  InputDevice.h
//  Spike Recorder
//
//  Created by Stanislav on 04/11/2020.
//  Copyright © 2020 BackyardBrains. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "InputDeviceConfig.h"
NS_ASSUME_NONNULL_BEGIN

@interface InputDevice : NSObject

@property (nonatomic, strong) InputDeviceConfig * config;
@property BOOL currentlyActive;
@property NSString * uniqueInstanceID;
-(id) initWithConfig:(InputDeviceConfig *)inconfig;
-(BOOL) isBasedOnCommunicationProtocol:(NSString*) protocolToCheck;
@end

NS_ASSUME_NONNULL_END
