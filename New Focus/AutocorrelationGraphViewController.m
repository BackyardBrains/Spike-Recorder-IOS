//
//  AutocorrelationGraphViewController.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 4/21/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "AutocorrelationGraphViewController.h"

@interface AutocorrelationGraphViewController ()
{
    CPTXYGraph *barChart;
}

@end

@implementation AutocorrelationGraphViewController

@synthesize hostingView;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
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
        //x axis data
        return [NSNumber numberWithFloat:0.1f*(((float)index)/101.0f)];//[NSNumber numberWithDouble:index];
    }
    else
    {
        //y axis data
        if(index==0)
        {
            return [NSNumber numberWithDouble:0.0];
        }
        return [_values objectAtIndex:index];
    }
}

#pragma mark - view creation


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    CGRect frameOfView = CGRectMake(self.view.bounds.origin.x, self.view.bounds.origin.y, self.view.bounds.size.width, self.view.bounds.size.height);
    barChart = [[CPTXYGraph alloc] initWithFrame:frameOfView];
    
    barChart.plotAreaFrame.borderLineStyle = nil;
    barChart.plotAreaFrame.cornerRadius = 0.0f;
    
    barChart.paddingLeft = 0.0f;
    barChart.paddingRight = 0.0f;
    barChart.paddingTop = 40.0f;
    barChart.paddingBottom = 0.0f;
    
    barChart.plotAreaFrame.paddingLeft = 60.0;
    barChart.plotAreaFrame.paddingTop = 40.0;
    barChart.plotAreaFrame.paddingRight = 20.0;
    barChart.plotAreaFrame.paddingBottom = 40.0;
    
    barChart.title = @"Autocorrelation";
    
    CPTMutableTextStyle *textStyle = [CPTTextStyle textStyle];
    textStyle.color = [CPTColor grayColor];
    textStyle.fontSize = 16.0f;
    textStyle.textAlignment = CPTTextAlignmentCenter;
    barChart.titleTextStyle = textStyle;  // Error found here
    barChart.titleDisplacement = CGPointMake(0.0f, -10.0f);
    barChart.titlePlotAreaFrameAnchor = CPTRectAnchorTop;
    
    CPTXYAxisSet *axisSet = (CPTXYAxisSet *)barChart.axisSet;
    CPTXYAxis *x = axisSet.xAxis;
    x.axisLineStyle = nil;
    x.majorTickLineStyle = nil;
    x.minorTickLineStyle = nil;
    x.majorIntervalLength = CPTDecimalFromString(@"10");
    x.orthogonalCoordinateDecimal = CPTDecimalFromString(@"0");
   // x.title = @"Names";
   // x.titleLocation = CPTDecimalFromFloat(7.5f);
   // x.titleOffset = 25.0f;
    
    // Define some custom labels for the data elements
    x.labelRotation = M_PI/5;
    x.labelingPolicy = CPTAxisLabelingPolicyNone;
    
    NSArray *customTickLocations = [NSArray arrayWithObjects:[NSDecimalNumber numberWithInt:0], [NSDecimalNumber numberWithInt:20], [NSDecimalNumber numberWithInt:40], [NSDecimalNumber numberWithInt:60], [NSDecimalNumber numberWithInt:80],[NSDecimalNumber numberWithInt:100], nil];
    
    
    NSArray *xAxisLabels = [NSArray arrayWithObjects:@"0", @"0.02", @"0.04", @"0.06", @"0.08", @"0.1", nil];
    NSUInteger labelLocation = 0;
    
    NSMutableArray *customLabels = [NSMutableArray arrayWithCapacity:[xAxisLabels count]];
    for (NSNumber *tickLocation in customTickLocations)
    {
        CPTAxisLabel *newLabel = [[CPTAxisLabel alloc] initWithText: [xAxisLabels objectAtIndex:labelLocation++] textStyle:x.labelTextStyle];
        newLabel.tickLocation = [tickLocation decimalValue];
        newLabel.offset = x.labelOffset + x.majorTickLength;
        newLabel.rotation = M_PI/4;
        [customLabels addObject:newLabel];
        [newLabel release];
    }
    
    x.axisLabels =  [NSSet setWithArray:customLabels];
    
    CPTXYAxis *y = axisSet.yAxis;
    y.labelingPolicy = CPTAxisLabelingPolicyAutomatic;
//    y.axisLineStyle = nil;
//    y.majorTickLineStyle = nil;
//    y.minorTickLineStyle = nil;
//    y.majorIntervalLength = CPTDecimalFromString(@"1000");
//    y.orthogonalCoordinateDecimal = CPTDecimalFromString(@"0");
    //y.title = @"Work Status";
    //y.titleOffset = 40.0f;
    //y.titleLocation = CPTDecimalFromFloat(150.0f);
    
    //self.hostingView = [[CPTGraphHostingView alloc] initWithFrame:frameOfView];
    //self.hostingView.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth);
    self.hostingView.hostedGraph = barChart;
    //[self.view addSubview:selfhostingView];
    
    //CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *) barChart.defaultPlotSpace;
    //plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(0.0) length:CPTDecimalFromDouble(101.0)];
    //plotSpace.yRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(0.0f) length:CPTDecimalFromDouble(5000.0f)];
    
    CPTBarPlot *barPlot = [[[CPTBarPlot alloc] init] autorelease];
    barPlot.fill = [CPTFill fillWithColor:[CPTColor blueColor]];
    barPlot.lineStyle = nil;
    barPlot.plotRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(0.0) length:CPTDecimalFromDouble(101.0)];//xAxisLength
    barPlot.barOffset = CPTDecimalFromFloat(1.0f);
    barPlot.baseValue = CPTDecimalFromString(@"0");

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        barPlot.barWidth = CPTDecimalFromFloat(10.0f);
    }
    else
    {
        barPlot.barWidth = CPTDecimalFromFloat(4.0f);
    }
    
    barPlot.cornerRadius = 0.0f;
    barPlot.barWidthsAreInViewCoordinates = YES;

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
