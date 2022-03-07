//
//  FilterSettings.h
//  Spike Recorder
//
//  Created by Stanislav on 02/05/2020.
//  Copyright © 2020 BackyardBrains. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum SignalType
{
    customSignalType = 0,
    eegSignal,
    emgSignal,
    plantSignal,
    neuronSignal,
    ergSignal,
    eogSignal,
    ecgSignal
    
} SignalType;

typedef enum NotchFilterState
{
    notchOff = 0,
    notch60Hz,
    notch50Hz
    
} NotchFilterState;

@interface FilterSettings : NSObject
    @property SignalType signalType;
    @property bool lowPassON;
    @property float lowPassCutoff;
    @property bool highPassON;
    @property float highPassCutoff;
    @property NotchFilterState notchFilterState;

-(id) initWithSignalType:(SignalType) inSignalTypeValue lowPassON:(bool) inLowPassON lowPassCutoff:(float) inLowPassCutoff highPassON:(bool) inHighPassON highPassCutoff:(float) inHighPassCutoff notchFilterState:(NotchFilterState) inNotchFilterState;
-(id) initWithTypicalValuesForSignalType:(SignalType) inSignalTypeValue;
@end

NS_ASSUME_NONNULL_END
