//
//  BBAudioManager.m
//  New Focus
//
//  Created by Alex Wiltschko on 7/4/12.
//

#import "BBAudioManager.h"

static BBAudioManager *bbAudioManager = nil;

@interface BBAudioManager ()
{
    Novocaine *audioManager;
    RingBuffer *ringBuffer;
    __block AudioFileWriter *fileWriter;
    __block BBAudioFileReader *fileReader;
    DSPThreshold *dspThresholder;
    dispatch_queue_t seekingQueue;
    float _threshold;
    
    // We need a special flag for seeking around in a file
    // The audio file reader is very sensitive to threading issues,
    // so we have to babysit it quite closely.
    float desiredSeekTimeInAudioFile;
}

@property BOOL playing;

- (void)loadSettingsFromUserDefaults;

@end

@implementation BBAudioManager

@synthesize samplingRate;

@synthesize numPulsesInDigitalStimulation;
@synthesize stimulationDigitalMessageFrequency;
@synthesize stimulationDigitalDuration;
@synthesize stimulationDigitalDutyCycle;
@synthesize stimulationDigitalFrequency;
@synthesize stimulationPulseFrequency;
@synthesize stimulationPulseDuration;
@synthesize stimulationToneFrequency;
@synthesize stimulationToneDuration;
@synthesize pulseDutyCycle;
@synthesize numPulsesInBiphasicStimulation;
@synthesize numTriggersInThresholdHistory;
@synthesize maxStimulationAmplitude;
@synthesize minStimulationAmplitude;
@synthesize stimulationType;
@synthesize threshold;
@synthesize thresholdDirection;
@synthesize recording;
@synthesize stimulating;
@synthesize thresholding;
@synthesize playing;


#pragma mark - Singleton Methods
+ (BBAudioManager *) bbAudioManager
{
	@synchronized(self)
	{
		if (bbAudioManager == nil) {
			bbAudioManager = [[BBAudioManager alloc] init];
		}
	}
    return bbAudioManager;
}

+ (id)allocWithZone:(NSZone *)zone {
    @synchronized(self) {
        if (bbAudioManager == nil) {
            bbAudioManager = [super allocWithZone:zone];
            return bbAudioManager;  // assignment and return on first allocation
        }
    }
    return nil; // on subsequent allocation attempts return nil
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)retain {
    return self;
}

- (unsigned)retainCount {
    return UINT_MAX;  // denotes an object that cannot be released
}

- (oneway void)release {
    //do nothing
}

#pragma mark - Initialization

- (id)init
{
    if (self = [super init])
    {
        audioManager = [Novocaine audioManager];
        ringBuffer = new RingBuffer(524288, 2);
        
        // Set a default input block acquiring data to a big ring buffer.
        audioManager.inputBlock = ^(float *data, UInt32 numFrames, UInt32 numChannels) {
            ringBuffer->AddNewInterleavedFloatData(data, numFrames, numChannels);
        };
        
        // Initialize parameters to defaults
        [self loadSettingsFromUserDefaults];
                
        recording = false;
        stimulating = false;
        thresholding = false;

    }
    
    return self;
}

- (void)loadSettingsFromUserDefaults
{
    // Make sure we've got our defaults right, y'know? Important.
    NSDictionary *defaultsDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SettingsDefaults" ofType:@"plist"]];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDict];

    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    self.numPulsesInDigitalStimulation = [[defaults valueForKey:@"numPulsesInDigitalStimulation"] intValue];
    self.stimulationDigitalMessageFrequency = [[defaults valueForKey:@"stimulationDigitalMessageFrequency"] floatValue];
    self.stimulationDigitalDuration = [[defaults valueForKey:@"stimulationDigitalDuration"] floatValue];
    self.stimulationDigitalDutyCycle = [[defaults valueForKey:@"stimulationDigitalDutyCycle"] floatValue];
    self.stimulationDigitalFrequency = [[defaults valueForKey:@"stimulationDigitalFrequency"] floatValue];
    self.stimulationPulseFrequency = [[defaults valueForKey:@"stimulationPulseFrequency"] floatValue];
    self.stimulationPulseDuration = [[defaults valueForKey:@"stimulationPulseDuration"] floatValue];
    self.stimulationToneFrequency = [[defaults valueForKey:@"stimulationToneFrequency"] floatValue];
    self.stimulationToneDuration = [[defaults valueForKey:@"stimulationToneDuration"] floatValue];
    self.pulseDutyCycle = [[defaults valueForKey:@"pulseDutyCycle"] floatValue];
    self.numPulsesInBiphasicStimulation = [[defaults valueForKey:@"numPulsesInBiphasicStimulation"] intValue];
    self.maxStimulationAmplitude = [[defaults valueForKey:@"maxStimulationAmplitude"] floatValue];
    self.minStimulationAmplitude = [[defaults valueForKey:@"minStimulationAmplitude"] floatValue];
    _threshold = [[defaults valueForKey:@"threshold"] floatValue];
    self.stimulationType = (BBStimulationType)[[defaults valueForKey:@"stimulationType"] intValue];

}

