//
//  ConfigViewController.h
//  Spike Recorder
//
//  Created by Stanislav on 15/03/2020.
//  Copyright © 2020 BackyardBrains. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NMRangeSlider.h"
#import "SelectFilterPresetView.h"
#import "ChannelColorsTableViewCell.h"
NS_ASSUME_NONNULL_BEGIN
@protocol ConfigViewControllerDelegate;
@interface ConfigViewController : UIViewController <UITableViewDataSource, UITableViewDelegate,UITextFieldDelegate,UITextViewDelegate,FilterPresetDelegateProtocol, ChannelColorsTableViewCellDelegate>

        @property (retain, nonatomic) IBOutlet SelectFilterPresetView *filterPresetSelection;
        @property (retain, nonatomic) IBOutlet UITextField *lowTI;
        @property (retain, nonatomic) IBOutlet UITextField *highTI;
        @property (retain, nonatomic) IBOutlet UISegmentedControl *selectNotchFilter;
        @property (retain, nonatomic) IBOutlet UITableView *channelsTableView;
        @property (nonatomic, assign) id <ConfigViewControllerDelegate> masterDelegate;
        @property (retain, nonatomic) IBOutlet NMRangeSlider *rangeSelector;
        - (IBAction)closeVIewTap:(id)sender;
        - (IBAction)rangeSelectrorValueChanged:(id)sender;
        -(void) setupFilters;
        -(void) updateFilters;
@end
@protocol ConfigViewControllerDelegate <NSObject>
        -(void) finishedWithConfiguration;
        -(void) configIsClossing;
@end
NS_ASSUME_NONNULL_END
