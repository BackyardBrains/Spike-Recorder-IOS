//
//  TrialsDCMDTableViewController.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 8/10/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "TrialsDCMDTableViewController.h"
#import "BBDCMDTrial.h"
#import "TrialActionsViewController.h"

@interface TrialsDCMDTableViewController ()

@end

@implementation TrialsDCMDTableViewController

@synthesize experiment=_experiment;

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
    self.title = @"Trials";
    [super viewDidLoad];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
}


-(void) viewWillAppear:(BOOL)animated
{
    
    if (self.navigationItem.rightBarButtonItem==nil) {
        
        self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Graphs" style:UIBarButtonItemStylePlain target:self action:@selector(openGraphs:)] autorelease];
    }
}

-(void) openGraphs:(id) sender
{

}

#pragma mark - Table view/source delegate
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[_experiment trials] count];
}

/*- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        BBDCMDTrial * tempTrial = [(BBDCMDTrial *)[_experiment.trials objectAtIndex:indexPath.row] retain];
        [_experiment.trials removeObjectAtIndex:indexPath.row];
        [tempTrial deleteObject];
        [tempTrial release];
        [tableView reloadData]; // tell table to refresh now
    }
}*/

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"TrialsCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    
    // Set the data for this cell:
    BBDCMDTrial * tempTrial = (BBDCMDTrial *)[_experiment.trials objectAtIndex:indexPath.row];
    
    cell.textLabel.text = [NSString stringWithFormat:@"Trial (v:%.3f, S:%.3f)",tempTrial.velocity, tempTrial.size];
    
    
    // set the accessory view:
    cell.accessoryType =  UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
    
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    TrialActionsViewController *trialSt = [[TrialActionsViewController alloc] initWithNibName:@"TrialActionsViewController" bundle:nil];

    trialSt.currentTrial = [_experiment.trials objectAtIndex:indexPath.row];
    [self.navigationController pushViewController:trialSt animated:YES];
    [trialSt release];
}

#pragma mark - destroy view

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
