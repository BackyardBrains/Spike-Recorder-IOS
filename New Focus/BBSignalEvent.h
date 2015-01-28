//
//  BBSignalEvent.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 6/14/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SQLitePersistentObject.h"
@interface BBSignalEvent : NSObject <NSCoding>

@property int eventType;
@property int index;
@property float time;
-(id) initWithType:(int) inType index:(int) inIndex andTime:(float) inTime;

@end
