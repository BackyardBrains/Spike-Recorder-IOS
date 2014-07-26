//
//  DynamicFFTGraphGLView.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 7/26/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//


#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include <OpenGLES/ES2/gl.h>
#include <OpenGLES/ES2/glext.h>

@interface DynamicFFTGraphGLView : UIView
{
CAEAGLLayer* _eaglLayer;
EAGLContext* _context;
GLuint _colorRenderBuffer;
GLuint _positionSlot;
GLuint _colorSlot;
}


@end
