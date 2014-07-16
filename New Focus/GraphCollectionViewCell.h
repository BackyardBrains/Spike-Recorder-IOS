//
//  GraphCollectionViewCell.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 7/4/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BBFile.h"
#import "CorePlot-CocoaTouch.h"

@interface GraphCollectionViewCell : UICollectionViewCell <CPTPlotDataSource>


-(void) setFile:(BBFile *) file andFirstIndex:(int) firstIndex andSecondIndex:(int) secondIndex;

@end
