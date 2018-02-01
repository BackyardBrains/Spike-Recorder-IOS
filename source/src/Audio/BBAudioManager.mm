//
//  BBAudioManager.m
//  New Focus
//
//  Created by Alex Wiltschko on 7/4/12.
//

#import "BBAudioManager.h"
#import "BBAnalysisManager.h"
#import "BBFile.h"
#import "BBSpike.h"
#import "BBSpikeTrain.h"
#import "BBChannel.h"
#import <Accelerate/Accelerate.h>
#import "BBECGAnalysis.h"

//#define RING_BUFFER_SIZE 524288
#define LENGTH_OF_EKG_BEEP_IN_SAMPLES 4851//0.11*44100
static BBAudioManager *bbAudioManager = nil;

@interface BBAudioManager ()
{
    Novocaine *audioManager;
    RingBuffer *ringBuffer;
    __block BBAudioFileWriter *fileWriter;
    __block BBAudioFileReader *fileReader;
    DSPThreshold *dspThresholder;
    DSPAnalysis *dspAnalizer;
    dispatch_queue_t seekingQueue;
    float _threshold;
    float _selectionStartTime;
    float _selectionEndTime;
    float _timeSpan;
    float selectionRMS;
    NSMutableArray* _spikeCountInSelection;
    BBFile * _file;
    //precise time used to sinc spikes display with waveform
    float _preciseTimeOfLastData;
    // We need a special flag for seeking around in a file
    // The audio file reader is very sensitive to threading issues,
    // so we have to babysit it quite closely.
    float desiredSeekTimeInAudioFile;
    float lastSeekPosition;
    float * tempCalculationBuffer;//used to load data for display while scrubbing

    UInt32 lastNumberOfSampleDisplayed;//used to find position of selection in trigger view
    
    int _sourceNumberOfChannels;
    float _sourceSamplingRate;
    
    int _selectedChannel;
    
    int maxNumberOfSamplesToDisplay;
    Float32 * tempResamplingIndexes;
    float * tempResamplingBuffer;
    float * tempResampledBuffer;
    bool differentFreqInOut;
    
    //basic stats
    float _currentSTD;
    float _currentMax;
    float _currentMin;
    float _currentMean;
    
   
    //ECG
    BBECGAnalysis * ecgAnalysis;
   // float * ekgBeepBuffer;
    
    //======bt thing
   /* EAAccessory *_accessory;
    EASession *_session;
    NSInteger availableBtData;
    NSMutableData *_writeData;
    NSMutableData *_readData;
    */
}

@property BOOL playing;

- (void)loadSettingsFromUserDefaults;

@end

@implementation BBAudioManager

@synthesize samplingRate;
//@synthesize sourceSamplingRate;
//@synthesize sourceNumberOfChannels;


@synthesize numTriggersInThresholdHistory;

@synthesize threshold;
@synthesize thresholdDirection;
@synthesize recording;
@synthesize stimulating;
@synthesize thresholding;
@synthesize selecting;
@synthesize playing;
@synthesize seeking;
@synthesize btOn;
@synthesize FFTOn;
@synthesize ECGOn;
@synthesize rtSpikeSorting;
@synthesize amOffset;
@synthesize amDemodulationIsON;
@synthesize currentFilterSettings;
@synthesize maxVoltageVisible;


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
        
        
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(filterParametersChanged) name:FILTER_PARAMETERS_CHANGED object:nil];
        
          [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resetupAudioInputs) name:@"audioChannelsChanged" object:nil];
        
        
        audioManager = [Novocaine audioManager];
        maxVoltageVisible = -100;//this negative voltage is sign that it is not set at all
        _sourceSamplingRate =  audioManager.samplingRate;
         NSLog(@"Init sampling rate: %f", _sourceSamplingRate);
        _sourceNumberOfChannels = audioManager.numInputChannels;
        
        _selectedChannel = 0;
        _spikeCountInSelection = [[NSMutableArray alloc] initWithCapacity:0];
        
        NSDictionary *defaultsDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SettingsDefaults" ofType:@"plist"]];
        [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDict];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        tempResamplingIndexes = (Float32 *)calloc(1024, sizeof(Float32));
        tempResamplingBuffer = (float *)calloc(1024, sizeof(float));
        tempResampledBuffer = (float *)calloc(1024, sizeof(float));
        
        maxNumberOfSamplesToDisplay = [[defaults valueForKey:@"numSamplesMaxNew"] integerValue];

        //Setup initial values for statistics
        _currentMax = [[defaults valueForKey:@"numVoltsMaxUpdate1"] floatValue]*0.8;
        _currentMin = -[[defaults valueForKey:@"numVoltsMaxUpdate1"] floatValue]*0.8;
        _currentMean = 0.0f;
        _currentSTD = _currentMax/6.0f;

        ringBuffer = new RingBuffer(maxNumberOfSamplesToDisplay, _sourceNumberOfChannels);
        tempCalculationBuffer = (float *)calloc(maxNumberOfSamplesToDisplay*_sourceNumberOfChannels, sizeof(float));

        lastSeekPosition = -1;
        dspAnalizer = new DSPAnalysis();
        
        
        
        // Set a default input block acquiring data to a big ring buffer.
        [audioManager setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels) {
            ringBuffer->AddNewInterleavedFloatData(data, numFrames, numChannels);
        }];
        
        // Initialize parameters to defaults
        [self loadSettingsFromUserDefaults];
        
        recording = false;
        stimulating = false;
        thresholding = false;
        selecting = false;
        FFTOn = false;
        ECGOn = false;
        btOn = false;
        rtSpikeSorting = false;
        
        [self filterParametersChanged];
        
        
        
        amDetectionNotchFilter = [[NVNotchFilter alloc] initWithSamplingRate:_sourceSamplingRate];
        amDetectionNotchFilter.centerFrequency = AM_CARRIER_FREQUENCY;
        amDetectionNotchFilter.q = 1.0  ;
        
        amDetectionLPFilter= [[NVLowpassFilter alloc] initWithSamplingRate:_sourceSamplingRate];
        amDetectionLPFilter.cornerFrequency = 6000;
        amDetectionLPFilter.Q = 0.8f;
        
        
        filterAMStage1= [[NVLowpassFilter alloc] initWithSamplingRate:_sourceSamplingRate];
        filterAMStage1.cornerFrequency = AM_DEMODULATION_CUTOFF;
        filterAMStage1.Q = 0.8f;
        
        filterAMStage2= [[NVLowpassFilter alloc] initWithSamplingRate:_sourceSamplingRate];
        filterAMStage2.cornerFrequency = AM_DEMODULATION_CUTOFF;
        filterAMStage2.Q = 0.8f;
        
        filterAMStage3= [[NVLowpassFilter alloc] initWithSamplingRate:_sourceSamplingRate];
        filterAMStage3.cornerFrequency = AM_DEMODULATION_CUTOFF;
        filterAMStage3.Q = 0.8f;
        
        amDCLevelRemovalCh1 = 0.231;
        amDCLevelRemovalCh2 = 0.231;

        
        rmsOfOriginalSignal = 0;
        rmsOfNotchedSignal = 0;
        amOffset = 0;
        
        ecgAnalysis = [[BBECGAnalysis alloc] init];
        [ecgAnalysis initECGAnalysisWithSamplingRate:_sourceSamplingRate numOfChannels:_sourceNumberOfChannels];
        
      /*  ekgBeepBuffer = (float *)calloc(LENGTH_OF_EKG_BEEP_IN_SAMPLES, sizeof(float));
        int i;
        int silentIndex = 44100*0.01;
        float frequencyOfBeep =2000.0;
        float periodInSamples = 44100.0/frequencyOfBeep;
        float angleIncrement = (2.0f*M_PI)/(float)periodInSamples;
        float angleForSin = 0;
        for(i=0;i<LENGTH_OF_EKG_BEEP_IN_SAMPLES;i++)
        {
            if(i<silentIndex)
            {
                ekgBeepBuffer[i] = 0.0f;
            }
            else
            {
                
                ekgBeepBuffer[i] = 100.1f*sinf(angleForSin);
                angleForSin += angleIncrement;
            }
        }*/

        
        currentFilterSettings = FILTER_SETTINGS_RAW;
        lpFilterCutoff = FILTER_LP_OFF;
        hpFilterCutoff = FILTER_HP_OFF;
        [audioManager play];
    }
    
    return self;
}


