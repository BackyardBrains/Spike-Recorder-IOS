//
//  BBFileActionViewControllerTBV.m
//  Backyard Brains
//
//  Copyright 2011 Backyard Brains. All rights reserved.
//

#import "BBFileActionViewControllerTBV.h"
#import "MyAppDelegate.h"
#import "BBAnalysisManager.h"
#import "MBProgressHUD.h"
#import "CrossCorrViewController.h"
#import "GraphMatrixViewController.h"
#import "ISIGraphViewController.h"
#import "AutoGraphViewController.h"
#import "AverageSpikeGraphViewController.h"

#define FILE_DETAILS_MENU_TEXT  @"File Details"
#define PLAY_MENU_TEXT          @"Play"
#define FIND_SPIKES_MENU_TEXT   @"Find Spikes"
#define AUTOCORR_MENU_TEXT      @"Autocorrelation"
#define ISI_MENU_TEXT           @"ISI"
#define CROSS_CORR_MENU_TEXT    @"Cross-correlation"
#define AVERAGE_SPIKE_MENU_TEXT @"Average Spike"
#define SHARE_MENU_TEXT         @"Share"
#define DELETE_MENU_TEXT        @"Delete"


#define SEGUE_CROSS_CORRELATION_MATRIX @"crossCorrMatrixSegue"
#define SEGUE_AUTOCORRELATION_GRAPH @"autocorrelationGraphSegue"
#define SEGUE_ISI_GRAPH @"isiGraphSegue"


@implementation BBFileActionViewControllerTBV


@synthesize actionOptions       = _actionOptions;
@synthesize files               = _files;
@synthesize delegate            = _delegate;


#pragma mark - View management

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [[self navigationController] setNavigationBarHidden:NO animated:NO];
    
    self.files = self.delegate.filesSelectedForAction;
    
    [self makeTableItems];
    
    //react on new shared file, we have to refresh table and display file
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(newFileAddedViaShare)
                                                 name:@"FileReceivedViaShare"
                                               object:nil];
    [self.tableView reloadData];
}


-(void) viewWillDisappear:(BOOL)animated
{
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"FileReceivedViaShare" object:nil];
    [super viewWillDisappear:animated];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}


#pragma mark - TableViewDelegate methods

-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// Customize the number of rows in the table view.
-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.actionOptions count];
}

-(void) makeTableItems
{
    if ([self.files count] == 1) //single file
    {
        BBFile * tempFile = [self.files objectAtIndex:0];
        self.navigationItem.title = [tempFile shortname];
        if([tempFile.spikesFiltered isEqualToString:FILE_SPIKE_SORTED] )
        {
            if([tempFile numberOfSpikeTrains]>1)
            {
                
                //when spikes are sorted and we have multiple spike trains
                self.actionOptions = [NSArray arrayWithObjects:
                                      FILE_DETAILS_MENU_TEXT,
                                      PLAY_MENU_TEXT,
                                      FIND_SPIKES_MENU_TEXT,
                                      AUTOCORR_MENU_TEXT,
                                      ISI_MENU_TEXT,
                                      CROSS_CORR_MENU_TEXT, //When we have multiple spike trains
                                      AVERAGE_SPIKE_MENU_TEXT,
                                      SHARE_MENU_TEXT,
                                      DELETE_MENU_TEXT, nil];
            }
            else
            {
                //when spikes are sorted and we have just one spike train (no cross-correlation)
                self.actionOptions = [NSArray arrayWithObjects:
                                      FILE_DETAILS_MENU_TEXT,
                                      PLAY_MENU_TEXT,
                                      FIND_SPIKES_MENU_TEXT,
                                      AUTOCORR_MENU_TEXT,
                                      ISI_MENU_TEXT,
                                      AVERAGE_SPIKE_MENU_TEXT,
                                      SHARE_MENU_TEXT,
                                      DELETE_MENU_TEXT, nil];
            }
        }
        else
        {
            //when spikes are not sorted display only spike sorting and file management
            self.actionOptions = [NSArray arrayWithObjects:
                                  FILE_DETAILS_MENU_TEXT,
                                  PLAY_MENU_TEXT,
                                  FIND_SPIKES_MENU_TEXT,
                                  SHARE_MENU_TEXT,
                                  DELETE_MENU_TEXT, nil];
        }
    }
}

