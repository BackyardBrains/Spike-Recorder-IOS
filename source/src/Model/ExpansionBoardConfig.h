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
    @property float defaultGain;
    @property (nonatomic, strong) NSMutableArray *channels;
@end

NS_ASSUME_NONNULL_END
