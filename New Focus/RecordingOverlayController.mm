//
//  RecordingOverlayController.m
//  BYB2
//
//  Created by Alex Wiltschko on 8/7/12.
//  Copyright (c) 2012 Datta Lab, Harvard University. All rights reserved.
//

#import "RecordingOverlayController.h"

@interface RecordingOverlayController ()
{
    NSTimer *theTimer;
}
@end

@implementation RecordingOverlayController
@synthesize completionBlock;

- (id)initWithCompletionBlock:(CompletionBlock)thisCompletionBlock {
    if (self = [super init]) {
        
        completionBlock = Block_copy(thisCompletionBlock);
        
        CGRect windowFrame = [[[[UIApplication sharedApplication] windows] objectAtIndex:0] frame];
        
        recordingOverlayView = [[RecordingOverlay alloc] initWithFrame:windowFrame];
        self.view = recordingOverlayView;

        [[[[UIApplication sharedApplication] windows] objectAtIndex:0] addSubview:recordingOverlayView];
        [[[[UIApplication sharedApplication] windows] objectAtIndex:0] bringSubviewToFront:recordingOverlayView];
        
        theTimer = [NSTimer timerWithTimeInterval:1.0 target:self.view selector:@selector(setNeedsDisplay) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:theTimer forMode:NSRunLoopCommonModes];
        
        self.view.alpha = 0.0f;
        [UIView animateWithDuration:0.4 animations:^{ self.view.alpha = 1.0f; }];
        self.view.contentMode = UIViewContentModeRedraw;

    }
    
    return self;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    // Breakdown the view right now
    if (theTimer) {
        NSLog(@"BOOOO");
        dispatch_async(dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.4
                             animations:^{
                                 self.view.alpha = 0.0f;
                             }
                             completion:^(BOOL finished) {
                                 
                                 //dispatch_async(dispatch_get_current_queue(), completionBlock);
                                 dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), completionBlock);
                                 
                                 [theTimer invalidate];
                                 theTimer = nil;
                                 [self.view removeFromSuperview];
                                 [self release];
                                 
                                 
                             }];
        });
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}

@end