-(void) filterParametersChanged
{
  /*  NSDictionary *defaultsDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SettingsDefaults" ofType:@"plist"]];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDict];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    float lowFilterValue = [[defaults valueForKey:@"lowFilterFreq"] floatValue];
    //Check if cut-off freq is too high
    if(lowFilterValue>(_sourceSamplingRate*0.3f))
    {
        lowFilterValue = (_sourceSamplingRate*0.3f);
        //if cut-off freq is too high change it and save it
        NSDictionary *defaultsDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SettingsDefaults" ofType:@"plist"]];
        [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDict];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        [defaults setValue:[NSNumber numberWithFloat:lowFilterValue] forKey:@"lowFilterFreq"];
    }
    
    float highFilterValue = [[defaults valueForKey:@"highFilterFreq"] floatValue];
    
    
    //Check if cut-off freq is too high
    if(highFilterValue>(_sourceSamplingRate*0.3f))
    {
        highFilterValue = (_sourceSamplingRate*0.3f);
        //if cut-off freq is too high change it and save it
        NSDictionary *defaultsDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SettingsDefaults" ofType:@"plist"]];
        [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDict];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        [defaults setValue:[NSNumber numberWithFloat:highFilterValue] forKey:@"highFilterFreq"];
    }
    
    notchIsOn = [[defaults valueForKey:@"notchFilterOn"] boolValue];
    
    NSLog(@" ************     MAKE FILTERS   ******************");
    NSLog(@"Filter: %f - %f", lowFilterValue, highFilterValue);
    if(notchIsOn)
    {
        NSLog(@"Notch active");
    }
    else
    {
        NSLog(@"Notch OFF");
    }
    
    LPFilter= [[NVLowpassFilter alloc] initWithSamplingRate:_sourceSamplingRate];
    LPFilter.cornerFrequency = highFilterValue;
    LPFilter.Q = 0.8f;
    
    //[LPFilter logCoefficients];
    
    if(lowFilterValue<1.0)
    {
        HPFilter = nil;
    }
    else
    {
        //patch for instability interval
        int tempFilterValue = (int)lowFilterValue;
        lowFilterValue = (float) tempFilterValue;
        if(tempFilterValue==2)
        {
            lowFilterValue = 2.2f;
        }
        if(tempFilterValue == 6)
        {
            lowFilterValue = 6.2;
        }
        if(tempFilterValue == 9)
        {
            lowFilterValue = 9.2;
        }
        //end of patch

        HPFilter = [[NVHighpassFilter alloc] initWithSamplingRate:_sourceSamplingRate];
        HPFilter.cornerFrequency = lowFilterValue;
        HPFilter.Q = 0.51f;
    }
    //[HPFilter logCoefficients];
    
    NotchFilter = [[NVNotchFilter alloc] initWithSamplingRate:_sourceSamplingRate];
    NotchFilter.centerFrequency = 60.0f;
    NotchFilter.q = 1.0  ;
    //[NotchFilter logCoefficients];*/
}



- (void)loadSettingsFromUserDefaults
{
    NSLog(@"Audio manager loadSettingsFromUserDefaults\n");
    // Make sure we've got our defaults right, y'know? Important.
    NSDictionary *defaultsDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SettingsDefaults" ofType:@"plist"]];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDict];

    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    _threshold = [[defaults valueForKey:@"threshold"] floatValue];


}

#pragma mark - Breakdown
- (void)saveSettingsToUserDefaults
{

    NSLog(@"Audio Manager saveSettingsToUserDefaults\n");
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults setValue:[NSNumber numberWithFloat:_threshold] forKey:@"threshold"];
    [defaults synchronize];
}

#pragma mark - Bluetooth

-(void) testBluetoothConnection
{
   // [[BBBTManager btManager] startBluetooth];
}

