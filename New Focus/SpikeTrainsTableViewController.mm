//
//  SpikeTrainsTableViewController.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 4/25/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "SpikeTrainsTableViewController.h"
#import "AutocorrelationGraphViewController.h"
#import "ISIHistogramViewController.h"
#import "MBProgressHUD.h"
#import "BBAnalysisManager.h"

@interface SpikeTrainsTableViewController ()
{
    int viewFunction;
}
    @property (nonatomic, retain) NSMutableArray * trainList;

@end

@implementation SpikeTrainsTableViewController
@synthesize file;
@synthesize trainList = _trainList;
- (id)initWithFile:(BBFile *) aFile andFunction:(int) aFunction
{
    self = [super init];
    if (self) {
        self.file = aFile;
        viewFunction = aFunction;
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
    }
    return self;
}

- (void)dealloc
{
    [super dealloc];
}


- (void)viewDidLoad
{
    [super viewDidLoad];
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
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        // TODO: Any other initialization that applies to all cells of this type.
        //       (Possibly create and add subviews, assign tags, etc.)
    }
    
    // Customize cell
    cell.textLabel.text = [self.trainList objectAtIndex:[indexPath row]];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    if(viewFunction==kAUTOCORRELATION)
    {
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        hud.labelText = @"Calculating...";
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            NSArray * values = [[BBAnalysisManager bbAnalysisManager] autocorrelationWithFile:self.file spikeTrainIndex:[indexPath row]  maxtime:0.1f andBinsize:0.001f];
            dispatch_async(dispatch_get_main_queue(), ^{
                [MBProgressHUD hideHUDForView:self.view animated:YES];
                AutocorrelationGraphViewController *avc = [[AutocorrelationGraphViewController alloc] initWithNibName:@"AutocorrelationGraphViewController" bundle:nil];
                avc.values = values;
                [self.navigationController pushViewController:avc animated:YES];
                [avc release];
            });
        });
    }
    else if (viewFunction == kISI)
    {
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        hud.labelText = @"Calculating...";
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            
            NSMutableArray* values = [[NSMutableArray alloc] initWithCapacity:0];
            NSMutableArray* limits = [[NSMutableArray alloc] initWithCapacity:0];
            
            [[BBAnalysisManager bbAnalysisManager] ISIWithFile:self.file spikeTrainIndex:[indexPath row]  maxtime:0.1f numOfBins:100 values:values limits:limits ];
            dispatch_async(dispatch_get_main_queue(), ^{
                [MBProgressHUD hideHUDForView:self.view animated:YES];
                ISIHistogramViewController *avc = [[ISIHistogramViewController alloc] initWithNibName:@"ISIHistogramViewController" bundle:nil];
                avc.values = values;
                avc.limits = limits;
                [self.navigationController pushViewController:avc animated:YES];
                [avc release];
                
            });
        });

    }
}

@end
