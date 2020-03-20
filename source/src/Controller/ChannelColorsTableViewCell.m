//
//  ChannelColorsTableViewCell.m
//  Spike Recorder
//
//  Created by Stanislav on 17/03/2020.
//  Copyright © 2020 BackyardBrains. All rights reserved.
//

#import "ChannelColorsTableViewCell.h"

@implementation ChannelColorsTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)dealloc {
    [_colorChooser release];
    [super dealloc];
}
@end
