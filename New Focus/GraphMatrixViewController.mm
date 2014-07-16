//
//  GraphMatrixViewController.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 7/4/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "GraphMatrixViewController.h"
#import "GraphCollectionViewCell.h"
#import "ColumnHeaderCollectionViewCell.h"
#import "RowHeaderColectionViewCell.h"
#import "MBProgressHUD.h"
#import "BBAnalysisManager.h"
#import "CrossCorrViewController.h"
#define GRAPH_CELL_NAME @"graphCell"
#define COLUMN_HEADER_GRAPH_CELL_NAME @"columngGraphCell"
#define ROW_HEADER_GRAPH_CELL_NAME @"rowGraphCell"

@interface GraphMatrixViewController ()
{

    int numberOfSpikeTrains;
    BOOL refreshLayout;
}

@end

@implementation GraphMatrixViewController
@synthesize bbfile = _bbfile;
@synthesize collectionView = _collectionView;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    refreshLayout = NO;
    [_collectionView registerClass:[GraphCollectionViewCell class] forCellWithReuseIdentifier:GRAPH_CELL_NAME];
    [_collectionView registerClass:[ColumnHeaderCollectionViewCell class] forCellWithReuseIdentifier:COLUMN_HEADER_GRAPH_CELL_NAME];
    [_collectionView registerClass:[RowHeaderColectionViewCell class] forCellWithReuseIdentifier:ROW_HEADER_GRAPH_CELL_NAME];
}

-(void) viewDidAppear:(BOOL)animated
{
    if(refreshLayout)
    {
        [self refreshAllGraphs];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(BBFile*) bbfile
{
    return _bbfile;
}

-(void) setBbfile:(BBFile *)bbfile
{
    _bbfile = bbfile;
    
    numberOfSpikeTrains = bbfile.numberOfSpikeTrains;
}


#pragma mark - UICollectionView delegate and source

-(NSInteger) numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

-(NSInteger) collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return numberOfSpikeTrains*numberOfSpikeTrains+2*numberOfSpikeTrains +1;
}


-(UICollectionViewCell *) collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if(indexPath.row<numberOfSpikeTrains+1)
    {
        
        ColumnHeaderCollectionViewCell* cell = [_collectionView  dequeueReusableCellWithReuseIdentifier:COLUMN_HEADER_GRAPH_CELL_NAME forIndexPath:indexPath];
        if(indexPath.row==0)
        {//this should be empty since it is header for column of row header
            [cell setNumberForTitleOfColumn:0];
        }
        else
        {
            [cell setNumberForTitleOfColumn:indexPath.row];
        }
        cell.backgroundColor=[UIColor whiteColor];
        return cell;
    }
    if((indexPath.row%(numberOfSpikeTrains+1))==0)
    {
        RowHeaderColectionViewCell* cell = [_collectionView  dequeueReusableCellWithReuseIdentifier:ROW_HEADER_GRAPH_CELL_NAME forIndexPath:indexPath];
        int tempRowIndex =(int)(((float)indexPath.row)/((float)_bbfile.numberOfSpikeTrains +1));
        [cell setNumberForTitleOfRow:tempRowIndex];
        cell.backgroundColor=[UIColor whiteColor];
        return cell;
    }
    
    GraphCollectionViewCell* cell = [_collectionView  dequeueReusableCellWithReuseIdentifier:GRAPH_CELL_NAME forIndexPath:indexPath];
    [cell setFile:_bbfile andFirstIndex:((int)((float)indexPath.row/(float)(_bbfile.numberOfSpikeTrains+1)))-1 andSecondIndex:(indexPath.row % (_bbfile.numberOfSpikeTrains+1))-1];
    cell.backgroundColor=[UIColor whiteColor];
    return cell;

}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    float widthOfRowHeader = 15;
    float heightOfColumnHeader = 15;
    CGSize sizeOfOneGraph = CGSizeMake((_collectionView.frame.size.width-((numberOfSpikeTrains+2)*10)-widthOfRowHeader)/numberOfSpikeTrains-1, (_collectionView.frame.size.height-([self bottomOfViewOffset] + [self topOfViewOffset])-((numberOfSpikeTrains+2)*10)-heightOfColumnHeader)/numberOfSpikeTrains);
    
    if(indexPath.row<numberOfSpikeTrains+1)
    {
        if(indexPath.row==0)
        {
            return CGSizeMake(widthOfRowHeader, heightOfColumnHeader);
        }
        else
        {
            return CGSizeMake(sizeOfOneGraph.width, heightOfColumnHeader);
        }
    }
    if((indexPath.row%(numberOfSpikeTrains+1))==0)
    {
        return CGSizeMake(widthOfRowHeader, sizeOfOneGraph.height);
    }
    
    return sizeOfOneGraph;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    
    [self refreshAllGraphs];
   
}