-(UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // See if there's an existing cell we can reuse
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"actionCell"];
    if (cell == nil) {
        // No cell to reuse => create a new one
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"actionCell"] autorelease];
        
        // Initialize cell
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    // Customize cell
    cell.textLabel.text = [self.actionOptions objectAtIndex:[indexPath row]];
    
    return cell;
}

//
//
//
-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	 
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    
    if ([cell.textLabel.text isEqualToString:PLAY_MENU_TEXT])
	{
        if(playbackController==nil)
        {
            playbackController = [[[PlaybackViewController alloc] initWithNibName:@"PlaybackViewController" bundle:nil] autorelease];
        }
        playbackController.showNavigationBar = NO;
        playbackController.bbfile = [self.files objectAtIndex:0];
        [self.navigationController pushViewController:playbackController animated:YES];
        //[playbackController release];

	}
     
	else if ([cell.textLabel.text isEqualToString:FILE_DETAILS_MENU_TEXT])
	{
        // Launch a detail view here.
        BBFileDetailsTableViewController *bbdvc = [[BBFileDetailsTableViewController alloc] initWithBBFile:[self.files objectAtIndex:0]];
        [self.navigationController pushViewController:bbdvc animated:YES];
        [bbdvc release];
        
	}
     
    else if ([cell.textLabel.text isEqualToString:FIND_SPIKES_MENU_TEXT])
	{
        BBFile * fileToAnalyze = (BBFile *)[self.files objectAtIndex:0];
       
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        hud.labelText = @"Analyzing Spikes";
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            
            if([[BBAnalysisManager bbAnalysisManager] findSpikes:fileToAnalyze] != -1)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    [MBProgressHUD hideHUDForView:self.view animated:YES];
                    SpikesAnalysisViewController *avc = [[SpikesAnalysisViewController alloc] initWithNibName:@"SpikesViewController" bundle:nil];
                    avc.bbfile = [self.files objectAtIndex:0];
                    [self.navigationController pushViewController:avc animated:YES];
                    [avc release];
                    
                });
            }
            else
            {
                //we have error on spike searching
                dispatch_async(dispatch_get_main_queue(), ^{
                    [MBProgressHUD hideHUDForView:self.view animated:YES];
                    UIAlertController *alertView = [UIAlertController alertControllerWithTitle:@"Can't find spikes" message:@"File is too short or it has low sampling rate." preferredStyle:UIAlertControllerStyleAlert];
                    [alertView addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action)
                                            {
                                                // OK button tappped. Do nothing
                                                [self dismissViewControllerAnimated:YES completion:^{
                                                }];
                                            }]];
                    // Present action sheet.
                    [self presentViewController:alertView animated:YES completion:nil];
                });
                
            }
            
        });
        
    }
    else if ([cell.textLabel.text isEqualToString:AUTOCORR_MENU_TEXT])
	{
        [self performSegueWithIdentifier:SEGUE_AUTOCORRELATION_GRAPH sender:self];
    }
    else if ([cell.textLabel.text isEqualToString:ISI_MENU_TEXT])
    {
        [self performSegueWithIdentifier:SEGUE_ISI_GRAPH sender:self];
    }
    else if ([cell.textLabel.text isEqualToString:CROSS_CORR_MENU_TEXT])
    {
        [self performSegueWithIdentifier:SEGUE_CROSS_CORRELATION_MATRIX sender:self];
    }
    else if ([cell.textLabel.text isEqualToString:AVERAGE_SPIKE_MENU_TEXT])
    {
  
        AverageSpikeGraphViewController *asvc = [[AverageSpikeGraphViewController alloc] initWithNibName:@"AverageSpikeGraphViewController" bundle:nil];
        [asvc calculateGraphForFile:(BBFile *)[self.files objectAtIndex:0] andChannelIndex:0];
        [self.navigationController pushViewController:asvc animated:YES];
        [asvc release];
        
    }
	else if ([cell.textLabel.text isEqualToString:SHARE_MENU_TEXT])
	{
        //grab just the filenames
        NSMutableArray *theFilenames = [[NSMutableArray alloc] init];
		for (BBFile *thisFile in self.files)
        {
            [thisFile saveWithoutArrays];
           // NSURL * url = [thisFile prepareBYBFile];
            [theFilenames addObject:[NSURL fileURLWithPath:[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:thisFile.filename]]];
        }
        UIActivityViewController * activities = [[[UIActivityViewController alloc]
                                                 initWithActivityItems:theFilenames
                                                 applicationActivities:nil] autorelease];
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            
            if([activities respondsToSelector:@selector(popoverPresentationController)])
            {
                    //iOS8
                    activities.popoverPresentationController.sourceView = self.view;
            }
            [[[self parentViewController] parentViewController] presentViewController:activities animated:YES completion:nil];

        }
        else
        {
            [self presentViewController:activities
                               animated:YES
                             completion:nil];
            
        }
        [theFilenames release];

	}
	else if ([cell.textLabel.text isEqualToString:DELETE_MENU_TEXT])
	{
        NSString *deleteTitle = [NSString stringWithFormat:@"Delete \"%@?\"", [[self.files objectAtIndex:0] shortname]];
        
        UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:deleteTitle message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        
        [actionSheet addAction:[UIAlertAction actionWithTitle:@"Yes, delete!" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action)
                                {
                                    [self.delegate deleteTheFiles:self.files];
                                    [self.navigationController popViewControllerAnimated:YES];
                                    [self dismissViewControllerAnimated:YES completion:^{
                                       
                                    }];
                                }]];
        [actionSheet addAction:[UIAlertAction actionWithTitle:@"No, go back." style:UIAlertActionStyleCancel handler:^(UIAlertAction *action)
                                {
                                    // Cancel button tappped. Do nothing
                                    [self dismissViewControllerAnimated:YES completion:^{
                                    }];
                                }]];
        // Present action sheet.
        [self presentViewController:actionSheet animated:YES completion:nil];
    }
}

