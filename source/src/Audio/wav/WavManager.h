//
//  WavManager.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 6/7/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import <Foundation/Foundation.h>

#define WAVE_FORMAT_IEEE_FLOAT 3 //32 bit float type
#define WAVE_FORMAT_PCM  1//16 bit integer
#define WAVE_FORMAT_UNKNOWN  0//16 bit integer

struct WavProperties
{
    long sampleRate;
    unsigned int compressionType;
    unsigned int numOfChannels;
    unsigned int bitsPerSample;
};

@interface WavManager : NSObject
{
    struct WavProperties fileProperties;
    
}
@property (nonatomic, assign) NSFileHandle *fileHandle;
@property (nonatomic, copy, readwrite) NSURL *fileURL;

-(void) createWav:(NSURL *)urlToFile samlingRate:(float) samplingRate numberOfChannels:(int) numberOfChannels;
-(void) appendData:(float *) dataBuffer numberOfFrames:(int) numberOfFrames;
-(void) finishFile;
-(float) getDuration;
-(struct WavProperties) openWav:(NSURL *)urlToFile;
- (UInt32)retrieveFreshAudio:(float *)buffer numFrames:(UInt32)thisNumFrames numChannels:(UInt32)thisNumChannels;
- (UInt32)retrieveFreshAudio:(float *)buffer numFrames:(UInt32)thisNumFrames numChannels:(UInt32)thisNumChannels seek:(UInt32) position;
-(float) getCurrentTime;
-(void) setCurrentTime:(float) newTime;
 @end
