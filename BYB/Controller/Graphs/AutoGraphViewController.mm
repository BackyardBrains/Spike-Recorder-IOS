//
//  AutoGraphViewController.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 7/8/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "AutoGraphViewController.h"
#import "MBProgressHUD.h"
#import "BBAnalysisManager.h"
#import "AutoGraphCollectionViewCell.h"
#import <CoreGraphics/CoreGraphics.h>
#import "BYBGLView.h"
#define AUTO_GRAPH_CELL_NAME @"autoGraphCell"

@interface AutoGraphViewController ()
{
    BBFile * _file;
    NSMutableArray* allValues;
    BOOL dataInitialized;
    
    //Central graph variables
    NSMutableArray * _values;
    
    CPTXYGraph *barChart;
    
    int selectedSpikeTrain;
    UIColor* graphColor;
}

@end

@implementation AutoGraphViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        dataInitialized = NO;
        allValues = [[NSMutableArray alloc] initWithCapacity:0];
    }
    return self; 
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tabBarController.tabBar.opaque = YES;
    self.tabBarController.tabBar.opaque = NO;
    [_collectionView registerClass:[AutoGraphCollectionViewCell class] forCellWithReuseIdentifier:AUTO_GRAPH_CELL_NAME];
    [_collectionViewR registerClass:[AutoGraphCollectionViewCell class] forCellWithReuseIdentifier:AUTO_GRAPH_CELL_NAME];
    
    
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.extendedLayoutIncludesOpaqueBars = NO;
    self.automaticallyAdjustsScrollViewInsets = NO;
    [self colorOfTheGraph:[BYBGLView getSpikeTrainColorWithIndex:0 transparency:1.0f]];
    [self handleOrientationOnEnd:[[UIApplication sharedApplication] statusBarOrientation]];
}


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController.navigationBar setBarTintColor:[UIColor blackColor]];
    self.navigationController.navigationBar.translucent = NO;
    [self.navigationController.navigationBar setTintColor:[UIColor whiteColor]];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    NSLog(@"Stopping regular view");
    [self.navigationController.navigationBar setBarTintColor:nil];
    self.navigationController.navigationBar.translucent = YES;
    [self.navigationController.navigationBar setTintColor:nil];
}



-(void) colorOfTheGraph:(UIColor *) theColor
{
    graphColor = [theColor copy];
    
}


-(void) setFileForGraph:(BBFile *) file
{
    _file = file;
    
    //Calculate autocorrelation for all spike trains
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.labelText = @"Calculating...";
    dataInitialized = NO;
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        
        for(int spIndex=0;spIndex<[_file numberOfSpikeTrains];spIndex++)
        {
            int channelIndex = [_file getChannelIndexForSpikeTrainWithIndex:spIndex];
            int inChannelSTIndex = [_file getIndexInsideChannelForSpikeTrainWithIndex:spIndex];
            
            NSArray * values = [[BBAnalysisManager bbAnalysisManager] autocorrelationWithFile:_file channelIndex:channelIndex spikeTrainIndex:inChannelSTIndex maxtime:0.1f andBinsize:0.001f];
            if(values == nil)
            {
                values = [[[NSMutableArray alloc] initWithCapacity:0] autorelease];
            }
            [allValues addObject:values];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            dataInitialized = YES;
            [MBProgressHUD hideHUDForView:self.view animated:YES];
            [self drawListAndGraph];
            
        });
    });
}

-(void) drawListAndGraph
{
    [_collectionView reloadData];
    [_collectionViewR reloadData];
    selectedSpikeTrain = 0;
    _values = [allValues objectAtIndex:0];
    [self drawGraph];
}



#pragma mark - UICollectionView delegate and source

-(NSInteger) numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    if(collectionView == _collectionView)
    {
        return 1;
    }
    else
    {
        return [_file numberOfSpikeTrains];
    }
}

-(NSInteger) collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    if(_file && dataInitialized)
    {
        if(collectionView == _collectionView)
        {
            return [_file numberOfSpikeTrains];
        }
        else
        {
            return 1;
        }
    }
    
    return 0;
}


