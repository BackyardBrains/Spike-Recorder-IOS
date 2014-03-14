//
//  BBBBAudioFileReader.m
//  New Focus
//
//  Created by Alex Wiltschko on 7/10/12.
//  Copyright (c) 2012 Datta Lab, Harvard University. All rights reserved.
//

#import "BBAudioFileReader.h"
#import <pthread.h>

static pthread_mutex_t threadLock;


@interface BBAudioFileReader ()
{
    RingBuffer *ringBuffer;
}

@property AudioStreamBasicDescription outputFormat;
@property ExtAudioFileRef inputFile;
@property SInt64 currentFileTime;



@end



@implementation BBAudioFileReader

@synthesize outputFormat = _outputFormat;
@synthesize inputFile = _inputFile;
@synthesize currentFileTime = _currentFileTime;
@synthesize currentTime = _currentTime;
@synthesize duration = _duration;
@synthesize samplingRate = _samplingRate;
@synthesize numChannels = _numChannels;
@synthesize audioFileURL = _audioFileURL;
@synthesize fileIsDone;

- (void)dealloc
{
    // Close the ExtAudioFile
    ExtAudioFileDispose(self.inputFile);
    
    [super dealloc];
}


- (id)initWithAudioFileURL:(NSURL *)urlToAudioFile samplingRate:(float)thisSamplingRate numChannels:(UInt32)thisNumChannels
{
    self = [super init];
    if (self)
    {
        
        
        // Open a reference to the audio file
        self.audioFileURL = urlToAudioFile;
        CFURLRef audioFileRef = (CFURLRef)self.audioFileURL;
        CheckError(ExtAudioFileOpenURL(audioFileRef, &_inputFile), "Opening file URL (ExtAudioFileOpenURL)");
        
        
        // Set a few defaults and presets
        self.samplingRate = thisSamplingRate;
        self.numChannels = thisNumChannels;        
        
        // We're going to impose a format upon the input file
        // Single-channel float does the trick.
        _outputFormat.mSampleRate = self.samplingRate;
        _outputFormat.mFormatID = kAudioFormatLinearPCM;
        _outputFormat.mFormatFlags = kAudioFormatFlagIsFloat;
        _outputFormat.mBytesPerPacket = 4*self.numChannels;
        _outputFormat.mFramesPerPacket = 1;
        _outputFormat.mBytesPerFrame = 4*self.numChannels;
        _outputFormat.mChannelsPerFrame = self.numChannels;
        _outputFormat.mBitsPerChannel = 32;
        
        // Apply the format to our file
        ExtAudioFileSetProperty(_inputFile, kExtAudioFileProperty_ClientDataFormat, sizeof(AudioStreamBasicDescription), &_outputFormat);
        
        pthread_mutex_init(&threadLock, NULL);
        
    }
    return self;
}


- (float)getCurrentTime
{
    SInt64 frameOffset = 0;
    ExtAudioFileTell(self.inputFile, &frameOffset);
    return (float)frameOffset / self.samplingRate;
    return 0.0f;
}


- (void)setCurrentTime:(float)thisCurrentTime
{
    fileIsDone = false;
    dispatch_async(dispatch_get_main_queue(), ^{
        ExtAudioFileSeek(self.inputFile, thisCurrentTime*self.samplingRate);
    });
}

- (float)getDuration
{

    // We're going to directly calculate the duration of the audio file (in seconds)
    SInt64 framesInThisFile;
    UInt32 propertySize = sizeof(framesInThisFile);
    ExtAudioFileGetProperty(self.inputFile, kExtAudioFileProperty_FileLengthFrames, &propertySize, &framesInThisFile);
    
    AudioStreamBasicDescription fileStreamFormat;
    propertySize = sizeof(AudioStreamBasicDescription);
    ExtAudioFileGetProperty(self.inputFile, kExtAudioFileProperty_FileDataFormat, &propertySize, &fileStreamFormat);
    
    return (float)framesInThisFile/(float)fileStreamFormat.mSampleRate;
    
}

- (void)retrieveFreshAudio:(float *)buffer numFrames:(UInt32)thisNumFrames numChannels:(UInt32)thisNumChannels
{
//    dispatch_sync(dispatch_get_main_queue(), ^{
    
        AudioBufferList incomingAudio;
        incomingAudio.mNumberBuffers = 1;
        incomingAudio.mBuffers[0].mNumberChannels = thisNumChannels;
        incomingAudio.mBuffers[0].mDataByteSize = thisNumFrames*thisNumChannels*sizeof(float);
        incomingAudio.mBuffers[0].mData = buffer;
        
        // Figure out where we are in the file
        SInt64 frameOffset = 0;
        ExtAudioFileTell(self.inputFile, &frameOffset);
        self.currentFileTime = (float)frameOffset / self.samplingRate;
        
        // Read the audio
        UInt32 framesRead = thisNumFrames;
        ExtAudioFileRead(self.inputFile, &framesRead, &incomingAudio);

        
        
        if (framesRead == 0)
            self.fileIsDone = true;
//    });
}

- (void)retrieveFreshAudio:(float *)buffer numFrames:(UInt32)thisNumFrames numChannels:(UInt32)thisNumChannels seek:(UInt32) position
{
    
    //    dispatch_sync(dispatch_get_main_queue(), ^{
    ExtAudioFileSeek(self.inputFile, position);
    AudioBufferList incomingAudio;
    incomingAudio.mNumberBuffers = 1;
    incomingAudio.mBuffers[0].mNumberChannels = thisNumChannels;
    incomingAudio.mBuffers[0].mDataByteSize = thisNumFrames*thisNumChannels*sizeof(float);
    incomingAudio.mBuffers[0].mData = buffer;
    
    // Figure out where we are in the file
    SInt64 frameOffset = 0;
    ExtAudioFileTell(self.inputFile, &frameOffset);
    self.currentFileTime = (float)frameOffset / self.samplingRate;
    
    // Read the audio
    UInt32 framesRead = thisNumFrames;
    ExtAudioFileRead(self.inputFile, &framesRead, &incomingAudio);
    
    
    
    if (framesRead == 0)
        self.fileIsDone = true;
    //    });
}





@end
