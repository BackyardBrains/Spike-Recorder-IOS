//
//  ChannelColorsTableViewCell.h
//  Spike Recorder
//
//  Created by Stanislav on 17/03/2020.
//  Copyright © 2020 BackyardBrains. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SelectChannelColor.h"
NS_ASSUME_NONNULL_BEGIN

@interface ChannelColorsTableViewCell : UITableViewCell
@property (retain, nonatomic) IBOutlet SelectChannelColor *colorChooser;

@end

NS_ASSUME_NONNULL_END
