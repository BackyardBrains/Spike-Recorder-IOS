//
//  ExpansionBoardConfig.h
//  Spike Recorder
//
//  Created by Stanislav on 03/05/2020.
//  Copyright © 2020 BackyardBrains. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ExpansionBoardConfig : NSObject
    @property (nonatomic, copy) NSString* boardType;
    @property (nonatomic, copy) NSString* userFriendlyFullName;
    @property (nonatomic, copy) NSString* userFriendlyShortName;
    @property float maxSampleRate;
    @property int maxNumberOfChannels;
    @property int currentSampleRate;
    @property int currentNumOfChannels;
    @property float defaultTimeScale;
    @property float defaultAmplitudeScale;
    @property bool expansionBoardSupportedByThisPlatform;
    @property (nonatomic, copy) NSString* productURL;
    @property (nonatomic, copy) NSString* helpURL;
    @property (nonatomic, copy) NSString* iconURL;
    @property (nonatomic, strong) NSMutableArray *channels;
    @property bool currentlyActive;
@end

NS_ASSUME_NONNULL_END
