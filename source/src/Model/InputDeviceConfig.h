//
//  InputDeviceConfig.h
//  Spike Recorder
//
//  Created by Stanislav on 03/05/2020.
//  Copyright © 2020 BackyardBrains. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FilterSettings.h"
NS_ASSUME_NONNULL_BEGIN


@interface InputDeviceConfig : NSObject

    @property (nonatomic, copy) NSString* uniqueName;//unique string name that is sent as response to board type
    @property (nonatomic, copy) NSString* hardwareComProtocolType;//serial, hid, mfi
    @property (nonatomic, copy) NSString* bybProtocolType;//currently just default
    @property (nonatomic, copy) NSString* bybProtocolVersion;//currently just one version

    @property FilterSettings* filterSettings;//default filter settings
    @property float maxSampleRate;
    @property int maxNumberOfChannels;
    @property int currentSampleRate;
    @property int currentNumOfChannels;
    @property float defaultTimeScale;
    @property float defaultGain;
    @property bool sampleRateIsFunctionOfNumberOfChannels;
    @property (nonatomic, copy) NSString* userFriendlyFullName;
    @property (nonatomic, copy) NSString* userFriendlyShortName;
    @property (nonatomic, copy) NSString* minAppVersion;//minimum version of BYB application for current platform
    @property (nonatomic, strong) NSMutableArray *expansionBoards;//configuration for expansion boards
    @property (nonatomic, strong) NSMutableArray *channels;

//default time scale
//default gain


//-(id) initWithSignalType:(SignalType) inSignalTypeValue lowPassON:(bool) inLowPassON lowPassCutoff:(float) inLowPassCutoff highPassON:(bool) inHighPassON highPassCutoff:(float) inHighPassCutoff notchFilterState:(NotchFilterState) inNotchFilterState;
//-(void) initWithTypicalValuesForSignalType:(SignalType) inSignalTypeValue;
@end

NS_ASSUME_NONNULL_END
