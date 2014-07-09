//
//  GraphMatrixViewController.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 7/4/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "GraphMatrixViewController.h"
#import "GraphCollectionViewCell.h"
#import "MBProgressHUD.h"
#import "BBAnalysisManager.h"
#import "CrossCorrViewController.h"
#define GRAPH_CELL_NAME @"graphCell"

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
    return numberOfSpikeTrains*numberOfSpikeTrains;
}


-(UICollectionViewCell *) collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    GraphCollectionViewCell* cell = [_collectionView  dequeueReusableCellWithReuseIdentifier:GRAPH_CELL_NAME forIndexPath:indexPath];
    [cell setFile:_bbfile andFirstIndex:(int)((float)indexPath.row/(float)_bbfile.numberOfSpikeTrains) andSecondIndex:indexPath.row % _bbfile.numberOfSpikeTrains];
    cell.backgroundColor=[UIColor whiteColor];
    return cell;

}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return CGSizeMake((_collectionView.frame.size.width-((numberOfSpikeTrains+1)*10))/numberOfSpikeTrains, (_collectionView.frame.size.height-([self bottomOfViewOffset] + [self topOfViewOffset])-((numberOfSpikeTrains+1)*10))/numberOfSpikeTrains);
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
    refreshLayout = YES;
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.labelText = @"Calculating...";
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        
        NSInteger firstChannelIndex = [_bbfile getChannelIndexForSpikeTrainWithIndex:(int)((float)indexPath.row/(float)_bbfile.numberOfSpikeTrains) ];
        NSInteger secondChannelIndex = [_bbfile getChannelIndexForSpikeTrainWithIndex:indexPath.row % _bbfile.numberOfSpikeTrains ];
        
        NSInteger firstSTIndex = [_bbfile getIndexInsideChannelForSpikeTrainWithIndex:(int)((float)indexPath.row/(float)_bbfile.numberOfSpikeTrains) ];
        NSInteger secondSTIndex = [_bbfile getIndexInsideChannelForSpikeTrainWithIndex:indexPath.row % _bbfile.numberOfSpikeTrains ];
        
        NSArray *values = [[BBAnalysisManager bbAnalysisManager] crosscorrelationWithFile:_bbfile firstChannelIndex:firstChannelIndex firstSpikeTrainIndex:firstSTIndex secondChannelIndex:secondChannelIndex secondSpikeTrainIndex:secondSTIndex maxtime:0.1 andBinsize:0.001f];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [MBProgressHUD hideHUDForView:self.view animated:YES];
            CrossCorrViewController *avc = [[CrossCorrViewController alloc] initWithNibName:@"CrossCorrViewController" bundle:nil];
            avc.graphTitle =[ NSString stringWithFormat:@"Cross-correlation Spike %d - Spike %d",(int)((float)indexPath.row/(float)_bbfile.numberOfSpikeTrains)+1,(indexPath.row % _bbfile.numberOfSpikeTrains)+1 ];
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