-(void) switchToBluetoothWithChannels:(int) channelConfiguration andSampleRate:(int) inSampleRate
{
  /*  btOn = YES;
    [[BBBTManager btManager] configBluetoothWithChannelConfiguration:channelConfiguration andSampleRate:inSampleRate];
    _sourceSamplingRate=inSampleRate;
    _sourceNumberOfChannels=[[BBBTManager btManager] numberOfChannels];
    
    [self stopAllInputOutput];
    [self resetBuffers];
    [self makeInputOutput];*/
}

-(void) closeBluetooth
{
    /*[self stopAllInputOutput];
    [[BBBTManager btManager] stopCurrentBluetoothConnection];
    _sourceSamplingRate =  audioManager.samplingRate;
    _sourceNumberOfChannels = audioManager.numInputChannels;
    btOn = NO;
    [self resetBuffers];
    [self makeInputOutput];
    [[NSNotificationCenter defaultCenter] postNotificationName:RESETUP_SCREEN_NOTIFICATION object:self];*/
}

-(int) numberOfFramesBuffered
{
    return 0;//[[BBBTManager btManager] numberOfFramesBuffered];
}


#pragma mark - Helper functions


-(void) stopAllInputOutput
{
    NSLog(@"stopAllInputOutput %p\n", audioManager);
    //[[BBBTManager btManager] setInputBlock:nil];
    //audioManager.inputBlock = nil;
    
    audioManager.outputBlock = nil;
    [audioManager setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels) {
        
        
        
    }];
   // audioManager.inputBlock = nil;
}

-(void) getChannelsConfig
{
    if(btOn)
    {
     /*   _sourceSamplingRate =  [[BBBTManager btManager] samplingRate];
        _sourceNumberOfChannels = [[BBBTManager btManager] numberOfChannels];*/
    }
    else
    {
        _sourceSamplingRate =  audioManager.samplingRate;
         NSLog(@"Get source channel config sampling rate: %f", _sourceSamplingRate);
        _sourceNumberOfChannels = audioManager.numInputChannels;
        NSLog(@"Get source number of channels: %d", _sourceNumberOfChannels);
    }
}

-(void) resetupAudioInputs
{
    NSLog(@"resetupAudioInputs - BBAudioManager\n");
    if(!playing && audioManager)
    {
        [self stopAllInputOutput];
        _sourceSamplingRate =  audioManager.samplingRate;
        NSLog(@"resetup audio inputs sampling rate: %f", _sourceSamplingRate);
        _sourceNumberOfChannels = audioManager.numInputChannels;
        btOn = NO;
        [self resetBuffers];
        [self makeInputOutput];
        [[NSNotificationCenter defaultCenter] postNotificationName:RESETUP_SCREEN_NOTIFICATION object:self];
    }
}

-(void) resetBuffers
{
    NSLog(@"resetBuffers\n");
    
    delete ringBuffer;
    free(tempCalculationBuffer);
    //create new buffers
    
    ringBuffer = new RingBuffer(maxNumberOfSamplesToDisplay, _sourceNumberOfChannels);
    tempCalculationBuffer = (float *)calloc(maxNumberOfSamplesToDisplay*_sourceNumberOfChannels, sizeof(float));
    [self filterParametersChanged];
    if(rtSpikeSorting)
    {
        [[BBAnalysisManager bbAnalysisManager] stopRTSpikeSorting];
        [[BBAnalysisManager bbAnalysisManager] initRTSpikeSorting:_sourceSamplingRate];
    }
}

-(void) makeInputOutput
{
     NSLog(@"makeInputOutput %p\n",audioManager);

   /* playEKGBeep = NO;
    counterForEKGBeep = 0;

    
    [audioManager setOutputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels) {
        
        if(playEKGBeep)
        {
            memset(data, 0, numChannels*numFrames*sizeof(float));
            
            int lengthToCopy = numFrames;
            if(lengthToCopy> (LENGTH_OF_EKG_BEEP_IN_SAMPLES- counterForEKGBeep))
            {
                lengthToCopy = (LENGTH_OF_EKG_BEEP_IN_SAMPLES- counterForEKGBeep);
            }
            memcpy(data, &(ekgBeepBuffer[counterForEKGBeep]), lengthToCopy);
            counterForEKGBeep+=lengthToCopy;
            if(counterForEKGBeep>=LENGTH_OF_EKG_BEEP_IN_SAMPLES)
            {
                playEKGBeep = NO;
            }
            
            NSLog(@"sound");
        }
        else
        {
            memset(data, 0, numChannels*numFrames*sizeof(float));
            return;
        }
        
            
    } ];
   
        */


    // Replace the input block with the old input block, where we just save an in-memory copy of the audio.
    [audioManager setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels) {
       
        if(ringBuffer == NULL)
        {
            NSLog(@"/n/n ERROR in Input block %p", self);
            return;
        }
        [self additionalProcessingOfInputData:data forNumOfFrames:numFrames andNumChannels:numChannels];
        
        ringBuffer->AddNewInterleavedFloatData(data, numFrames, numChannels);
       
    }];
    
}


//
// Main routing function. All the processing should hook up here onto data packets
//
-(void) additionalProcessingOfInputData:(float *) data forNumOfFrames:(UInt32) numFrames andNumChannels:(UInt32) numChannels
{
    
    [self amDemodulationOfData:data numFrames:numFrames numChannels:numChannels];
    
    if(self.amDemodulationIsON)
    {
        [self filterData:data numFrames:numFrames numChannels:numChannels];
    }
    
    if (recording)
    {
        [fileWriter writeNewAudio:data numFrames:numFrames numChannels:numChannels];
    }
    
    
    
    
    [self updateBasicStatsOnData:data numFrames:numFrames numChannels:numChannels];
   
    if (thresholding)
    {
        dspThresholder->ProcessNewAudio(data, numFrames);
        [ecgAnalysis updateECGData:data withNumberOfFrames:numFrames numberOfChannels: numChannels andThreshold:dspThresholder->GetThreshold()];
       // NSLog(@"%d",(int)[self heartRate]);
    }
    
    if(playing)
    {
        // do nothing with input from MIC/BT
    }
    
    if(FFTOn)
    {
        dspAnalizer->CalculateDynamicFFT(data, numFrames, _selectedChannel);
    }
    
    if(rtSpikeSorting)
    {
        [[BBAnalysisManager bbAnalysisManager] findSpikesInRTForData:data numberOfFrames:numFrames numberOfChannel:numChannels selectedChannel:_selectedChannel];
    }
    
}