-(UICollectionViewCell *) collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    
    int indexForItem;
    AutoGraphCollectionViewCell* cell;
    if(collectionView == _collectionView)
    {
        indexForItem = indexPath.row;
        cell = [_collectionView  dequeueReusableCellWithReuseIdentifier:AUTO_GRAPH_CELL_NAME forIndexPath:indexPath];
    }
    else
    {
        indexForItem = indexPath.section;
        cell = [_collectionViewR  dequeueReusableCellWithReuseIdentifier:AUTO_GRAPH_CELL_NAME forIndexPath:indexPath];
    }
    
    [cell colorOfTheGraph:[BYBGLView getSpikeTrainColorWithIndex:indexForItem transparency:1.0f]];
    [cell setValues:((NSMutableArray *) [allValues objectAtIndex:indexForItem])];
    [cell setTitleOfGraph:[NSString stringWithFormat:@"ST%d",indexForItem+1]];
    cell.backgroundColor=[UIColor blackColor];
    return cell;
    
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return CGSizeMake(80.0f,80.0f);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    int indexForItem;
    if(collectionView == _collectionView)
    {
        indexForItem = indexPath.row;
    }
    else
    {
        indexForItem = indexPath.section;
    }
    [self colorOfTheGraph:[BYBGLView getSpikeTrainColorWithIndex:indexForItem transparency:1.0f]];
    selectedSpikeTrain = indexForItem;
    _values = [allValues objectAtIndex:indexForItem];
    [self drawGraph];
}

#pragma mark - Orientation of view and layout


- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [self handleOrientationOnEnd:[[UIApplication sharedApplication] statusBarOrientation]];
}

- (void) handleOrientationOnEnd:(UIInterfaceOrientation) orientation {
    
    [self drawGraph];
    
    if (orientation == UIInterfaceOrientationPortrait || orientation == UIInterfaceOrientationPortraitUpsideDown)
    {
        NSLog(@"Will rotate");
        [UIView animateWithDuration:.65 animations:^{
            _collectionView.frame = CGRectMake(_collectionView.frame.origin.x,
                                               _collectionView.frame.origin.y-101,
                                               _collectionView.frame.size.width,
                                               _collectionView.frame.size.height);
            _hostView.frame = CGRectMake(_hostView.frame.origin.x,
                                         _hostView.frame.origin.y,
                                         _hostView.frame.size.width,
                                         _hostView.frame.size.height-101);
            

        } completion:^(BOOL finished){
            NSLog(@"Bottom finished");
            
        }];
        
        
    }
    else if (orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight)
    {
        NSLog(@"Will rotate");
        [UIView animateWithDuration:.65 animations:^{
            _collectionViewR.frame = CGRectMake(_collectionViewR.frame.origin.x-101,
                                                _collectionViewR.frame.origin.y,
                                                _collectionViewR.frame.size.width,
                                                _collectionViewR.frame.size.height);
            _hostView.frame = CGRectMake(_hostView.frame.origin.x,
                                         _hostView.frame.origin.y,
                                         _hostView.frame.size.width-101,
                                         _hostView.frame.size.height);
        } completion:^(BOOL finished){
            NSLog(@"Bottom finished");
            
        }];
        
    }
}


-(void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [self handleOrientationOnStart:[[UIApplication sharedApplication] statusBarOrientation]];
}

- (void) handleOrientationOnStart:(UIInterfaceOrientation) orientation {
    
    CPTBarPlot * plot = (CPTBarPlot*)[barChart plotAtIndex:0];
    float widthOfBar = self.view.frame.size.height/(0.9*[_values count]);
    plot.barWidth = CPTDecimalFromFloat(widthOfBar);
    
    if (orientation == UIInterfaceOrientationPortrait || orientation == UIInterfaceOrientationPortraitUpsideDown)
    {
        NSLog(@"Will rotate");
        [UIView animateWithDuration:.25 animations:^{
            _collectionView.frame = CGRectMake(_collectionView.frame.origin.x,
                                               _collectionView.frame.origin.y+101,
                                               _collectionView.frame.size.width,
                                               _collectionView.frame.size.height);
            _hostView.frame = CGRectMake(_hostView.frame.origin.x,
                                         _hostView.frame.origin.y,
                                         _hostView.frame.size.width,
                                         _hostView.frame.size.height+101);
            
        } completion:^(BOOL finished){
            NSLog(@"Bottom finished");
            
        }];
    }
    else if (orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight)
    {
        [UIView animateWithDuration:.25 animations:^{
        _collectionViewR.frame = CGRectMake(_collectionViewR.frame.origin.x+101,
                                            _collectionViewR.frame.origin.y,
                                            _collectionViewR.frame.size.width,
                                            _collectionViewR.frame.size.height);
        _hostView.frame = CGRectMake(_hostView.frame.origin.x,
                                     _hostView.frame.origin.y,
                                     _hostView.frame.size.width+101,
                                     _hostView.frame.size.height);
        
        } completion:^(BOOL finished){
            NSLog(@"Bottom finished");
            
        }];
    }
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
    if(barChart)
    {
        [barChart release];
        barChart = nil;
    }
    
}


