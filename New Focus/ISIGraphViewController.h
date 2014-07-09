//
//  ISIGraphViewController.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 7/7/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CorePlot-CocoaTouch.h"
#import "BBFile.h"

@interface ISIGraphViewController : UIViewController <UICollectionViewDataSource, UICollectionViewDelegate, CPTPlotDataSource>

@property (retain, nonatomic) IBOutlet CPTGraphHostingView *hostView;
@property (retain, nonatomic) IBOutlet UICollectionView *collectionView;
@property (retain, nonatomic) IBOutlet UICollectionView *collectionViewR;

-(void) setFileForGraph:(BBFile *) file;

@end