-(void) amDemodulationOfData:(float *)newData numFrames:(UInt32) thisNumFrames numChannels:(UInt32) thisNumChannels
{
    if(thisNumChannels<3)
    {
    
        //calculate RMS for original signal
        

        float zero = 0.0f;
        //get first channel
        vDSP_vsadd(newData,
                   thisNumChannels,
                   &zero,
                   tempResamplingBuffer,
                   1,
                   thisNumFrames);
        [amDetectionLPFilter filterData:tempResamplingBuffer numFrames:thisNumFrames numChannels:1];
        
        float rms;
        vDSP_rmsqv(tempResamplingBuffer,1,&rms,thisNumFrames);
        rmsOfOriginalSignal = rmsOfOriginalSignal*0.9+rms*0.1;
        
        
       [amDetectionNotchFilter filterData:tempResamplingBuffer numFrames:thisNumFrames numChannels:1];
        //calculate RMS after Notch filter
       vDSP_rmsqv(tempResamplingBuffer,1,&rms,thisNumFrames);
       rmsOfNotchedSignal = rmsOfNotchedSignal*0.9 + rms*0.1;
        
        //NSLog(@"a/b: %f",rmsOfOriginalSignal/rmsOfNotchedSignal);
        if(rmsOfNotchedSignal*3<rmsOfOriginalSignal)
        {
    
             self.amDemodulationIsON = true;
            
            
                vDSP_vabs(newData, 1, newData, 1, thisNumChannels*thisNumFrames);
            
            
            
            
                [filterAMStage1 filterData:newData numFrames:thisNumFrames numChannels:thisNumChannels];
                [filterAMStage2 filterData:newData numFrames:thisNumFrames numChannels:thisNumChannels];
                [filterAMStage3 filterData:newData numFrames:thisNumFrames numChannels:thisNumChannels];
            
            float sum = 0;
            float offset = 0;
            
            
            if(thisNumChannels==1)
            {
                
                vDSP_sve(newData, 1, &sum, thisNumFrames);
                sum = sum/(float)thisNumFrames;
                amDCLevelRemovalCh1 = 0.99*amDCLevelRemovalCh1 + 0.01*sum;
                offset = - amDCLevelRemovalCh1;
                //NSLog(@"NF: %d - sum: %f - DC: %f\n",thisNumFrames, sum, amDCLevelRemovalCh1);
                vDSP_vsadd(newData,
                           1,
                           &offset,
                           newData,
                           1,
                           thisNumFrames);
            }
            else if(thisNumChannels==2)
            {
                
                vDSP_sve(newData, 2, &sum, thisNumFrames);
                sum = sum/(float)thisNumFrames;
                amDCLevelRemovalCh1 = 0.99*amDCLevelRemovalCh1 + 0.01*sum;
                offset = - amDCLevelRemovalCh1;
                vDSP_vsadd(newData,
                           2,
                           &offset,
                           newData,
                           2,
                           thisNumFrames);
                
                sum = 0;
                
                vDSP_sve((float *)&newData[1], 2, &sum, thisNumFrames);
                sum = sum/(float)thisNumFrames;
                amDCLevelRemovalCh2 = 0.99*amDCLevelRemovalCh2 + 0.01*sum;
                offset = - amDCLevelRemovalCh2;
                vDSP_vsadd((float *)&newData[1],
                           2,
                           &offset,
                           (float *)&newData[1],
                           2,
                           thisNumFrames);
 
            }
            
            //vDSP_vneg(newData,1, newData, 1, thisNumChannels*thisNumFrames);
           
            
            //amOffset = newData[0];
        }
        else
        {
            self.amDemodulationIsON = false;
        }
    }
}


-(void) filterData:(float *)newData numFrames:(UInt32)thisNumFrames numChannels:(UInt32)thisNumChannels
{
    
    if(LPFilter || HPFilter)
    {
            int i;
            if(thisNumChannels>2)
            {
                for(i=0;i<_sourceNumberOfChannels;i++)
                {
                    float zero = 0.0f;
                    //get selected channel
                    vDSP_vsadd((float *)&newData[i],
                               thisNumChannels,
                               &zero,
                               tempResamplingBuffer,
                               1,
                               thisNumFrames);
                    //
                    if(HPFilter)
                    {
                        [HPFilter filterData:tempResamplingBuffer numFrames:thisNumFrames numChannels:1];
                    }
                    if(LPFilter)
                    {
                        [LPFilter filterData:tempResamplingBuffer numFrames:thisNumFrames numChannels:1];
                    }
                    if(notchIsOn)
                    {
                        [NotchFilter filterData:tempResamplingBuffer numFrames:thisNumFrames numChannels:1];
                    }
                    
                    vDSP_vsadd(tempResamplingBuffer,
                               1,
                               &zero,
                               (float *)&newData[i],
                               thisNumChannels,
                               thisNumFrames);
                }
            }
            else
            {
                if(HPFilter)
                {
                    [HPFilter filterData:newData numFrames:thisNumFrames numChannels:thisNumChannels];
                }
                if(LPFilter)
                {
                    [LPFilter filterData:newData numFrames:thisNumFrames numChannels:thisNumChannels];
                }
                if(notchIsOn)
                {
                    [NotchFilter filterData:newData numFrames:thisNumFrames numChannels:thisNumChannels];
                }
            }
    }
}


-(void) setFilterSettings:(int) newFilterSettings
{
    
    
    switch (newFilterSettings) {
        case FILTER_SETTINGS_RAW:
            [self setFilterLPCutoff:FILTER_LP_OFF hpCutoff:FILTER_HP_OFF];
            break;
        case FILTER_SETTINGS_EKG:
            [self setFilterLPCutoff:50 hpCutoff:1];
           // [self overrideAudioOutput];
            break;
        case FILTER_SETTINGS_EEG:
            [self setFilterLPCutoff:100 hpCutoff:1];
            break;
        case FILTER_SETTINGS_PLANT:
            [self setFilterLPCutoff:5 hpCutoff:FILTER_HP_OFF];
            break;
        case FILTER_SETTINGS_CUSTOM:
            if(currentFilterSettings != FILTER_SETTINGS_CUSTOM)
            {
                [self setFilterLPCutoff:FILTER_LP_OFF hpCutoff:FILTER_HP_OFF];
            }
            break;
        default:
            break;
    }
    currentFilterSettings = newFilterSettings;
}

