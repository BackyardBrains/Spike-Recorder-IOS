//
//  CrossCorrViewController.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 4/28/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CorePlot-CocoaTouch.h"

@interface CrossCorrViewController : UIViewController <CPTPlotDataSource>
{
    NSArray * _values;
}

@property (retain) NSArray * values;

@property (retain, nonatomic) IBOutlet CPTGraphHostingView *hostingView;

@end
