//
//  WavManager.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 6/7/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "WavManager.h"


@interface WavManager()
{
    
    long totalAudioLen;
    long totalDataLen;
    NSString * _pathToFile;
    UInt32 currentPositionDuringRead;
}



@end


@implementation WavManager

@synthesize fileHandle;
@synthesize fileURL;

- (id)init
{
    if (self = [super init])
    {}
    return self;
}

-(void) createWav:(NSURL *)urlToFile samlingRate:(float) samplingRate numberOfChannels:(int) numberOfChannels
{
    fileProperties.sampleRate = (long)samplingRate;
    fileProperties.numOfChannels = (unsigned int)numberOfChannels;
    fileProperties.compressionType = WAVE_FORMAT_IEEE_FLOAT;
    self.fileURL = urlToFile ;
    totalAudioLen = 0;
    totalDataLen = totalAudioLen + 44;
    _pathToFile = [[urlToFile path] copy];
    long byteRate = fileProperties.numOfChannels * fileProperties.sampleRate * 4;//4 bytes for float
    
    Byte *header = (Byte*)calloc(44, sizeof(Byte));
    header[0] = 'R';  // RIFF/WAVE header
    header[1] = 'I';
    header[2] = 'F';
    header[3] = 'F';
    header[4] = (Byte) (totalDataLen & 0xff);
    header[5] = (Byte) ((totalDataLen >> 8) & 0xff);
    header[6] = (Byte) ((totalDataLen >> 16) & 0xff);
    header[7] = (Byte) ((totalDataLen >> 24) & 0xff);
    header[8] = 'W';
    header[9] = 'A';
    header[10] = 'V';
    header[11] = 'E';
    header[12] = 'f';  // 'fmt ' chunk
    header[13] = 'm';
    header[14] = 't';
    header[15] = ' ';
    header[16] = 16;  // 4 bytes: size of 'fmt ' chunk
    header[17] = 0;
    header[18] = 0;
    header[19] = 0;
    header[20] = (Byte) fileProperties.compressionType;  // format = 1
    header[21] = 0;
    header[22] = (Byte) fileProperties.numOfChannels;
    header[23] = 0;
    header[24] = (Byte) (fileProperties.sampleRate & 0xff);
    header[25] = (Byte) ((fileProperties.sampleRate >> 8) & 0xff);
    header[26] = (Byte) ((fileProperties.sampleRate >> 16) & 0xff);
    header[27] = (Byte) ((fileProperties.sampleRate >> 24) & 0xff);
    header[28] = (Byte) (byteRate & 0xff);
    header[29] = (Byte) ((byteRate >> 8) & 0xff);
    header[30] = (Byte) ((byteRate >> 16) & 0xff);
    header[31] = (Byte) ((byteRate >> 24) & 0xff);
    header[32] = (Byte) (fileProperties.numOfChannels * 4);  // block align
    header[33] = 0;
    header[34] = 32;  // bits per sample (32 for float)
    header[35] = 0;
    header[36] = 'd';
    header[37] = 'a';
    header[38] = 't';
    header[39] = 'a';
    header[40] = (Byte) (totalAudioLen & 0xff);
    header[41] = (Byte) ((totalAudioLen >> 8) & 0xff);
    header[42] = (Byte) ((totalAudioLen >> 16) & 0xff);
    header[43] = (Byte) ((totalAudioLen >> 24) & 0xff);
    
    
    NSData *headerData = [NSData dataWithBytes:header length:44];
    
    //delete file if exist on path
    NSFileManager * fm = [NSFileManager defaultManager];
    [fm removeItemAtPath:[self.fileURL path] error:nil];

    if([[NSFileManager defaultManager] createFileAtPath:[self.fileURL path] contents:headerData attributes:nil])
    {
        NSLog(@"Created file at :%@",[self.fileURL path]);
    }
    else
    {
        NSLog(@"Error creating file at :%@",[self.fileURL path]);
    }

    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath: [self.fileURL path]];
   // NSFileHandle *myHandle = [NSFileHandle fileHandleForUpdatingAtPath:appFile];
    if (self.fileHandle == nil)
    {
        NSLog(@"Failed to open file");
    }
    
    
    [self.fileHandle closeFile];
    self.fileHandle = nil;

    
    //free(header);
}