#pragma mark - Segue functions


- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:SEGUE_CROSS_CORRELATION_MATRIX])
    {
        GraphMatrixViewController *actionViewController = (GraphMatrixViewController *)segue.destinationViewController;
        actionViewController.bbfile = (BBFile *)[self.files objectAtIndex:0];;
    }
    else if ([[segue identifier] isEqualToString:SEGUE_AUTOCORRELATION_GRAPH])
    {
        AutoGraphViewController *autovc = (AutoGraphViewController *)segue.destinationViewController;
        [autovc setFileForGraph:(BBFile *)[self.files objectAtIndex:0]];
    }
    else if ([[segue identifier] isEqualToString:SEGUE_ISI_GRAPH])
    {
        ISIGraphViewController *isivc = (ISIGraphViewController *)segue.destinationViewController;
        [isivc setFileForGraph:(BBFile *)[self.files objectAtIndex:0]];
    }
}


#pragma mark - File sharing functions
//
// Reset flag if user tries to open shard file and app was on this screen
// before it went to background.
//
-(void) newFileAddedViaShare
{
    MyAppDelegate * appDelegate = (MyAppDelegate*)[[UIApplication sharedApplication] delegate];
    if([appDelegate sharedFileShouldBeOpened])
    {
        [appDelegate sharedFileIsOpened];
    }
}

#pragma mark - Memory management

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)dealloc
{
    [_actionOptions release];
    [_files release];
    [super dealloc];
}


@end
