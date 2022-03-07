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
#import "BBEvent.h"
#import "tinyxml2.h"
#import "ZipArchive.h"

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
@synthesize fileUsage;

@synthesize spikesFiltered;

using namespace tinyxml2;

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
        [dateFormatter setDateFormat:@"'BYB Recording 'M'-'d'-'yyyy'-'h'-'mm'-'ss'-'Sa'.wav'"];
    }
    else
    {
        [dateFormatter setDateFormat:@"'BYB Recording 'M'-'d'-'yyyy'-'h'-'mm'-'ss'-'Sa'.m4a'"];
    }
    self.filename = [dateFormatter stringFromDate:self.date];
    NSLog(@"Filename: %@", self.filename);
    
    [dateFormatter setDateFormat:@"'BYB Recording 'M'-'d'-'yyyy'-'h'-'mm'-'ss'-'Sa"];
    self.shortname = [dateFormatter stringFromDate:self.date];
    
    [dateFormatter setDateFormat:@"M'-'d'-'yyyy'-'h'-'mma"];
    self.subname = [dateFormatter stringFromDate:self.date];
    
    [dateFormatter release];
    
    self.comment = @"";
    self.fileUsage = NORMAL_FILE_USAGE;
    // Grab the sampling rate from NSUserDefaults
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.samplingrate   = [[BBAudioManager bbAudioManager] sourceSamplingRate];

    self.gain           = [[defaults valueForKey:@"gain"] floatValue];
    self.spikesFiltered = FILE_NOT_SPIKE_SORTED;
    self.numberOfChannels = 0;
    _allChannels = [[NSMutableArray alloc] initWithCapacity:0];
    _allSpikes = [[NSMutableArray alloc] initWithCapacity:0];
    _allEvents = [[NSMutableArray alloc] initWithCapacity:0];
    
   /*
    //debug events - test
    BBEvent * tempEvent = [[BBEvent alloc] initWithValue:1 index:44100 andTime:1.0f];
    [_allEvents addObject:tempEvent];
    tempEvent = [[BBEvent alloc] initWithValue:2 index:2*44100 andTime:2.0f];
    [_allEvents addObject:tempEvent];
    tempEvent = [[BBEvent alloc] initWithValue:3 index:3*44100 andTime:3.0f];
    [_allEvents addObject:tempEvent];*/
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
        
        [dateFormatter setDateFormat:@"M'-'d'-'yyyy'-'h'-'mma"];
		self.subname = [dateFormatter stringFromDate:self.date];
        
		[dateFormatter release];
		
		self.comment = @"";
		
        self.fileUsage = NORMAL_FILE_USAGE;
        
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


-(void) changeParameterWithName:(NSString *)name forParent:(XMLElement *) parent withValue:(NSString *) value
{
    XMLElement * tempElement = parent->FirstChildElement([name UTF8String]);
    if(tempElement)
    {
        tempElement->SetText([value UTF8String]);
    }
    else
    {
        NSLog(@"Error: Problem parsing XML template. No %@.",name);
    }


}



