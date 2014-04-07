//
//  BBFile.h
//  Backyard Brains
//
//  Created by Alex Wiltschko on 2/21/10.
//  Copyright 2010 University of Michigan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "SQLitePersistentObject.h"
#import "BBAudioManager.h"

@interface BBFile : SQLitePersistentObject {
	NSString *filename;
	NSString *shortname;
	NSString *subname;
	NSString *comment;
	NSDate *date;
	float samplingrate;
	float gain;
	float filelength;
}

@property (nonatomic, retain) NSString *filename;
@property (nonatomic, retain) NSString *shortname;
@property (nonatomic, retain) NSString *subname;
@property (nonatomic, retain) NSString *comment;
@property (nonatomic, retain) NSDate *date;
@property float samplingrate;
@property float gain;
@property float filelength;

- (NSURL *)fileURL;
-(id) initWithUrl:(NSURL *) urlOfExistingFile;

@end
