//
//  CrossCorrViewController.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 4/28/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "CrossCorrViewController.h"

@interface CrossCorrViewController ()
{
    CPTXYGraph *barChart;
    UIColor* graphColor;
}
@end

@implementation CrossCorrViewController

@synthesize hostingView;
@synthesize graphTitle;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    //self.view.backgroundColor = [UIColor blackColor];
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        graphTitle = @"Cross-correlation";
    }
    return self;
}

#pragma mark - CorePlot data protocol

-(NSUInteger)numberOfRecordsForPlot:(CPTPlot *)plot
{
    return [_values count];
}


-(NSNumber *)numberForPlot:(CPTPlot *)plot
                     field:(NSUInteger)fieldEnum
               recordIndex:(NSUInteger)index
{
    if(fieldEnum == CPTScatterPlotFieldX)
    {
        //x axis data (-0.1, +0.1)
        return [NSNumber numberWithFloat:-0.1+0.2f*(((float)index)/[_values count])];    }
    else
    {
        
        return [_values objectAtIndex:index];
    }
}

-(void) colorOfTheGraph:(UIColor *) theColor
{
    graphColor = [theColor copy];

}

#pragma mark - view creation

- (void)viewWillAppear:(BOOL)animated
{
    [self.navigationController.navigationBar setBarTintColor:[UIColor blackColor]];
    self.navigationController.navigationBar.translucent = NO;
    [self.navigationController.navigationBar setTintColor:[UIColor whiteColor]];
    [super viewWillAppear:animated];

}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    NSLog(@"Stopping regular view");
    [self.navigationController.navigationBar setBarTintColor:nil];
    self.navigationController.navigationBar.translucent = YES;
    [self.navigationController.navigationBar setTintColor:nil];
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    CGRect frameOfView = CGRectMake(self.hostingView.bounds.origin.x, self.hostingView.bounds.origin.y, self.hostingView.bounds.size.width, self.hostingView.bounds.size.height);

    
    
    barChart = [[CPTXYGraph alloc] initWithFrame:frameOfView];
    
    
    
    
    barChart.backgroundColor = [UIColor blackColor].CGColor;
    barChart.plotAreaFrame.borderLineStyle = nil;
    barChart.plotAreaFrame.cornerRadius = 0.0f;
    
    barChart.paddingLeft = 0.0f;
    barChart.paddingRight = 0.0f;
    barChart.paddingTop = 20.0f;
    barChart.paddingBottom = 0.0f;
    
    barChart.plotAreaFrame.paddingLeft = 20.0;
    barChart.plotAreaFrame.paddingTop = 20.0;
    barChart.plotAreaFrame.paddingRight = 20.0;
    barChart.plotAreaFrame.paddingBottom = 20.0;
    
    barChart.title = graphTitle;
    
    CPTMutableTextStyle *textStyle = [CPTTextStyle textStyle];
    textStyle.color = [CPTColor whiteColor];
    textStyle.fontSize = 16.0f;
    textStyle.textAlignment = CPTTextAlignmentCenter;
    barChart.titleTextStyle = textStyle;  // Error found here
    barChart.titleDisplacement = CGPointMake(0.0f, 20.0f);
    barChart.titlePlotAreaFrameAnchor = CPTRectAnchorTop;
    
    CPTXYAxisSet *axisSet = (CPTXYAxisSet *)barChart.axisSet;

    //set text style to white for axis
    CPTMutableTextStyle *labelTextStyle = [CPTMutableTextStyle textStyle];
    labelTextStyle.color = [CPTColor whiteColor];
    
    //set stile for line for axis
    CPTMutableLineStyle *axisLineStyle = [CPTMutableLineStyle lineStyle];
    [axisLineStyle setLineWidth:1];
    [axisLineStyle setLineColor:[CPTColor colorWithCGColor:[[UIColor whiteColor] CGColor]]];
    
    
    CPTXYAxis *x = axisSet.xAxis;
    x.labelingPolicy = CPTAxisLabelingPolicyAutomatic;
    x.labelTextStyle = labelTextStyle;
    [x setAxisLineStyle:axisLineStyle];
    [x setMajorTickLineStyle:axisLineStyle];
    
    //make x axis with two decimal places
    NSNumberFormatter *Xformatter = [[NSNumberFormatter alloc] init];
    [Xformatter setGeneratesDecimalNumbers:YES];
    [Xformatter setMinimumFractionDigits:2];
    [Xformatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [Xformatter setDecimalSeparator:@"."];
    x.labelFormatter = Xformatter;
    [Xformatter release];
    x.labelingPolicy = CPTAxisLabelingPolicyAutomatic;
    
    
    x.title = @"Time (s)";
    x.titleOffset = 26.0f;
    x.titleLocation = CPTDecimalFromFloat(0.0f);
    
    
    CPTXYAxis *y = axisSet.yAxis;
    y.labelingPolicy = CPTAxisLabelingPolicyAutomatic;
    y.labelTextStyle = labelTextStyle;
    
    [y setAxisLineStyle:axisLineStyle];
    [y setMajorTickLineStyle:axisLineStyle];
    
    //put y axis at the left side of graph
    y.orthogonalCoordinateDecimal = CPTDecimalFromDouble(-0.1);
    self.hostingView.hostedGraph = barChart;
       
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)barChart.defaultPlotSpace;
    plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(-0.1) length:CPTDecimalFromDouble(0.1)];
    
    CPTBarPlot *barPlot = [[[CPTBarPlot alloc] init] autorelease];
    barPlot.fill = [CPTFill fillWithColor:[CPTColor colorWithCGColor:graphColor.CGColor]];
    barPlot.lineStyle = nil;
    //make bars width greater if it is iPad
    float widthOfBar = 1.8*hostingView.frame.size.width/[_values count];
    barPlot.barWidth = CPTDecimalFromFloat(widthOfBar);
    barPlot.backgroundColor = [UIColor blackColor].CGColor;
    barPlot.cornerRadius = 0.0f;
    barPlot.barWidthsAreInViewCoordinates = YES; //bar width are defined in pixels of screen
    barPlot.dataSource = self;
    [barChart addPlot:barPlot];
    [barChart.defaultPlotSpace scaleToFitPlots:[barChart allPlots]];
}



- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

//Values of histogram
-(void) setValues:(NSArray *)values
{
    _values = [values retain];
}

//Values of histogram
-(NSArray *) values
{
    return _values;
}

- (void)dealloc {
    [super dealloc];
}
@end
