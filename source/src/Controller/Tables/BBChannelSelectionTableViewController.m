//
//  BBChannelSelectionTableViewController.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 6/18/14.
//  Copyright (c) 2014 BackyardBrains. All rights reserved.
//

#import "BBChannelSelectionTableViewController.h"

@interface BBChannelSelectionTableViewController ()
{
    NSMutableArray * allItems;
}

@end

@implementation BBChannelSelectionTableViewController

@synthesize delegate=_delegate;


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"Popover Title";
    allItems = [[self.delegate getAllRows] retain];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Table view data source


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [allItems count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    
    if(!cell)
    {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"Cell"] autorelease];
    }
    cell.textLabel.text = [allItems objectAtIndex:indexPath.row] ;
    
    return cell;
}


#pragma mark - Table view delegate

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [self.delegate rowSelected:indexPath.row];
    
}


@end
