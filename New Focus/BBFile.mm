//
//  BBFile.m
//  Backyard Brains
//
//  Created by Alex Wiltschko on 2/21/10.
//  Copyright 2010 University of Michigan. All rights reserved.
//

#import "BBFile.h"
#import "BBSpike.h"
#import "BBChannel.h"
#import "BBSpikeTrain.h"

//#define  kDataID 1633969266

@implementation BBFile

@synthesize filename;
@synthesize shortname;
@synthesize subname;
@synthesize comment;
@synthesize date;
@synthesize samplingrate;
@synthesize numberOfChannels;
@synthesize gain;
@synthesize filelength;


@synthesize spikesFiltered;

- (void)dealloc {
	[filename release];
	[shortname release];
    [spikesFiltered release];
	[subname release];
	[comment release];
	[date release];
	[_allSpikes release];
    [_allChannels release];
    [_allEvents release];
	[super dealloc];

}

- (id)init {
	if ((self = [super init])) {
		
		[self setupFilePropertiesForWav:NO];
	}
    
	return self;
}

- (id)initWav {
	if ((self = [super init])) {
		
		[self setupFilePropertiesForWav:YES];
	}
    
	return self;
}


-(void) setupFilePropertiesForWav:(BOOL) isWav
{
    self.date = [NSDate date];
    
    //Format date into the filename
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    
    if(isWav)
    {
        [dateFormatter setDateFormat:@"'BYB Recording 'M'-'d'-'yyyy' 'h':'mm':'ss':'S a'.wav'"];
    }
    else
    {
        [dateFormatter setDateFormat:@"'BYB Recording 'M'-'d'-'yyyy' 'h':'mm':'ss':'S a'.m4a'"];
    }
    self.filename = [dateFormatter stringFromDate:self.date];
    NSLog(@"Filename: %@", self.filename);
    
    [dateFormatter setDateFormat:@"'BYB Recording 'M'-'d'-'yyyy' 'h':'mm':'ss':'S a"];
    self.shortname = [dateFormatter stringFromDate:self.date];
    
    [dateFormatter setDateFormat:@"M'/'d'/'yyyy',' h':'mm a"];
    self.subname = [dateFormatter stringFromDate:self.date];
    
    [dateFormatter release];
    
    self.comment = @"";
    
    // Grab the sampling rate from NSUserDefaults
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.samplingrate   = [[BBAudioManager bbAudioManager] samplingRate];
    //        self.samplingrate = [[Novocaine audioManager] samplingrate];
    self.gain           = [[defaults valueForKey:@"gain"] floatValue];
    self.spikesFiltered = FILE_NOT_SPIKE_SORTED;
    self.numberOfChannels = 0;
    _allChannels = [[NSMutableArray alloc] initWithCapacity:0];
    _allSpikes = [[NSMutableArray alloc] initWithCapacity:0];
    _allEvents = [[NSMutableArray alloc] initWithCapacity:0];
}

-(id) initWithUrl:(NSURL *) urlOfExistingFile
{
    if ((self = [super init])) {
		
		self.date = [NSDate date];
        NSString *onlyFilename = [[urlOfExistingFile path] lastPathComponent];
        NSString *testFileName;
        testFileName = [NSString stringWithFormat:@"Shared %@",onlyFilename];
        
        
        
        // If there's a file with same filename
        BOOL isThereAFileAlready = YES;
        
        // If there is, let's change the name
        int i;
        i=2;
        while (isThereAFileAlready) {
            
            
            isThereAFileAlready = [[NSFileManager defaultManager] fileExistsAtPath:[[self docPath] stringByAppendingPathComponent:testFileName]];
            
            if(isThereAFileAlready)
            {
                NSLog(@"There's a file already");
                testFileName = [NSString stringWithFormat:@"Shared %d %@", i, onlyFilename];
                i++;
            }
        }
        onlyFilename = testFileName;
        
        
		//Format date into the filename
		NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        
		self.filename = onlyFilename;
        NSLog(@"Filename: %@", self.filename);
		
		self.shortname = [onlyFilename stringByDeletingPathExtension];
		NSLog(@"Shortname: %@", self.shortname);
        
		[dateFormatter setDateFormat:@"M'/'d'/'yyyy',' h':'mm a"];
		self.subname = [dateFormatter stringFromDate:self.date];
        
		[dateFormatter release];
		
		self.comment = @"";
		
        
        
        NSError *avPlayerError = nil;
        AVAudioPlayer *avPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:urlOfExistingFile error:&avPlayerError];
        if (avPlayerError)
        {
            NSLog(@"Error init file: %@", [avPlayerError description]);
            self.numberOfChannels =1;
            self.samplingrate = 44100.0f;
        }
        else
        {
            self.numberOfChannels = [avPlayer numberOfChannels];
            self.samplingrate = [[[avPlayer settings] objectForKey:AVSampleRateKey] floatValue];
            NSLog(@"Source file num. of channels %d, sampling rate %f", self.numberOfChannels, self.samplingrate );
        }
        [avPlayer release];
        avPlayer = nil;

		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		self.gain           = [[defaults valueForKey:@"gain"] floatValue];
        self.spikesFiltered = FILE_NOT_SPIKE_SORTED;
        [self setupChannels];
        
        _allSpikes = [[NSMutableArray alloc] initWithCapacity:0];
        _allEvents = [[NSMutableArray alloc] initWithCapacity:0];

	}
    
	return self;
    
}

