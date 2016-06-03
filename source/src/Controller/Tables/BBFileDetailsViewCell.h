//
//  BBFileDetailsViewCell.h
//  Spike Recorder
//
//  Created by Stanislav Mircic on 5/30/16.
//  Copyright © 2016 Datta Lab, Harvard University. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BBFileDetailsViewCell : UITableViewCell <UITextFieldDelegate>

@property (retain, nonatomic) IBOutlet UILabel *nameLabel;
@property (retain, nonatomic) IBOutlet UITextField *textTI;

@end
