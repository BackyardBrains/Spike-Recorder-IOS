//
//  BBExperimentsTableViewController.m
//  Spike Recorder
//
//  Created by Stanislav on 9/18/19.
//  Copyright © 2019 BackyardBrains. All rights reserved.
//

#import "BBExperimentsTableViewController.h"
#import "ExperimentsViewController.h"
#define DCMD_EXPERIMENT         @"DCMD Experiment"

#define SEGUE_DCMD_VIEW         @"openDcmdViewSegue"
@interface BBExperimentsTableViewController ()

@end

@implementation BBExperimentsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {

    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {

    return 1;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                   reuseIdentifier:@"ExperimentsCell"] autorelease];
    //UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ExperimentsCell" forIndexPath:indexPath];
    cell.textLabel.text = DCMD_EXPERIMENT;
    cell.detailTextLabel.text = @"Looming stimulation, recording and analysis";
    // Configure the cell...
    
    return cell;
}

//
//
//
-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    
    if ([cell.textLabel.text isEqualToString:DCMD_EXPERIMENT])
    {
        [self performSegueWithIdentifier:SEGUE_DCMD_VIEW sender:self];
    }
}


- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:SEGUE_DCMD_VIEW])
    {
    }
}


@end