-(void) setupChannels
{
    _allChannels = [[NSMutableArray alloc] initWithCapacity:0];
    
    for (int i =0; i<self.numberOfChannels; i++)
    {
        NSString * nameOfChannel = [NSString stringWithFormat:@"Channel %d",i+1];
        BBChannel * newChannel = [[BBChannel alloc] initWithNameOfChannel:nameOfChannel];
        
        NSString * nameOfSpikeTrain = [NSString stringWithFormat:@"Spike %da",(i+1)];
        BBSpikeTrain * newSpikeTrain = [[BBSpikeTrain alloc]initWithName:nameOfSpikeTrain];
        
        [newChannel.spikeTrains addObject:newSpikeTrain];
        
        [_allChannels addObject:newChannel];
    }

}

-(void) setAllSpikes:(NSMutableArray *) spikes
{
    [_allSpikes removeAllObjects];
    [_allSpikes addObjectsFromArray:spikes];
}

-(NSMutableArray*) allSpikes
{
    return _allSpikes;
}


-(void) setAllChannels:(NSMutableArray *)allChannels
{
    [_allChannels removeAllObjects];
    [_allChannels addObjectsFromArray:allChannels];
}

-(NSMutableArray*) allChannels
{
    return _allChannels;
}

-(void) setAllEvents:(NSMutableArray *)allEvents
{
    [_allEvents removeAllObjects];
    [_allEvents addObjectsFromArray:allEvents];
}

-(NSMutableArray*) allEvents
{
    return _allEvents;
}




+(NSArray *)allObjects
{
    NSArray * allFiles = [[self class] findByCriteria:@""];
    int i;
    for(i=0;i<[allFiles count];i++)
    {
        [((BBFile *)[allFiles objectAtIndex:i]) CSVToSpikes];
    }
	return allFiles;
}

//
// Save file. First transform arrays of spikes to CSV, than save and than restore arrays
// It is much much faster to save one CSV string than spike train array
//
-(void)save
{
    [self renameIfNeeded];
    [self spikesToCSV];
    _allSpikes = [[NSMutableArray alloc] init];
    [super save];
    [self CSVToSpikes];
}

//
// Save file but don't save spike trains. It is faster and sometimes enough.
//
-(void) saveWithoutArrays
{
    [self renameIfNeeded];
    //[self spikesToCSV];
    //_spikes = [[NSMutableArray alloc] init];
    [super saveWithoutArrays];
}

//
// Check if we can save file with original name or we have already file with same name.
// If we find file with same name add index number
//
-(void) renameIfNeeded
{
    NSString * newNameFromShortName = [NSString stringWithFormat:@"%@.%@", [self shortname], [[self fileURL] pathExtension]];
    //check if name of the file is different than shortname
    //if yes than make it same
    if(![newNameFromShortName isEqualToString:[[self filename] stringByDeletingPathExtension]])
    {
        
        // If there's a file with same filename
        BOOL isThereAFileAlready = YES;
        
        // If there is, let's change the name
        int i;
        i=2;
        while (isThereAFileAlready) {
            
            
            isThereAFileAlready = [[NSFileManager defaultManager] fileExistsAtPath:[[self docPath] stringByAppendingPathComponent:newNameFromShortName]];
            
            if(isThereAFileAlready)
            {
                NSLog(@"There's a file already");
                newNameFromShortName = [NSString stringWithFormat:@"%@ %d.%@", [self shortname], i, [[self fileURL] pathExtension]];
                i++;
            }
        }
        //copy file with new name
        [[NSFileManager defaultManager] copyItemAtURL:[self fileURL] toURL:[NSURL fileURLWithPath:[[self docPath] stringByAppendingPathComponent:newNameFromShortName]] error:nil];
        //remove old file
        [[NSFileManager defaultManager] removeItemAtPath:[[self docPath] stringByAppendingPathComponent:self.filename] error:nil];
        
        self.filename = newNameFromShortName;
    }
}

//
//compress all spikes to csv
//
-(void) spikesToCSV
{
    
    for(int channelIndex = 0;channelIndex<[_allChannels count];channelIndex++)
    {
        BBChannel * tempChannel = (BBChannel *)[_allChannels objectAtIndex:channelIndex];
        for(int trainIndex=0;trainIndex<[[tempChannel spikeTrains] count];trainIndex++)
        {
            [[[tempChannel spikeTrains] objectAtIndex:trainIndex] spikesToCSV];
        }
    }
}


//
// Uncompress all CSV to spike trains
//
-(void) CSVToSpikes
{
    for(int channelIndex = 0;channelIndex<[_allChannels count];channelIndex++)
    {
        BBChannel * tempChannel = (BBChannel *)[_allChannels objectAtIndex:channelIndex];
        for(int trainIndex=0;trainIndex<[[tempChannel spikeTrains] count];trainIndex++)
        {
            [[[tempChannel spikeTrains] objectAtIndex:trainIndex] CSVToSpikes];
        }
    }
}


-(int) numberOfSpikeTrains
{
    int numOfST = 0;
    for(int channelIndex = 0;channelIndex<[_allChannels count];channelIndex++)
    {
        BBChannel * tempChannel = (BBChannel *)[_allChannels objectAtIndex:channelIndex];
        numOfST +=[[tempChannel spikeTrains] count];
    }
    return numOfST;
}


- (void)deleteObject {
	[super deleteObject];
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
    // First check if there's a file there at all
    BOOL isThereAFileAlready = [fileManager fileExistsAtPath:[[self docPath] stringByAppendingPathComponent:self.filename]];
    
    // If there is, nuke the file.
    if (isThereAFileAlready) {
        NSError *error = nil;
        if (!	[fileManager removeItemAtPath:[[self docPath] stringByAppendingPathComponent:self.filename] error:&error]) {
            NSLog(@"Error deleting file: %@", error);
        }
    }	
}


- (NSURL *)fileURL
{
    return [NSURL fileURLWithPath:[[self docPath] stringByAppendingPathComponent:self.filename]];
    
}

- (NSString *)docPath
{
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
}

@end
