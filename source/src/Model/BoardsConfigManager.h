//
//  BoardsConfigManager.h
//  Spike Recorder
//
//  Created by Stanislav on 06/05/2020.
//  Copyright © 2020 BackyardBrains. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "InputDeviceConfig.h"
#define DEFAULT_BOARDS_CONFIG_URL @"/src/Asset/config/board-config.json"
NS_ASSUME_NONNULL_BEGIN



@interface BoardsConfigManager : NSObject
    @property (nonatomic,retain) NSMutableArray * boardsConfig;

    -(int) loadLocalConfig;
    -(InputDeviceConfig *) getDeviceConfigForUniqueName:(NSString *) uniqueName;

@end

NS_ASSUME_NONNULL_END