#pragma mark - Breakdown
- (void)saveSettingsToUserDefaults
{

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults setValue:[NSNumber numberWithInt:numPulsesInDigitalStimulation] forKey:@"numPulsesInDigitalStimulation"];
    [defaults setValue:[NSNumber numberWithFloat:stimulationDigitalMessageFrequency] forKey:@"stimulationDigitalMessageFrequency"];
    [defaults setValue:[NSNumber numberWithFloat:stimulationDigitalDuration] forKey:@"stimulationDigitalDuration"];
    [defaults setValue:[NSNumber numberWithFloat:stimulationDigitalDutyCycle] forKey:@"stimulationDigitalDutyCycle"];
    [defaults setValue:[NSNumber numberWithFloat:stimulationDigitalFrequency] forKey:@"stimulationDigitalFrequency"];
    [defaults setValue:[NSNumber numberWithFloat:stimulationPulseDuration] forKey:@"stimulationPulseDuration"];
    [defaults setValue:[NSNumber numberWithFloat:stimulationToneFrequency] forKey:@"stimulationToneFrequency"];
    [defaults setValue:[NSNumber numberWithFloat:stimulationToneDuration] forKey:@"stimulationToneDuration"];
    [defaults setValue:[NSNumber numberWithFloat:pulseDutyCycle] forKey:@"pulseDutyCycle"];
    [defaults setValue:[NSNumber numberWithInt:numPulsesInBiphasicStimulation] forKey:@"numPulsesInBiphasicStimulation"];
    [defaults setValue:[NSNumber numberWithFloat:maxStimulationAmplitude] forKey:@"maxStimulationAmplitude"];
    [defaults setValue:[NSNumber numberWithFloat:minStimulationAmplitude] forKey:@"minStimulationAmplitude"];
    [defaults setValue:[NSNumber numberWithInt:stimulationType] forKey:@"stimulationType"];
    [defaults setValue:[NSNumber numberWithFloat:_threshold] forKey:@"threshold"];
    [defaults synchronize];
}

#pragma mark - Input Methods
- (void)startMonitoring
{
    if (recording)
        [self stopRecording];
    if (thresholding)
        [self stopThresholding];
    
    audioManager.inputBlock = ^(float *data, UInt32 numFrames, UInt32 numChannels) {
        ringBuffer->AddNewInterleavedFloatData(data, numFrames, numChannels);
    };

}

- (void)startThresholding:(UInt32)newNumPointsToSavePerThreshold
{
    if (recording)
        [self stopRecording];
    
    if (thresholding)
        return;
    
    thresholding = true;
    
    numPointsToSavePerThreshold = newNumPointsToSavePerThreshold;
    
    if (!dspThresholder) {
        dspThresholder = new DSPThreshold(ringBuffer, numPointsToSavePerThreshold, 50);
        dspThresholder->SetThreshold(_threshold);
    }
    
    audioManager.inputBlock = ^(float *data, UInt32 numFrames, UInt32 numChannels) {
        ringBuffer->AddNewInterleavedFloatData(data, numFrames, numChannels);
        dspThresholder->ProcessNewAudio(data, numFrames, numChannels);
    };

    
}

- (void)stopThresholding
{
    if (!thresholding)
        return;
    
    thresholding = false;
    
    // Replace the input block with the old input block, where we just save an in-memory copy of the audio.
    audioManager.inputBlock = ^(float *data, UInt32 numFrames, UInt32 numChannels) {
        ringBuffer->AddNewInterleavedFloatData(data, numFrames, numChannels);
    };
    
//    delete dspThresholder;
}

