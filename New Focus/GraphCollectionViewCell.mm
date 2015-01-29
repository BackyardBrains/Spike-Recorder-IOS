//
//  GraphCollectionViewCell.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 7/4/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "GraphCollectionViewCell.h"
#import "BBAnalysisManager.h"

@interface GraphCollectionViewCell ()
{
    CPTXYGraph *barChart;
    NSArray * _values;
    CPTGraphHostingView *_hostingView;
    UIColor* graphColor;
}
@end


@implementation GraphCollectionViewCell

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {

        [self.layer setBorderWidth:1.0f];
        [self.layer setBorderColor:[UIColor darkGrayColor].CGColor];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(redrawGraph:) name:@"kEndChangeCellSizeInMatrixView" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clearGraph:) name:@"kStartChangeCellSizeInMatrixView" object:nil];
        
        
        [self drawGraph];
    }
    return self;
}

-(void) colorOfTheGraph:(UIColor *) theColor
{
    graphColor = [theColor copy];
    
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"kStartChangeCellSizeInMatrixView" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"kEndChangeCellSizeInMatrixView" object:nil];
    [super dealloc];
}


-(void) setFile:(BBFile *) file andFirstIndex:(int) firstIndex andSecondIndex:(int) secondIndex;
{
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        
        NSInteger firstChannelIndex = [file getChannelIndexForSpikeTrainWithIndex:firstIndex ];
        NSInteger secondChannelIndex = [file getChannelIndexForSpikeTrainWithIndex:secondIndex ];
        
        NSInteger firstSTIndex = [file getIndexInsideChannelForSpikeTrainWithIndex:firstIndex ];
        NSInteger secondSTIndex = [file getIndexInsideChannelForSpikeTrainWithIndex:secondIndex ];
        
        _values = [[[BBAnalysisManager bbAnalysisManager] crosscorrelationWithFile:file firstChannelIndex:firstChannelIndex firstSpikeTrainIndex:firstSTIndex secondChannelIndex:secondChannelIndex secondSpikeTrainIndex:secondSTIndex maxtime:0.1 andBinsize:0.001f] retain];
        
        dispatch_async(dispatch_get_main_queue(), ^{
           
            [self drawGraph];
        });
    });
}

//
// Trigered on start of screen rotation
//
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


//
// Trigered on end of screen rotation
//
-(void) redrawGraph:(NSNotification *)notification
{
    [self drawGraph];
}


-(void) drawGraph
{
    
    [self clearGraph:nil];
    
    CGRect frameOfView = CGRectMake(self.bounds.origin.x, self.bounds.origin.y, self.bounds.size.width, self.bounds.size.height);
    barChart = [[CPTXYGraph alloc] initWithFrame:frameOfView];
    
    
    _hostingView = [[CPTGraphHostingView alloc] initWithFrame:frameOfView];
    _hostingView.userInteractionEnabled = NO;
   /* UITapGestureRecognizer *touchOnView = [[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(touchOnGraph)] autorelease];
    // Set required taps and number of touches
    [touchOnView setNumberOfTapsRequired:1];
    [touchOnView setNumberOfTouchesRequired:1];
    // Add the gesture to the view
    [_hostingView addGestureRecognizer:touchOnView];*/
    
    
    barChart.plotAreaFrame.borderLineStyle = nil;
    barChart.plotAreaFrame.cornerRadius = 0.0f;
    
    barChart.paddingLeft = 0.0f;
    barChart.paddingRight = 0.0f;
    barChart.paddingTop = 5.0f;
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
    barChart.titleDisplacement = CGPointMake(0.0f, -10.0f);
    barChart.titlePlotAreaFrameAnchor = CPTRectAnchorTop;
    
    CPTXYAxisSet *axisSet = (CPTXYAxisSet *)barChart.axisSet;
    CPTXYAxis *x = axisSet.xAxis;
    x.labelingPolicy = CPTAxisLabelingPolicyAutomatic;
    
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
    //put y axis at the left side of graph
    y.orthogonalCoordinateDecimal = CPTDecimalFromDouble(-0.1);
    _hostingView.hostedGraph = barChart;
    [self addSubview:_hostingView];
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)barChart.defaultPlotSpace;
    plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(-0.1) length:CPTDecimalFromDouble(0.1)];
    
    CPTBarPlot *barPlot = [[[CPTBarPlot alloc] init] autorelease];
    barPlot.fill = [CPTFill fillWithColor:[CPTColor colorWithCGColor:graphColor.CGColor]];
    //barPlot.fill = [CPTFill fillWithColor:[CPTColor colorWithComponentRed:0.0f green:0.27843137254901963 blue:1.0f alpha:1.0f]];
    barPlot.lineStyle = nil;
    
    float widthOfBar = _hostingView.frame.size.width/[_values count];
    if(widthOfBar<1.0)
    {
        widthOfBar = 1.0;
    }
    barPlot.barWidth = CPTDecimalFromFloat(widthOfBar);
    
    barPlot.cornerRadius = 0.0f;
    barPlot.barWidthsAreInViewCoordinates = YES; //bar width are defined in pixels of screen
    barPlot.dataSource = self;
    [barChart addPlot:barPlot];
    [barChart.defaultPlotSpace scaleToFitPlots:[barChart allPlots]];
    [self addSubview:_hostingView];
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






@end
