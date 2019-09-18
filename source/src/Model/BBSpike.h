//
//  BBSpike.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 4/11/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SQLitePersistentObject.h"
@interface BBSpike : NSObject <NSCoding>

@property float value;
@property long long index;
@property float time;
-(id) initWithValue:(float) inValue index:(int) inIndex andTime:(float) inTime;
@end
