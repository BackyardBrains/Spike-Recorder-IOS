//
//  ISIHistogramViewController.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 4/22/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "ISIHistogramViewController.h"

@interface ISIHistogramViewController ()
{
    CPTXYGraph *barChart;
}

@end

@implementation ISIHistogramViewController

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
        return [_limits objectAtIndex:index];//0.1f*(((float)index)/101.0f)];//[NSNumber numberWithFloat:0.1f*(((float)index)/101.0f)];
    }
    else
    {
        //y axis data
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
    
    barChart.title = @"Inter-Spike-Interval";
    
    CPTMutableTextStyle *textStyle = [CPTTextStyle textStyle];
    textStyle.color = [CPTColor grayColor];
    textStyle.fontSize = 16.0f;
    textStyle.textAlignment = CPTTextAlignmentCenter;
    barChart.titleTextStyle = textStyle;  // Error found here
    barChart.titleDisplacement = CGPointMake(0.0f, -10.0f);
    barChart.titlePlotAreaFrameAnchor = CPTRectAnchorTop;
    
    CPTXYAxisSet *axisSet = (CPTXYAxisSet *)barChart.axisSet;
    CPTXYAxis *x = axisSet.xAxis;
    NSNumberFormatter *ns = [[NSNumberFormatter alloc] init];
    [ns setNumberStyle: NSNumberFormatterScientificStyle];
    x.labelFormatter = ns;
    [ns release];
    x.labelingPolicy = CPTAxisLabelingPolicyAutomatic;
    //x.axisLineStyle = nil;
    //x.majorTickLineStyle = nil;
    //x.minorTickLineStyle = nil;
    //x.majorIntervalLength = CPTDecimalFromString(@"0.1");
    //x.orthogonalCoordinateDecimal = CPTDecimalFromString(@"0");
    // x.title = @"Names";
    // x.titleLocation = CPTDecimalFromFloat(7.5f);
    // x.titleOffset = 25.0f;
    
    // Define some custom labels for the data elements
   // x.labelRotation = M_PI/5;
   /* NSSet *majorTickLocations = [NSSet setWithObjects:[NSNumber numberWithDouble:0.001],
                                 [NSNumber numberWithDouble:0.01],
                                 [NSNumber numberWithDouble:0.1],
                                 [NSNumber numberWithDouble:1],
                                 [NSNumber numberWithDouble:10],
                                 nil];
    x.labelingPolicy = CPTAxisLabelingPolicyNone;
   // x.majorTickLocations = majorTickLocations;
    
    
    NSArray *xAxisLabels = [NSArray arrayWithObjects:@"1E-3", @"1E-2", @"1E-1", @"1E0", @"1E1",nil];
    NSUInteger labelLocation = 0;
    
    NSMutableArray *customLabels = [NSMutableArray arrayWithCapacity:[xAxisLabels count]];
    for (NSNumber *tickLocation in majorTickLocations)
    {
        CPTAxisLabel *newLabel = [[CPTAxisLabel alloc] initWithText: [xAxisLabels objectAtIndex:labelLocation++] textStyle:x.labelTextStyle];
        newLabel.tickLocation = [tickLocation decimalValue];
        newLabel.offset = x.labelOffset + x.majorTickLength;
        newLabel.rotation = M_PI/4;
        [customLabels addObject:newLabel];
        [newLabel release];
    }
    
    x.axisLabels =  [NSSet setWithArray:customLabels];*/
    
    CPTXYAxis *y = axisSet.yAxis;
    y.labelingPolicy = CPTAxisLabelingPolicyAutomatic;
   // y.axisLineStyle = nil;
   // y.majorTickLineStyle = nil;
   // y.minorTickLineStyle = nil;
   // y.majorIntervalLength = CPTDecimalFromString(@"1000");
   // y.orthogonalCoordinateDecimal = CPTDecimalFromString(@"0");
    //y.title = @"Work Status";
    //y.titleOffset = 40.0f;
    //y.titleLocation = CPTDecimalFromFloat(150.0f);
    
   
   
    self.hostingView.hostedGraph = barChart;
   


    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)barChart.defaultPlotSpace;
    plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(0.00001) length:CPTDecimalFromDouble(10.0)];

    plotSpace.xScaleType = CPTScaleTypeLog;
    plotSpace.yScaleType = CPTScaleTypeLinear;
    
    CPTBarPlot *barPlot = [[[CPTBarPlot alloc] init] autorelease];
    barPlot.fill = [CPTFill fillWithColor:[CPTColor blueColor]];
    barPlot.lineStyle = nil;
   // barPlot.plotRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(0.001) length:CPTDecimalFromDouble(10.0)];//xAxisLength
   // barPlot.barOffset = CPTDecimalFromFloat(10.0f);
    //barPlot.baseValue = CPTDecimalFromString(@"0");
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

//X limits of histogram
-(void) setLimits:(NSArray *)limits
{
    _limits = [limits retain];
}

//X limits of histogram
-(NSArray *) limits
{
    return _limits;
}

- (void)dealloc {
    [super dealloc];
}
@end
