//
//  Log.h
//  Spike Recorder
//
//  Created by Stanislav Mircic on 7/23/15.
//  Copyright (c) 2015 Datta Lab, Harvard University. All rights reserved.
//


// file Log.h
#define NSLog(args...) _Log(@"DEBUG ", __FILE__,__LINE__,__PRETTY_FUNCTION__,args);

@interface Log : NSObject
void _Log(NSString *prefix, const char *file, int lineNumber, const char *funcName, NSString *format,...);
@end