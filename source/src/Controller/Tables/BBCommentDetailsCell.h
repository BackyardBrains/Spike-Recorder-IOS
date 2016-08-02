//
//  BBCommentDetailsCell.h
//  Spike Recorder
//
//  Created by Stanislav Mircic on 5/30/16.
//  Copyright © 2016 Datta Lab, Harvard University. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BBCommentDetailsCell : UITableViewCell <UITextViewDelegate>
@property (retain, nonatomic) IBOutlet UILabel *titleLabel;

@property (retain, nonatomic) IBOutlet UITextView *textTV;

@end
