//
//  ChannelColorsTableViewCell.m
//  Spike Recorder
//
//  Created by Stanislav on 17/03/2020.
//  Copyright © 2020 BackyardBrains. All rights reserved.
//

#import "ChannelColorsTableViewCell.h"

@implementation ChannelColorsTableViewCell
@synthesize colorChooser;
@synthesize channelConfig;
- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
    [colorChooser initMainUIElements];
    colorChooser.delegate = self;
    //colorChooser.nameLabel.text = @"test";
}

- (void)layoutSubviews {
    [super layoutSubviews];
    //colorChooser is nil here
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

-(void) setToColorIndex:(int) newColorIndex
{
    colorChooser.selectedColorIndex = newColorIndex;
    [colorChooser setNeedsDisplay];
}
-(void) channelColorChanged
{
    [self.colorDelegate channelColorChanged:channelConfig cell:self];
}
- (void)dealloc {
    [colorChooser release];
    [channelConfig release];
    [super dealloc];
}
@end