-(void) overrideAudioOutput
{
    //https://stackoverflow.com/questions/2175082/force-iphone-to-output-through-the-speaker-while-recording-from-headphone-mic?noredirect=1&lq=1
    //https://stackoverflow.com/questions/5931799/redirecting-audio-output-to-phone-speaker-and-mic-input-to-headphones
    //https://stackoverflow.com/questions/1064846/iphone-audio-playback-force-through-internal-speaker
  /*  audioManager.ignoreHandler = YES;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_Speaker;  // 1
    AudioSessionSetProperty (kAudioSessionProperty_OverrideAudioRoute,sizeof (audioRouteOverride), &audioRouteOverride);
    
    // Force audio to come out of speaker
  //  [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
    
    */
    

}

-(int) getLPFilterCutoff {return lpFilterCutoff;}
-(int) getHPFilterCutoff {return hpFilterCutoff;}


-(void) setFilterLPCutoff:(int) newLPCuttof hpCutoff:(int)newHPCutoff
{
    
    lpFilterCutoff = newLPCuttof;
    hpFilterCutoff = newHPCutoff;

    
    if(lpFilterCutoff != FILTER_LP_OFF)
    {
        LPFilter= [[NVLowpassFilter alloc] initWithSamplingRate:_sourceSamplingRate];
        LPFilter.cornerFrequency = lpFilterCutoff;
        LPFilter.Q = 0.4f;
    }
    else
    {
        LPFilter = nil;
    }
    
    if(hpFilterCutoff != FILTER_HP_OFF)
    {
        float tempFilterValue = newHPCutoff;

        HPFilter = [[NVHighpassFilter alloc] initWithSamplingRate:_sourceSamplingRate];
        HPFilter.cornerFrequency = tempFilterValue;
        HPFilter.Q = 0.40f;
    }
    else
    {
        HPFilter = nil;
    }

}


-(void) updateBasicStatsOnData:(float *)newData numFrames:(UInt32)thisNumFrames numChannels:(UInt32)thisNumChannels
{
    //get data for selected channel
    float zero = 0.0f;
    //get selected channel
    vDSP_vsadd((float *)&newData[_selectedChannel],
               thisNumChannels,
               &zero,
               tempResamplingBuffer,
               1,
               thisNumFrames);
    
    dspAnalizer->calculateBasicStats(tempResamplingBuffer, thisNumFrames, &_currentSTD, &_currentMin, &_currentMax, &_currentMean);
    
    self.currSTD = 0.001*_currentSTD + 0.999*self.currSTD;
    self.currMean = 0.001*_currentMean + 0.999*self.currMean;
    
   /* if(self.currMin>_currentMin)
    {
        self.currMin = _currentMin;
    }*/
    self.currMin = ringBuffer->Min();
    /*if(self.currMax<_currentMax)
    {
        self.currMax = _currentMax;
    }*/
    self.currMax = ringBuffer->Max();
    if(ABS(self.currMin)>self.currMax)
    {
        self.currMax = ABS(self.currMin);
    }
}

-(void) quitAllFunctions
{
    NSLog(@"quitAllFunctions\n");
    [self stopAllInputOutput];
    
    if (recording)
    {
        [self stopRecording];
    }
    if (thresholding)
    {
        [self stopThresholding];
    }
    
    if(playing)
    {
        [self stopPlaying];
    }
    
    if(FFTOn)
    {
        [self stopFFT];
    }
    
    if(ECGOn)
    {
        [self stopECG];
    }
    
   /* if(rtSpikeSorting)
    {
        [self stopRTSpikeSorting];
    }*/
    
}


#pragma mark - Input Methods
- (void)startMonitoring
{
    NSLog(@"Audio manager startMonitoring\n");
    audioManager=[Novocaine audioManager];
    
    [self quitAllFunctions];
    float tempSamplingRate = _sourceSamplingRate;
    int tempNumberOfChannels = _sourceNumberOfChannels;
    [self getChannelsConfig];
    if(tempSamplingRate != _sourceSamplingRate  || tempNumberOfChannels != _sourceNumberOfChannels)
    {
        [self resetBuffers];
    }
    [self makeInputOutput];
}


#pragma mark - Thresholding

- (void)startThresholding:(UInt32)newNumPointsToSavePerThreshold
{
    [self quitAllFunctions];
    [self getChannelsConfig];
    [self makeInputOutput];
    numPointsToSavePerThreshold = newNumPointsToSavePerThreshold;

    if (dspThresholder) {
        NSLog(@"DSP already made");
        dspThresholder->SetRingBuffer(ringBuffer);
        dspThresholder->SetNumberOfChannels(_sourceNumberOfChannels);
        
    }
    else
    {
        NSLog(@"DSP not made");
        dspThresholder = new DSPThreshold(ringBuffer, numPointsToSavePerThreshold, 50,_sourceNumberOfChannels);
       
    }
    dspThresholder->SetThreshold(_threshold);
    
    NSLog(@"Select threshold channel from BB audio init");
    dspThresholder->SetSelectedChannel(_selectedChannel);
    [ecgAnalysis reset];
    thresholding = true;
}

- (void)stopThresholding
{
    thresholding = false;
    NSLog(@"Stop thresholding");
}


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

-(BOOL) isThresholdTriggered
{
    if(dspThresholder)
    {
        dspThresholder->GetIsTriggered();
    }
    else
    {
        return NO;
    }
}

#pragma mark - Recording

- (void)startRecording:(NSURL *)urlToFile
{
    // If we're already recording, skip out
    if (recording == true) {
        return;
    }
    else {
        
        NSLog(@"Start recording at sample rate: %f", _sourceSamplingRate);
        
        // Grab a file writer. This takes care of the creation and management of the audio file.
        fileWriter = [[BBAudioFileWriter alloc]
                      initWithAudioFileURL:urlToFile 
                      samplingRate:_sourceSamplingRate
                      numChannels:_sourceNumberOfChannels];
        
        // Replace the audio input function
        [self makeInputOutput];
        recording = true;
        
    }
}

