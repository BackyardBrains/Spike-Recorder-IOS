//
//  ChannelConfig.h
//  Spike Recorder
//
//  Created by Stanislav on 06/05/2020.
//  Copyright © 2020 BackyardBrains. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ChannelConfig : NSObject
    @property (nonatomic, copy) NSString* userFriendlyFullName;
    @property (nonatomic, copy) NSString* userFriendlyShortName;
    @property bool activeByDefault;
    @property bool currentlyActive;
    @property bool filtered;
    @property NSInteger colorIndex;
    @property float calibrationCoef;
    @property bool channelIsCalibrated;
@end

NS_ASSUME_NONNULL_END
