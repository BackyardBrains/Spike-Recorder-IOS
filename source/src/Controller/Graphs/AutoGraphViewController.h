//
//  AutoGraphViewController.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 7/8/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CorePlot-CocoaTouch.h"
#import "BBFile.h"

@interface AutoGraphViewController : UIViewController <UICollectionViewDataSource, UICollectionViewDelegate, CPTPlotDataSource>
@property (retain, nonatomic) IBOutlet UICollectionView *collectionViewR;

@property (retain, nonatomic) IBOutlet UICollectionView *collectionView;
@property (retain, nonatomic) IBOutlet CPTGraphHostingView *hostView;


-(void) setFileForGraph:(BBFile *) file;
-(void) colorOfTheGraph:(UIColor *) theColor;

@end