- (void)stopRecording
{
    recording = false;
    
    [fileWriter stop];
    // do the breakdown
    [fileWriter release];
    fileWriter = nil;

}


#pragma mark - RT Spike Sorting

-(float *) rtSpikeValues
{
    return [[BBAnalysisManager bbAnalysisManager] rtPeaksValues];
}
-(float *) rtSpikeIndexes
{
    return [[BBAnalysisManager bbAnalysisManager] rtPeaksIndexs];
}

-(int) numberOfRTSpikes
{
    return [[BBAnalysisManager bbAnalysisManager] numberOfRTSpikes];
}

-(void) stopRTSpikeSorting
{
    if(rtSpikeSorting)
    {
        rtSpikeSorting = false;
        [[BBAnalysisManager bbAnalysisManager] stopRTSpikeSorting];
    }

}

-(void) startRTSpikeSorting
{
    [[BBAnalysisManager bbAnalysisManager] initRTSpikeSorting:_sourceSamplingRate];
    rtSpikeSorting = true;
}

-(void) setRtThresholdFirst:(float)rtThreshold
{
    [[BBAnalysisManager bbAnalysisManager] setRtThresholdFirst:rtThreshold];
}

-(void) setRtThresholdSecond:(float)rtThreshold
{
    [[BBAnalysisManager bbAnalysisManager] setRtThresholdSecond:rtThreshold];
}

-(float) rtThresholdFirst
{
    return [[BBAnalysisManager bbAnalysisManager] rtThresholdFirst];
}

-(float) rtThresholdSecond
{
    return [[BBAnalysisManager bbAnalysisManager] rtThresholdSecond];
}


#pragma mark - ECG code



-(float) heartRate
{
    return [ecgAnalysis heartRate];
}

-(BOOL) heartBeatPresent
{
    return [ecgAnalysis heartBeatPresent];
}


#pragma mark - Playback

- (void)startPlaying:(BBFile *) fileToPlay
{
    NSLog(@"Audio manager startPlaying\n");
    [self stopAllInputOutput];
    
    if (self.playing == true)
        return;
    
    
    if (self.playing == false && fileReader != nil)
    {
        [fileReader release];
        fileReader = nil;
    }
    
    _file = fileToPlay;
    
    
    //Check sampling rate and number of channels in file
    NSError *avPlayerError = nil;
    AVAudioPlayer *avPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[_file fileURL] error:&avPlayerError];
    if (avPlayerError)
    {
        NSLog(@"Error opening file: %@", [avPlayerError description]);
        _sourceNumberOfChannels =1;
        _sourceSamplingRate = 44100.0f;
         NSLog(@"start playing 1 inputs sampling rate: %f", _sourceSamplingRate);
    }
    else
    {
        _sourceNumberOfChannels = [avPlayer numberOfChannels];
        _sourceSamplingRate = [[[avPlayer settings] objectForKey:AVSampleRateKey] floatValue];
        NSLog(@"Source file num. of channels %d, sampling rate %f", _sourceNumberOfChannels, _sourceSamplingRate);
    }
    [avPlayer release];
    avPlayer = nil;
    

    //Free memory
    [self resetBuffers];
    
    free(tempResamplingBuffer);
    free(tempResampledBuffer);
    tempResamplingBuffer = (float *)calloc(1024, sizeof(float));
    tempResampledBuffer = (float *)calloc(1024, sizeof(float));

    fileReader = [[BBAudioFileReader alloc]
                  initWithAudioFileURL:[_file fileURL]
                  samplingRate:_sourceSamplingRate
                  numChannels:_sourceNumberOfChannels];
    
    differentFreqInOut = _sourceSamplingRate != audioManager.samplingRate;
    
    
    [audioManager setOutputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels) {
        
        
        //------- Scrubbing ----------------
        UInt32 realNumberOfFrames = (UInt32)(((float)numFrames)*(_sourceSamplingRate/audioManager.samplingRate));

       
        Float32 zero = 0;
        Float32 increment = (float)(realNumberOfFrames)/(float)(numFrames);
        vDSP_vramp(&zero, &increment, tempResamplingIndexes, 1, numFrames);//here may be numFrames-1
        
        
        if (!self.playing) {
            //if we have new seek position
            if(self.seeking && lastSeekPosition != fileReader.currentTime)
            {
                lastSeekPosition = fileReader.currentTime;
                //clear ring buffer

                
                //calculate begining and end of interval to display
                UInt32 targetFrame = (UInt32)(fileReader.currentTime * ((float)_sourceSamplingRate));
                int startFrame = targetFrame - maxNumberOfSamplesToDisplay;
                if(startFrame<0)
                {
                    startFrame = 0;
                }

                //get the data from file into clean ring buffer
                dispatch_sync(dispatch_get_main_queue(), ^{
                    ringBuffer->Clear();
                    ringBuffer->SeekWriteHeadPosition(0);
                    ringBuffer->SeekReadHeadPosition(0);
                    [fileReader retrieveFreshAudio:tempCalculationBuffer numFrames:(UInt32)(targetFrame-startFrame) numChannels:_sourceNumberOfChannels seek:(UInt32)startFrame];
                    
                    
                    //Filtering of recorded data while scrolling
                    //[self filterData:tempCalculationBuffer numFrames:(UInt32)(targetFrame-startFrame) numChannels:_sourceNumberOfChannels];
                    
                    
                    
                    
                    ringBuffer->AddNewInterleavedFloatData(tempCalculationBuffer, targetFrame-startFrame, _sourceNumberOfChannels);
                  
                    _preciseTimeOfLastData = (float)targetFrame/(float)_sourceSamplingRate;

                    //set playback time to scrubber position
                    fileReader.currentTime = lastSeekPosition;
                    if(selecting)
                    {
                         //if we have active selection recalculate RMS
                        [self updateSelection:_selectionEndTime timeSpan:_timeSpan];
                    }
                });
            }
            
            //set playback data to zero (silence during scrubbing)
            memset(data, 0, numChannels*numFrames*sizeof(float));
            return;
        }
        
        
        
        //------- Playing ----------------
        
        
        //we keep currentTime here to have precise time to sinc spikes marks display with waveform
        dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH , 0), ^{
         //dispatch_sync(dispatch_get_main_queue(), ^{
            
            //get all data (wil get more than 2 cannels in buffer)
            [fileReader retrieveFreshAudio:tempCalculationBuffer numFrames:realNumberOfFrames numChannels:_sourceNumberOfChannels];
            
            
            
            //FIltering of playback data
          //  [self filterData:tempCalculationBuffer numFrames:realNumberOfFrames numChannels:_sourceNumberOfChannels];
            
            
            //move just numChannels in buffer
            float zero = 0.0f;
           
            if(differentFreqInOut)
            {
                //make interpolation
                vDSP_vsadd((float *)&tempCalculationBuffer[_selectedChannel],
                           _sourceNumberOfChannels,
                           &zero,
                           &tempResamplingBuffer[1],
                           1,
                           realNumberOfFrames);
                vDSP_vlint(tempResamplingBuffer, tempResamplingIndexes, 1, tempResampledBuffer, 1, numFrames, realNumberOfFrames);
                
                for (int iChannel = 0; iChannel < numChannels; ++iChannel) {

                    vDSP_vsadd(tempResampledBuffer,
                               1,
                               &zero,
                               &data[iChannel],
                               numChannels,
                               numFrames);
                }
                tempResamplingBuffer[0] = tempResamplingBuffer[realNumberOfFrames];
            }
            else
            {
                for (int iChannel = 0; iChannel < numChannels; ++iChannel) {
                        vDSP_vsadd((float *)&tempCalculationBuffer[_selectedChannel],
                                   _sourceNumberOfChannels,
                                   &zero,
                                   &data[iChannel],
                                   numChannels,
                                   numFrames);
                }
            }
          
            ringBuffer->AddNewInterleavedFloatData(tempCalculationBuffer, realNumberOfFrames, _sourceNumberOfChannels);
            _preciseTimeOfLastData = fileReader.currentTime;
            [self updateBasicStatsOnData:tempCalculationBuffer numFrames:realNumberOfFrames numChannels:_sourceNumberOfChannels];
            

            
        });
        
        
        
        //------- Stop - End of file ----------------
        
        if (fileReader.fileIsDone) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                fileReader.currentTime = 0.0f;
                _preciseTimeOfLastData = 0.0f;
                ringBuffer->Clear();
                [self pausePlaying];
            });
            return;
        }
        
    }];
    
    [self resumePlaying];
    
    
}

