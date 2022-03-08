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
#import "BBEvent.h"
#import "BBChannel.h"
#import <Accelerate/Accelerate.h>
#import "BBECGAnalysis.h"
#import "MyAppDelegate.h"
#import "BoardsConfigManager.h"
#import "InputDeviceConfig.h"
#import "ChannelConfig.h"
#import "InputDevice.h"


//#define RING_BUFFER_SIZE 524288
#define LENGTH_OF_EKG_BEEP_IN_SAMPLES 4851//0.11*44100
#define LOCAL_AUDIO_DEVICE_UNIQUE_NAME @"LOCMIC"
#define LOCAL_MICROPHONE_SHORT_NAME @"Microphone"
#define UNIQUE_INSTANCE_ID_OF_MICROPHONE @"localmicrophone"
#define UNIQUE_NAME_OF_AM_MODULATED_INPUT @"AMMOD"
#define UNIQUE_INSTANCE_ID_OF_AM_MODULATED_SIGNAL @"ammodulatedsignal"

#define SIZE_OF_MAX_SAMPLES_FOR_ALL_CHANNELS 20000

static BBAudioManager *bbAudioManager = nil;

@interface BBAudioManager ()
{
    Novocaine *audioManager;
    RingBuffer *ringBuffer;
    DemoProtocol * eaManager;
    __block BBAudioFileWriter *fileWriter;
    __block BBAudioFileReader *fileReader;
    DSPThreshold *dspThresholder;
    DSPAnalysis *dspAnalizer;
    BoardsConfigManager * boardsConfigManager;
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
    float newSeekPosition;
    float * tempCalculationBuffer;//used to load data for display while scrubbing

    UInt32 lastNumberOfSampleDisplayed;//used to find position of selection in trigger view
    
    int _numberOfSourceChannels;
    float _sourceSamplingRate;
    
    int _selectedChannel;
    
    int maxNumberOfSamplesToDisplay;
    Float32 * tempResamplingIndexes;
    float * tempResamplingBuffer;
    float * tempResampledBuffer;
    bool differentFreqInOut;
    float tempSampleForLinearInterpolation;
    
    //basic stats
    float _currentSTD;
    float _currentMax;
    float _currentMin;
    float _currentMean;
    
    //events
    NSMutableArray * rtEvents;

   
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
    
    NSMutableArray * availableInputChannels;
    NSMutableArray * currentDeviceAvailableInputChannels;
    uint16_t activeChannels;
    NSMutableArray * currentDeviceActiveInputChannels;
    float * extractedChannelsBuffer;
    int activeChannelColorIndex[16];
    
    BOOL shouldTurnONAMModulation;
    dispatch_queue_t serialQueue ;

}

@property BOOL playing;

- (void)loadSettingsFromUserDefaults;
- (void) initAMDetection;

@end

@implementation BBAudioManager

@synthesize availableInputDevices;
@synthesize numTriggersInThresholdHistory;
@synthesize threshold;
@synthesize thresholdDirection;
@synthesize recording;
@synthesize stimulating;
@synthesize thresholding;
@synthesize selecting;
@synthesize playing;
@synthesize seeking;
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
    
    if([[UIApplication sharedApplication] isProtectedDataAvailable])
    {
        NSLog(@"Device is unlocked! BBaudio manager");
    }
    else
    {
        NSLog(@"Device is locked! BBaudio manager");
    }
    
    NSLog(@"Init BBAudioManager - start");
    MyAppDelegate * appDelegate = (MyAppDelegate*)[[UIApplication sharedApplication] delegate];
    //if ((self = [super init]) && ![appDelegate launchingFromLocked])
    if (self || (self = [super init]))
    {
        NSLog(@"Create local audio devices");
        bool reinitializeMFi = false;
        if(appDelegate.shouldReinitializeAudio)
        {
            reinitializeMFi= true;
            NSLog(@"App delegate ssays we sshould reinit audio");
            [audioManager initNovocaine];
        }
        [self createLocalAudioDevice];
        
        if([audioManager shouldReinitializeAudio])
        {
            NSLog(@"BBAudioManager shouldReinitializeAudio detected");
            appDelegate.shouldReinitializeAudio = true;
        }
        else
        {
            appDelegate.shouldReinitializeAudio = false;
        }
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resetupAudioInputs) name:@"audioChannelsChanged" object:nil];
        
        
        
        serialQueue = dispatch_queue_create("com.blah.queue", DISPATCH_QUEUE_SERIAL);
        boardsConfigManager = [[BoardsConfigManager alloc] init];
        
        eaManager = [MyAppDelegate getEaManager];
        extractedChannelsBuffer = (float *)calloc(SIZE_OF_MAX_SAMPLES_FOR_ALL_CHANNELS, sizeof(float));
        

        
        
        
        
        
        
        [self initInputDevices];
        
        
        maxVoltageVisible = MAX_VOLTAGE_NOT_SET;//max voltage on last screen (if not set load default value from config)
        
        
        _selectedChannel = 0;
        _spikeCountInSelection = [[NSMutableArray alloc] initWithCapacity:0];
        
        
        tempResamplingIndexes = (Float32 *)calloc(1024, sizeof(Float32));
        tempResamplingBuffer = (float *)calloc(1024, sizeof(float));
        tempResampledBuffer = (float *)calloc(1024, sizeof(float));
        
        
        
        
        // Initialize parameters to defaults
        [self loadSettingsFromUserDefaults];
        
        
        
        
        

        ringBuffer = new RingBuffer(maxNumberOfSamplesToDisplay, 1);
        tempCalculationBuffer = (float *)calloc(maxNumberOfSamplesToDisplay*1, sizeof(float));

        lastSeekPosition = -1;
        newSeekPosition = -1;
        
        
        
        dspAnalizer = new DSPAnalysis();

        //init state variables
        recording = false;
        stimulating = false;
        thresholding = false;
        selecting = false;
        FFTOn = false;
        ECGOn = false;
        rtSpikeSorting = false;
        shouldTurnONAMModulation = false;
        
        [self setCurrentFilterSettingsWithType:FILTER_SETTINGS_RAW];
        //currentFilterSettings = FILTER_SETTINGS_RAW;
        lpFilterCutoff = FILTER_LP_OFF;
        hpFilterCutoff = FILTER_HP_OFF;
        
        // init one input device
        [self activateFirstInstanceOfInputDeviceWithUniqueName:LOCAL_AUDIO_DEVICE_UNIQUE_NAME];
        [self initAMDetection];
        
       
        
        ecgAnalysis = [[BBECGAnalysis alloc] init];
        [ecgAnalysis initECGAnalysisWithSamplingRate:_sourceSamplingRate numOfChannels:[self numberOfActiveChannels]];

        
        rtEvents = [[NSMutableArray alloc] initWithCapacity:0];
        
        //if(appDelegate.shouldReinitializeAudio)
        if(reinitializeMFi)
        {
            NSLog(@"App delegate ssays we sshould reinit accessory");
            [eaManager reAddExistingAccessory];
            
        }
        NSLog(@"audio manger play - before");
        [audioManager play];
        NSLog(@"audio manger play - after");
        
       
        
        
    }
    NSLog(@"Init BBAudioManager - end");
    return self;
}

-(void) createLocalAudioDevice
{
    audioManager = [Novocaine audioManager];
    _sourceSamplingRate =  audioManager.samplingRate;
    _numberOfSourceChannels = audioManager.numInputChannels;
}



