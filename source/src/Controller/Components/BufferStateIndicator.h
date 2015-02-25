//
//  BufferStateIndicator.h
//  Spike Recorder
//
//  Created by Stanislav Mircic on 2/25/15.
//  Copyright (c) 2015 Datta Lab, Harvard University. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BufferStateIndicator : UIView
{
    float stateOfBuffer;
    
}

-(void) updateBufferState:(float) bufferState;


@end
