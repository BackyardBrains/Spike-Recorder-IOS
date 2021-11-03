//
//  SelectFilterPresetView.h
//  Spike Recorder
//
//  Created by Stanislav on 15/03/2020.
//  Copyright © 2020 BackyardBrains. All rights reserved.
//

#import <UIKit/UIKit.h>
@protocol FilterPresetDelegateProtocol;

typedef enum FilterPresetType
{
    ecgPreset = 0,
    eegPreset,
    emgPreset,
    plantPreset,
    neuronPreset
    
} FilterPresetType;


NS_ASSUME_NONNULL_BEGIN

@interface SelectFilterPresetView : UIView
{
    NSMutableArray * _buttons;
}
    @property FilterPresetType selectedType;
    @property(nonatomic,assign) id <FilterPresetDelegateProtocol> delegate;
    -(void) deselectAll;
    -(void) lightUpButtonIndex:(int)indexToSelect;
@end

@protocol FilterPresetDelegateProtocol
@required
- (void)endSelectionOfFilterPreset:(FilterPresetType) filterType;
@end

NS_ASSUME_NONNULL_END
