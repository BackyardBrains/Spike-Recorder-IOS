//
//  BBFile.m
//  Backyard Brains
//
//  Created by Alex Wiltschko on 2/21/10.
//  Copyright 2010 University of Michigan. All rights reserved.
//

#import "BBFile.h"

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

- (void)dealloc {
	[filename release];
	[shortname release];
	[subname release];
	[comment release];
	[date release];
	[_spikes release];
	[super dealloc];

}

- (id)init {
	if ((self = [super init])) {
		
		self.date = [NSDate date];		

		//Format date into the filename
		NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];

		[dateFormatter setDateFormat:@"'BYB Recording 'M'-'d'-'yyyy' 'h':'mm':'ss':'S a'.m4a'"];
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
		_spikes = [[NSMutableArray alloc] initWithCapacity:0];
	}
    
	return self;
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
        _spikes = [[NSMutableArray alloc] init];
	}
    
	return self;
    
}




//- (void)setFilename:(NSString *)newFilename
//{
//    NSLog(@"New filename: %@", newFilename);
//    
//    NSString *oldFilename = [filename copy];
//    filename = newFilename;
//    
//    // If there's a file that exists at the old filename location (if we've already recorded something)
//    // then we're going to rename it
//    NSError *error = nil;
//    NSFileManager *fileManager = [NSFileManager defaultManager];
//
//    // First check if there's a file there at all
//    BOOL isThereAFileAlready = [fileManager fileExistsAtPath:[[self docPath] stringByAppendingPathComponent:self.filename]];
//    
//    // If there is, let's move it.                                                           
//    if (isThereAFileAlready) {
//        
//        
//        NSLog(@"There's a file already");
//        
//        NSURL *oldURL = [self fileURL];    
//        NSURL *newURL = [NSURL fileURLWithPath:[[self docPath] stringByAppendingPathComponent:newFilename]];
//        
//        NSLog(@"Old URL: %@", oldURL);
//        NSLog(@"New URL: %@", newURL);
//             
//        BOOL success = [fileManager moveItemAtURL:oldURL toURL:newURL error:&error];
//        
//        // If we got it right, then we're all good. If we failed (if there's another file with the desired name), then we don't remember the new filename.
//        if (!success)
//            filename = [oldFilename copy];
//        else
//            NSLog(@"Error moving file: %@", error);
//        
//        NSLog(@"The filename now is: %@", filename);
//        
//    }
//    
//    [oldFilename release];
//    
//}

-(void)save
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
    
    
    [super save];
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
