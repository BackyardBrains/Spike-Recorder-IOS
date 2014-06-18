//
//  SelectCrosscorelTableViewController.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 4/26/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "SelectCrosscorelTableViewController.h"
#import "BBAnalysisManager.h"
#import "MBProgressHUD.h"
#import "CrossCorrViewController.h"

@interface SelectCrosscorelTableViewController ()
{
    int _firstIndexPath;
    int _secondIndexPath;
}

 @property (nonatomic, retain) NSMutableArray * trainList;
@end

@implementation SelectCrosscorelTableViewController

@synthesize file;
@synthesize trainList = _trainList;
- (id)initWithFile:(BBFile *) aFile
{
    self = [super init];
    if (self) {
    /*    self.file = aFile;

        self.trainList = [[[NSMutableArray alloc] init] autorelease];
        
        int i;
        float lowerThresh;
        float higherThresh;
        for(i=0;i<[aFile.spikes count];i++)
        {
            if([[aFile.thresholds objectAtIndex:i*2] floatValue] >[[aFile.thresholds objectAtIndex:i*2+1] floatValue])
            {
                higherThresh = [[aFile.thresholds objectAtIndex:i*2] floatValue];
                lowerThresh = [[aFile.thresholds objectAtIndex:i*2+1] floatValue];
            }
            else
            {
                higherThresh = [[aFile.thresholds objectAtIndex:i*2+1] floatValue];
                lowerThresh = [[aFile.thresholds objectAtIndex:i*2] floatValue];
            }
            NSString * nameOfTrain = [[NSString alloc] initWithFormat:@"ST%d (%4.3fmV to %4.3fmV)", i+1, lowerThresh, higherThresh ];
            [self.trainList addObject:nameOfTrain];
            [nameOfTrain release];
            
        }
        self.tableView.dataSource = self;
		self.tableView.delegate = self;
		self.tableView.sectionIndexMinimumDisplayRowCount=10;
		self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
        _firstIndexPath = -1;
        _secondIndexPath = -1;
        
        
        //Add done button
        UIBarButtonItem *doneButton = [[UIBarButtonItem alloc]
                                       initWithTitle:@"Done"
                                       style:UIBarButtonItemStylePlain
                                       target:self
                                       action:@selector(startAnalysis)];
        self.navigationItem.rightBarButtonItem = doneButton;
        [doneButton release];
        */
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableView.allowsMultipleSelection = YES;
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.trainList count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // See if there's an existing cell we can reuse
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"spikeTrainCell"];
    if (cell == nil) {
        // No cell to reuse => create a new one
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"spikeTrainCell"] autorelease];
        
        // Initialize cell
        //cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        // TODO: Any other initialization that applies to all cells of this type.
        //       (Possibly create and add subviews, assign tags, etc.)
    }
    
    // Customize cell
    cell.textLabel.text = [self.trainList objectAtIndex:[indexPath row]];
    
    if([[tableView indexPathsForSelectedRows] containsObject:indexPath]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryCheckmark;

    _firstIndexPath = _secondIndexPath;
    _secondIndexPath = (int)(indexPath.row);

    
    
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView.indexPathsForSelectedRows.count > 1)
    {
        NSIndexPath * oldIndexPath = [NSIndexPath indexPathForRow:_firstIndexPath inSection:0];
        UITableViewCell* cell = [tableView cellForRowAtIndexPath:oldIndexPath];
        cell.accessoryType = UITableViewCellAccessoryNone;
        [self.tableView deselectRowAtIndexPath:oldIndexPath animated:NO];
    }
    
    return indexPath;
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryNone;
    
    
    NSLog(@"%d",indexPath.row);
    NSLog(@"%d",_firstIndexPath);
    if(indexPath.row == _firstIndexPath)
    {
        _firstIndexPath = -1;

    }
    if(indexPath.row == _secondIndexPath)
    {
        _secondIndexPath = _firstIndexPath;
        _firstIndexPath = -1;
        
    }

}

-(void) startAnalysis
{
    if(_firstIndexPath!=-1 && _secondIndexPath!=-1)
    {
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        hud.labelText = @"Calculating...";
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            NSArray *values = [[BBAnalysisManager bbAnalysisManager] crosscorrelationWithFile:self.file firstSpikeTrainIndex:_firstIndexPath secondSpikeTrainIndex:_secondIndexPath maxtime:0.1 andBinsize:0.001f];
            dispatch_async(dispatch_get_main_queue(), ^{
                [MBProgressHUD hideHUDForView:self.view animated:YES];
                CrossCorrViewController *avc = [[CrossCorrViewController alloc] initWithNibName:@"CrossCorrViewController" bundle:nil];
                avc.values = values;
                [self.navigationController pushViewController:avc animated:YES];
                [avc release];
            });
        });
    }
    else
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Can not calculate" message:@"Please select two spike trains to calculate Cross-correlation." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
		[alert show];
		[alert release];
    }
}

@end
