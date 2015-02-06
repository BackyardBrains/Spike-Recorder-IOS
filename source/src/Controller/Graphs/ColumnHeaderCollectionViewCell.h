//
//  ColumnHeaderCollectionViewCell.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 7/15/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ColumnHeaderCollectionViewCell : UICollectionViewCell
@property (nonatomic, retain) NSString * titleOfColumn;
-(void) setNumberForTitleOfColumn:(int) numOfColumn;
@end