-(void) addLocalInputDeviceToInputDevices
{
    InputDeviceConfig * inpDevConf = [[InputDeviceConfig alloc] init];
    
    //fill in generic data and data from audio manager
    inpDevConf.uniqueName = LOCAL_AUDIO_DEVICE_UNIQUE_NAME;
    
    NSString * currentInputName = audioManager.inputRoute;
    if([currentInputName isEqualToString:@"HeadsetInOut"])
    {
        currentInputName = @"Smartphone Cable";
    }
    
    if([currentInputName isEqualToString:@"ReceiverAndMicrophone"])
    {
        currentInputName = @"Microphone";
    }

    
    inpDevConf.userFriendlyShortName = currentInputName;
    inpDevConf.userFriendlyFullName = currentInputName;
    inpDevConf.maxSampleRate = audioManager.samplingRate;
    inpDevConf.currentSampleRate = audioManager.samplingRate;
    inpDevConf.currentNumOfChannels = 1;
    inpDevConf.maxNumberOfChannels = audioManager.numInputChannels;
    inpDevConf.hardwareComProtocolType = HARDWARE_PROTOCOL_TYPE_LOCAL;
    inpDevConf.inputDevicesSupportedByThisPlatform = YES;
    inpDevConf.defaultTimeScale = 2.0;
    inpDevConf.defaultAmplitudeScale = 1.0;
    inpDevConf.sampleRateIsFunctionOfNumberOfChannels = NO;
    inpDevConf.minAppVersion = @"1.0.0";
    
    inpDevConf.filterSettings.highPassON = NO;
    inpDevConf.filterSettings.highPassCutoff = 0;
    inpDevConf.filterSettings.lowPassON = NO;
    inpDevConf.filterSettings.lowPassCutoff = 0.5*audioManager.samplingRate;
    inpDevConf.filterSettings.notchFilterState = notchOff;
    
    for(int i=0;i<inpDevConf.maxNumberOfChannels;i++)
    {
        ChannelConfig * newChannel= [[ChannelConfig alloc] init];
        newChannel.userFriendlyFullName = [NSString stringWithFormat:@"%@ channel %d",currentInputName, i+1];
        newChannel.userFriendlyShortName = [NSString stringWithFormat:@"%@ channel %d",currentInputName, i+1];
        
        newChannel.activeByDefault = i==0;
        newChannel.filtered = YES;
        [inpDevConf.channels addObject:newChannel];
    }
    
    InputDevice * newInputDevice = [[InputDevice alloc] initWithConfig:inpDevConf];
    newInputDevice.uniqueInstanceID = UNIQUE_INSTANCE_ID_OF_MICROPHONE;
    //add local microphone to available input devices
    
    InputDevice * inputDeviceThatWeFound = nil;
    for(int i=0;i<[availableInputDevices count];i++)
    {
        InputDevice * tempInputDevice  = [availableInputDevices objectAtIndex:i];
        
        if([tempInputDevice.config.uniqueName isEqualToString:LOCAL_AUDIO_DEVICE_UNIQUE_NAME] || [tempInputDevice.config.uniqueName isEqualToString:UNIQUE_NAME_OF_AM_MODULATED_INPUT])
        {
            inputDeviceThatWeFound = tempInputDevice;
            [availableInputDevices removeObject:tempInputDevice];
        }
    }
    
    
    [availableInputDevices addObject:newInputDevice];
    [self updateAvailableInputChannels];
    
    if(inputDeviceThatWeFound)//if there was already device of same type
    {
        if(inputDeviceThatWeFound.currentlyActive)//if that device was active
        {
            [self activateFirstInstanceOfInputDeviceWithUniqueName:LOCAL_AUDIO_DEVICE_UNIQUE_NAME];
        }
    }
    
}




-(void) initInputDevices
{
    
    availableInputDevices = [[NSMutableArray alloc] initWithCapacity:0];
    availableInputChannels = [[NSMutableArray alloc] initWithCapacity:0];
    currentDeviceActiveInputChannels = [[NSMutableArray alloc] initWithCapacity:0];
    currentDeviceAvailableInputChannels = [[NSMutableArray alloc] initWithCapacity:0];
    //create input device config for standard input (microphone)
    [self addLocalInputDeviceToInputDevices];
}



-(void) addNewInputDevice:(InputDevice *) newInputDevice
{
    for(int i=0;i<[availableInputDevices count];i++)
    {
        InputDevice * tempInputDevice = (InputDevice *)[availableInputDevices objectAtIndex:i];
        if([tempInputDevice.config.uniqueName isEqualToString:newInputDevice.config.uniqueName])
        {
            [availableInputDevices removeObject:tempInputDevice];
        }
    }
    [availableInputDevices addObject:newInputDevice];
    [self updateAvailableInputChannels];
}

-(InputDevice *) getInputDeviceWithUniqueName:(NSString *) uniqueName
{
    for(int i=0;i<[availableInputDevices count];i++)
    {
        InputDevice * tempInputDevice = (InputDevice *)[availableInputDevices objectAtIndex:i];
        if([tempInputDevice.config.uniqueName isEqualToString:uniqueName])
        {
            return tempInputDevice;
        }
    }
    return nil;
}

-(void) removeInputDevice:(InputDevice *) inputDeviceToRemove
{
    [self deactivateInputDevice:inputDeviceToRemove];
    [availableInputDevices removeObject:inputDeviceToRemove];
    [self updateAvailableInputChannels];
}

-(void) deactivateInputDevice:(InputDevice *) inputDeviceToDeactivate
{
    if([inputDeviceToDeactivate currentlyActive])
    {
        if(![self activateFirstInstanceOfInputDeviceWithUniqueName:LOCAL_AUDIO_DEVICE_UNIQUE_NAME])
        {
            [self activateInputDeviceAtIndex:0];
        }
    }
}


-(InputDevice *) findInputDeviceForChannel:(ChannelConfig *) channelConfig
{
    for(int inputIndex=0;inputIndex<[availableInputDevices count];inputIndex++)
    {
            InputDevice* inputDeviceToActivate = (InputDevice*)[availableInputDevices objectAtIndex:inputIndex];
            InputDeviceConfig* devConf = (InputDeviceConfig*)[inputDeviceToActivate config];
            for (int i =0;i<[devConf.channels count];i++)
            {
                if(devConf.channels[i] == channelConfig)
                {
                    return inputDeviceToActivate;
                }
            }

            if(devConf.connectedExpansionBoard)
            {
                for (int i =0;i<[devConf.connectedExpansionBoard.channels count];i++)
                {
                    if(devConf.connectedExpansionBoard.channels[i] == channelConfig)
                    {
                        return inputDeviceToActivate;
                    }
                }
            }
    }
    return nil;
}







-(int) indexOfCurrentlyActiveDevice
{
    for (int i=0;i<[availableInputDevices count];i++)
    {
        if(((InputDevice*)[availableInputDevices objectAtIndex:i]).currentlyActive==YES)
        {
            return i;
        }
    }
    return -1;
}


-(InputDevice*) currentlyActiveInputDevice
{
    int index = [self indexOfCurrentlyActiveDevice];
    if(index !=-1)
    {
        return (InputDevice*)[availableInputDevices objectAtIndex:index];
    }
    return nil;
}

//
// Deactivate all devices, find one with Unique Name that is same as uniqueName
// and activate it
//
-(BOOL) activateFirstInstanceOfInputDeviceWithUniqueName:(NSString *) uniqueName
{
    NSLog(@"Activate first instance with name %@", uniqueName);
    BOOL foundDevice = NO;
    int indexOfNewDevice = 0;
    for (int i=0;i<[availableInputDevices count];i++)
    {
        if([[[(InputDevice*)[availableInputDevices objectAtIndex:i] config] uniqueName] isEqualToString:uniqueName])
        {
            /*
             IF we have single device and switch OFF last channel (to black) no channels will be active
             if(((InputDevice*)[availableInputDevices objectAtIndex:i]).currentlyActive)
            {
                //already active
                return YES;
            }*/
            foundDevice = YES;
            indexOfNewDevice = i;
        }
        ((InputDevice*)[availableInputDevices objectAtIndex:i]).currentlyActive  = NO;
    }
    if(foundDevice)
    {
        [self activateInputDeviceAtIndex:indexOfNewDevice];
    }

    return foundDevice;
}

