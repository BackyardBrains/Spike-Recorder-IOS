//
//  SelectChannelColor.h
//  Spike Recorder
//
//  Created by Stanislav on 16/03/2020.
//  Copyright © 2020 BackyardBrains. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@protocol SelectChannelColorViewDelegate;
@interface SelectChannelColor : UIView
{
    NSMutableArray * _buttons;
    UIView *selectMarkViewPart1;
    UIView *selectMarkViewPart2;
}
@property int selectedColorIndex;
@property UILabel *nameLabel;
@property (nonatomic, assign) id <SelectChannelColorViewDelegate> delegate;
-(void) initMainUIElements;
@end

@protocol SelectChannelColorViewDelegate <NSObject>
        -(void) channelColorChanged;
@end

NS_ASSUME_NONNULL_END