-(void) clearWaveform
{
    NSLog(@"clear waveform");
    if(ringBuffer)
    {
        ringBuffer->Clear();
    }
}

- (void)stopPlaying
{
    NSLog(@"Stop Playing\n");
    if(self.playing)
    {
       NSLog(@"Stop Playing - inside\n");
        [self pausePlaying];
        _file = nil;
        _preciseTimeOfLastData = 0.0f;
        // Toss the file reader.
        [fileReader release];
        fileReader = nil;
        ringBuffer->Clear();
    }
}

- (void)pausePlaying
{
    self.playing = false;
}

- (void)resumePlaying
{
    self.playing = true;
}


#pragma mark - FFT code


-(float **) getDynamicFFTResult
{
    return dspAnalizer->FFTDynamicMagnitude;
}


-(void) startDynanimcFFT
{
    float maxNumOfSeconds = MAX_NUMBER_OF_FFT_SEC;
    [self quitAllFunctions];
    [self getChannelsConfig];
    //Try to make under 1Hz resolution
    //if it is too much than limit it to samplingRate/2^11
    uint32_t log2n = log2f((float)_sourceSamplingRate);
    
    uint32_t n = 1 << (log2n+2);
    
    [self makeInputOutput];// here we also create ring buffer so it must be before we set ring buffer
    
    dspAnalizer->InitDynamicFFT(ringBuffer, _sourceNumberOfChannels, _sourceSamplingRate, n, 95, maxNumOfSeconds);
    
    FFTOn = true;
    
}


-(void) stopFFT
{
    if (!FFTOn)
        return;
    
    FFTOn = false;
    [self makeInputOutput];
}

-(UInt32) lengthOfFFTData
{
    return dspAnalizer->LengthOfFFTData;
}

-(UInt32) lengthOf30HzData
{
    return dspAnalizer->LengthOf30HzData;
}

-(UInt32) lenghtOfFFTGraphBuffer
{
    return dspAnalizer->NumberOfGraphsInBuffer;
}

-(UInt32) indexOfFFTGraphBuffer
{
    return dspAnalizer->GraphBufferIndex;
}

//-(float *) movingAverageFFT
//{
//    return dspAnalizer->movingAverageFFT;
//}


#pragma mark - data feed for graphs

- (float)fetchAudio:(float *)data numFrames:(UInt32)numFrames whichChannel:(UInt32)whichChannel stride:(UInt32)stride
{
    
    if(whichChannel>=_sourceNumberOfChannels)
    {
        return 0.0f;
    }
    
    if (!thresholding) {
        //Fetch data and get time of data as precise as posible. Used to sichronize
        //display of waveform and spike marks
        float timeOfData = ringBuffer->FetchFreshData2(data, numFrames, whichChannel, stride);
        return timeOfData;
    }
    else if (thresholding) {

        lastNumberOfSampleDisplayed = numFrames;
        dspThresholder->GetCenteredTriggeredData(data, numFrames, whichChannel, stride);
        //if we have active selection recalculate RMS
        if(selecting)
        {
            [self updateSelection:_selectionEndTime timeSpan:_timeSpan];
            
        }
    }
    return 0.0f;
}

- (float)fetchAudioForSelectedChannel:(float *)data numFrames:(UInt32)numFrames stride:(UInt32)stride
{
    return [self fetchAudio:data numFrames:numFrames whichChannel:_selectedChannel stride:stride];
    
}

-(NSMutableArray *) getChannels
{
    return [_file allChannels];
}

#pragma mark - Spikes

-(NSMutableArray *) getSpikes
{
    
    //TODO: Check if this is ok:
    if(_file && [_file.allSpikes count]>0)
    {
        return _file.allSpikes;
    }
    
    return nil;
}

-(float) getTimeForSpikes
{
   
    return _preciseTimeOfLastData;
    
}


#pragma mark - Selection analysis

