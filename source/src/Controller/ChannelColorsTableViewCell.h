//
//  ChannelColorsTableViewCell.h
//  Spike Recorder
//
//  Created by Stanislav on 17/03/2020.
//  Copyright © 2020 BackyardBrains. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SelectChannelColor.h"
#import "ChannelConfig.h"
NS_ASSUME_NONNULL_BEGIN
@protocol ChannelColorsTableViewCellDelegate;
@interface ChannelColorsTableViewCell : UITableViewCell <SelectChannelColorViewDelegate>
@property (retain, nonatomic) IBOutlet SelectChannelColor *colorChooser;
@property (retain, nonatomic) ChannelConfig * channelConfig;
@property (nonatomic, assign) id <ChannelColorsTableViewCellDelegate> colorDelegate;
-(void) setToColorIndex:(int) newColorIndex;
@end
@protocol ChannelColorsTableViewCellDelegate <NSObject>
        -(void) channelColorChanged:(ChannelConfig*) config cell:(ChannelColorsTableViewCell*) cell;
@end
NS_ASSUME_NONNULL_END