-(void) appendData:(float *) dataBuffer numberOfFrames:(int) numberOfFrames
{

    unsigned int numberOfBytes = numberOfFrames*fileProperties.numOfChannels*4;
    
    NSData *data = [NSData dataWithBytes:dataBuffer length:numberOfBytes];
    NSFileHandle * _fileHandle = [NSFileHandle fileHandleForWritingAtPath: _pathToFile];
    if (_fileHandle == nil)
    {
        NSLog(@"Failed to open file");
    }
    [_fileHandle seekToEndOfFile];
    totalAudioLen +=numberOfBytes;
    [_fileHandle writeData:data ];
    [_fileHandle closeFile];

}


-(void) finishFile
{
    totalDataLen = totalAudioLen + 44;
    NSFileHandle * _fileHandle = [NSFileHandle fileHandleForWritingAtPath: _pathToFile];
    if (_fileHandle == nil)
    {
        NSLog(@"Failed to open file");
    }
    //Update file length
    Byte *headerUpdate = (Byte*)calloc(4, sizeof(Byte));
    headerUpdate[0] = (Byte) (totalDataLen & 0xff);
    headerUpdate[1] = (Byte) ((totalDataLen >> 8) & 0xff);
    headerUpdate[2] = (Byte) ((totalDataLen >> 16) & 0xff);
    headerUpdate[3] = (Byte) ((totalDataLen >> 24) & 0xff);
    
    NSData *data = [NSData dataWithBytes:headerUpdate length:4];
    [_fileHandle seekToFileOffset: 4];
    [_fileHandle writeData: data];
    
    //Update audio length
    headerUpdate[0] = (Byte) (totalAudioLen & 0xff);
    headerUpdate[1] = (Byte) ((totalAudioLen >> 8) & 0xff);
    headerUpdate[2] = (Byte) ((totalAudioLen >> 16) & 0xff);
    headerUpdate[3] = (Byte) ((totalAudioLen >> 24) & 0xff);
    [_fileHandle seekToFileOffset: 40];
    [_fileHandle writeData: data];
    
    [_fileHandle closeFile];
    free(headerUpdate);
}


-(WavProperties) openWav:(NSURL *)urlToFile
{
    _pathToFile = [urlToFile path];
    struct WavProperties newFileProperties;
    newFileProperties.numOfChannels = 0;
    newFileProperties.sampleRate = 0;
    newFileProperties.compressionType = 0;
    
    NSFileHandle * _fileHandle = [NSFileHandle fileHandleForReadingAtPath:_pathToFile];
    if (_fileHandle == nil)
    {
        NSLog(@"Failed to open the wav file");
        return newFileProperties;
    }

    NSData *headerData =[_fileHandle readDataOfLength:44];
    
    Byte * allBytes = (Byte *)[headerData bytes];
    long tempHeaderParameter;
    long tempNumber;
    
    //compression type
    tempHeaderParameter = allBytes[21];
    tempHeaderParameter = tempHeaderParameter<<8;
    tempHeaderParameter = tempHeaderParameter | allBytes[20];

    newFileProperties.compressionType = tempHeaderParameter;
    
    //Number of channels
    tempHeaderParameter = allBytes[23];
    tempHeaderParameter = (tempHeaderParameter<<8) | allBytes[22];
    newFileProperties.numOfChannels = tempHeaderParameter;
    
    //Sampling rate
    tempHeaderParameter = 0;
    tempNumber = allBytes[27];
    tempHeaderParameter = tempHeaderParameter | (tempNumber<<24);
    tempNumber = allBytes[26];
    tempHeaderParameter = tempHeaderParameter | (tempNumber<<16);
    tempNumber = allBytes[25];
    tempHeaderParameter = tempHeaderParameter | (tempNumber<<8);
    tempNumber = allBytes[24];
    tempHeaderParameter = tempHeaderParameter | tempNumber;
    
    newFileProperties.sampleRate = tempHeaderParameter;
    
    
    //Total audio length
    tempHeaderParameter = 0;
    tempNumber = allBytes[43];
    tempHeaderParameter = tempHeaderParameter | (tempNumber<<24);
    tempNumber = allBytes[42];
    tempHeaderParameter = tempHeaderParameter | (tempNumber<<16);
    tempNumber = allBytes[41];
    tempHeaderParameter = tempHeaderParameter | (tempNumber<<8);
    tempNumber = allBytes[40];
    tempHeaderParameter = tempHeaderParameter | tempNumber;
    
    totalAudioLen = tempHeaderParameter;
    
    
    fileProperties = newFileProperties;
    
    currentPositionDuringRead = 44;
    
    return fileProperties;
}


