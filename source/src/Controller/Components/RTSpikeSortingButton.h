//
//  RTSpikeSortingButton.h
//  Spike Recorder
//
//  Created by Stanislav Mircic on 3/17/15.
//  Copyright (c) 2015 Datta Lab, Harvard University. All rights reserved.
//

#import <UIKit/UIKit.h>
#define TICK_MARK_STATE 0
#define HANDLE_STATE 1


@interface RTSpikeSortingButton : UIView
{
    UIColor * currentColor;
    int currentState;
}

-(void) objectColor:(UIColor * ) theColor;
-(void) changeCurrentState:(int) newCurrentState;
-(int) currentStatus;
@end