-(void) refreshAllGraphs
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSNotification *snotification = [NSNotification notificationWithName:@"kStartChangeCellSizeInMatrixView" object:self];
        [[NSNotificationCenter defaultCenter] postNotification:snotification];
    });
    [self.collectionView performBatchUpdates:nil completion:^(BOOL finished) {
        
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSNotification *notification = [NSNotification notificationWithName:@"kEndChangeCellSizeInMatrixView" object:self];
            [[NSNotificationCenter defaultCenter] postNotification:notification];
        });
        
    }];
}



- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    
    if(indexPath.row<numberOfSpikeTrains+1)
    {
        return;
    }
    if((indexPath.row%(numberOfSpikeTrains+1))==0)
    {
        return;
    }
    
    refreshLayout = YES;
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.labelText = @"Calculating...";
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        
        NSInteger firstChannelIndex = [_bbfile getChannelIndexForSpikeTrainWithIndex:((int)((float)indexPath.row/((float)_bbfile.numberOfSpikeTrains+1)) -1)];
        NSInteger secondChannelIndex = [_bbfile getChannelIndexForSpikeTrainWithIndex:(indexPath.row % (_bbfile.numberOfSpikeTrains+1) -1)];
        
        NSInteger firstSTIndex = [_bbfile getIndexInsideChannelForSpikeTrainWithIndex:((int)((float)indexPath.row/((float)_bbfile.numberOfSpikeTrains+1)) -1)];
        NSInteger secondSTIndex = [_bbfile getIndexInsideChannelForSpikeTrainWithIndex:((indexPath.row % (_bbfile.numberOfSpikeTrains+1)) -1)];
        
        NSArray *values = [[BBAnalysisManager bbAnalysisManager] crosscorrelationWithFile:_bbfile firstChannelIndex:firstChannelIndex firstSpikeTrainIndex:firstSTIndex secondChannelIndex:secondChannelIndex secondSpikeTrainIndex:secondSTIndex maxtime:0.1 andBinsize:0.001f];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [MBProgressHUD hideHUDForView:self.view animated:YES];
            CrossCorrViewController *avc = [[CrossCorrViewController alloc] initWithNibName:@"CrossCorrViewController" bundle:nil];
            avc.graphTitle =[ NSString stringWithFormat:@"Cross-correlation Spike %d - Spike %d",(int)((float)indexPath.row/((float)_bbfile.numberOfSpikeTrains+1)),(indexPath.row % (_bbfile.numberOfSpikeTrains+1)) ];
            avc.values = values;
            [self.navigationController pushViewController:avc animated:YES];
            [avc release];
        });
        
        
    });

}

- (CGFloat)topOfViewOffset
{
    CGFloat top = 0;
    if ([self respondsToSelector:@selector(topLayoutGuide)])
    {
        top = self.topLayoutGuide.length;
    }
    return top;
}

- (CGFloat)bottomOfViewOffset
{
    CGFloat top = 0;
    if ([self respondsToSelector:@selector(bottomLayoutGuide)])
    {
        top = self.bottomLayoutGuide.length;
    }
    return top;
}

- (void)dealloc {
    [_collectionView release];
    [super dealloc];
}
@end
