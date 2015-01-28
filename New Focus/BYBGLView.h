//
//  BYBGLView.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 1/26/15.
//  Copyright (c) 2015 Datta Lab, Harvard University. All rights reserved.
//

#import "CCGLTouchView.h"

@interface BYBGLView : CCGLTouchView


+(UIColor *) getSpikeTrainColorWithIndex:(int) iindex transparency:(float) transp;
-(void) setGLColor:(UIColor *) theColor;

@end
