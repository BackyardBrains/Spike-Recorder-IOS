//
//  FFTViewController.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 7/16/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "CCGLTouchViewController.h"
#import "FFTCinderGLView.h"
#import "BBAudioManager.h"

@interface FFTViewController : CCGLTouchViewController
{
    FFTCinderGLView *glView;
}

@end
