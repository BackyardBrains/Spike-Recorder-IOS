//
//  ISIGraphCollectionViewCell.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 7/7/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "ISIGraphCollectionViewCell.h"


@interface ISIGraphCollectionViewCell ()
{
    NSMutableArray * _values;
    NSMutableArray * _limits;
    
    CPTXYGraph *barChart;
    CPTGraphHostingView *_hostingView;
    
    UILabel * labelForTitle;
    UIColor* graphColor;
}
@end

@implementation ISIGraphCollectionViewCell

@synthesize titleOfGraph = _titleOfGraph;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self.layer setBorderWidth:1.0f];
        [self.layer setBorderColor:[UIColor darkGrayColor].CGColor];
        self.backgroundColor = [UIColor blackColor];
    }
    return self;
}


-(void) setValues:(NSMutableArray *) values andLimits:(NSMutableArray *) limits
{
    _values = values;
    _limits = limits;
    [self drawGraph];

}

-(void) colorOfTheGraph:(UIColor *) theColor
{
    graphColor = [theColor copy];
    
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
    labelForTitle.backgroundColor = [UIColor blackColor];
    labelForTitle.text = intitleOfGraph;
    labelForTitle.textAlignment = NSTextAlignmentCenter;
    labelForTitle.textColor = [UIColor whiteColor];
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
        return [_limits objectAtIndex:index];
    }
    else
    {
        //y axis data
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
    barChart.titleTextStyle = textStyle;  // Error found here
    barChart.titleDisplacement = CGPointMake(0.0f, 0.0f);
    barChart.titlePlotAreaFrameAnchor = CPTRectAnchorTop;
    
    //make exp. labels
    CPTXYAxisSet *axisSet = (CPTXYAxisSet *)barChart.axisSet;
    CPTXYAxis *x = axisSet.xAxis;
    NSNumberFormatter *ns = [[NSNumberFormatter alloc] init];
    [ns setNumberStyle: NSNumberFormatterScientificStyle];
    x.labelFormatter = ns;
    [ns release];
    x.labelingPolicy = CPTAxisLabelingPolicyAutomatic;
    
    
    CPTXYAxis *y = axisSet.yAxis;
    y.labelingPolicy = CPTAxisLabelingPolicyAutomatic;
    
    
    _hostingView.hostedGraph = barChart;
    [self addSubview:_hostingView];
    
    
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)barChart.defaultPlotSpace;
    plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(0.00001) length:CPTDecimalFromDouble(10.0)];
    
    //make x axis log type
    plotSpace.xScaleType = CPTScaleTypeLog;
    plotSpace.yScaleType = CPTScaleTypeLinear;
    
    CPTBarPlot *barPlot = [[[CPTBarPlot alloc] init] autorelease];
    barPlot.fill = [CPTFill fillWithColor:[CPTColor colorWithCGColor:graphColor.CGColor]];
    //barPlot.fill = [CPTFill fillWithColor:[CPTColor blueColor]];
    barPlot.lineStyle = nil;
    
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