- (UInt32)retrieveFreshAudio:(float *)buffer numFrames:(UInt32)thisNumFrames numChannels:(UInt32)thisNumChannels
{
    
    NSFileHandle * _fileHandle = [NSFileHandle fileHandleForReadingAtPath: _pathToFile];
    
    if (_fileHandle == nil)
    {
        NSLog(@"Failed to open the wav file");
        return 0;
    }
    UInt32 numberOfBytesToRead = thisNumChannels*thisNumFrames*4;
    [_fileHandle seekToFileOffset: currentPositionDuringRead];
    NSData *headerData =[_fileHandle readDataOfLength:numberOfBytesToRead];
    UInt32 numberOfBytes = [headerData length];
    memcpy(buffer, [headerData bytes], numberOfBytes);
    currentPositionDuringRead +=numberOfBytes;
    return numberOfBytes/(fileProperties.numOfChannels*4);
}


- (UInt32)retrieveFreshAudio:(float *)buffer numFrames:(UInt32)thisNumFrames numChannels:(UInt32)thisNumChannels seek:(UInt32) position
{
    NSFileHandle * _fileHandle = [NSFileHandle fileHandleForReadingAtPath: _pathToFile];
    
    if (_fileHandle == nil)
    {
        NSLog(@"Failed to open the wav file");
        return 0;
    }
    UInt32 numberOfBytesToRead = thisNumChannels*thisNumFrames*4;
    UInt32 positionToSeek = thisNumChannels*position*4+44;
    
    [_fileHandle seekToFileOffset: positionToSeek];
    NSData *headerData =[_fileHandle readDataOfLength:numberOfBytesToRead];
    memcpy(buffer, [headerData bytes], [headerData length]);
    return [headerData length]/(fileProperties.numOfChannels*4);
}



-(float) getDuration
{
    if(fileProperties.compressionType == 3)//if float type than we have 4 bytes per sample
    {
        return ((float)totalAudioLen)/((float)(fileProperties.numOfChannels * fileProperties.sampleRate * 4));
    }
    else
    {
        return ((float)totalAudioLen)/((float)(fileProperties.numOfChannels * fileProperties.sampleRate * 2));
    }
}

-(float) getCurrentTime
{
    return ((float)(currentPositionDuringRead-44))/((float)(4*fileProperties.numOfChannels*fileProperties.sampleRate));
}

-(void) setCurrentTime:(float) newTime
{
    UInt32 numberOfBytes = newTime*fileProperties.numOfChannels * fileProperties.sampleRate * 4;
    numberOfBytes = numberOfBytes - (numberOfBytes%(fileProperties.numOfChannels*4));//position it on begining of frame
    currentPositionDuringRead = 44 + numberOfBytes;
}

@end
