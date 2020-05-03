//
//  FilterSettings.m
//  Spike Recorder
//
//  Created by Stanislav on 02/05/2020.
//  Copyright © 2020 BackyardBrains. All rights reserved.
//

#import "FilterSettings.h"

@implementation FilterSettings

    @synthesize signalType;
    @synthesize lowPassON;
    @synthesize lowPassCutoff;
    @synthesize highPassON;
    @synthesize highPassCutoff;
    @synthesize notchFilterState;

    -(id) initWithSignalType:(SignalType) inSignalTypeValue lowPassON:(bool) inLowPassON lowPassCutoff:(float) inLowPassCutoff highPassON:(bool) inHighPassON highPassCutoff:(float) inHighPassCutoff notchFilterState:(NotchFilterState) inNotchFilterState
    {
        if ((self = [super init])) {
            signalType = inSignalTypeValue;
            lowPassON = inLowPassON;
            lowPassCutoff = inLowPassCutoff;
            highPassON = inHighPassON;
            highPassCutoff = inHighPassCutoff;
            notchFilterState = inNotchFilterState;
        }
        return self;
    }

    -(void) initWithTypicalValuesForSignalType:(SignalType) inSignalTypeValue
    {
        switch (inSignalTypeValue) {
            case eegSignal:
                signalType = eegSignal;
                lowPassON = true;
                lowPassCutoff = 50;
                highPassON = true;
                highPassCutoff = 1;
                notchFilterState = notch60Hz;
                break;
            case ecgSignal:
                signalType = ecgSignal;
                lowPassON = true;
                lowPassCutoff = 120;
                highPassON = true;
                highPassCutoff = 1;
                notchFilterState = notch60Hz;
                break;
            case emgSignal:
                signalType = emgSignal;
                lowPassON = true;
                lowPassCutoff = 2500;
                highPassON = true;
                highPassCutoff = 70;
                notchFilterState = notchOff;
                break;
            case plantSignal:
                signalType = plantSignal;
                lowPassON = true;
                lowPassCutoff = 5;
                highPassON = false;
                highPassCutoff =0;
                notchFilterState = notch60Hz;
                break;
            case neuronSignal:
                signalType = neuronSignal;
                lowPassON = true;
                lowPassCutoff = 5000;
                highPassON = true;
                highPassCutoff = 1;
                notchFilterState = notch60Hz;
                break;
            case eogSignal:
                signalType = eogSignal;
                lowPassON = true;
                lowPassCutoff = 50;
                highPassON = true;
                highPassCutoff = 1;
                notchFilterState = notch60Hz;
                break;
            case ergSignal:
                signalType = ergSignal;
                lowPassON = true;
                lowPassCutoff = 300;
                highPassON = true;
                highPassCutoff = 1;
                notchFilterState = notch60Hz;
                break;
            default:
                signalType = customSignalType;
                lowPassON = false;
                lowPassCutoff = 5000;
                highPassON = false;
                highPassCutoff = 0;
                notchFilterState = notchOff;
                break;
        }
    }

    - (void)dealloc {
        
        [super dealloc];
    }
@end
