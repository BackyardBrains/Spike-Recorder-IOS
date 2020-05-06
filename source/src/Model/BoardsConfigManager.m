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

@implementation BoardsConfigManager
@synthesize boardsConfig;

- (id)init {
    if ((self = [super init]))
    {
        boardsConfig = [[NSMutableArray alloc] initWithCapacity:0];
        [self loadLocalConfig];
    }
    return self;
}

-(int) loadLocalConfig
{
    //_pathToFile = [[urlToFile path] retain];
    NSString *filePath= [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"board-config.json"];
    NSFileHandle * _fileHandle = [NSFileHandle fileHandleForReadingAtPath:filePath];
    if (_fileHandle == nil)
    {
        NSLog(@"ERROR: Failed to open the board config file");
        return 1;
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
    
    // the originating poster wants to deal with dictionaries;
    // assuming you do too then something like this is the first
    // validation step:
    if([object isKindOfClass:[NSDictionary class]])
    {
        NSDictionary *results = object;
        NSDictionary * config = [results valueForKey:@"config"];
        NSString *versionOfJSON = [config valueForKey:@"version"];
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
        [boardsConfig removeAllObjects];
        InputDeviceConfig * newBoard = [[InputDeviceConfig alloc] init];
        NSDictionary * oneBoardJSON = [allBoards objectAtIndex:boardIndex];
        if(oneBoardJSON)
        {
            newBoard.uniqueName = [oneBoardJSON valueForKey:@"uniqueName"];
            newBoard.hardwareComProtocolType = [oneBoardJSON valueForKey:@"hardwareComProtocolType"];
            newBoard.bybProtocolType = [oneBoardJSON valueForKey:@"bybProtocolType"];
            newBoard.bybProtocolVersion = [oneBoardJSON valueForKey:@"bybProtocolVersion"];
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
            
            tempString  = [oneBoardJSON valueForKey:@"defaultGain"];
            if(tempString)
            {
                if([tempString floatValue])
                {
                    newBoard.defaultGain = [tempString floatValue];
                }
            }
            
            newBoard.sampleRateIsFunctionOfNumberOfChannels = [[oneBoardJSON valueForKey:@"sampleRateIsFunctionOfNumberOfChannels"] boolValue];
            
            
            newBoard.userFriendlyFullName = [oneBoardJSON valueForKey:@"userFriendlyFullName"];
            newBoard.userFriendlyShortName = [oneBoardJSON valueForKey:@"userFriendlyShortName"];
            newBoard.minAppVersion = [oneBoardJSON valueForKey:@"miniOSAppVersion"];

            
            
            
            
            
    
            
           /* @property FilterSettings* filterSettings;//default filter settings

            @property int currentSampleRate;
            @property int currentNumOfChannels;

            @property (nonatomic, strong) NSMutableArray *expansionBoards;//configuration for expansion boards
            @property (nonatomic, strong) NSMutableArray *channels;*/
            
            [boardsConfig addObject:newBoard];
        }
    }
    return 0;
}

@end