//
//
//
-(void) activateInputDeviceAtIndex:(int) indexOfDevice
{
    // ------ check if allready active ------
    
    /*if([self indexOfCurrentlyActiveDevice]==indexOfDevice)
    {
        return;
    }
    */
    NSLog(@"Start activateInputDeviceAtIndex VVVVVVVVVVVVVVVV");
    // ------ stop all functions ------
    
    [self quitAllFunctions];
    
    
    // ------ set all devices and channels to inactive ------
    
    for (int i=0;i<[availableInputDevices count];i++)
    {
        InputDevice * tempInputDevice = ((InputDevice*)[availableInputDevices objectAtIndex:i]);
        InputDeviceConfig * tempConfig = tempInputDevice.config;
        tempInputDevice.currentlyActive  = NO;
        
        for (int i =0;i<[tempConfig.channels count];i++)
        {
            ((ChannelConfig*) tempConfig.channels[i]).currentlyActive = NO;
            ((ChannelConfig*) tempConfig.channels[i]).colorIndex = 0;
        }
        if(tempConfig.connectedExpansionBoard)
        {
            for (int i =0;i<[tempConfig.connectedExpansionBoard.channels count];i++)
            {
                ((ChannelConfig*) tempConfig.connectedExpansionBoard.channels[i]).currentlyActive = NO;
                ((ChannelConfig*) tempConfig.connectedExpansionBoard.channels[i]).colorIndex = 0;
            }
        }
    }
    
    // ------ check how many channels we will have to activate ------
    
    InputDevice* inputDeviceToActivate = (InputDevice*)[availableInputDevices objectAtIndex:indexOfDevice];
    InputDeviceConfig* devConf = (InputDeviceConfig*)[inputDeviceToActivate config];
    inputDeviceToActivate.currentlyActive = YES;

    
    //----- set color for chanels ------
    
    int colorIndex = 1;
    for (int i =0;i<[devConf.channels count];i++)
    {
        if([((ChannelConfig*) devConf.channels[i]) activeByDefault])
        {
            ((ChannelConfig*) devConf.channels[i]).colorIndex = colorIndex;
            colorIndex = colorIndex+1;
            ((ChannelConfig*) devConf.channels[i]).currentlyActive = YES;
        }
        else
        {
            //set black and turn OFF the channel
            ((ChannelConfig*) devConf.channels[i]).colorIndex = 0;
            ((ChannelConfig*) devConf.channels[i]).currentlyActive = NO;
        }
    }
    
    if(devConf.connectedExpansionBoard)
    {
        for (int i =0;i<[devConf.connectedExpansionBoard.channels count];i++)
        {
            if([((ChannelConfig*) devConf.connectedExpansionBoard.channels[i]) activeByDefault])
            {
                ((ChannelConfig*) devConf.connectedExpansionBoard.channels[i]).colorIndex = colorIndex;
                colorIndex = colorIndex+1;
                ((ChannelConfig*) devConf.connectedExpansionBoard.channels[i]).currentlyActive = YES;
            }
            else
            {
                //set black and turn OFF the channel
                ((ChannelConfig*) devConf.connectedExpansionBoard.channels[i]).colorIndex = 0;
                ((ChannelConfig*) devConf.connectedExpansionBoard.channels[i]).currentlyActive = NO;
            }
        }
    }

    [self updateCurrentDeviceAvailableInputChannels];
    [self updateCurrentlyActiveChannels];
   
    int numOfActiveChannels = 0;
    int numberOfAvailableChannels = 0;
    inputDeviceToActivate.currentlyActive = YES;
    for (int i =0;i<[devConf.channels count];i++)
    {
        if([((ChannelConfig*) devConf.channels[i]) activeByDefault])
        {
            numOfActiveChannels++;
        }
        numberOfAvailableChannels++;
    }
    
    if(devConf.connectedExpansionBoard)
    {
        for (int i =0;i<[devConf.connectedExpansionBoard.channels count];i++)
        {
            if([((ChannelConfig*) devConf.connectedExpansionBoard.channels[i]) activeByDefault])
            {
                numOfActiveChannels++;
            }
            numberOfAvailableChannels++;
        }
    }

    // ------ find what will be the new sample rate ------
    
    float tempSamplingRate = [devConf maxSampleRate];
    if(devConf.sampleRateIsFunctionOfNumberOfChannels)
    {
        tempSamplingRate = (int)(tempSamplingRate/numOfActiveChannels);
    }
    

   
    
    //if we have different sameple rate or number of channels resize buffers
    //if(tempSamplingRate != _sourceSamplingRate  || numOfActiveChannels != [self numberOfActiveChannels])
    //{
        _sourceSamplingRate = tempSamplingRate;
        _numberOfSourceChannels = numberOfAvailableChannels;
        [self resetBuffers];
  /*  }
    else
    {
        _sourceSamplingRate = tempSamplingRate;
        _numberOfSourceChannels = numberOfAvailableChannels;
        rtEvents = [[NSMutableArray alloc] initWithCapacity:0];
        ringBuffer->Clear();
    }*/
    
    
    // ------ set filters according to config ------
    [self setCurrentFilterSettingsWithType:FILTER_SETTINGS_CUSTOM];
    //currentFilterSettings = FILTER_SETTINGS_CUSTOM;
    int tempLowPassCutoff = FILTER_LP_OFF;
    if(devConf.filterSettings.lowPassON)
    {
        tempLowPassCutoff = devConf.filterSettings.lowPassCutoff;
    }
    
    int tempHighPassCutoff = FILTER_HP_OFF;
    if(devConf.filterSettings.highPassON)
    {
        tempHighPassCutoff = devConf.filterSettings.highPassCutoff;
    }
    lpFilterCutoff = tempLowPassCutoff;
    hpFilterCutoff = tempHighPassCutoff;
    [self updateFilters];
    
    // ------ activate inputs and outputs ------
    [[NSNotificationCenter defaultCenter] postNotificationName:RESETUP_SCREEN_NOTIFICATION object:self];
    [[NSNotificationCenter defaultCenter] postNotificationName:NEW_DEVICE_ACTIVATED object:self];
    [self startAquiringInputs:inputDeviceToActivate];
    NSLog(@"END activateInputDeviceAtIndex AAAAAAAAAAAAAAA");
}

//used when just channel active/inactive change but not a input device
-(void) updateBufferOnReconfigurationOfChannelsOnActiveDevice
{
    [self quitAllFunctions];
    [self updateCurrentDeviceAvailableInputChannels];
    [self updateCurrentlyActiveChannels];
    InputDevice * inputDeviceToActivate = [self currentlyActiveInputDevice];
    InputDeviceConfig* devConf = (InputDeviceConfig*)[inputDeviceToActivate config];
    int numOfActiveChannels = 0;
    int numberOfAvailableChannels = 0;
    for (int i =0;i<[devConf.channels count];i++)
    {
        if([((ChannelConfig*) devConf.channels[i]) currentlyActive])
        {
            numOfActiveChannels++;
        }
        numberOfAvailableChannels++;
    }
    
    if(devConf.connectedExpansionBoard)
    {
        for (int i =0;i<[devConf.connectedExpansionBoard.channels count];i++)
        {
            if([((ChannelConfig*) devConf.connectedExpansionBoard.channels[i]) currentlyActive])
            {
                numOfActiveChannels++;
            }
            numberOfAvailableChannels++;
        }
    }

    // ------ find what will be the new sample rate ------
    
    float tempSamplingRate = [devConf maxSampleRate];
    if(devConf.sampleRateIsFunctionOfNumberOfChannels)
    {
        tempSamplingRate = (int)(tempSamplingRate/numOfActiveChannels);
    }
    
  
   
    _sourceSamplingRate = tempSamplingRate;
    _numberOfSourceChannels = numberOfAvailableChannels;
    [self resetBuffers];
    [self updateFilters];
   
    // ------ activate inputs and outputs ------
    [[NSNotificationCenter defaultCenter] postNotificationName:RESETUP_SCREEN_NOTIFICATION object:self];
    [self startAquiringInputs:inputDeviceToActivate];
}

-(BOOL) externalAccessoryIsActive
{
    return [[self currentlyActiveInputDevice] isBasedOnCommunicationProtocol:HARDWARE_PROTOCOL_TYPE_MFI];
}


-(void) extractActiveChannelsFormData:(float **) datain withNumberOfFrames:(UInt32) numFrames numberOfChannels:(UInt32) numChannels
{
    
    int goalNumberOfChannels = [self numberOfActiveChannels];
    float * data = *datain;
    if(numChannels==goalNumberOfChannels)
    {
        return;
    }
    int currentlyExtracting = 0;
    uint16_t indexForChannelBit = 1;
    float zero = 0.0f;
    for (int i=0; i < numChannels; ++i)
    {
        if(indexForChannelBit & activeChannels)
        {
            //channel is active, extract it
            vDSP_vsadd((float *)&data[i],
                       numChannels,
                       &zero,
                       (float *)&extractedChannelsBuffer[currentlyExtracting],
                       goalNumberOfChannels,
                       numFrames);
            currentlyExtracting++;
        }
        indexForChannelBit = indexForChannelBit<<1;
    }
    
    (*datain) = extractedChannelsBuffer;
}

