//
//  BBFile.m
//  Backyard Brains
//
//  Created by Alex Wiltschko on 2/21/10.
//  Copyright 2010 University of Michigan. All rights reserved.
//

#import "BBFile.h"
#import "BBSpike.h"

#define  kDataID 1633969266

@implementation BBFile

@synthesize filename;
@synthesize shortname;
@synthesize subname;
@synthesize comment;
@synthesize date;
@synthesize samplingrate;
@synthesize gain;
@synthesize filelength;
@synthesize analyzed;
@synthesize spikesCSV;
@synthesize spikesFiltered;

- (void)dealloc {
	[filename release];
	[shortname release];
    [spikesFiltered release];
	[subname release];
	[comment release];
    [spikesCSV release];
	[date release];
	[_spikes release];
	[super dealloc];

}

- (id)init {
	if ((self = [super init])) {
		
		self.date = [NSDate date];		

		//Format date into the filename
		NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];

		[dateFormatter setDateFormat:@"'BYB Recording 'M'-'d'-'yyyy' 'h':'mm':'ss':'S a'.wav'"];//.m4a
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
        self.spikesCSV = [[[NSMutableArray alloc] init] autorelease];
        self.analyzed = NO;
        self.spikesFiltered = @"";
        _thresholds = [[NSMutableArray alloc] initWithCapacity:0];
		_spikes = [[NSMutableArray alloc] initWithCapacity:0];
        [_thresholds addObject:[NSNumber numberWithFloat:0.0f]];
        [_thresholds addObject:[NSNumber numberWithFloat:0.0f]];
	}
    
	return self;
}



-(NSMutableArray *) thresholds
{
    return _thresholds;
}

-(void) setThresholds:(NSMutableArray *)athresholds
{
    [_thresholds removeAllObjects];
    [_thresholds addObjectsFromArray:athresholds];
    if([_thresholds count]==0)
    {
        [_thresholds addObject:[NSNumber numberWithFloat:0.0f]];
        [_thresholds addObject:[NSNumber numberWithFloat:0.0f]];
    }
}

-(int) numberOfThresholds
{
    return [_thresholds count]/2;
}

-(void) setSpikes:(NSMutableArray *) spikes
{
    [_spikes removeAllObjects];
    [_spikes addObjectsFromArray:spikes];
}

-(NSMutableArray*) spikes
{
    return _spikes;
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
		
		// Grab the sampling rate from NSUserDefaults
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        self.samplingrate   = [[BBAudioManager bbAudioManager] samplingRate];
        //        self.samplingrate = [[Novocaine audioManager] samplingrate];
		self.gain           = [[defaults valueForKey:@"gain"] floatValue];
        self.spikesCSV = [[[NSMutableArray alloc] initWithCapacity:0] autorelease];
        self.analyzed = NO;
        self.spikesFiltered = @"";
        _thresholds = [[NSMutableArray alloc] initWithCapacity:0];
        _spikes = [[NSMutableArray alloc] init];
        [_thresholds addObject:[NSNumber numberWithFloat:0.0f]];
        [_thresholds addObject:[NSNumber numberWithFloat:0.0f]];
	}
    
	return self;
    
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
    _spikes = [[NSMutableArray alloc] init];
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
// Make array of CSV strings out of array of spike train arrays
// We do this because it is much faster to save few long strings
// than few arrays with hundreds of spike objects
// When we load file object we "decompress" CSVs into arrays of spikes 
//
-(void) spikesToCSV
{
    NSMutableString *csvString;
    int i;
    int j;
    BBSpike * tempSpike;
    NSMutableArray * tempSpikeTrain;
    [self.spikesCSV removeAllObjects];
    for(j=0;j<[_spikes count];j++)
    {
        tempSpikeTrain = [_spikes objectAtIndex:j];
        csvString = [NSMutableString string];
        for(i=0;i<[tempSpikeTrain count];i++)
        {
            tempSpike = (BBSpike *) [tempSpikeTrain objectAtIndex:i];
            [csvString appendString:[NSString stringWithFormat:@"%f,%f,%d\n",
                                     tempSpike.value, tempSpike.time, tempSpike.index]];
        }
        [self.spikesCSV addObject:csvString];
    }
}


