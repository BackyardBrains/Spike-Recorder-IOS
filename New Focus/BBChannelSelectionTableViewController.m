//
//  BBChannelSelectionTableViewController.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 6/18/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
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
    allItems = [[self.delegate getAllChannels] retain];
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
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if(cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    cell.textLabel.text = [allItems objectAtIndex:indexPath.row] ;
    
    return cell;
}


#pragma mark - Table view delegate

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [self.delegate channelSelected:indexPath.row];
    
}


@end