-(void) startAquiringInputs:(InputDevice *) inputDeviceToActivate
{
    NSLog(@"startAquiringInputs %p\n",audioManager);
    
    _preciseVirtualTimeNumOfFrames = 0;
    
    if([inputDeviceToActivate isBasedOnCommunicationProtocol:HARDWARE_PROTOCOL_TYPE_MFI])
    {
        [eaManager setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels)
         {
             if(numFrames>0)
             {
              [self extractActiveChannelsFormData:&data withNumberOfFrames:numFrames numberOfChannels:[self numberOfSourceChannels]];
             }
             if([eaManager shouldRestartDevice])
             {
                 NSLog(@"inside");
                 [self updateMfiDeviceParameters];
                 [eaManager deviceRestarted];
                 return;
             }
             
             if(ringBuffer == NULL)
             {
                 NSLog(@"/n/n ERROR in Input block for Mfi %p/n/n", self);
                 return;
             }
             if(numFrames>0)
             {
                 [self additionalProcessingOfInputData:data forNumOfFrames:numFrames andNumChannels:[self numberOfActiveChannels]];
                 ringBuffer->AddNewInterleavedFloatData(data, numFrames, [self numberOfActiveChannels]);
                 _preciseVirtualTimeNumOfFrames += numFrames;
             }
             
         }];
    }
    else if([inputDeviceToActivate isBasedOnCommunicationProtocol:HARDWARE_PROTOCOL_TYPE_LOCAL])
    {
            // Replace the input block with the old input block, where we just save an in-memory copy of the audio.
            [audioManager setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels)
            {
                [self checkIfWeHaveAMModulatedFirstChannelWithData:data numFrames:numFrames numChannels:numChannels];
                if(self.amDemodulationIsON)
                {
                    //demodulate and extract just first channel
                    [self demodulateAMSignalAndExtractFirstChannelFromData:data numberOfFrames:numFrames numChannels:numChannels];
                }
                [self extractActiveChannelsFormData:&data withNumberOfFrames:numFrames numberOfChannels:[self numberOfSourceChannels]];
                if(ringBuffer == NULL)
                {
                    NSLog(@"/n/n ERROR in Input block %p/n/n", self);
                    return;
                }
                [self additionalProcessingOfInputData:data forNumOfFrames:numFrames andNumChannels:[self numberOfActiveChannels]];
                ringBuffer->AddNewInterleavedFloatData(data, numFrames, [self numberOfActiveChannels]);
                _preciseVirtualTimeNumOfFrames += numFrames;
            }];
    }

     inputDeviceToActivate.currentlyActive  = YES;
}

-(void) initAMDetection
{
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
    
}


- (void)loadSettingsFromUserDefaults
{
    NSLog(@"Audio manager loadSettingsFromUserDefaults\n");
    // Make sure we've got our defaults right, y'know? Important.
    NSDictionary *defaultsDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SettingsDefaults" ofType:@"plist"]];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDict];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    _threshold = [[defaults valueForKey:@"threshold"] floatValue];
    maxNumberOfSamplesToDisplay = [[defaults valueForKey:@"numSamplesMaxNew"] integerValue];
    
    //Setup initial values for statistics
    _currentMax = [[defaults valueForKey:@"numVoltsMaxUpdate1"] floatValue]*0.8;
    _currentMin = -[[defaults valueForKey:@"numVoltsMaxUpdate1"] floatValue]*0.8;
    _currentMean = 0.0f;
    _currentSTD = _currentMax/6.0f;

}

-(float) getDefaultTimeScale
{
    InputDevice * tempInputDevice = [self currentlyActiveInputDevice];
    return tempInputDevice.config.defaultTimeScale;
}

-(float) getVoltageScaleForChannelIndex:(int)indexOfChannel
{
    if(playing)
    {
        //since we don't have config for the device that we used to record the file
        //and file does not contain that information we can take info about voltage scale from current device
        //the last thing that user set on the device
        indexOfChannel = 0;
    }
    ChannelConfig* tempChannelConfig = [currentDeviceActiveInputChannels objectAtIndex:indexOfChannel];
    return tempChannelConfig.defaultVoltageScale;
}

-(void) reactivateCurrentDevice
{
    [self stopAllInputOutput];
    NSLog(@"Reactivate current device");
    InputDevice * tempInputDevice = ((InputDevice*)[availableInputDevices objectAtIndex:[self indexOfCurrentlyActiveDevice]]);
    InputDeviceConfig * devConf = tempInputDevice.config;

    float tempSamplingRate = [devConf maxSampleRate];
    int numOfActiveChannels = 0;
    int numberOfAvailableChannels = 0;

    for (int i =0;i<[devConf.channels count];i++)
    {
        if([((ChannelConfig*) devConf.channels[i]) currentlyActive])
        {
            numOfActiveChannels++;
        }
        numberOfAvailableChannels++;
    }
    
    if(devConf.connectedExpansionBoard)
    {
        for (int i =0;i<[devConf.connectedExpansionBoard.channels count];i++)
        {
            if([((ChannelConfig*) devConf.connectedExpansionBoard.channels[i]) currentlyActive])
            {
                numOfActiveChannels++;
            }
            numberOfAvailableChannels++;
        }
    }
    if(devConf.sampleRateIsFunctionOfNumberOfChannels)
    {
        tempSamplingRate = (int)(tempSamplingRate/numOfActiveChannels);
    }

    _sourceSamplingRate = tempSamplingRate;
    _numberOfSourceChannels = numberOfAvailableChannels;

    [self updateCurrentlyActiveChannels];
    [self resetBuffers];

    
    
    //[self activateInputDeviceAtIndex: [self indexOfCurrentlyActiveDevice]];
}
#pragma mark - Channels code

//Note:
// Active channels are channels shown on the screen
// Available channel is any channel that can be activated
// Available channel can be activate or inactive
// Inactive channel is channel that is sent by the device but we are not showing it

-(int) numberOfSourceChannels
{
    return _numberOfSourceChannels;
}

-(int) numberOfActiveChannels
{
    int activeNumberOfChannels = 0;
    uint16_t mask = 1;
    for (int i=0;i<16;i++)
    {
        if(activeChannels & mask)
        {
            activeNumberOfChannels++;
        }
        mask = mask<<1;
    }
    return activeNumberOfChannels;
}

-(NSArray * ) currentlyAvailableInputChannels
{
    return availableInputChannels;
}

-(void) updateAvailableInputChannels
{
    [availableInputChannels removeAllObjects];
    for(int inputIndex=0;inputIndex<[availableInputDevices count];inputIndex++)
    {
            InputDevice* inputDeviceToActivate = (InputDevice*)[availableInputDevices objectAtIndex:inputIndex];
            InputDeviceConfig* devConf = (InputDeviceConfig*)[inputDeviceToActivate config];
            
            for (int i =0;i<[devConf.channels count];i++)
            {
                [availableInputChannels addObject: devConf.channels[i]];
            }

            if(devConf.connectedExpansionBoard)
            {
                for (int i =0;i<[devConf.connectedExpansionBoard.channels count];i++)
                {
                    [availableInputChannels addObject: devConf.connectedExpansionBoard.channels[i]];
                }
            }
    }
}


-(void) updateCurrentDeviceAvailableInputChannels
{
    [currentDeviceAvailableInputChannels removeAllObjects];
    InputDevice * currInputDevice = [self currentlyActiveInputDevice];
    InputDeviceConfig* devConf = (InputDeviceConfig*)[currInputDevice config];
   
    for (int i =0;i<[devConf.channels count];i++)
    {
        [currentDeviceAvailableInputChannels addObject: devConf.channels[i]];
        
    }

    if(devConf.connectedExpansionBoard)
    {
        for (int i =0;i<[devConf.connectedExpansionBoard.channels count];i++)
        {
            [currentDeviceAvailableInputChannels addObject: devConf.connectedExpansionBoard.channels[i]];
        }
    }
    
}

//
// activeChannels stores info which channel is active in bits of 16bit word
// 1- channel is active
// 0 - channel is not active
//
-(void) updateCurrentlyActiveChannels
{
    activeChannels = 0;
    uint16_t mask = 1;
    [currentDeviceActiveInputChannels removeAllObjects];
    InputDevice * currInputDevice = [self currentlyActiveInputDevice];
    InputDeviceConfig* devConf = (InputDeviceConfig*)[currInputDevice config];
    int colorArrayIndex = 0;
    for (int i =0;i<[devConf.channels count];i++)
    {
        ChannelConfig * tempChannel = (ChannelConfig *) devConf.channels[i];
        if(tempChannel.currentlyActive)
        {
            activeChannels = activeChannels | mask;
            activeChannelColorIndex[colorArrayIndex] = tempChannel.colorIndex;
            colorArrayIndex++;
            [currentDeviceActiveInputChannels addObject:tempChannel];
        }
        mask = mask<<1;
    }

    if(devConf.connectedExpansionBoard)
    {
        for (int i =0;i<[devConf.connectedExpansionBoard.channels count];i++)
        {
            ChannelConfig * tempChannel = (ChannelConfig *) devConf.connectedExpansionBoard.channels[i];
            if(tempChannel.currentlyActive)
            {
                activeChannels = activeChannels | mask;
                activeChannelColorIndex[colorArrayIndex] = tempChannel.colorIndex;
                colorArrayIndex++;
                [currentDeviceActiveInputChannels addObject:tempChannel];
            }
            mask = mask<<1;
        }
    }
}

-(void) updateColorOfActiveChannels
{
    InputDevice * currInputDevice = [self currentlyActiveInputDevice];
    InputDeviceConfig* devConf = (InputDeviceConfig*)[currInputDevice config];
    int colorArrayIndex = 0;
    for (int i =0;i<[devConf.channels count];i++)
    {
        ChannelConfig * tempChannel = (ChannelConfig *) devConf.channels[i];
        if(tempChannel.currentlyActive)
        {
            activeChannelColorIndex[colorArrayIndex] = tempChannel.colorIndex;
            colorArrayIndex++;
        }
    }

    if(devConf.connectedExpansionBoard)
    {
        for (int i =0;i<[devConf.connectedExpansionBoard.channels count];i++)
        {
            ChannelConfig * tempChannel = (ChannelConfig *) devConf.connectedExpansionBoard.channels[i];
            if(tempChannel.currentlyActive)
            {
                activeChannelColorIndex[colorArrayIndex] = tempChannel.colorIndex;
                colorArrayIndex++;
            }
        }
    }
}

