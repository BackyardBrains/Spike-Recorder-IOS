//
//  ISIHistogramViewController.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 4/22/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CorePlot-CocoaTouch.h"

@interface ISIHistogramViewController : UIViewController <CPTPlotDataSource>
{
    NSArray * _values; //y axis data
    NSArray * _limits; //x axis data
}

@property (retain) NSArray * values;
@property (retain) NSArray * limits;
@property (retain, nonatomic) IBOutlet CPTGraphHostingView *hostingView;

@end
