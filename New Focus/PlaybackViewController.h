//
//  PlaybackViewController.h
//  New Focus
//
//  Created by Alex Wiltschko on 7/9/12.
//  Copyright (c) 2012 Datta Lab, Harvard University. All rights reserved.
//

#import "CCGLTouchViewController.h"
#import "MyCinderGLView.h"
#import "BBAudioManager.h"
#import "BBFile.h"


@interface PlaybackViewController : CCGLTouchViewController
{
    MyCinderGLView *glView;
}

- (void)setGLView:(CCGLTouchView *)view;

@property (retain, nonatomic) BBFile *bbfile;

@property (retain, nonatomic) IBOutlet UIButton *playPauseButton;
@property (retain, nonatomic) IBOutlet UISlider *timeSlider;


- (IBAction)sliderValueChanged:(id)sender;
- (IBAction)playPauseButtonPressed:(id)sender;

@end