- (void)startRecording:(NSURL *)urlToFile
{
    // If we're already recording, skip out
    if (recording == true) {
        return;
    }
    
    // If we need to start recording, go ahead and start recording.
    else if (!recording) {
        
        recording = true;
        
        // Grab a file writer. This takes care of the creation and management of the audio file.
        fileWriter = [[AudioFileWriter alloc] 
                      initWithAudioFileURL:urlToFile 
                      samplingRate:audioManager.samplingRate 
                      numChannels:audioManager.numInputChannels];
        
        // Replace the audio input function
        // We're still going to save an in-copy memory of the audio for display,
        // but we'll also write the audio data to file as well (it's asynchronous, don't worry)
        audioManager.inputBlock = ^(float *data, UInt32 numFrames, UInt32 numChannels) {
            ringBuffer->AddNewInterleavedFloatData(data, numFrames, numChannels);
            [fileWriter writeNewAudio:data numFrames:numFrames numChannels:numChannels];
        };
        
    }
}

- (void)stopRecording
{
    recording = false;
    
    // Replace the input block with the old input block, where we just save an in-memory copy of the audio.
    audioManager.inputBlock = ^(float *data, UInt32 numFrames, UInt32 numChannels) {
        ringBuffer->AddNewInterleavedFloatData(data, numFrames, numChannels);
    };
    
    // do the breakdown
    [fileWriter release];

}

- (void)startPlaying:(NSURL *)urlToFile
{

    if (self.playing == true)
        return;
    
    if (self.playing == false && fileReader != nil)
        fileReader = nil;
    
    ringBuffer->Clear();
    fileReader = [[BBAudioFileReader alloc] 
                  initWithAudioFileURL:urlToFile 
                  samplingRate:audioManager.samplingRate
                  numChannels:audioManager.numOutputChannels];
    
    audioManager.inputBlock = nil;
    audioManager.outputBlock = ^(float *data, UInt32 numFrames, UInt32 numChannels) {
        
        if (!self.playing) {
            memset(data, 0, numChannels*numFrames*sizeof(float));
            return;
        }
        
        [fileReader retrieveFreshAudio:data numFrames:numFrames numChannels:numChannels];
        ringBuffer->AddNewInterleavedFloatData(data, numFrames, numChannels);

        if (fileReader.fileIsDone) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                fileReader.currentTime = 0.0f;
                [self pausePlaying];
            });
            return;
        }
        
    };
    
    [self resumePlaying];


}

- (void)stopPlaying
{
    // Mark ourselves as not playing
    [self pausePlaying];
    audioManager.outputBlock = nil;
        
    // Toss the file reader.
    [fileReader release];
    fileReader = nil;
    
    ringBuffer->Clear();

}

- (void)pausePlaying
{
    self.playing = false;
}

- (void)resumePlaying
{
    self.playing = true;
    


}

- (void)fetchAudio:(float *)data numFrames:(UInt32)numFrames whichChannel:(UInt32)whichChannel stride:(UInt32)stride
{
    if (!thresholding) {
        ringBuffer->FetchFreshData2(data, numFrames, whichChannel, stride);
    }
    else if (thresholding) {
        // NOTE: this is not multi-channel
        dspThresholder->GetCenteredTriggeredData(data, numFrames, stride);
    }
    
}

