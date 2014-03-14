//
//  RecordingOverlayController.h
//  BYB2
//
//  Created by Alex Wiltschko on 8/7/12.
//  Copyright (c) 2012 Datta Lab, Harvard University. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RecordingOverlay.h"
#import "BBAudioManager.h"

typedef void (^CompletionBlock)();

@interface RecordingOverlayController : UIViewController
{
    RecordingOverlay *recordingOverlayView;
    CompletionBlock completionBlock;
}

- (id)initWithCompletionBlock:(CompletionBlock)thisCompletionBlock;

@property (nonatomic, copy) CompletionBlock completionBlock;
@end