-(int) getColorIndexForActiveChannelIndex:(int) indexOfChannel
{
    return activeChannelColorIndex[indexOfChannel];
}

-(BOOL) activateChannelWithConfig:(ChannelConfig *) channelConfigToActivate
{
    InputDevice * inputDeviceForChannel = [self findInputDeviceForChannel:channelConfigToActivate];
    if(inputDeviceForChannel==nil)
    {
        return NO;
    }
    if(inputDeviceForChannel == [self currentlyActiveInputDevice])
    {
        channelConfigToActivate.currentlyActive = YES;
        [self updateBufferOnReconfigurationOfChannelsOnActiveDevice];
    }
    else
    {
        //turn off current device and activate another device and its channel
        [self activateFirstInstanceOfInputDeviceWithUniqueName:inputDeviceForChannel.config.uniqueName];
        
        InputDeviceConfig* devConf = (InputDeviceConfig*)[inputDeviceForChannel config];
        for (int i =0;i<[devConf.channels count];i++)
        {
            ((ChannelConfig*) devConf.channels[i]).currentlyActive = NO;
            ((ChannelConfig*) devConf.channels[i]).colorIndex = 0;
        }
        
        if(devConf.connectedExpansionBoard)
        {
            for (int i =0;i<[devConf.connectedExpansionBoard.channels count];i++)
            {
                ((ChannelConfig*) devConf.connectedExpansionBoard.channels[i]).currentlyActive = NO;
                ((ChannelConfig*) devConf.connectedExpansionBoard.channels[i]).colorIndex = 0;
            }
        }
        //deactivate all the channels and activate only selected
        channelConfigToActivate.currentlyActive = YES;
        [self updateBufferOnReconfigurationOfChannelsOnActiveDevice];
    }
    return YES;
}

-(BOOL) deactivateChannelWithConfig:(ChannelConfig *) channelConfigToDeactivate
{
    InputDevice * inputDeviceForChannel = [self findInputDeviceForChannel:channelConfigToDeactivate];
    if(inputDeviceForChannel==nil)
    {
        return NO;
    }
    
    InputDeviceConfig* devConf = (InputDeviceConfig*)[inputDeviceForChannel config];
    int numOfActiveChannels = 0;
    for (int i =0;i<[devConf.channels count];i++)
    {
        if(((ChannelConfig*) devConf.channels[i]).currentlyActive)
        {
            numOfActiveChannels++;
        }
    }
    
    if(devConf.connectedExpansionBoard)
    {
        for (int i =0;i<[devConf.connectedExpansionBoard.channels count];i++)
        {
            if(((ChannelConfig*) devConf.connectedExpansionBoard.channels[i]).currentlyActive)
            {
                numOfActiveChannels++;
            }
        }
    }
    
    if(numOfActiveChannels<=1)
    {
        [self deactivateInputDevice:inputDeviceForChannel];
        return NO;
    }
    else
    {
        channelConfigToDeactivate.currentlyActive = NO;
        [self updateBufferOnReconfigurationOfChannelsOnActiveDevice];
    }
    return YES;
}

#pragma mark - Breakdown
- (void)saveSettingsToUserDefaults
{

    NSLog(@"Audio Manager saveSettingsToUserDefaults\n");
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults setValue:[NSNumber numberWithFloat:_threshold] forKey:@"threshold"];
    [defaults synchronize];
}



#pragma mark - External accessory MFi

-(void) addMfiDeviceWithModelNumber:(NSString *) modelNumber andSerial:(NSString *) serialNum;
{
    NSLog(@"Received info about new accesory");
    //first we have to find if we have model number in our config file
    InputDeviceConfig* newConfig = [boardsConfigManager getDeviceConfigForUniqueName:modelNumber];
    if(newConfig==nil)
    {
        //show notification to user that we don't support this
        [[NSNotificationCenter defaultCenter] postNotificationName:CAN_NOT_FIND_CONFIG_FOR_DEVICE object:modelNumber];
        return;
    }
    
    DemoProtocol * mfiAccessory = [MyAppDelegate getEaManager];
    newConfig.currentSampleRate = newConfig.maxSampleRate;
    newConfig.currentNumOfChannels = [newConfig.channels count];
   
    [mfiAccessory setSampleRate:newConfig.currentSampleRate numberOfChannels:newConfig.currentNumOfChannels andResolution:newConfig.sampleResolution];
    //add device to available devices and start emediately
    InputDevice * newInputDevice = [[InputDevice alloc] initWithConfig:newConfig];
    newInputDevice.uniqueInstanceID = serialNum;
    [self addNewInputDevice:newInputDevice];
    [self activateFirstInstanceOfInputDeviceWithUniqueName:modelNumber];
    [[NSNotificationCenter defaultCenter] postNotificationName:RESETUP_SCREEN_NOTIFICATION object:self];
}

//TODO:implement this function for expansion boards
//
// Called when eaManager request restart of device (shouldRestartDevice)
//
-(void) updateMfiDeviceParameters
{
    NSLog(@"updateMfiDeviceParameters");
    //check which expansion board is currently active
    int currentExpansionBoard = 0;
    InputDevice* inputDev = [self currentlyActiveInputDevice];
    if(inputDev)
    {
        InputDeviceConfig * configForDevice = inputDev.config;
        if(configForDevice.connectedExpansionBoard)
        {
            ExpansionBoardConfig* expConfig = configForDevice.connectedExpansionBoard;
            currentExpansionBoard = [expConfig.boardType intValue];
        }
        //if expansion board changed, add new one
        if(eaManager.getCurrentExpansionBoard !=  currentExpansionBoard)
        {
            NSMutableArray* expBoards = configForDevice.expansionBoards;
            
            for(int i=0;i<[expBoards count];i++)
            {
                ExpansionBoardConfig * expBoardConf = (ExpansionBoardConfig*)[expBoards objectAtIndex:i];
                int totalNumberOfChannels = [configForDevice.channels count] + [expBoardConf.channels count];
                int sampleRate = expBoardConf.maxSampleRate;
                int resolutionOfData = configForDevice.sampleResolution;
                if(eaManager.getCurrentExpansionBoard == [expBoardConf.boardType intValue])
                {
                    expBoardConf.currentlyActive = YES;
                    inputDev.config.connectedExpansionBoard = expBoardConf;
                    //dispatch_async(dispatch_get_main_queue(), ^{
                            [self updateAvailableInputChannels];
                            [self activateFirstInstanceOfInputDeviceWithUniqueName:configForDevice.uniqueName];
                            [eaManager setSampleRate:sampleRate numberOfChannels:totalNumberOfChannels andResolution:resolutionOfData];
                    //});
                }
            }
        }
        
    }
    else
    {
        return;
    }
}

-(void) removeMfiDeviceWithModelNumber:(NSString *) modelNumber andSerial:(NSString *) serialNum;
{
   // [self stopAllInputOutput];
    
    [self removeInputDevice:[self getInputDeviceWithUniqueName:modelNumber]];
    [[NSNotificationCenter defaultCenter] postNotificationName:RESETUP_SCREEN_NOTIFICATION object:self];
    
}


- (void) addEvent:(int) eventType withOffset:(int) inOffset
{
    
    BBEvent * tempEvent = [[BBEvent alloc] initWithValue:eventType index:inOffset+[self getVirtualTime]*_sourceSamplingRate andTime:[self getVirtualTime]+inOffset/_sourceSamplingRate];
    if(recording)
    {
        [[_file allEvents] addObject:tempEvent];
    }

    [rtEvents addObject:tempEvent];
    
    
}
#pragma mark - Helper functions


-(void) stopAllInputOutput
{
    NSLog(@"stopAllInputOutput %p\n", audioManager);
    audioManager.outputBlock = nil;
    [audioManager setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels) {
    }];
    
    
    [eaManager setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels) {
        
    }];
}


-(void) resetupAudioInputs
{
    NSLog(@"resetupAudioInputs - BBAudioManager\n");
    if(!playing && audioManager)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            //dispatch_async(serialQueue, ^{
                [self addLocalInputDeviceToInputDevices];
                [self activateFirstInstanceOfInputDeviceWithUniqueName:LOCAL_AUDIO_DEVICE_UNIQUE_NAME];
                [[NSNotificationCenter defaultCenter] postNotificationName:RESETUP_SCREEN_NOTIFICATION object:self];
            //});
        });
        
    }
}

