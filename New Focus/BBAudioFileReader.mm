//
//  BBBBAudioFileReader.m
//  New Focus
//
//  Created by Alex Wiltschko on 7/10/12.
//  Copyright (c) 2012 Datta Lab, Harvard University. All rights reserved.
//

#import "BBAudioFileReader.h"
#import <pthread.h>
#import "WavManager.h"

static pthread_mutex_t threadLock;


@interface BBAudioFileReader ()
{
    RingBuffer *ringBuffer;
    BOOL isWawFile;
    WavManager * wavManager;
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
    if(self.inputFile)
    {
        ExtAudioFileDispose(self.inputFile);
    }
    
    [super dealloc];
}


- (id)initWithAudioFileURL:(NSURL *)urlToAudioFile samplingRate:(float)thisSamplingRate numChannels:(UInt32)thisNumChannels
{
    self = [super init];
    if (self)
    {
        
        isWawFile = !([[[urlToAudioFile path] uppercaseString] rangeOfString:@".WAV"].location == NSNotFound);
        
        if(isWawFile)
        {
            if(wavManager)
            {
                [wavManager release];
            }
            
            wavManager = [[WavManager alloc] init];
            [wavManager openWav:urlToAudioFile];
            
        }
        else
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
            
            UInt32 codecManf = kAppleSoftwareAudioCodecManufacturer;
            ExtAudioFileSetProperty(_inputFile, kExtAudioFileProperty_CodecManufacturer, sizeof(UInt32), &codecManf);
            
            
            // Apply the format to our file
            ExtAudioFileSetProperty(_inputFile, kExtAudioFileProperty_ClientDataFormat, sizeof(AudioStreamBasicDescription), &_outputFormat);
            
            pthread_mutex_init(&threadLock, NULL);
        }
        
    }
    return self;
}


- (float)getCurrentTime
{
    if(isWawFile)
    {
        return [wavManager getCurrentTime];
    }
    else
    {
        SInt64 frameOffset = 0;
        ExtAudioFileTell(self.inputFile, &frameOffset);
        return (float)frameOffset / self.samplingRate;
    }
    
}


- (void)setCurrentTime:(float)thisCurrentTime
{
    fileIsDone = false;
    
    if(isWawFile)
    {
        [wavManager setCurrentTime:thisCurrentTime];
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            ExtAudioFileSeek(self.inputFile, thisCurrentTime*self.samplingRate);
        });
    }
}

- (float)getDuration
{

    if(isWawFile)
    {
        return [wavManager getDuration];
    }
    else
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
    
}

- (float)retrieveFreshAudio:(float *)buffer numFrames:(UInt32)thisNumFrames numChannels:(UInt32)thisNumChannels
{
 //   dispatch_sync(dispatch_get_main_queue(), ^{
    
    if(isWawFile)
    {
         UInt32 framesRead = [wavManager retrieveFreshAudio:buffer numFrames:thisNumFrames numChannels:thisNumChannels];
        if (framesRead == 0)
        {
            self.fileIsDone = true;
        }
        return [wavManager getCurrentTime];
    }
    else
    {
    
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
        return (float)frameOffset / self.samplingRate;
    }
//    });
}

- (void)retrieveFreshAudio:(float *)buffer numFrames:(UInt32)thisNumFrames numChannels:(UInt32)thisNumChannels seek:(UInt32) position
{
    if(isWawFile)
    {
        [wavManager retrieveFreshAudio:buffer numFrames:thisNumFrames numChannels:thisNumChannels seek:position];
    }
    else
    {
        ExtAudioFileSeek(self.inputFile, position);
        [self retrieveFreshAudio:buffer numFrames:thisNumFrames numChannels:thisNumChannels];
    }
}





@end
