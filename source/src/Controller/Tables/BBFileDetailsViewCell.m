//
//  BBFileDetailsViewCell.m
//  Spike Recorder
//
//  Created by Stanislav Mircic on 5/30/16.
//  Copyright © 2016 Datta Lab, Harvard University. All rights reserved.
//

#import "BBFileDetailsViewCell.h"

@implementation BBFileDetailsViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
    self.textTI.delegate = self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)dealloc {
    [_nameLabel release];
    [_textTI release];
    [super dealloc];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return FALSE;
}

@end