#pragma mark - Output Methods
- (void)startStimulating:(BBStimulationType)newStimulationType
{
        
    self.stimulating = true;
    self.stimulationType = newStimulationType;

    // PWM
    // ============================================================
    if (stimulationType == BBStimulationTypePWM) {
        __block int sample = 0;
        
        audioManager.outputBlock = ^(float *data, UInt32 numFrames, UInt32 numChannels) {
            int numSamplesInPeriod = audioManager.samplingRate / stimulationPulseFrequency;
            int numSamplesOn = (int)(pulseDutyCycle * audioManager.samplingRate / stimulationPulseFrequency);
            for (int i=0; i < numFrames; ++i) {
                for (int iChannel = 0; iChannel < numChannels; ++iChannel) {
                    data[i*numChannels+iChannel] = (sample < numSamplesOn) ? maxStimulationAmplitude : minStimulationAmplitude;
                }
                sample += 1;
                if (sample >= numSamplesInPeriod) {
                    sample = 0;
                }
            }
        };
        
    }
    
    
    
    else if (stimulationType == BBStimulationTypePWMPulse) {
        
        __block float secondsPlayed = 0.0f;
        __block int sample = 0;
        
        audioManager.outputBlock = ^(float *data, UInt32 numFrames, UInt32 numChannels) {
            
            if (secondsPlayed < stimulationPulseDuration) {
                
                int numSamplesInPeriod = audioManager.samplingRate / stimulationPulseFrequency;
                int numSamplesOn = (int)(pulseDutyCycle * audioManager.samplingRate / stimulationPulseFrequency);
                for (int i=0; i < numFrames; ++i) {
                    for (int iChannel = 0; iChannel < numChannels; ++iChannel) {
                        data[i*numChannels+iChannel] = (sample < numSamplesOn) ? maxStimulationAmplitude : minStimulationAmplitude;
                    }
                    sample += 1;
                    if (sample >= numSamplesInPeriod) {
                        sample = 0;
                    }
                    
                    
                }
                secondsPlayed += (float)numFrames / self.samplingRate;
            }
            else {
                audioManager.outputBlock = nil;
                self.stimulating = false;
            }
        };
    }

    
    
    // Single-shot PWM
    // ============================================================
    
    // The pulses should be 1ms width. 
    else if (stimulationType == BBStimulationTypeBiphasic) {

        __block int sample = 0;
        __block int numPulsesPlayed = 0;
        
        audioManager.outputBlock = ^(float *data, UInt32 numFrames, UInt32 numChannels) {
            
            int numSamplesInPeriod = audioManager.samplingRate / self.stimulationPulseFrequency;
            int numSamplesOn = (int)(audioManager.samplingRate / 1000.0f); // always 1ms pulses
            
            if (numPulsesPlayed < numPulsesInBiphasicStimulation) {
                
                for (int i=0; i < numFrames; ++i) {
                    for (int iChannel = 0; iChannel < numChannels; ++iChannel) {
                        data[i*numChannels+iChannel] = (sample < numSamplesOn) ? maxStimulationAmplitude : minStimulationAmplitude;
                    }
                    sample = sample + 1;
                    if (sample >= numSamplesInPeriod) {
                        sample = 0;
                        numPulsesPlayed = numPulsesPlayed + 1;
                    }
                }
                
            }
            
            else {
                audioManager.outputBlock = nil;
                self.stimulating = false;
            }
            
        };
    }
    
    // Pure Tone
    // ============================================================
    else if (stimulationType == BBStimulationTypeTone) {
        
        __block float phase = 0.0;
        
        audioManager.outputBlock = ^(float *data, UInt32 numFrames, UInt32 numChannels)
         {

             for (int i=0; i < numFrames; ++i)
             {
                 for (int iChannel = 0; iChannel < numChannels; ++iChannel) 
                 {
                     float theta = phase * M_PI * 2;
                     data[i*numChannels + iChannel] = sin(theta);
                 }
                 phase += 1.0 / (self.samplingRate / self.stimulationToneFrequency);
                 if (phase > 1.0) phase = -1;
             }
         };
    }
    
    // Pure Tone Pulse
    // ============================================================

    else if (stimulationType == BBStimulationTypeTonePulse) {
        
        __block float phase = 0.0f;
        __block float secondsPlayed = 0.0f;
        
        audioManager.outputBlock = ^(float *data, UInt32 numFrames, UInt32 numChannels) {
            
            if (secondsPlayed < stimulationToneDuration) {
            
                for (int i=0; i < numFrames; ++i)
                {
                    for (int iChannel = 0; iChannel < numChannels; ++iChannel) 
                    {
                        float theta = phase * M_PI * 2;
                        data[i*numChannels + iChannel] = sin(theta);
                    }
                    phase += 1.0 / (self.samplingRate / self.stimulationToneFrequency);
                    if (phase > 1.0) phase = -1;
                }
                secondsPlayed += (float)numFrames / self.samplingRate;
            }

            else {
                audioManager.outputBlock = nil;
                self.stimulating = false;
            }

        };
    }
    
    
    // Digital Control (bursts of high-frequency pure tones, ~20KHz,
    // which custom hardware is designed to interpret)
    // ============================================================
    

        
    else if (stimulationType == BBStimulationTypeDigitalControlPulse) {
        __block float pulsed_phase = 0.0f;
        __block int pulsed_sample = 0;
        __block int numPulsesPlayed = 0;

        
        audioManager.outputBlock = ^(float *data, UInt32 numFrames, UInt32 numChannels) {
            
            int numSamplesInPeriod = audioManager.samplingRate / self.stimulationDigitalFrequency;
            int numSamplesOn = (int)(self.stimulationDigitalDutyCycle * audioManager.samplingRate / self.stimulationDigitalFrequency);
            
            if (numPulsesPlayed < self.numPulsesInDigitalStimulation) {

                if (pulsed_sample + numFrames >= numSamplesInPeriod) {
                    numPulsesPlayed += 1;
                    
                    if (numPulsesPlayed == self.numPulsesInDigitalStimulation) {
                        numFrames = numSamplesInPeriod - pulsed_sample;
                    }
                }
                
                float samplingRate = self.samplingRate;
                float messageFrequency = self.stimulationDigitalMessageFrequency;
            
                for (int i=0; i < numFrames; ++i) {
                    for (int iChannel = 0; iChannel < numChannels; ++iChannel) {
                        float theta = pulsed_phase * M_PI * 2;
                        data[i*numChannels+iChannel] = (pulsed_sample < numSamplesOn) ? sin(theta) : 0.0f;
                    }

                    pulsed_phase += 1.0 / (samplingRate / messageFrequency);
                    if (pulsed_phase > 1.0) pulsed_phase -= 2; // TODO: test this thingy
                    pulsed_sample += 1;
                    if (pulsed_sample >= numSamplesInPeriod) {
                        pulsed_sample = 0;
                    }
                    
                }

            }

            else {
                audioManager.outputBlock = nil;
                self.stimulating = false;
            }
        };
    }
    
    
    else if (stimulationType == BBStimulationTypeDigitalControl) {
        
        __block float phase = 0.0f;
        __block int sample = 0;
        
        audioManager.outputBlock = ^(float *data, UInt32 numFrames, UInt32 numChannels) {
            
            int numSamplesInPeriod = audioManager.samplingRate / self.stimulationDigitalFrequency;
            int numSamplesOn = (int)(self.stimulationDigitalDutyCycle * audioManager.samplingRate / self.stimulationDigitalFrequency);
            
            float samplingRate = self.samplingRate;
            float messageFrequency = self.stimulationDigitalMessageFrequency;
            
            for (int i=0; i < numFrames; ++i) {
                for (int iChannel = 0; iChannel < numChannels; ++iChannel) {
                    float theta = phase * M_PI * 2;
                    data[i*numChannels+iChannel] = (sample < numSamplesOn) ? sin(theta) : 0.0f;
                }
                
                phase += 1.0 / (samplingRate / messageFrequency);
                if (phase > 1.0) phase -= 2; // TODO: test this thingy
                sample += 1;
                if (sample >= numSamplesInPeriod) {
                    sample = 0;
                }
            }

                        
        };
    }
    
    
    
    
}


