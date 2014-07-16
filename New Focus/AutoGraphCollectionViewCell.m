//
//  AutoGraphCollectionViewCell.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 7/8/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "AutoGraphCollectionViewCell.h"


@interface AutoGraphCollectionViewCell ()
{
    NSMutableArray * _values;

    CPTXYGraph *barChart;
    CPTGraphHostingView *_hostingView;
    
    UILabel * labelForTitle;
}
@end

@implementation AutoGraphCollectionViewCell

@synthesize titleOfGraph = _titleOfGraph;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self.layer setBorderWidth:1.0f];
        [self.layer setBorderColor:[UIColor darkGrayColor].CGColor];
        _titleOfGraph = @"";
        
    }
    return self;
}

-(void) setValues:(NSMutableArray *) values
{
    _values = values;
    [self drawGraph];
    
}

#pragma mark - Label title

-(void) setTitleOfGraph:(NSString *)intitleOfGraph
{
    _titleOfGraph = intitleOfGraph;
    if(labelForTitle)
    {
        [labelForTitle removeFromSuperview];
        [labelForTitle release];
        labelForTitle = nil;
    }
    
    labelForTitle = [[UILabel alloc] initWithFrame:CGRectMake(self.frame.size.width-30, 2, 28, 12)];
    labelForTitle.backgroundColor = [UIColor whiteColor];
    labelForTitle.text = intitleOfGraph;
    labelForTitle.textAlignment = NSTextAlignmentCenter;
    labelForTitle.font = [UIFont fontWithName:@"Georgia" size:(11)];
    [self addSubview:labelForTitle];
    
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
        return [NSNumber numberWithFloat:0.1f*(((float)index)/101.0f)];
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

#pragma mark - graph creation

-(void) clearGraph:(NSNotification *)notification
{
    if(_hostingView)
    {
        [_hostingView removeFromSuperview];
        [_hostingView release];
        _hostingView = nil;
    }
    
    if(barChart)
    {
        [barChart release];
        barChart = nil;
    }
    
}


- (void)drawGraph
{
    
    [self clearGraph:nil];
    CGRect frameOfView = CGRectMake(self.bounds.origin.x, self.bounds.origin.y, self.bounds.size.width, self.bounds.size.height);
    barChart = [[CPTXYGraph alloc] initWithFrame:frameOfView];
    
    _hostingView = [[CPTGraphHostingView alloc] initWithFrame:frameOfView];
    _hostingView.userInteractionEnabled = NO;
    
    barChart.plotAreaFrame.borderLineStyle = nil;
    barChart.plotAreaFrame.cornerRadius = 0.0f;
    
    barChart.paddingLeft = 0.0f;
    barChart.paddingRight = 0.0f;
    barChart.paddingTop = 0.0f;
    barChart.paddingBottom = 0.0f;
    

    barChart.plotAreaFrame.paddingLeft = 0.0;
    barChart.plotAreaFrame.paddingTop = 0.0;
    barChart.plotAreaFrame.paddingRight = 0.0;
    barChart.plotAreaFrame.paddingBottom = 0.0;
    
    barChart.title = @"";
    
    CPTMutableTextStyle *textStyle = [CPTTextStyle textStyle];
    textStyle.color = [CPTColor grayColor];
    textStyle.fontSize = 16.0f;
    textStyle.textAlignment = CPTTextAlignmentCenter;
    barChart.titleTextStyle = textStyle;
    barChart.titleDisplacement = CGPointMake(0.0f, 0.0f);
    barChart.titlePlotAreaFrameAnchor = CPTRectAnchorTop;
    
    CPTXYAxisSet *axisSet = (CPTXYAxisSet *)barChart.axisSet;
    CPTXYAxis *x = axisSet.xAxis;
    x.axisLineStyle = nil;
    x.majorTickLineStyle = nil;
    x.minorTickLineStyle = nil;
    x.majorIntervalLength = CPTDecimalFromString(@"10");
    x.orthogonalCoordinateDecimal = CPTDecimalFromString(@"0");
    
    
    // Define some custom labels for the data elements
    x.labelRotation = M_PI/5;
    x.labelingPolicy = CPTAxisLabelingPolicyNone;
    
    NSArray *customTickLocations = [NSArray arrayWithObjects:[NSDecimalNumber numberWithInt:0], [NSDecimalNumber numberWithInt:20], [NSDecimalNumber numberWithInt:40], [NSDecimalNumber numberWithInt:60], [NSDecimalNumber numberWithInt:80],[NSDecimalNumber numberWithInt:100], nil];
    
    NSArray *xAxisLabels = [NSArray arrayWithObjects:@"0", @"0.02", @"0.04", @"0.06", @"0.08", @"0.1", nil];
    NSUInteger labelLocation = 0;
    //make custom labels
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
    //set custom labels on x axis
    x.axisLabels =  [NSSet setWithArray:customLabels];
    
    
    CPTXYAxis *y = axisSet.yAxis;
    y.labelingPolicy = CPTAxisLabelingPolicyAutomatic;
    
    _hostingView.hostedGraph = barChart;
    [self addSubview:_hostingView];
    
    CPTBarPlot *barPlot = [[[CPTBarPlot alloc] init] autorelease];
    barPlot.fill = [CPTFill fillWithColor:[CPTColor blueColor]];
    barPlot.lineStyle = nil;
    barPlot.plotRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(0.0) length:CPTDecimalFromDouble(101.0)];//xAxisLength
    barPlot.barOffset = CPTDecimalFromFloat(1.0f);
    barPlot.baseValue = CPTDecimalFromString(@"0");
    
    float widthOfBar = self.frame.size.width/[_values count];   
    barPlot.barWidth = CPTDecimalFromFloat(widthOfBar);
    
    
    barPlot.cornerRadius = 0.0f;
    barPlot.barWidthsAreInViewCoordinates = YES; //bar width are defined in pixels of screen
    
    barPlot.dataSource = self;
    [barChart addPlot:barPlot];
    [barChart.defaultPlotSpace scaleToFitPlots:[barChart allPlots]];
    [labelForTitle removeFromSuperview];
    [self addSubview:labelForTitle];
}
@end
