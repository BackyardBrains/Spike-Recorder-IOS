//
//  ISIGraphViewController.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 7/7/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "ISIGraphViewController.h"
#import "MBProgressHUD.h"
#import "BBAnalysisManager.h"
#import "ISIGraphCollectionViewCell.h"
#import <CoreGraphics/CoreGraphics.h>

#define ISI_GRAPH_CELL_NAME @"isiGraphCell"

@interface ISIGraphViewController ()
{
    BBFile * _file;
    NSMutableArray* allValues;
    NSMutableArray* allLimits;
    BOOL dataInitialized;
    
    //Central graph variables
    NSMutableArray * _values;
    NSMutableArray * _limits;
    
    CPTXYGraph *barChart;
    
    int selectedSpikeTrain;
}

@end

@implementation ISIGraphViewController


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        dataInitialized = NO;
        allValues = [[NSMutableArray alloc] initWithCapacity:0];
        allLimits = [[NSMutableArray alloc] initWithCapacity:0];
        
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tabBarController.tabBar.opaque = YES;
    self.tabBarController.tabBar.opaque = NO;
    [_collectionView registerClass:[ISIGraphCollectionViewCell class] forCellWithReuseIdentifier:ISI_GRAPH_CELL_NAME];
    [_collectionViewR registerClass:[ISIGraphCollectionViewCell class] forCellWithReuseIdentifier:ISI_GRAPH_CELL_NAME];

    
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.extendedLayoutIncludesOpaqueBars = NO;
    self.automaticallyAdjustsScrollViewInsets = NO;

    [self handleOrientationOnEnd:[[UIApplication sharedApplication] statusBarOrientation]];
    
}


-(void) setFileForGraph:(BBFile *) file
{
    _file = file;
    
    //Calculate ISI for all spike trains
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.labelText = @"Calculating...";
    dataInitialized = NO;
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        
        for(int spIndex=0;spIndex<[_file numberOfSpikeTrains];spIndex++)
        {
            NSMutableArray* values = [[NSMutableArray alloc] initWithCapacity:0];
            NSMutableArray* limits = [[NSMutableArray alloc] initWithCapacity:0];
        
            int channelIndex = [_file getChannelIndexForSpikeTrainWithIndex:spIndex];
            int inChannelSTIndex = [_file getIndexInsideChannelForSpikeTrainWithIndex:spIndex];
            
            [[BBAnalysisManager bbAnalysisManager] ISIWithFile:_file channelIndex:channelIndex spikeTrainIndex:inChannelSTIndex maxtime:0.1f numOfBins:100 values:values limits:limits ];
            
            [allLimits addObject:limits];
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
    _limits = [allLimits objectAtIndex:0];
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
    ISIGraphCollectionViewCell* cell;
    if(collectionView == _collectionView)
    {
        indexForItem = indexPath.row;
        cell = [_collectionView  dequeueReusableCellWithReuseIdentifier:ISI_GRAPH_CELL_NAME forIndexPath:indexPath];
    }
    else
    {
        indexForItem = indexPath.section;
        cell = [_collectionViewR  dequeueReusableCellWithReuseIdentifier:ISI_GRAPH_CELL_NAME forIndexPath:indexPath];
    }
    

    [cell setValues:((NSMutableArray *) [allValues objectAtIndex:indexForItem]) andLimits:((NSMutableArray *) [allLimits objectAtIndex:indexForItem])];
    cell.backgroundColor=[UIColor whiteColor];
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
    selectedSpikeTrain = indexForItem;
    _values = [allValues objectAtIndex:indexForItem];
    _limits = [allLimits objectAtIndex:indexForItem];
    [self drawGraph];
}

#pragma mark - Orientation of view and layout


- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [self handleOrientationOnEnd:[[UIApplication sharedApplication] statusBarOrientation]];
}

- (void) handleOrientationOnEnd:(UIInterfaceOrientation) orientation {
    
    if (orientation == UIInterfaceOrientationPortrait || orientation == UIInterfaceOrientationPortraitUpsideDown)
    {
        NSLog(@"Will rotate");
        [UIView animateWithDuration:.25 animations:^{
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
        [UIView animateWithDuration:.25 animations:^{
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
        _collectionViewR.frame = CGRectMake(_collectionViewR.frame.origin.x+101,
                                            _collectionViewR.frame.origin.y,
                                            _collectionViewR.frame.size.width,
                                            _collectionViewR.frame.size.height);
        _hostView.frame = CGRectMake(_hostView.frame.origin.x,
                                     _hostView.frame.origin.y,
                                     _hostView.frame.size.width+101,
                                     _hostView.frame.size.height);
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
    
    barChart.title = [NSString stringWithFormat:@"ISI Spike Train %d",selectedSpikeTrain+1] ;
    
    CPTMutableTextStyle *textStyle = [CPTTextStyle textStyle];
    textStyle.color = [CPTColor grayColor];
    textStyle.fontSize = 16.0f;
    textStyle.textAlignment = CPTTextAlignmentCenter;
    barChart.titleTextStyle = textStyle;  // Error found here
    barChart.titleDisplacement = CGPointMake(0.0f, -10.0f);
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
    
    
    _hostView.hostedGraph = barChart;
    
    
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)barChart.defaultPlotSpace;
    plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(0.00001) length:CPTDecimalFromDouble(10.0)];
    
    //make x axis log type
    plotSpace.xScaleType = CPTScaleTypeLog;
    plotSpace.yScaleType = CPTScaleTypeLinear;
    
    CPTBarPlot *barPlot = [[[CPTBarPlot alloc] init] autorelease];
    barPlot.fill = [CPTFill fillWithColor:[CPTColor blueColor]];
    barPlot.lineStyle = nil;
    
    //make width of bars on ipad greater
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        barPlot.barWidth = CPTDecimalFromFloat(10.0f);
    }
    else
    {
        barPlot.barWidth = CPTDecimalFromFloat(4.0f);
    }
    
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
    [_hostView release];
    [_collectionView release];
    [_collectionViewR release];
    [super dealloc];
}
@end
