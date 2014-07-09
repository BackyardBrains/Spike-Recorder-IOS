//
//  ISIGraphCollectionViewCell.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 7/7/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CorePlot-CocoaTouch.h"

@interface ISIGraphCollectionViewCell : UICollectionViewCell <CPTPlotDataSource>

-(void) setValues:(NSMutableArray *) values andLimits:(NSMutableArray *) limits;
@end
