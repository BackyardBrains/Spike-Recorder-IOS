//
//  BBFileActionViewControllerTBV.m
//  Backyard Brains
//
//  Created by Zachary King on 7/13/11.
//  Copyright 2011 Backyard Brains. All rights reserved.
//

#import "BBFileActionViewControllerTBV.h"
#import "MyAppDelegate.h"
#import "BBAnalysisManager.h"
#import "MBProgressHUD.h"
#import "AutocorrelationGraphViewController.h"
#import "ISIHistogramViewController.h"
#import "SpikeTrainsTableViewController.h"
#import "SelectCrosscorelTableViewController.h"
#import "CrossCorrViewController.h"
#import "GraphMatrixViewController.h"
#import "ISIGraphViewController.h"
#import "AutoGraphViewController.h"

@implementation BBFileActionViewControllerTBV


//@synthesize theTableView;
@synthesize actionOptions       = _actionOptions;
@synthesize fileNamesToShare    = _fileNamesToShare;
@synthesize files               = _files;

@synthesize delegate            = _delegate;

- (void)dealloc
{
    [super dealloc];
    
    [_actionOptions release];
    [_fileNamesToShare release];
    [_files release];
}


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{    
	if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
		self.tableView.dataSource = self;
		self.tableView.delegate = self;
		self.tableView.sectionIndexMinimumDisplayRowCount=10;
		self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
		
    }
    return self;
}



- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.files = self.delegate.filesSelectedForAction;
    
    if ([self.files count] == 1) //single file
    {
        BBFile * tempFile = [self.files objectAtIndex:0];
        self.navigationItem.title = [tempFile shortname];
        if([tempFile.spikesFiltered isEqualToString:FILE_SPIKE_SORTED] )
        {
            if([tempFile numberOfSpikeTrains]>1)
            {
                self.actionOptions = [NSArray arrayWithObjects:
                              @"File Details",
                              @"Play",
                              @"Find Spikes",
                              @"Autocorrelation",
                              @"ISI",
                              @"Cross-correlation",
                              //@"Average Spike",
                              //@"Email",
                              @"Share",
                              @"Delete", nil];
            }
            else
            {
            
                self.actionOptions = [NSArray arrayWithObjects:
                                      @"File Details",
                                      @"Play",
                                      @"Find Spikes",
                                      @"Autocorrelation",
                                      @"ISI",
                                      //@"Average Spike",
                                      //@"Email",
                                      @"Share",
                                      @"Delete", nil];
            }
        }
        else
        {
            self.actionOptions = [NSArray arrayWithObjects:
                                  @"File Details",
                                  @"Play",
                                  @"Find Spikes",
                                  @"Share",
                                  @"Delete", nil];
        }
    }
    else //multiple files
    {
        self.navigationItem.title = [NSString stringWithFormat:@"%u Files", [self.files count]];
        
        self.actionOptions = [NSArray arrayWithObjects:
                              @"File Details",
                              @"Email",
                              @"Share",
                              @"Delete", nil];
    }
    
    
    self.contentSizeForViewInPopover =
        CGSizeMake(310.0, (self.tableView.rowHeight * ([self.actionOptions count] +1)));
    
    //react on new file, we have to refresh table and display file
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(newFileAddedViaShare)
                                                 name:@"FileReceivedViaShare"
                                               object:nil];
    [self.tableView reloadData];
}

//If file is opened reset flag
-(void) newFileAddedViaShare
{
    MyAppDelegate * appDelegate = (MyAppDelegate*)[[UIApplication sharedApplication] delegate];
    if([appDelegate sharedFileShouldBeOpened])
    {
        [appDelegate sharedFileIsOpened];
    }

}

-(void) viewWillDisappear:(BOOL)animated
{
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"FileReceivedViaShare" object:nil];
    [super viewWillDisappear:animated];
}

#pragma mark - TableViewDelegate methods

//UITableViewDelegate
- (void)tableView:(UITableView *)tableView willDisplayCell:(BBFileTableCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    //return [allFiles count];
    return [self.actionOptions count];
}




- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // See if there's an existing cell we can reuse
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"actionCell"];
    if (cell == nil) {
        // No cell to reuse => create a new one
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"actionCell"] autorelease];
        
        // Initialize cell
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        // TODO: Any other initialization that applies to all cells of this type.
        //       (Possibly create and add subviews, assign tags, etc.)
    }
    
    // Customize cell
    cell.textLabel.text = [self.actionOptions objectAtIndex:[indexPath row]];
    
    return cell;
}


 - (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	 
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    
    if ([cell.textLabel.text isEqualToString:@"Play"])
	{
        
       // NSMutableArray *allViewControllers = [NSMutableArray arrayWithArray: self.navigationController.viewControllers];
        //[allViewControllers removeObjectIdenticalTo: playbackController];
        //self.navigationController.viewControllers = allViewControllers;
        if(playbackController==nil)
        {
            playbackController = [[[PlaybackViewController alloc] initWithNibName:@"PlaybackViewController" bundle:nil] autorelease];
        }
        playbackController.bbfile = [self.files objectAtIndex:0];
        [self.navigationController pushViewController:playbackController animated:YES];
        //[playbackController release];

	}
     
	else if ([cell.textLabel.text isEqualToString:@"File Details"])
	{
        
        // Launch a detail view here.
        BBFileDetailViewController *bbdvc = [[BBFileDetailViewController alloc] initWithBBFile:[self.files objectAtIndex:0]];
        [self.navigationController pushViewController:bbdvc animated:YES];
        [bbdvc release];
        
	}
     
    else if ([cell.textLabel.text isEqualToString:@"Find Spikes"])
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
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Can't find spikes" message:@"File is too short or it has low sampling rate."
                                                                   delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
                    [alert show];    
                    [alert release];
                });
                
            }
            
        });
        
    }
    else if ([cell.textLabel.text isEqualToString: @"Autocorrelation"])
	{
        
        AutoGraphViewController *autovc = [[AutoGraphViewController alloc] initWithNibName:@"AutoGraphViewController" bundle:nil];
        [autovc setFileForGraph:(BBFile *)[self.files objectAtIndex:0]];
        [self.navigationController pushViewController:autovc animated:YES];
        [autovc release];

      /*  if([(BBFile *)[self.files objectAtIndex:0] numberOfSpikeTrains]<2)
        {
            MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
            hud.labelText = @"Calculating...";
            dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                NSArray * values = [[BBAnalysisManager bbAnalysisManager] autocorrelationWithFile:(BBFile *)[self.files objectAtIndex:0] spikeTrainIndex:0  maxtime:0.1f andBinsize:0.001f];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [MBProgressHUD hideHUDForView:self.view animated:YES];
                    AutocorrelationGraphViewController *avc = [[AutocorrelationGraphViewController alloc] initWithNibName:@"AutocorrelationGraphViewController" bundle:nil];
                    avc.values = values;
                    [self.navigationController pushViewController:avc animated:YES];
                    [avc release];
                });
            });
        }
        else
        {
            SpikeTrainsTableViewController *avc = [[SpikeTrainsTableViewController alloc] initWithFile:(BBFile *)[self.files objectAtIndex:0] andFunction:kAUTOCORRELATION];
            [self.navigationController pushViewController:avc animated:YES];
            [avc release];
            
        }*/
        
    }
    else if ([cell.textLabel.text isEqualToString: @"ISI"])
	{
        
      /*  if([(BBFile *)[self.files objectAtIndex:0] numberOfSpikeTrains]<2)
        {
            
        }
        else
        {*/
            

            ISIGraphViewController *isivc = [[ISIGraphViewController alloc] initWithNibName:@"ISIGraphViewController" bundle:nil];
            [isivc setFileForGraph:(BBFile *)[self.files objectAtIndex:0]];
            [self.navigationController pushViewController:isivc animated:YES];
            [isivc release];
            
            

       /* }*/
        
       /* if([(BBFile *)[self.files objectAtIndex:0] numberOfSpikeTrains]<2)
        {
            MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
            hud.labelText = @"Calculating...";
            dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                
                NSMutableArray* values = [[NSMutableArray alloc] initWithCapacity:0];
                NSMutableArray* limits = [[NSMutableArray alloc] initWithCapacity:0];
                
                [[BBAnalysisManager bbAnalysisManager] ISIWithFile:(BBFile *)[self.files objectAtIndex:0] spikeTrainIndex:0  maxtime:0.1f numOfBins:100 values:values limits:limits ];
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
        else
        {
            SpikeTrainsTableViewController *avc = [[SpikeTrainsTableViewController alloc] initWithFile:(BBFile *)[self.files objectAtIndex:0] andFunction:kISI];
            [self.navigationController pushViewController:avc animated:YES];
            [avc release];
        
        }*/
    }
    else if ([cell.textLabel.text isEqualToString: @"Cross-correlation"])
    {
        
        //GraphMatrixViewController
        GraphMatrixViewController *gmvc = [[GraphMatrixViewController alloc] initWithNibName:@"GraphMatrixViewController" bundle:nil];
        gmvc.bbfile = (BBFile *)[self.files objectAtIndex:0];
        [self.navigationController pushViewController:gmvc animated:YES];
        [gmvc release];

        
       /* if([(BBFile *)[self.files objectAtIndex:0] numberOfSpikeTrains]==2)
        {
            MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
            hud.labelText = @"Calculating...";
            dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                NSArray *values = [[BBAnalysisManager bbAnalysisManager] crosscorrelationWithFile:(BBFile *)[self.files objectAtIndex:0] firstSpikeTrainIndex:0 secondSpikeTrainIndex:1 maxtime:0.1 andBinsize:0.001f];
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
            
            SelectCrosscorelTableViewController *avc = [[SelectCrosscorelTableViewController alloc] initWithFile:(BBFile *)[self.files objectAtIndex:0]];
            [self.navigationController pushViewController:avc animated:YES];
            [avc release];
            
        }*/
    }
	else if ([cell.textLabel.text isEqualToString:@"Share"])
	{
        //grab just the filenames
        NSMutableArray *theFilenames = [[NSMutableArray alloc] initWithObjects:nil];
		for (BBFile *thisFile in self.files)
        {
            [thisFile saveWithoutArrays];
            [theFilenames addObject:[NSURL fileURLWithPath:[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:thisFile.filename]]];

        }
        self.fileNamesToShare = (NSArray *)theFilenames;
        [theFilenames release];
        

        UIActivityViewController * activities = [[[UIActivityViewController alloc]
                                                 initWithActivityItems:theFilenames
                                                 applicationActivities:nil] autorelease];
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [[[self parentViewController] parentViewController] presentViewController:activities animated:YES completion:nil];

        }
        else
        {
            [self presentViewController:activities
                               animated:YES
                             completion:nil];
            
        }

	}
	else if ([cell.textLabel.text isEqualToString:@"Delete"])
	{
        
        NSString *deleteTitle;
        if ([self.files count] == 1)
            deleteTitle = [NSString stringWithFormat:@"Delete \"%@?\"", [[self.files objectAtIndex:0] shortname]];
        else
            deleteTitle = [NSString stringWithFormat:@"Delete %u files?", [self.files count]];
        
        UIActionSheet *mySheet = [[UIActionSheet alloc] initWithTitle:deleteTitle
                                                             delegate:self 
													cancelButtonTitle:@"No, go back."
                                               destructiveButtonTitle:@"Yes, delete!" 
													otherButtonTitles:nil];
        
        mySheet.actionSheetStyle = UIActionSheetStyleBlackOpaque;
        [mySheet showInView:self.view];
        [mySheet release];
        
    }
}