-(void) calculateSpikeCountInSelection
{
    [_spikeCountInSelection removeAllObjects];
    
    BBSpike * tempSpike;
    BBSpike * lastSpike;
    float averageISI;
    BBChannel * tempChannel;
    BBSpikeTrain * tempSpikeTrain;
    float startTime, endTime;
    //selection times are negative so we need oposite logic
    if(_selectionEndTime> _selectionStartTime)
    {
        startTime = _selectionEndTime ;
        endTime = _selectionStartTime ;

    }
    else
    {
        startTime = _selectionStartTime ;
        endTime = _selectionEndTime ;
    }
   // startTime = _timeSpan-startTime;
   // endTime = _timeSpan - endTime;
    startTime = [self currentFileTime]-startTime;
    endTime = [self currentFileTime] - endTime;
    
    BOOL weAreInInterval;

    tempChannel = [[_file allChannels] objectAtIndex:_selectedChannel];

    for(int trainIndex=0;trainIndex<[[tempChannel spikeTrains] count];trainIndex++)
    {
        tempSpikeTrain = [[tempChannel spikeTrains] objectAtIndex:trainIndex];
        
        
        weAreInInterval = NO;

  
        int i = 0;
        averageISI = 0.0f;
        //go through all spikes
        for (tempSpike in tempSpikeTrain.spikes) {
           
            if([tempSpike time]>startTime && [tempSpike time]<endTime)
            {
                i++;

                if(i>1)
                {
                    averageISI += tempSpike.time - lastSpike.time;
                }
                lastSpike = tempSpike;
                
            }
            else if(weAreInInterval)
            {//if we pass last spike in selected interval
                break;
            }
        }
        
        [_spikeCountInSelection addObject:[NSNumber numberWithInt:i]];
        if(i>1)
        {
            i--;
            averageISI = averageISI/(float)i;
            averageISI = 1.0f/averageISI;
            [_spikeCountInSelection addObject:[NSNumber numberWithFloat:averageISI]];
        }
        else
        {
            [_spikeCountInSelection addObject:[NSNumber numberWithFloat:0.0f]];
        }
    }
}


-(float) calculateSelectionRMS
{
    
    int startSample, endSample;
    //selection times are negative so we need oposite logic
    if(_selectionEndTime> _selectionStartTime)
    {
        startSample = _selectionStartTime * [self sourceSamplingRate];
        endSample = _selectionEndTime * [self sourceSamplingRate];
    }
    else
    {
        startSample = _selectionEndTime * [self sourceSamplingRate];
        endSample = _selectionStartTime * [self sourceSamplingRate];
    }
    
    
    // Aight, now that we've got our ranges correct, let's ask for the audio.
    memset(tempCalculationBuffer, 0, _sourceNumberOfChannels*maxNumberOfSamplesToDisplay*sizeof(float));
    
    if (!thresholding) {
        //fetchAudio will put all data (from left time limit to right edge of the screen) at the begining
        //of the display buffer. After that we just take data from begining of the buffer to the length of
        //selected time interval and calculate RMS
        ringBuffer->FetchFreshData2(tempCalculationBuffer, endSample, _selectedChannel , 1);
        selectionRMS =dspAnalizer->RMSSelection((tempCalculationBuffer), endSample-startSample);
    }
    else if (thresholding) {
        //we first get all the data that is displayed on the screen and then we chose only segment that is selected
        //this is done lake this because GetCenteredTriggeredData is returning always centered data
        dspThresholder->GetCenteredTriggeredData(tempCalculationBuffer, lastNumberOfSampleDisplayed,_selectedChannel, 1);
        selectionRMS =dspAnalizer->RMSSelection((tempCalculationBuffer+lastNumberOfSampleDisplayed-endSample), endSample-startSample);

    }
    return selectionRMS;
}





- (float)rmsOfSelection
{
    return selectionRMS;
}


#pragma mark - State

//
// Selected channel to play and analyse
//
-(void) selectChannel:(int) selectedChannel
{
    NSLog(@"IN Audio selected channel: %d", selectedChannel);
    _selectedChannel = selectedChannel;
    if(thresholding)
    {
        dspThresholder->SetSelectedChannel(_selectedChannel);
    }
    if(rtSpikeSorting)
    {
        [[BBAnalysisManager bbAnalysisManager] clearRTSpikes];
    }
}

//private. Starts selection functionality
-(void) startSelection:(float) newSelectionStartTime
{
    _selectionStartTime = newSelectionStartTime;
    _selectionEndTime = newSelectionStartTime;
    selecting = true;
}

//Ends selection functionality
-(void) endSelection
{
    selecting = false;
    selectionRMS = 0;
}

//Update selection interval
//
// newSelectionTime is time from right end of the screen to touch (positive value)
//
-(void) updateSelection:(float) newSelectionTime timeSpan:(float)timeSpan
{
    _timeSpan = timeSpan;
    if(selecting)
    {
        _selectionEndTime = newSelectionTime;
        selectionRMS = [self calculateSelectionRMS];
        [self calculateSpikeCountInSelection];
    }
    else
    {
        [self startSelection:newSelectionTime];
        selectionRMS = 0;
    }
    
}

- (float) selectionStartTime
{
    return _selectionStartTime;
}

- (float) selectionEndTime
{
    return _selectionEndTime;
}

-(NSMutableArray *) spikesCount
{
    return _spikeCountInSelection;
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
        if(fileReader.duration<newCurrentFileTime)
        {
            newCurrentFileTime = fileReader.duration;
        }
        fileReader.currentTime = newCurrentFileTime;
    }
}

- (float)fileDuration
{
    
    if (recording) {
        return fileWriter.duration;
        
    }
    else
    {
        return fileReader.duration;
    }

    
    return 0;
    
}

- (float)samplingRate
{
    return audioManager.samplingRate;
}

-(int) numberOfChannels
{
    return audioManager.numInputChannels;
}


- (float) sourceSamplingRate
{
    return _sourceSamplingRate;
}

-(int) sourceNumberOfChannels
{
    return _sourceNumberOfChannels;
}

- (void)setNumTriggersInThresholdHistory:(UInt32)numTriggersInThresholdHistoryLocal
{
    if (dspThresholder)
    {
        dspThresholder->SetNumTriggersInHistory(numTriggersInThresholdHistoryLocal);
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
