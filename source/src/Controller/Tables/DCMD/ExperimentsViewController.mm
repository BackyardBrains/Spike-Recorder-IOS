//
//  ExperimentsViewController.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 8/5/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "ExperimentsViewController.h"

#import "BBDCMDExperiment.h"
@interface ExperimentsViewController ()

@end

@implementation ExperimentsViewController
@synthesize allExperiments = _allExperiments;
@synthesize myNewExperiment = _myNewExperiment;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        
        _allExperiments = [[NSMutableArray alloc] initWithCapacity:0];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    
    if(self = [super initWithCoder:aDecoder]) {
        
        
        _allExperiments = [[NSMutableArray alloc] initWithCapacity:0];
        
    }
    
    return self;
}

- (void)viewDidLoad
{
    self.title = @"Experiments";
    [super viewDidLoad];
    self.expTableView  = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    [self.expTableView setAutoresizesSubviews:YES];
    [self.expTableView setAutoresizingMask:
     UIViewAutoresizingFlexibleWidth |
     UIViewAutoresizingFlexibleHeight];
    // must set delegate & dataSource, otherwise the the table will be empty and not responsive
    self.expTableView.delegate = self;
    self.expTableView.dataSource = self;
    
    
    // add to canvas
    [self.view addSubview:self.expTableView];
    
}

- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    self.expTableView.frame = self.view.bounds;
    [self.expTableView reloadData];
}

-(void) viewWillAppear:(BOOL)animated
{
    self.expTableView.delegate = self;
    self.expTableView.dataSource = self;
    
    _allExperiments = [[NSMutableArray arrayWithArray:[BBDCMDExperiment allObjects]] retain];
    
    if (self.navigationItem.rightBarButtonItem==nil) {
        
        UIBarButtonItem *rightButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                     target:self
                                                                                     action:@selector(createNewExperiment:)];
        
        self.navigationItem.rightBarButtonItem = rightButton;
    }
    [self.expTableView reloadData];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)dealloc {
    [self.expTableView release];
    
    [super dealloc];
}

#pragma mark - Experiment procedure

-(void) createNewExperiment:(id)sender
{
    ExperimentSetupViewController *expSt = [[ExperimentSetupViewController alloc] initWithNibName:@"ExperimentSetupViewController" bundle:nil];
    _myNewExperiment = [[BBDCMDExperiment alloc] init];
    expSt.experiment = _myNewExperiment;
    expSt.masterDelegate = self;
    [self.navigationController pushViewController:expSt animated:YES];
    [expSt release];
}

-(void) endOfSetup
{
    [self.navigationController popViewControllerAnimated:NO];
    DCMDExperimentViewController *expVC = [[DCMDExperimentViewController alloc] initWithNibName:@"DCMDExperimentViewController" bundle:nil];
    expVC.experiment = _myNewExperiment;
    expVC.masterDelegate = self;
    expVC.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:expVC animated:YES];
    [expVC release];
}

-(void) endOfExperiment
{
    [self.navigationController popViewControllerAnimated:NO];
    [[self navigationController] setNavigationBarHidden:NO animated:YES];
    TrialsDCMDTableViewController *trialsVC = [[TrialsDCMDTableViewController alloc] initWithNibName:@"TrialsDCMDTableViewController" bundle:nil];
    trialsVC.experiment = _myNewExperiment;
    [self.navigationController pushViewController:trialsVC animated:YES];
    [trialsVC release];
}

#pragma mark - Table view code

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_allExperiments count];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        BBDCMDExperiment * tempExperiment = (BBDCMDExperiment *)[_allExperiments objectAtIndex:indexPath.row];
        [_allExperiments removeObjectAtIndex:indexPath.row];
        for(int i=[[tempExperiment trials] count]-1;i>=0;i--)
        {
            BBDCMDTrial * tempTrial = [[tempExperiment trials] objectAtIndex:i];
            if([tempTrial file] != nil)
            {
                [[tempTrial file] deleteObject];
            }
            [tempTrial setFile:nil];
            [tempTrial deleteObject];
            [tempExperiment.trials removeObject:tempTrial];
        }
        [tempExperiment deleteObject];
        [tableView reloadData]; // tell table to refresh now
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"ExperimentsCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    
    // Set the data for this cell:
    BBDCMDExperiment * tempExperiment = (BBDCMDExperiment *)[_allExperiments objectAtIndex:indexPath.row];
    
    cell.textLabel.text = tempExperiment.name;
    
    
    // set the accessory view:
    cell.accessoryType =  UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
    
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self removeAllTrialsThatAreNotSimulated:[_allExperiments objectAtIndex:indexPath.row]];
    TrialsDCMDTableViewController *trialsVC = [[TrialsDCMDTableViewController alloc] initWithNibName:@"TrialsDCMDTableViewController" bundle:nil];
    trialsVC.experiment = [_allExperiments objectAtIndex:indexPath.row];
    [self.navigationController pushViewController:trialsVC animated:YES];
    [trialsVC release];
}



-(void) removeAllTrialsThatAreNotSimulated:(BBDCMDExperiment *) experimentToClean
{
    for(int i=[experimentToClean.trials count]-1;i>=0;i--)
    {
        BBDCMDTrial * tempTrial = [experimentToClean.trials objectAtIndex:i];
        if([tempTrial file]==nil)
        {
            [tempTrial deleteObject];
            [experimentToClean.trials removeObject:tempTrial];
        }
    }
}

@end
