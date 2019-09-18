//
//  BBEvent.h
//  Spike Recorder
//
//  Created by Stanislav on 6/20/19.
//  Copyright © 2019 BackyardBrains. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "SQLitePersistentObject.h"
@interface BBEvent : NSObject <NSCoding>

@property int value;
@property long long index;
@property float time;
-(id) initWithValue:(int) inValue index:(int) inIndex andTime:(float) inTime;
@end
