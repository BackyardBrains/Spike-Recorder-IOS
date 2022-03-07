//
//  Section.m
//  Spike Recorder
//
//  Created by Stanislav on 10/16/19.
//  Copyright © 2019 BackyardBrains. All rights reserved.
//

/*
 Model class used to represent a list of products/purchases.
 */


#import "Section.h"

@implementation Section

-(instancetype)init {
    return [self initWithName:nil elements:@[]];
}

-(instancetype)initWithName:(NSString *)name elements:(NSArray *)elements {
    self = [super init];
    
    if(self != nil) {
        _name = [name copy];
        _elements = elements;
    }
    return self;
}
@end