-(void) resetBuffers
{
    NSLog(@"resetBuffers\n");

    if(rtEvents)
    {
        [rtEvents release];
    }
    rtEvents = [[NSMutableArray alloc] initWithCapacity:0];
    
    delete ringBuffer;
    free(tempCalculationBuffer);
    //create new buffers
    
    ringBuffer = new RingBuffer(maxNumberOfSamplesToDisplay, [self numberOfActiveChannels]);
    tempCalculationBuffer = (float *)calloc(maxNumberOfSamplesToDisplay*[self numberOfActiveChannels], sizeof(float));
    if(rtSpikeSorting)
    {
        [[BBAnalysisManager bbAnalysisManager] stopRTSpikeSorting];
        [[BBAnalysisManager bbAnalysisManager] initRTSpikeSorting:_sourceSamplingRate];
    }
}


//
// Main routing function. All the processing should hook up here onto data packets
//
-(void) additionalProcessingOfInputData:(float *) data forNumOfFrames:(UInt32) numFrames andNumChannels:(UInt32) numChannels
{
    /*[self amDemodulationOfData:data numFrames:numFrames numChannels:numChannels];
    
    if(self.amDemodulationIsON)//TODO:WHat is this? Just filtering in the same way as normal channels
    {
        [self filterData:data numFrames:numFrames numChannels:numChannels];
    }
    */
    [self filterData:data numFrames:numFrames numChannels:numChannels];
    
    if (recording)
    {
        //TODO: select just active channels
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


-(void) checkIfWeHaveAMModulatedFirstChannelWithData:(float *)inData numFrames:(UInt32) inNumFrames numChannels:(UInt32) inNumChannels
{
    //calculate RMS for original signal
    float zero = 0.0f;
    //get first channel
    vDSP_vsadd(inData,
               inNumChannels,
               &zero,
               tempResamplingBuffer,
               1,
               inNumFrames);
    
    //low pass at 6000Hz
    [amDetectionLPFilter filterData:tempResamplingBuffer numFrames:inNumFrames numChannels:1];
    
    //calc. RMS before demodulation
    float rms;
    vDSP_rmsqv(tempResamplingBuffer,1,&rms,inNumFrames);
    rmsOfOriginalSignal = rmsOfOriginalSignal*0.9+rms*0.1;
    
    //Notch out 5000Hz carier
    [amDetectionNotchFilter filterData:tempResamplingBuffer numFrames:inNumFrames numChannels:1];
    
    //calc. RMS after Notch filter
    vDSP_rmsqv(tempResamplingBuffer,1,&rms,inNumFrames);
    rmsOfNotchedSignal = rmsOfNotchedSignal*0.9 + rms*0.1;
    
    //NSLog(@"a/b: %f",rmsOfOriginalSignal/rmsOfNotchedSignal);
    //If RMS of the signal without carier is at least 3 times smaller than
    //with carrier than we have carrier present in original signal
    if(rmsOfNotchedSignal*3<rmsOfOriginalSignal)
    {
       
        if(!self.amDemodulationIsON)
        {
            shouldTurnONAMModulation = true;
            dispatch_async(dispatch_get_main_queue(), ^{
                //dispatch_async(serialQueue, ^{
                    NSLog(@"Start AM modulation!!!!!");
                    [self turnONAMModulation];
                //});
            });
        }
    }
    else
    {
        shouldTurnONAMModulation = false;
        if(self.amDemodulationIsON)
        {
            //turn OFF AM modulation
            dispatch_async(dispatch_get_main_queue(), ^{
                //dispatch_async(serialQueue, ^{
                    NSLog(@"Stop AM Modulation!!!!!");
                    self.amDemodulationIsON = false;
                    InputDevice * amDevice = [self getInputDeviceWithUniqueName:UNIQUE_NAME_OF_AM_MODULATED_INPUT];
                    InputDevice * micDevice = [self getInputDeviceWithUniqueName:LOCAL_AUDIO_DEVICE_UNIQUE_NAME];
                    if(amDevice)
                    {
                        if(micDevice==nil)
                        {
                            [self addLocalInputDeviceToInputDevices];
                            [self activateFirstInstanceOfInputDeviceWithUniqueName:LOCAL_AUDIO_DEVICE_UNIQUE_NAME];
                        }
                        [self removeInputDevice:amDevice];
                    }
                    else
                    {
                        if(micDevice)
                        {
                            [self activateFirstInstanceOfInputDeviceWithUniqueName:LOCAL_AUDIO_DEVICE_UNIQUE_NAME];
                        }
                        else
                        {
                            [self addLocalInputDeviceToInputDevices];
                            [self activateFirstInstanceOfInputDeviceWithUniqueName:LOCAL_AUDIO_DEVICE_UNIQUE_NAME];
                        }
                    }
                    
                    
                //});
            });
        }
    }
}


-(void) turnONAMModulation
{
    shouldTurnONAMModulation = false;
    //turn ON AM modulation
    self.amDemodulationIsON = true;
    
    InputDeviceConfig * newDeviceConfig = [boardsConfigManager getDeviceConfigForUniqueName:UNIQUE_NAME_OF_AM_MODULATED_INPUT];
    newDeviceConfig.maxSampleRate = [self sourceSamplingRate];
    newDeviceConfig.currentSampleRate = [self sourceSamplingRate];
    newDeviceConfig.currentNumOfChannels = 1;
    newDeviceConfig.maxNumberOfChannels = 1;
    
    InputDevice * newInputDevice = [[InputDevice alloc] initWithConfig:newDeviceConfig];
    newInputDevice.uniqueInstanceID = UNIQUE_INSTANCE_ID_OF_AM_MODULATED_SIGNAL;
    //add AM modulated input to available input devices
    
    InputDevice * inputDeviceThatWeFound = nil;
    for(int i=0;i<[availableInputDevices count];i++)
    {
        InputDevice * tempInputDevice  = [availableInputDevices objectAtIndex:i];
        
        if([tempInputDevice.config.uniqueName isEqualToString:LOCAL_AUDIO_DEVICE_UNIQUE_NAME])
        {
            inputDeviceThatWeFound = tempInputDevice;
            [availableInputDevices removeObject:tempInputDevice];
        }
    }
    
    
    [availableInputDevices addObject:newInputDevice];
    [self updateAvailableInputChannels];
    [self activateFirstInstanceOfInputDeviceWithUniqueName:UNIQUE_NAME_OF_AM_MODULATED_INPUT];
}


-(void) demodulateAMSignalAndExtractFirstChannelFromData:(float *) newData numberOfFrames:(UInt32) thisNumFrames numChannels:(UInt32) thisNumChannels
{
    vDSP_vabs(newData, 1, newData, 1, thisNumChannels*thisNumFrames);

    float offset = 0;
    vDSP_vsadd(newData,
               1,
               &offset,
               newData,
               1,
               thisNumFrames);
    //this will filter all channels together?! at 500Hz cutoff
    [filterAMStage1 filterData:newData numFrames:thisNumFrames numChannels:thisNumChannels];
    [filterAMStage2 filterData:newData numFrames:thisNumFrames numChannels:thisNumChannels];
    [filterAMStage3 filterData:newData numFrames:thisNumFrames numChannels:thisNumChannels];
}
/*
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
        
        //low pass at 6000Hz
        [amDetectionLPFilter filterData:tempResamplingBuffer numFrames:thisNumFrames numChannels:1];
        
        //calc. RMS before demodulation
        float rms;
        vDSP_rmsqv(tempResamplingBuffer,1,&rms,thisNumFrames);
        rmsOfOriginalSignal = rmsOfOriginalSignal*0.9+rms*0.1;
        
        //Notch out 5000Hz carier
        [amDetectionNotchFilter filterData:tempResamplingBuffer numFrames:thisNumFrames numChannels:1];
        
        //calc. RMS after Notch filter
        vDSP_rmsqv(tempResamplingBuffer,1,&rms,thisNumFrames);
        rmsOfNotchedSignal = rmsOfNotchedSignal*0.9 + rms*0.1;
        
        //NSLog(@"a/b: %f",rmsOfOriginalSignal/rmsOfNotchedSignal);
        //If RMS of the signal without carier is at least 3 times smaller than
        //with carrier than we have carrier present in original signal
        if(rmsOfNotchedSignal*3<rmsOfOriginalSignal)
        {
            self.amDemodulationIsON = true;
            vDSP_vabs(newData, 1, newData, 1, thisNumChannels*thisNumFrames);

            //this will filter all channels together?! at 500Hz cutoff
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
        }
        else
        {
            self.amDemodulationIsON = false;
        }
    }
}
*/
-(BOOL) isNotchON
{
    return notch50HzIsOn || notch60HzIsOn;
}
-(BOOL) is60HzNotchON
{
    return notch60HzIsOn;
}

-(BOOL) is50HzNotchON
{
    return notch50HzIsOn;
}

-(void) turnON60HzNotch
{
    notch50HzIsOn = NO;
    notch60HzIsOn = YES;
    notchFilters = [[NSMutableArray alloc] initWithCapacity:0];
    for(int i=0;i<[self numberOfActiveChannels];i++)
    {
        NVNotchFilter * NotchFilter = [[NVNotchFilter alloc] initWithSamplingRate:_sourceSamplingRate];
        NotchFilter.centerFrequency = 60.0;
        NotchFilter.q = 1.0  ;
        [notchFilters addObject:NotchFilter];
    }
}

-(void) turnON50HzNotch
{
    notch50HzIsOn = YES;
    notch60HzIsOn = NO;
    notchFilters = [[NSMutableArray alloc] initWithCapacity:0];
    for(int i=0;i<[self numberOfActiveChannels];i++)
    {
        NVNotchFilter * NotchFilter = [[NVNotchFilter alloc] initWithSamplingRate:_sourceSamplingRate];
        NotchFilter.centerFrequency = 50.0;
        NotchFilter.q = 1.0  ;
        [notchFilters addObject:NotchFilter];
    }
}

-(void) turnOFFNotchFilters
{
    notch50HzIsOn = NO;
    notch60HzIsOn = NO;
    notchFilters = [[NSMutableArray alloc] initWithCapacity:0];
}

-(void) filterData:(float *)newData numFrames:(UInt32)thisNumFrames numChannels:(UInt32)thisNumChannels
{
    ChannelConfig * tempChannelConfig;
    if([lpFilters count]>0 || [hpFilters count]>0 || [notchFilters count]>0)
    {
            for(int i=0;i<thisNumChannels;i++)
            {
                
                tempChannelConfig = (ChannelConfig *)[currentDeviceActiveInputChannels objectAtIndex:i];
                if(tempChannelConfig.filtered)
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
                        if([hpFilters count]>0)
                        {
                           [[hpFilters objectAtIndex:i] filterData:tempResamplingBuffer numFrames:thisNumFrames numChannels:1];
                        }
                        if([lpFilters count]>0)
                        {
                            [[lpFilters objectAtIndex:i] filterData:tempResamplingBuffer numFrames:thisNumFrames numChannels:1];
                        }
                        if([self isNotchON])
                        {
                            [[notchFilters objectAtIndex:i] filterData:tempResamplingBuffer numFrames:thisNumFrames numChannels:1];
                        }
                        
                        vDSP_vsadd(tempResamplingBuffer,
                                   1,
                                   &zero,
                                   (float *)&newData[i],
                                   thisNumChannels,
                                   thisNumFrames);
                
                }
            }
    }
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

-(void) updateFilters
{
    [self setFilterLPCutoff:[self getLPFilterCutoff] hpCutoff:[self getHPFilterCutoff]];
    if([self is50HzNotchON])
    {
        [self turnON50HzNotch];
    }
    else if([self is60HzNotchON])
    {
        [self turnON60HzNotch];
    }
    else
    {
        [self turnOFFNotchFilters];
    }
}

-(void) setFilterLPCutoff:(int) newLPCuttof hpCutoff:(int)newHPCutoff
{
    
    lpFilterCutoff = newLPCuttof;
    hpFilterCutoff = newHPCutoff;

    if(hpFilters)
    {
        [hpFilters release];
    }
    if(lpFilters)
    {
        [lpFilters release];
    }
    hpFilters = [[NSMutableArray alloc] initWithCapacity:0];
    lpFilters = [[NSMutableArray alloc] initWithCapacity:0];
    
    if(lpFilterCutoff != FILTER_LP_OFF)
    {
        for(int i=0;i<[self numberOfActiveChannels];i++)
        {
            NVLowpassFilter * LPFilter= [[NVLowpassFilter alloc] initWithSamplingRate:_sourceSamplingRate];
            LPFilter.cornerFrequency = lpFilterCutoff;
            LPFilter.Q = 0.4f;
            [lpFilters addObject:LPFilter];
            [LPFilter release];
        }
    }
    else
    {
        lpFilters = [[NSMutableArray alloc] initWithCapacity:0];
    }
    
    if(hpFilterCutoff != FILTER_HP_OFF)
    {
        float tempFilterValue = newHPCutoff;
        for(int i=0;i<[self numberOfActiveChannels];i++)
        {
            NVHighpassFilter* HPFilter = [[NVHighpassFilter alloc] initWithSamplingRate:_sourceSamplingRate];
            HPFilter.cornerFrequency = tempFilterValue;
            HPFilter.Q = 0.40f;
            [hpFilters addObject:HPFilter];
            [HPFilter release];
        }
    }
    else
    {
        hpFilters = [[NSMutableArray alloc] initWithCapacity:0];
    }

}

-(void) setCurrentFilterSettingsWithType:(int) filterType
{
    self.currentFilterSettings = filterType;
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
    
}



#pragma mark - Thresholding

- (void)startThresholding:(UInt32)newNumPointsToSavePerThreshold
{
    [self quitAllFunctions];
    [self startAquiringInputs:[self currentlyActiveInputDevice]];
    numPointsToSavePerThreshold = newNumPointsToSavePerThreshold;

    if (dspThresholder) {
        NSLog(@"DSP already made");
        dspThresholder->SetRingBuffer(ringBuffer);
        dspThresholder->SetNumberOfChannels([self numberOfActiveChannels]);
    }
    else
    {
        NSLog(@"DSP not made");
        dspThresholder = new DSPThreshold(ringBuffer, numPointsToSavePerThreshold, 50,[self numberOfActiveChannels]);
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
        return dspThresholder->GetIsTriggered();
    }
    else
    {
        return NO;
    }
}

#pragma mark - Recording

- (void)startRecording:(BBFile *) aFile
{
    _file = aFile;
    // If we're already recording, skip out
    if (recording == true) {
        return;
    }
    else {
        
        NSLog(@"Start recording at sample rate: %f", _sourceSamplingRate);
        
        // Grab a file writer. This takes care of the creation and management of the audio file.
        fileWriter = [[BBAudioFileWriter alloc]
                      initWithAudioFileURL:[aFile fileURL]
                      samplingRate:_sourceSamplingRate
                      numChannels:[self numberOfActiveChannels]];
        
        // Replace the audio input function
        [self resetVirtualTimeAndEvents];
        [self startAquiringInputs:[self currentlyActiveInputDevice]];
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

-(void) recalculateFFT
{
    //calculate begining and end of interval to display

    UInt32 targetFrame = (UInt32)(newSeekPosition * ((float)_sourceSamplingRate));
    int startFrame = targetFrame - MAX_NUMBER_OF_FFT_SEC*_sourceSamplingRate;
    if(startFrame<0)
    {
        startFrame = 0;
    }
    
    //get the data from file into clean ring buffer
   // dispatch_sync(dispatch_get_main_queue(), ^{
        dspAnalizer->CalculateDynamicFFTDuringSeek(fileReader, targetFrame-startFrame, startFrame, [self numberOfActiveChannels], _selectedChannel);

    //});
    
}

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
        _numberOfSourceChannels =1;
         activeChannels = 1;
        _sourceSamplingRate = 44100.0f;
         NSLog(@"start playing 1 inputs sampling rate: %f", _sourceSamplingRate);
    }
    else
    {
        _numberOfSourceChannels = [avPlayer numberOfChannels];
        uint16_t mask = 1;
        activeChannels = 0;
        for(int i =0;i<_numberOfSourceChannels;i++)
        {
            activeChannels = activeChannels | mask;
            mask = mask<<1;
        }
        _sourceSamplingRate = [[[avPlayer settings] objectForKey:AVSampleRateKey] floatValue];
        NSLog(@"Source file num. of channels %d, sampling rate %f", [self numberOfSourceChannels], _sourceSamplingRate);
    }
    [avPlayer release];
    avPlayer = nil;
    
    _selectedChannel = 0;
    //Free memory
    [self resetBuffers];
    
    free(tempResamplingBuffer);
    free(tempResampledBuffer);
    tempResamplingBuffer = (float *)calloc(1024, sizeof(float));
    tempResampledBuffer = (float *)calloc(1024, sizeof(float));

    fileReader = [[BBAudioFileReader alloc]
                  initWithAudioFileURL:[_file fileURL]
                  samplingRate:_sourceSamplingRate
                  numChannels:[self numberOfSourceChannels]];
    
    differentFreqInOut = _sourceSamplingRate != audioManager.samplingRate;
    
    
    [audioManager setOutputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels) {
        
        UInt32 realNumberOfFrames = (UInt32)(((float)numFrames)*(_sourceSamplingRate/audioManager.samplingRate));
        Float32 zero = 0;
        Float32 increment = (float)(realNumberOfFrames)/(float)(numFrames);
        vDSP_vramp(&zero, &increment, tempResamplingIndexes, 1, numFrames);//here may be numFrames-1
        
        
        //---------- NOT Playing ---------------------------- (stop or seek)
        
        if (!self.playing) {
            //if we have new seek position
            //if(self.seeking && lastSeekPosition != fileReader.currentTime)
            if(self.seeking && lastSeekPosition != newSeekPosition)
            {
                
                lastSeekPosition = newSeekPosition;
                //clear ring buffer
                
                //calculate begining and end of interval to display
               
                UInt32 targetFrame = (UInt32)(lastSeekPosition * ((float)_sourceSamplingRate));
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
                    //NSLog(@"Before raw reading: begining of reading: %f and current file position: %f", ((float)startFrame)/_sourceSamplingRate, fileReader.currentTime);
                    [fileReader retrieveFreshAudio:tempCalculationBuffer numFrames:(UInt32)(targetFrame-startFrame) numChannels:[self numberOfSourceChannels] seek:(UInt32)startFrame];
                    
                    //NSLog(@"After raw reading:begining of reading: %f and current file position: %f", ((float)startFrame)/_sourceSamplingRate, fileReader.currentTime);
                    
                    ringBuffer->AddNewInterleavedFloatData(tempCalculationBuffer, targetFrame-startFrame, [self numberOfSourceChannels]);
                    
                    _preciseTimeOfLastData = (float)targetFrame/(float)_sourceSamplingRate;
                    
                    //set playback time to scrubber position
                    
                    if(selecting)
                    {
                        //if we have active selection recalculate RMS
                        [self updateSelection:_selectionEndTime timeSpan:_timeSpan];
                    }
                    
                    if(FFTOn)
                    {
                        [self recalculateFFT];
                       
                    }
                   
                    
                });
            }//end of if(self.seeking && lastSeekPosition != fileReader.currentTime)
            
            //set playback data to zero (silence during scrubbing)
            memset(data, 0, numChannels*numFrames*sizeof(float));
            return;
        }//end of not playing
        
        
        
        //------- Playing ----------------
        
        
        //we keep currentTime here to have precise time to sinc spikes marks display with waveform
        dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH , 0), ^{
         //dispatch_sync(dispatch_get_main_queue(), ^{
            
            //get all data (wil get more than 2 cannels in buffer)
            [fileReader retrieveFreshAudio:tempCalculationBuffer numFrames:realNumberOfFrames numChannels:[self numberOfSourceChannels]];
            
            
            //FIltering of playback data
          //  [self filterData:tempCalculationBuffer numFrames:realNumberOfFrames numChannels:[self numberOfSourceChannels]];
           
            //move just numChannels in buffer
            float zero = 0.0f;
           
            if(differentFreqInOut)
            {
                //make interpolation
                vDSP_vsadd((float *)&tempCalculationBuffer[_selectedChannel],
                           [self numberOfSourceChannels],
                           &zero,
                           &tempResamplingBuffer[1],
                           1,
                           realNumberOfFrames);
                
                //tempSampleForLinearInterpolation patch explanation:
                //because interpolation will use elements from zero to (realNumberOfFrames+1). And we are loading only
                //realNumberOfFrames elements. We need to put into zero element
                //realNumberOfFrames element from previous batch and load new data (realNumberOfFrames elements)
                //from first element (above). SO that we end up with (realNumberOfFrames+1) elements
               
                tempResamplingBuffer[0] = tempSampleForLinearInterpolation;
                vDSP_vlint(tempResamplingBuffer, tempResamplingIndexes, 1, tempResampledBuffer, 1, numFrames, realNumberOfFrames);
 
                for (int iChannel = 0; iChannel < numChannels; ++iChannel) {

                    vDSP_vsadd(tempResampledBuffer,
                               1,
                               &zero,
                               &data[iChannel],
                               numChannels,
                               numFrames);
                }
              
                
                tempSampleForLinearInterpolation = tempResamplingBuffer[realNumberOfFrames];
            }
            else
            {
                for (int iChannel = 0; iChannel < numChannels; ++iChannel) {
                        vDSP_vsadd((float *)&tempCalculationBuffer[_selectedChannel],
                                   [self numberOfSourceChannels],
                                   &zero,
                                   &data[iChannel],
                                   numChannels,
                                   numFrames);
                }
            }
          
            ringBuffer->AddNewInterleavedFloatData(tempCalculationBuffer, realNumberOfFrames, [self numberOfActiveChannels]);
            _preciseTimeOfLastData = fileReader.currentTime;
            [self updateBasicStatsOnData:tempCalculationBuffer numFrames:realNumberOfFrames numChannels:[self numberOfActiveChannels]];
            if(FFTOn)
            {
                dspAnalizer->CalculateDynamicFFT(data, realNumberOfFrames, _selectedChannel);
            }
            

            
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


-(void) startDynanimcFFTForLiveView
{
    float maxNumOfSeconds = MAX_NUMBER_OF_FFT_SEC;
    [self quitAllFunctions];

    //Try to make under 1Hz resolution
    //if it is too much than limit it to samplingRate/2^11
    uint32_t log2n = log2f((float)_sourceSamplingRate);
    
    uint32_t n = 1 << (log2n+2);
    
    [self startAquiringInputs:[self currentlyActiveInputDevice]];// here we also create ring buffer so it must be before we set ring buffer
    
    dspAnalizer->InitDynamicFFT(ringBuffer, [self numberOfActiveChannels], _sourceSamplingRate, n, 99, maxNumOfSeconds);
    
    FFTOn = true;
    
}

-(void) startDynanimcFFTForRecording:(BBFile *) newFile;
{
    
    [self startPlaying:newFile];
    float maxNumOfSeconds = MAX_NUMBER_OF_FFT_SEC;

    uint32_t log2n = log2f((float)_sourceSamplingRate);
    uint32_t n = 1 << (log2n+2);
    
    dspAnalizer->InitDynamicFFT(ringBuffer, [self numberOfActiveChannels], _sourceSamplingRate,n,99, maxNumOfSeconds);
    
    FFTOn = true;
    
}


-(void) stopFFT
{
    if (!FFTOn)
        return;
    
    FFTOn = false;
    [self startAquiringInputs:[self currentlyActiveInputDevice]];
}

-(UInt32) lengthOfFFTData
{
    return dspAnalizer->dLengthOfFFTData;
}

-(float) baseFFTFrequency
{
    return dspAnalizer->oneFrequencyStep;
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




#pragma mark - data feed for graphs

- (float)fetchAudio:(float *)data numFrames:(UInt32)numFrames whichChannel:(UInt32)whichChannel stride:(UInt32)stride
{
    
    if(whichChannel>=[self numberOfActiveChannels])
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

-(NSMutableArray *) getEvents
{
    
    if(_file && playing)
    {
        return [_file allEvents];
    }
    else
    {
        float oldEventsTime = [self getVirtualTime]-(6*44100/_sourceSamplingRate)-0.1;
        for(int i = [rtEvents count]-1;i>=0;i--)
        {
            BBEvent * currentEvent = [rtEvents objectAtIndex:i];
            if([currentEvent time]<oldEventsTime)
            {
                [rtEvents removeObjectAtIndex:i];
            }
        }
        return rtEvents;
        
    }
    //return [[NSMutableArray alloc] initWithCapacity:0];
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

-(float) getVirtualTime
{
    if(_file && (playing || seeking))
   {
       return _preciseTimeOfLastData;
   }
   else
   {
       return (float)_preciseVirtualTimeNumOfFrames/(float)_sourceSamplingRate;
   }
    
}


-(void) resetVirtualTimeAndEvents
{
    for (int i=0;i<[rtEvents count];i++)
    {
        BBEvent * rtEvent = [rtEvents objectAtIndex:i];
        [rtEvent setIndex:([rtEvent index]-_preciseVirtualTimeNumOfFrames)];
        [rtEvent setTime:((float)[rtEvent index]/(float)_sourceSamplingRate)];
    }
    _preciseVirtualTimeNumOfFrames=0.0f;
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
    memset(tempCalculationBuffer, 0, [self numberOfActiveChannels]*maxNumberOfSamplesToDisplay*sizeof(float));
    
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

-(void) setSeekTime:(float) newTime
{
    if(fileReader.duration<newTime)
    {
        newTime = fileReader.duration;
    }
    newSeekPosition  = newTime;
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


- (float) sourceSamplingRate
{
    return _sourceSamplingRate;
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
