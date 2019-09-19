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
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
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
        //[self performSegueWithIdentifier:SEGUE_DCMD_VIEW sender:self];
        ExperimentsViewController *expVC = [[ExperimentsViewController alloc] initWithNibName:@"ExperimentsViewController" bundle:nil];
        [self.navigationController pushViewController:expVC animated:YES];
        [expVC release];
    }
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
