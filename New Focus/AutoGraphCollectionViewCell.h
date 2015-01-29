//
//  AutoGraphCollectionViewCell.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 7/8/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CorePlot-CocoaTouch.h"

@interface AutoGraphCollectionViewCell : UICollectionViewCell <CPTPlotDataSource>

-(void) setValues:(NSMutableArray *) values;

@property (nonatomic, retain) NSString * titleOfGraph;
-(void) colorOfTheGraph:(UIColor *) theColor;

@end