//Delete files action sheet
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	
	switch (buttonIndex) {
		case 0:
			[self.delegate deleteTheFiles:self.files];
            [self.navigationController popViewControllerAnimated:YES];//tk consider reordering
			break;
		default:
			break;
	}
	
}

- (void)emailFiles {
	
	// If we can't send email right now, let the user know about it
	if (![MFMailComposeViewController canSendMail]) {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Can't Send Mail" message:@"Can't send mail right now. Double-check that your email client is set up and you have an internet connection"
													   delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
		[alert show];    
		[alert release];
		
		return;
	}
	
	MFMailComposeViewController *message = [[MFMailComposeViewController alloc] init];
	message.mailComposeDelegate = self;
	
	[message setSubject:@"A recording from my Backyard Brains app!"];
    
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    for (BBFile *thisFile in self.files)
    {
        NSString *fullFilePath = [docPath stringByAppendingPathComponent:thisFile.filename];
        NSData *attachmentData = [NSData dataWithContentsOfFile:fullFilePath];
        [message addAttachmentData:attachmentData mimeType:@"audio/wav" fileName:thisFile.filename];
        // 32kadpcm
    }
    
    NSMutableString *bodyText = [NSMutableString stringWithFormat:@"<p>I recorded these files:"];
    for (BBFile *thisFile in self.files)
    {
        [bodyText appendFormat:@"<p>\"%@,\" ", thisFile.shortname];
        
        int minutes = (int)floor(thisFile.filelength / 60.0);
        int seconds = (int)(thisFile.filelength - minutes*60.0);
        
        if (minutes > 0) {
            [bodyText appendFormat: @"which lasted %d minutes and %d seconds.</p>", minutes, seconds];
        }
        else {
            [bodyText appendFormat:@"which lasted %d seconds.</p>", seconds];
        }
        
        
        [bodyText appendFormat:@"<p>Some other info about the file: <br>Sampling rate: %0.0f<br>", thisFile.samplingrate];
        [bodyText appendFormat:@"Gain: %0.0f</p>", thisFile.gain];
        [bodyText appendFormat:@"<p>%@</p>", thisFile.comment];
    }
    
	[message setMessageBody:bodyText isHTML:YES];
	
    [self presentViewController:message animated:YES completion:nil];
	[message release];
    
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)downloadFiles
{

}



@end
