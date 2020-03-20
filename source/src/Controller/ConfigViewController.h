//
//  ConfigViewController.h
//  Spike Recorder
//
//  Created by Stanislav on 15/03/2020.
//  Copyright © 2020 BackyardBrains. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ConfigViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (retain, nonatomic) IBOutlet UITextField *lowTI;
@property (retain, nonatomic) IBOutlet UITextField *highTI;
@property (retain, nonatomic) IBOutlet UISegmentedControl *selectNotchFilter;
@property (retain, nonatomic) IBOutlet UITableView *channelsTableView;

@end

NS_ASSUME_NONNULL_END