- (void)drawGraph
{
    
    [self clearGraph:nil];
    CGRect frameOfView = CGRectMake(_hostView.bounds.origin.x, _hostView.bounds.origin.y, _hostView.bounds.size.width, _hostView.bounds.size.height);
    barChart = [[CPTXYGraph alloc] initWithFrame:frameOfView];
    
    _hostView.userInteractionEnabled = NO;
    
    barChart.plotAreaFrame.borderLineStyle = nil;
    barChart.plotAreaFrame.cornerRadius = 0.0f;
    
    barChart.paddingLeft = 0.0f;
    barChart.paddingRight = 0.0f;
    barChart.paddingTop = 0.0f;
    barChart.paddingBottom = 0.0f;

    int max = [[_values valueForKeyPath:@"@max.intValue"] integerValue];
    
    if(max>999)
    {
        barChart.plotAreaFrame.paddingLeft = 60.0;
    }
    else if(max>99)
    {
        barChart.plotAreaFrame.paddingLeft = 50.0;
    }
    else
    {
        barChart.plotAreaFrame.paddingLeft = 40.0;
    }

    barChart.plotAreaFrame.paddingTop = 40.0;
    barChart.plotAreaFrame.paddingRight = 20.0;
    barChart.plotAreaFrame.paddingBottom = 40.0;
    
    barChart.title = [NSString stringWithFormat:@"Autocorrelation Spike Train %d",selectedSpikeTrain+1];
    
    CPTMutableTextStyle *textStyle = [CPTTextStyle textStyle];
    textStyle.color = [CPTColor whiteColor];
    textStyle.fontSize = 16.0f;
    textStyle.textAlignment = CPTTextAlignmentCenter;
    barChart.titleTextStyle = textStyle;
    barChart.titleDisplacement = CGPointMake(0.0f, -10.0f);
    barChart.titlePlotAreaFrameAnchor = CPTRectAnchorTop;
    
    
    //set text style to white for axis
    CPTMutableTextStyle *labelTextStyle = [CPTMutableTextStyle textStyle];
    labelTextStyle.color = [CPTColor whiteColor];
    
    //set stile for line for axis
    CPTMutableLineStyle *axisLineStyle = [CPTMutableLineStyle lineStyle];
    [axisLineStyle setLineWidth:1];
    [axisLineStyle setLineColor:[CPTColor colorWithCGColor:[[UIColor whiteColor] CGColor]]];
    

    
    
    CPTXYAxisSet *axisSet = (CPTXYAxisSet *)barChart.axisSet;
    CPTXYAxis *x = axisSet.xAxis;
    x.labelTextStyle = labelTextStyle;

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
    [x setAxisLineStyle:axisLineStyle];
    [x setMajorTickLineStyle:axisLineStyle];
    
    CPTXYAxis *y = axisSet.yAxis;
    y.labelingPolicy = CPTAxisLabelingPolicyAutomatic;
    y.labelTextStyle = labelTextStyle;
    
    [y setAxisLineStyle:axisLineStyle];
    [y setMajorTickLineStyle:axisLineStyle];
    _hostView.hostedGraph = barChart;
    
    CPTBarPlot *barPlot = [[[CPTBarPlot alloc] init] autorelease];
   // barPlot.fill = [CPTFill fillWithColor:[CPTColor blueColor]];
    barPlot.fill = [CPTFill fillWithColor:[CPTColor colorWithCGColor:graphColor.CGColor]];
    barPlot.lineStyle = nil;
    barPlot.plotRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(0.0) length:CPTDecimalFromDouble(101.0)];//xAxisLength
    barPlot.barOffset = CPTDecimalFromFloat(1.0f);
    barPlot.baseValue = CPTDecimalFromString(@"0");
    
    float widthOfBar = _hostView.frame.size.width/[_values count];
    barPlot.barWidth = CPTDecimalFromFloat(widthOfBar);
    
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

- (void)dealloc {
    [_collectionViewR release];
    [_collectionView release];
    [_hostView release];
    [super dealloc];
}
@end
