//
//  BBAudioFileWriter.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 6/10/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "Novocaine.h"


@interface BBAudioFileWriter : NSObject

// ----- Read-write ------
@property (nonatomic, copy) NovocaineInputBlock writerBlock;

// ----- Read-only ------
@property (nonatomic, assign, getter=getDuration, readonly) float currentTime;
@property (nonatomic, assign, getter=getDuration, readonly) float duration;
@property (nonatomic, assign, readonly) float samplingRate;
@property (nonatomic, assign, readonly) UInt32 numChannels;
@property (nonatomic, assign, readonly) float latency;
@property (nonatomic, copy, readonly)   NSURL *audioFileURL;
@property (nonatomic, assign, readonly) BOOL recording;


- (id)initWithAudioFileURL:(NSURL *)urlToAudioFile samplingRate:(float)thisSamplingRate numChannels:(UInt32)thisNumChannels;

// You use this method to grab audio if you have your own callback.
// The buffer'll fill at the speed the audio is normally being played.
- (void)writeNewAudio:(float *)newData numFrames:(UInt32)thisNumFrames numChannels:(UInt32)thisNumChannels;
- (void)stop;

@end
