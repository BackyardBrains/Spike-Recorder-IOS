//
//  TrialActionsViewController.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 8/10/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "TrialActionsViewController.h"
#import "PlaybackViewController.h"
#import "MBProgressHUD.h"
#import "SpikesAnalysisViewController.h"

#define ACTION_DETAILS @"Trial details"
#define ACTION_PLAY @"Play"
#define ACTION_SORT @"Find Spikes"
#define ACTION_SHARE @"Share"
#define ACTION_DELETE @"Delete"
@interface TrialActionsViewController ()
{
    NSArray *actionOptions;
    PlaybackViewController * playbackController;
}
   
@end

@implementation TrialActionsViewController

@synthesize currentTrial;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        actionOptions = [NSArray arrayWithObjects:
                         ACTION_DETAILS,
                         ACTION_PLAY,
                         ACTION_SORT,
                         ACTION_SHARE,
                         ACTION_DELETE, nil];
    }
    return self;
}

#pragma mark - Table view/source delegate
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [actionOptions count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"TrialOptionsCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }

    cell.textLabel.text = (NSString *)[actionOptions objectAtIndex:indexPath.row];
    
    
    // set the accessory view:
    cell.accessoryType =  UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
    
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    
    if ([cell.textLabel.text isEqualToString:ACTION_DETAILS])
	{
    
    }
    else if ([cell.textLabel.text isEqualToString:ACTION_PLAY])
    {
        if(playbackController==nil)
        {
            playbackController = [[[PlaybackViewController alloc] initWithNibName:@"PlaybackViewController" bundle:nil] autorelease];
        }
        playbackController.bbfile = currentTrial.file;
        playbackController.showNavigationBar = YES;
        [self.navigationController pushViewController:playbackController animated:YES];
    }
    else if ([cell.textLabel.text isEqualToString:ACTION_SORT])
    {
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        hud.labelText = @"Analyzing Spikes";
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            
            if([[BBAnalysisManager bbAnalysisManager] findSpikes:currentTrial.file] != -1)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    [MBProgressHUD hideHUDForView:self.view animated:YES];
                    SpikesAnalysisViewController *avc = [[SpikesAnalysisViewController alloc] initWithNibName:@"SpikesViewController" bundle:nil];
                    avc.bbfile = currentTrial.file;
                    [self.navigationController pushViewController:avc animated:YES];
                    [avc release];
                    
                });
            }
            else
            {
                //we have error on spike searching
                dispatch_async(dispatch_get_main_queue(), ^{
                    [MBProgressHUD hideHUDForView:self.view animated:YES];
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Can't find spikes" message:@"File is too short or it has low sampling rate."
                                                                   delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
                    [alert show];
                    [alert release];
                });
                
            }
            
        });

    }
    else if ([cell.textLabel.text isEqualToString:ACTION_SHARE])
    {
        
    }
    else if ([cell.textLabel.text isEqualToString:ACTION_DELETE])
    {
        
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    self.title = [NSString stringWithFormat:@"Trial (v:%.3f, S:%.3f)",currentTrial.velocity, currentTrial.size];
}



- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    [_tableView release];
    [super dealloc];
}
@end
