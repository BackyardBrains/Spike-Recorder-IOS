//
//  Section.h
//  Spike Recorder
//
//  Created by Stanislav on 10/16/19.
//  Copyright © 2019 BackyardBrains. All rights reserved.
//

#import <Foundation/Foundation.h>

/*
 Model class used to represent a list of products/purchases.
 */


@interface Section : NSObject
/// Products/Purchases are organized by category.
@property (nonatomic, copy) NSString *name;

/// List of products/purchases.
@property (strong) NSArray *elements;

/// Create a Section object.
-(instancetype)initWithName:(NSString *)name elements:(NSArray *)elements NS_DESIGNATED_INITIALIZER;
@end