-(NSURL *)prepareBYBFile
{
    XMLDocument doc;
  //  NSString * templateName = @"template.xml";
    NSString *path = [[NSBundle mainBundle] pathForResource:@"template" ofType:@"xml"];
    
    doc.LoadFile([path UTF8String]);
    XMLElement * rootElement = doc.FirstChildElement("bybrecording");
    if(rootElement)
    {
        [self changeParameterWithName:@"filename" forParent:rootElement withValue:self.filename];
        
        NSDateFormatter* df = [[NSDateFormatter alloc]init];
        NSTimeZone *gmt = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
        [df setTimeZone:gmt];
        [df setDateFormat: @"yyyy-MM-dd HH:mm:ss zzz"];
        NSString *dateCreated = [df stringFromDate:self.date];
        [df release];
        [self changeParameterWithName:@"datecreated" forParent:rootElement withValue:dateCreated];
        [self changeParameterWithName:@"description" forParent:rootElement withValue:self.description];
        [self changeParameterWithName:@"subjectname" forParent:rootElement withValue:@"unknown"];
        [self changeParameterWithName:@"createdby" forParent:rootElement withValue:@"unknown"];
        [self changeParameterWithName:@"softwaretype" forParent:rootElement withValue:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"]];
        [self changeParameterWithName:@"softwareversion" forParent:rootElement withValue:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
        [self changeParameterWithName:@"softwarebuild" forParent:rootElement withValue:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];
    }
    else
    {
        NSLog(@"Error: Problem parsing XML template. No root element.");
    }
    
    
    //->FirstChildElement("softwareversion")->SetText([ UTF8String]);
   
    //
    NSURL * tempUrl = [NSURL fileURLWithPath:[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"temp.xml"]];
     doc.SaveFile([[tempUrl path] UTF8String]);
    return tempUrl;
}


-(void) setupChannels
{
    _allChannels = [[NSMutableArray alloc] initWithCapacity:0];
    
    for (int i =0; i<self.numberOfChannels; i++)
    {
        NSString * nameOfChannel = [[NSString stringWithFormat:@"Channel %d",i+1] copy];
        BBChannel * newChannel = [[[BBChannel alloc] initWithNameOfChannel:nameOfChannel] autorelease];
        [nameOfChannel release];
        
        NSString * nameOfSpikeTrain = [[NSString stringWithFormat:@"Spike %da",(i+1)] copy];
        BBSpikeTrain * newSpikeTrain = [[[BBSpikeTrain alloc]initWithName:nameOfSpikeTrain] autorelease];
        [nameOfSpikeTrain release];
        
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
    NSArray * allFiles = [[self class] findByCriteria:@"ORDER BY date DESC"];
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

-(NSString * ) saveWithArraysToArchieve
{
    [self renameIfNeeded];
    [super saveWithoutArrays];
    NSString *eventsPath = @"";
    if( [self.spikesFiltered isEqualToString:FILE_SPIKE_SORTED] || [_allEvents count]>0 )
    {
        NSError *error;
        NSMutableString *fileContentString = [NSMutableString stringWithString:@"# Marker IDs can be arbitrary strings.\n# Marker ID,    Time (in s)\n"];
        
       
        //[fileContentString appendFormat:@"Name.... %@\n", accessory.name];

        eventsPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-events.txt",self.shortname]];
       
        //save events
        if([_allEvents count]>0)
        {
            for(int i=0;i<[_allEvents count];i++)
            {
                BBEvent * tempEvent = [_allEvents objectAtIndex:i];
                [fileContentString appendFormat:@"%d,\t%f\n", tempEvent.value, tempEvent.time];
            }
        }
        
        //save spikes
        if([self.spikesFiltered isEqualToString:FILE_SPIKE_SORTED])
        {
            int neuronCount = 0;
            for(int channelIndex = 0;channelIndex<self.numberOfChannels;channelIndex++)
            {
                BBChannel * tempChannel = [[self allChannels] objectAtIndex:channelIndex];
                //NSMutableArray * currentChannelSpikes = [[self allSpikes] objectAtIndex:channelIndex];
                for(int spikeIndex = 0;spikeIndex<[tempChannel.spikeTrains count];spikeIndex++)
                {
                    BBSpikeTrain * tempSpikeTrain = [tempChannel.spikeTrains objectAtIndex:spikeIndex];
                    if([tempSpikeTrain.spikes count]==0)
                    {
                        continue;
                    }
                    for(int i=0;i<[tempSpikeTrain.spikes count];i++)
                    {
                        BBSpike * tempSpike = (BBSpike *) [tempSpikeTrain.spikes objectAtIndex:i];
                        //_ch0_neuron0,    3.8111
                        [fileContentString appendFormat:@"_ch%d_neuron%d,\t%f\n", channelIndex,neuronCount,tempSpike.time];
                    }//spikes loop
                    //save threshold
                    //_neuron0threshhig1275,    0.0000
                    //_neuron0threshlow206,    0.0000
                    //multiply value with 32768 to convert from float [-1,1] interval to integer [-32768,32768]
                    [fileContentString appendFormat:@"_neuron%dthreshhig%d,\t0.0000\n", neuronCount,(int)(tempSpikeTrain.firstThreshold*32768)];
                    [fileContentString appendFormat:@"_neuron%dthreshlow%d,\t0.0000\n", neuronCount,(int)(tempSpikeTrain.secondThreshold*32768)];
                    neuronCount++;
                }//spike train loop
            }//channel loop
        }//FILE_SPIKE_SORTED

        [fileContentString writeToFile:eventsPath atomically:YES encoding:NSUTF8StringEncoding error:&error];
        
        NSMutableArray * arrayOfFiles = [[[NSMutableArray alloc] initWithCapacity:0] autorelease];
        [arrayOfFiles addObject:[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:self.filename]];
        [arrayOfFiles addObject:eventsPath];
        
        
        NSString * pathToReturn =  [self createZipArchiveWithFiles:arrayOfFiles andName:[NSString stringWithFormat:@"%@.zip",self.shortname]];
        return pathToReturn;
    }//end of if we have anything to save
    else
    {
        return [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:self.filename];
    }
}

- (NSString*) createZipArchiveWithFiles:(NSArray*)files andName:(NSString*)nameOFile
{
    ZipArchive* zip = [[[ZipArchive alloc] init] autorelease];
    NSArray *paths = NSSearchPathForDirectoriesInDomains
    (NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *zipPath = [NSString stringWithFormat:@"%@/%@",
                         [paths objectAtIndex:0], nameOFile] ;
    
    
    [zip CreateZipFile2:zipPath];
    for (NSString* file in files) {
        [zip addFileToZip:file newname:[file lastPathComponent]];
        
    }
    [zip CloseZipFile2];
    return zipPath;
}


//
// Check if we can save file with original name or we have already file with same name.
// If we find file with same name add index number
//
-(void) renameIfNeeded
{
    //NSString * newShortString = [[self shortname] stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    //newShortString = [[self shortname] stringByReplacingOccurrencesOfString:@"\\" withString:@"_"];
    
    NSString * newShortString =  [[[self shortname]  componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@"-"];
     newShortString =  [[newShortString componentsSeparatedByCharactersInSet:[NSCharacterSet illegalCharacterSet]] componentsJoinedByString:@"-"];
     newShortString =  [[newShortString componentsSeparatedByCharactersInSet:[NSCharacterSet controlCharacterSet]] componentsJoinedByString:@"-"];
    newShortString =  [[newShortString componentsSeparatedByString:@":"] componentsJoinedByString:@"-"];
    newShortString =  [[newShortString componentsSeparatedByString:@"/"] componentsJoinedByString:@"-"];
    newShortString =  [[newShortString componentsSeparatedByString:@"\\"] componentsJoinedByString:@"-"];
   
    
    NSString * newNameFromShortName = [NSString stringWithFormat:@"%@.%@", newShortString, [[self fileURL] pathExtension]];
    //check if name of the file is different than shortname
    //if yes than make it same

    if(![newNameFromShortName isEqualToString:[self filename]])
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
                newNameFromShortName = [NSString stringWithFormat:@"%@ %d.%@", newShortString, i, [[self fileURL] pathExtension]];
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


-(BBSpikeTrain *) getSpikeTrainWithIndex:(int) spikeTrainIndex
{
    int stCounter = 0;
    for(int channelIndex = 0;channelIndex<[_allChannels count];channelIndex++)
    {
        BBChannel * tempChannel = (BBChannel *)[_allChannels objectAtIndex:channelIndex];
        for(int stIndex=0;stIndex<[[tempChannel spikeTrains] count];stIndex++)
        {
            if(stCounter==spikeTrainIndex)
            {
                return [[tempChannel spikeTrains] objectAtIndex:stIndex];
            }
            stCounter++;
        }
    }
    return nil;
}


-(NSInteger) getChannelIndexForSpikeTrainWithIndex: (int) spikeTrainIndex
{
    int stCounter = 0;
    for(int channelIndex = 0;channelIndex<[_allChannels count];channelIndex++)
    {
        BBChannel * tempChannel = (BBChannel *)[_allChannels objectAtIndex:channelIndex];
        for(int stIndex=0;stIndex<[[tempChannel spikeTrains] count];stIndex++)
        {
            if(stCounter==spikeTrainIndex)
            {
                return channelIndex;
            }
            stCounter++;
        }
    }
    return 0;
}

-(NSInteger) getIndexInsideChannelForSpikeTrainWithIndex: (int) spikeTrainIndex
{

    int stCounter = 0;
    for(int channelIndex = 0;channelIndex<[_allChannels count];channelIndex++)
    {
        BBChannel * tempChannel = (BBChannel *)[_allChannels objectAtIndex:channelIndex];
        for(int stIndex=0;stIndex<[[tempChannel spikeTrains] count];stIndex++)
        {
            if(stCounter==spikeTrainIndex)
            {
                return stIndex;
            }
            stCounter++;
        }
    }
    return 0;


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
