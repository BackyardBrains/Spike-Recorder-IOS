//
//  SelectChannelColor.h
//  Spike Recorder
//
//  Created by Stanislav on 16/03/2020.
//  Copyright © 2020 BackyardBrains. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SelectChannelColor : UIView
{
    NSMutableArray * _buttons;
    UIView *selectMarkViewPart1;
    UIView *selectMarkViewPart2;
}
@property int selectedColorIndex;
@property UILabel *nameLabel;

@end

NS_ASSUME_NONNULL_END