//
// Convert array of CSV strings to array of spike train arrays
//
-(void) CSVToSpikes
{
    [_spikes removeAllObjects];
    
    int i;
    for(i=0;i<[self.spikesCSV count];i++)
    {
        NSMutableArray * newSpikeTrain = [[[NSMutableArray alloc] initWithCapacity:0] autorelease];
        NSScanner *scanner = [NSScanner scannerWithString:((NSString *)[self.spikesCSV objectAtIndex:i])];
        [scanner setCharactersToBeSkipped:
         [NSCharacterSet characterSetWithCharactersInString:@"\n, "]];
        float value, time;
        int index;
        BBSpike * newSpike;
        while ( [scanner scanFloat:&value] && [scanner scanFloat:&time] && [scanner scanInt:&index]) {
            newSpike = [[BBSpike alloc] initWithValue:value index:index andTime:time];
            [newSpikeTrain addObject:newSpike];
            [newSpike release];
        }
        [_spikes addObject:newSpikeTrain];
    }
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

//
// Set spike train index to next value
// It will influence threshold getters/setters
//
-(NSInteger) moveToNextSpikeTrain
{
    int nextSpikeTrain = _currentSpikeTrain +1;
    if([self numberOfThresholds]<=nextSpikeTrain)
    {
        nextSpikeTrain = 0;
    }
    _currentSpikeTrain=nextSpikeTrain;
    return _currentSpikeTrain;
}

//
// Set spike train index to new value
// It will influence threshold getters/setters
//
-(void) setCurrentSpikeTrain:(NSInteger) aCurrentSpikeTrain
{
    if(_spikes && [self numberOfThresholds]>aCurrentSpikeTrain && aCurrentSpikeTrain>=0)
    {
        _currentSpikeTrain = aCurrentSpikeTrain;
    }
    else
    {
//        NSException *e = [NSException
//                          exceptionWithName:@"Invalid spike train index."
//                          reason:@"Index out of bounds."
//                          userInfo:nil];
//        @throw e;
    }
}

//Add another threshold pair
-(void) addAnotherThresholds
{
    [_thresholds addObject:[NSNumber numberWithFloat:0.0f]];
    [_thresholds addObject:[NSNumber numberWithFloat:0.0f]];
    _currentSpikeTrain = (int)([_thresholds count]/2)-1;
}

-(void) removeCurrentThresholds
{
    if([self numberOfThresholds]>1)
    {
        [_thresholds removeObjectAtIndex:_currentSpikeTrain*2+1];
        [_thresholds removeObjectAtIndex:_currentSpikeTrain*2];
        
        int newCurrentSpikeTrain = [self currentSpikeTrain]-1;
        if(newCurrentSpikeTrain<0)
        {
            newCurrentSpikeTrain = 0;
        }
        
        [self setCurrentSpikeTrain:newCurrentSpikeTrain];
    }
}

-(NSInteger) currentSpikeTrain
{
    return _currentSpikeTrain;
}

-(void) setThresholdFirst:(float)thresholdFirst
{
    [_thresholds replaceObjectAtIndex:_currentSpikeTrain*2 withObject:[NSNumber numberWithFloat:thresholdFirst]];
}

-(float) thresholdFirst
{
    return [[_thresholds objectAtIndex:_currentSpikeTrain*2] floatValue];
}

-(void) setThresholdSecond:(float)thresholdSecond
{
    [_thresholds replaceObjectAtIndex:_currentSpikeTrain*2+1 withObject:[NSNumber numberWithFloat:thresholdSecond]];
}

-(float) thresholdSecond
{
    return [[_thresholds objectAtIndex:_currentSpikeTrain*2+1] floatValue];
}

- (NSURL *)fileURL
{
    return [NSURL fileURLWithPath:[[self docPath] stringByAppendingPathComponent:self.filename]];
    
}

- (NSString *)docPath
{
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
}

/*-(NSString*) spikesFiltered
{
    return _spikesFiltered;
}

-(void) setSpikesFiltered:(NSString *) aSpikesFiltered
{
    _spikesFiltered = aSpikesFiltered;
}*/

@end