- (void)stopStimulating
{
    self.stimulating = false;
    audioManager.outputBlock = nil;    
}



#pragma mark - State
- (void)setThreshold:(float)newThreshold
{
    _threshold = newThreshold;
    
    if (dspThresholder)
        dspThresholder->SetThreshold(newThreshold);
}

- (float)threshold
{
    
    if (dspThresholder) {
        _threshold = dspThresholder->GetThreshold();
        return _threshold;
    }
    else {
        return 0;
    }
}

- (BBThresholdType)thresholdDirection
{
    if (dspThresholder) {
        return dspThresholder->GetThresholdDirection();
    }

    return BBThresholdTypeNone;
    
}

- (void)setThresholdDirection:(BBThresholdType)newThresholdDirection
{
    if (dspThresholder) {
        dspThresholder->SetThresholdDirection(newThresholdDirection);
    }
}

- (float)currentFileTime
{
    if (fileReader) {
        return fileReader.currentTime;
    }
    if (fileWriter) {
        return fileWriter.duration;
    }

    return 0;
}

- (void)setCurrentFileTime:(float)newCurrentFileTime
{
    
    if (fileReader) {
        fileReader.currentTime = newCurrentFileTime;
    }
}

- (float)fileDuration
{
    
    if (fileReader) {
        return fileReader.duration;
    }
    if (fileWriter) {
        return fileWriter.duration;
    }
    
    return 0;
    
}

- (float)samplingRate
{
    return audioManager.samplingRate;
}

- (void)setNumTriggersInThresholdHistory:(UInt32)numTriggersInThresholdHistory
{
    if (dspThresholder)
    {
        dspThresholder->SetNumTriggersInHistory(numTriggersInThresholdHistory);
    }
}

- (UInt32)numTriggersInThresholdHistory
{
    if (dspThresholder)
    {
        return dspThresholder->GetNumTriggersInHistory();
    }
    else
    {
        return 0;
    }
}

@end
