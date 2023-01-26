//
//  BoardsConfigManager.m
//  Spike Recorder
//
//  Created by Stanislav on 06/05/2020.
//  Copyright © 2020 BackyardBrains. All rights reserved.
//

#import "BoardsConfigManager.h"
#import "InputDeviceConfig.h"
#import "ChannelConfig.h"
#import "ExpansionBoardConfig.h"

#define CONFIG_DOWNLOAD_URL @"https://backyardbrains.com/products/firmwares/devices/board-config.json"

@implementation BoardsConfigManager
@synthesize boardsConfig;

- (id)init {
    if ((self = [super init]))
    {
        boardsConfig = [[NSMutableArray alloc] initWithCapacity:0];
        [self downloadNewConfig];
    }
    return self;
}

-(void) downloadNewConfig
{
    NSString *url_string = [NSString stringWithFormat: CONFIG_DOWNLOAD_URL];
    NSData *data = [NSData dataWithContentsOfURL: [NSURL URLWithString:url_string]];
    if(data)
    {
        NSString *jsonString = [[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:NSUTF8StringEncoding];
        [self writeConfigToFile:jsonString];
    }
    
    [self loadConfig];
}

- (void)writeConfigToFile:(NSString*)aString {

    // Build the path, and create if needed.
    NSString* filePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString* fileName = @"downloaded_config.json";
    NSString* fileAtPath = [filePath stringByAppendingPathComponent:fileName];

    if (![[NSFileManager defaultManager] fileExistsAtPath:fileAtPath]) {
        [[NSFileManager defaultManager] createFileAtPath:fileAtPath contents:nil attributes:nil];
    }

    [[aString dataUsingEncoding:NSUTF8StringEncoding] writeToFile:fileAtPath atomically:NO];
}


-(InputDeviceConfig *) getDeviceConfigForUniqueName:(NSString *) uniqueName
{
    for (int i=0;i<[boardsConfig count];i++)
    {
        InputDeviceConfig * tempConfig = (InputDeviceConfig*) [boardsConfig objectAtIndex:i];
        if([tempConfig.uniqueName isEqualToString:uniqueName])
        {
            return tempConfig;
        }
    }
    return nil;
}

-(int) loadConfig
{
    NSString *filePath;
    
    NSString* directoryPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString* fileName = @"downloaded_config.json";
    filePath = [directoryPath stringByAppendingPathComponent:fileName];
    
    NSFileHandle * _fileHandle = [NSFileHandle fileHandleForReadingAtPath:filePath];
    if (_fileHandle == nil)
    {
        NSLog(@"No downloaded file");
        filePath= [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"board-config.json"];
        _fileHandle = [NSFileHandle fileHandleForReadingAtPath:filePath];
    }
    
    NSData *jsonConfig =[_fileHandle readDataToEndOfFile];
    
    NSError *error = nil;
    id object = [NSJSONSerialization
                 JSONObjectWithData:jsonConfig
                 options:0
                 error:&error];
    
    if(error)
    {
        NSLog(@"ERROR: JSON board config is not formated correctly: %@",[error userInfo]);

    }

    if([object isKindOfClass:[NSDictionary class]])
    {
        NSDictionary *results = object;
        NSDictionary * config = [results valueForKey:@"config"];
        NSString *versionOfJSON = [config valueForKey:@"version"];
[boardsConfig removeAllObjects];//should be cleaned at the end of parsing when we are sure that we have new data
        if([versionOfJSON isEqualToString:@"1.0"])
        {
            int ret  = [self parseConfigJSonV1_0:config];
            return ret;
        }
    }
    else
    {
        NSLog(@"ERROR: JSON board config is not formated correctly: outermost object is not a NSDictionary.");
    }
    
    return 0;
}

-(int) parseConfigJSonV1_0:(NSDictionary* )config
{
    NSMutableArray *allBoards = [config valueForKey:@"boards"];
    
    for(int boardIndex =0;boardIndex<[allBoards count];boardIndex++)
    {
        InputDeviceConfig * newBoard = [[InputDeviceConfig alloc] init];
        NSDictionary * oneBoardJSON = [allBoards objectAtIndex:boardIndex];
        if(oneBoardJSON)
        {
            newBoard.uniqueName = [oneBoardJSON valueForKey:@"uniqueName"];
            newBoard.hardwareComProtocolType = [oneBoardJSON valueForKey:@"hardwareComProtocolType"];
            newBoard.bybProtocolType = [oneBoardJSON valueForKey:@"bybProtocolType"];
            newBoard.bybProtocolVersion = [oneBoardJSON valueForKey:@"bybProtocolVersion"];
            newBoard.sampleResolution = [[oneBoardJSON valueForKey:@"sampleResolution"] intValue];
            NSString * tempString  = [oneBoardJSON valueForKey:@"maxSampleRate"];
            if(tempString)
            {
                if([tempString intValue])
                {
                    newBoard.maxSampleRate = [tempString intValue];
                }
            }
            
            tempString  = [oneBoardJSON valueForKey:@"maxNumberOfChannels"];
            if(tempString)
            {
                if([tempString intValue])
                {
                    newBoard.maxNumberOfChannels = [tempString intValue];
                }
            }
            
            tempString  = [oneBoardJSON valueForKey:@"defaultTimeScale"];
            if(tempString)
            {
                if([tempString floatValue])
                {
                    newBoard.defaultTimeScale = [tempString floatValue];
                }
            }
            
            tempString  = [oneBoardJSON valueForKey:@"defaultAmplitudeScale"];
            if(tempString)
            {
                if([tempString floatValue])
                {
                    newBoard.defaultAmplitudeScale = [tempString floatValue];
                }
            }
            
            newBoard.sampleRateIsFunctionOfNumberOfChannels = [[oneBoardJSON valueForKey:@"sampleRateIsFunctionOfNumberOfChannels"] boolValue];
            
            
            newBoard.userFriendlyFullName = [oneBoardJSON valueForKey:@"userFriendlyFullName"];
            newBoard.userFriendlyShortName = [oneBoardJSON valueForKey:@"userFriendlyShortName"];
            newBoard.minAppVersion = [oneBoardJSON valueForKey:@"miniOSAppVersion"];

            newBoard.productURL = [oneBoardJSON valueForKey:@"productURL"];
            newBoard.helpURL = [oneBoardJSON valueForKey:@"helpURL"];
            newBoard.firmwareUpdateUrl = [oneBoardJSON valueForKey:@"firmwareUpdateUrl"];
            newBoard.iconURL = [oneBoardJSON valueForKey:@"iconURL"];
            newBoard.p300CapabilityPresent = [[oneBoardJSON valueForKey:@"p300CapabilityPresent"] boolValue];
            //"supportedPlatforms":"android,win,mac,linux",
            NSString *supportedPlatforms = [oneBoardJSON valueForKey:@"supportedPlatforms"];
            newBoard.inputDevicesSupportedByThisPlatform = [[supportedPlatforms lowercaseString] containsString:@"ios"];
            
            NSDictionary * filterJSON = [oneBoardJSON valueForKey:@"filter"];

            newBoard.filterSettings.signalType = customSignalType;
            if(filterJSON)
            {
                NSString * signalTypeJSON = [filterJSON valueForKey:@"signalType"];
                
                if(signalTypeJSON)
                {
                    NSArray *signalTypeValues = [NSArray arrayWithObjects:@"customSignalType", @"eegSignal", @"emgSignal", @"plantSignal", @"neuronSignal", @"ergSignal", @"eogSignal", @"ecgSignal", nil];
                    
                    for(int  i=0;i<[signalTypeValues count];i++)
                    {
                        if([signalTypeJSON containsString:[signalTypeValues objectAtIndex:i]])
                        {
                            newBoard.filterSettings.signalType = i;
                            break;
                        }
                    }
                }
                
                newBoard.filterSettings.lowPassON = [[filterJSON valueForKey:@"lowPassON"] boolValue];
                newBoard.filterSettings.lowPassCutoff = [[filterJSON valueForKey:@"lowPassCutoff"] floatValue];
                newBoard.filterSettings.highPassON = [[filterJSON valueForKey:@"highPassON"] boolValue];
                newBoard.filterSettings.highPassCutoff = [[filterJSON valueForKey:@"highPassCutoff"] floatValue];
                
                
                NSArray *notchFilterValues = [NSArray arrayWithObjects:@"notchOff", @"notch60Hz", @"notch50Hz", nil];
                NSString * notchFilterStateJSON = [filterJSON valueForKey:@"notchFilterState"];
                if(notchFilterStateJSON)
                {
                    for(int  i=0;i<[notchFilterValues count];i++)
                    {
                        if([notchFilterStateJSON containsString:[notchFilterValues objectAtIndex:i]])
                        {
                            newBoard.filterSettings.notchFilterState = i;
                            break;
                        }
                    }
                }
            }
            
            //parse main channels
            NSMutableArray *allMainChannelsJSON = [oneBoardJSON valueForKey:@"channels"];
            [newBoard.channels removeAllObjects];
            if(allMainChannelsJSON)
            {
                for(int channelIndex=0;channelIndex<[allMainChannelsJSON count];channelIndex++)
                {
                    ChannelConfig * newChannel= [[ChannelConfig alloc] init];
                    NSDictionary * oneChannelJSON = [allMainChannelsJSON objectAtIndex:channelIndex];
                    newChannel.userFriendlyFullName = [oneChannelJSON valueForKey:@"userFriendlyFullName"];
                    newChannel.userFriendlyShortName = [oneChannelJSON valueForKey:@"userFriendlyShortName"];
                    newChannel.activeByDefault = [[oneChannelJSON valueForKey:@"activeByDefault"] boolValue];
                    newChannel.filtered = [[oneChannelJSON valueForKey:@"filtered"] boolValue];
                    newChannel.calibrationCoef = [[oneChannelJSON valueForKey:@"calibrationCoef"] floatValue];
                    newChannel.channelIsCalibrated = [[oneChannelJSON valueForKey:@"channelIsCalibrated"] boolValue];
                    newChannel.defaultVoltageScale = [[oneChannelJSON valueForKey:@"defaultVoltageScale"] floatValue];
                    
                    [newBoard.channels addObject:newChannel];
                }
            }

             //@property (nonatomic, strong) NSMutableArray *expansionBoards;//configuration for expansion boards
            NSMutableArray *allExpansionBoardsJSON = [oneBoardJSON valueForKey:@"expansionBoards"];
            [newBoard.expansionBoards removeAllObjects];
            if(allExpansionBoardsJSON)
            {
                for(int ebIndex=0;ebIndex<[allExpansionBoardsJSON count];ebIndex++)
                {
                    ExpansionBoardConfig * newExpansionBoard= [[ExpansionBoardConfig alloc] init];
                    NSDictionary * oneEBJSON = [allExpansionBoardsJSON objectAtIndex:ebIndex];
                    
                    newExpansionBoard.boardType = [oneEBJSON valueForKey:@"boardType"];
                    newExpansionBoard.userFriendlyFullName = [oneEBJSON valueForKey:@"userFriendlyFullName"];
                    newExpansionBoard.userFriendlyShortName = [oneEBJSON valueForKey:@"userFriendlyShortName"];
                    
                    NSString *supportedPlatformsForBoards = [oneEBJSON valueForKey:@"supportedPlatforms"];
                    newExpansionBoard.expansionBoardSupportedByThisPlatform = [[supportedPlatformsForBoards lowercaseString] containsString:@"ios"];
                    
                    tempString  = [oneEBJSON valueForKey:@"maxNumberOfChannels"];
                    if(tempString)
                    {
                        if([tempString intValue])
                        {
                            newExpansionBoard.maxNumberOfChannels = [tempString intValue];
                        }
                    }
                    
                    newExpansionBoard.productURL = [oneEBJSON valueForKey:@"productURL"];
                    newExpansionBoard.helpURL = [oneEBJSON valueForKey:@"helpURL"];
                    newExpansionBoard.iconURL = [oneEBJSON valueForKey:@"iconURL"];
                    
                    tempString  = [oneEBJSON valueForKey:@"maxSampleRate"];
                    if(tempString)
                    {
                        if([tempString intValue])
                        {
                            newExpansionBoard.maxSampleRate = [tempString intValue];
                        }
                    }
                    else
                    {
                        newExpansionBoard.maxSampleRate = newBoard.maxSampleRate;
                    }
                    
                    
                    tempString  = [oneEBJSON valueForKey:@"defaultTimeScale"];
                    if(tempString)
                    {
                        if([tempString floatValue])
                        {
                            newExpansionBoard.defaultTimeScale = [tempString floatValue];
                        }
                    }
                    else
                    {
                        newExpansionBoard.defaultTimeScale = newBoard.defaultTimeScale;
                    }
                    
                    tempString  = [oneEBJSON valueForKey:@"defaultAmplitudeScale"];
                    if(tempString)
                    {
                        if([tempString floatValue])
                        {
                            newExpansionBoard.defaultAmplitudeScale = [tempString floatValue];
                        }
                    }
                    else
                    {
                        newExpansionBoard.defaultAmplitudeScale = newBoard.defaultAmplitudeScale;
                    }
                    
                   
                    //parse main channels
                    NSMutableArray *allEBChannelsJSON = [oneEBJSON valueForKey:@"channels"];
                    [newExpansionBoard.channels removeAllObjects];
                    if(allEBChannelsJSON)
                    {
                        for(int channelIndex=0;channelIndex<[allEBChannelsJSON count];channelIndex++)
                        {
                            ChannelConfig * newChannel= [[ChannelConfig alloc] init];
                            NSDictionary * oneChannelJSON = [allEBChannelsJSON objectAtIndex:channelIndex];
                            newChannel.userFriendlyFullName = [oneChannelJSON valueForKey:@"userFriendlyFullName"];
                            newChannel.userFriendlyShortName = [oneChannelJSON valueForKey:@"userFriendlyShortName"];
                            newChannel.activeByDefault = [[oneChannelJSON valueForKey:@"activeByDefault"] boolValue];
                            newChannel.filtered = [[oneChannelJSON valueForKey:@"filtered"] boolValue];
                            newChannel.calibrationCoef = [[oneChannelJSON valueForKey:@"calibrationCoef"] floatValue];
                            newChannel.channelIsCalibrated = [[oneChannelJSON valueForKey:@"channelIsCalibrated"] boolValue];
                            newChannel.defaultVoltageScale = [[oneChannelJSON valueForKey:@"defaultVoltageScale"] floatValue];
                            [newExpansionBoard.channels addObject:newChannel];
                        }
                    }
                    
                    [newBoard.expansionBoards addObject:newExpansionBoard];
                }
            }
            
            [boardsConfig addObject:newBoard];
        }
    }
    return 0;
}

@end
