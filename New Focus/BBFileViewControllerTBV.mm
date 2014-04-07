//
//  BBFileTableViewControllerTBV.m
//  Backyard Brains
//
//  Created by Zachary King on 9-15-2011
//  Copyright 2011 Backyard Brains. All rights reserved.
//


#import "BBFileViewControllerTBV.h"
#import "MyAppDelegate.h"

#define kSyncWaitTime 10 //seconds

@interface BBFileViewControllerTBV()

- (void)populateSelectedArray;
- (void)populateSelectedArrayWithSelectionAt:(int)num;

- (void)pushActionView;

- (NSString *)stringWithFileLengthFromBBFile:(BBFile *)thisFile;

- (void)dbButtonPressed;
- (void)pushDropboxSettings;
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex;
- (void)dbDisconnect;
- (void)dbUpdate;
- (void)dbUpdateTimedOut;
- (void)clearStatus;
- (void)compareBBFilesToNewFilePaths:(NSArray *)newPaths;


@property (nonatomic, retain) UIImage *selectedImage;
@property (nonatomic, retain) UIImage *unselectedImage;

@property (nonatomic, retain) NSDictionary *preferences;

@property (nonatomic, retain) DBRestClient *restClient;
@property (nonatomic, retain) NSString *status;
@property (nonatomic, retain) NSTimer *syncTimer;
@property (nonatomic, retain) NSArray *lastFilePaths;
@property (nonatomic, retain) NSString *docPath;

@end





@implementation BBFileViewControllerTBV


@synthesize theTableView, toolbar;
//@synthesize activityIndicator;
@synthesize allFiles;

@synthesize selectedArray;
@synthesize selectedImage, unselectedImage;

@synthesize inPseudoEditMode;
@synthesize filesSelectedForAction;
@synthesize preferences;
@synthesize restClient;
@synthesize status, syncTimer, lastFilePaths, docPath;

@synthesize popoverController, splitViewController, rootPopoverButtonItem;

@synthesize dbStatusBar, triedCreatingFolder;
@synthesize filesHash;


#pragma mark - Memory management

- (void)dealloc {
    [popoverController release];
    [rootPopoverButtonItem release];
    [theTableView release];
    [dbStatusBar release];
	[allFiles release];
    [filesSelectedForAction release];
	[selectedArray release];
	[selectedImage release];
	[unselectedImage release];
    [preferences release];
    [restClient release];
    [status release];
    [syncTimer release];
    [lastFilePaths release];
    [filesHash release];
    [super dealloc];
}





#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    //grab preferences
    NSString *pathStr = [[NSBundle mainBundle] bundlePath];
    NSString *finalPath = [pathStr stringByAppendingPathComponent:@"BBFileViewController.plist"];
    self.preferences = [NSDictionary dictionaryWithContentsOfFile:finalPath];
    
    
    self.theTableView = self.tableView;
    self.theTableView.rowHeight = 54;
    
    if (self.selectedImage==nil)
        self.selectedImage = [UIImage imageNamed:@"selected.png"];
    if (self.unselectedImage==nil)
        self.unselectedImage =  [UIImage imageNamed:@"unselected.png"];
    
    //create the status bar
    if (self.dbStatusBar==nil)
    {
        self.dbStatusBar = [[[UIButton alloc] initWithFrame:CGRectMake(self.theTableView.frame.origin.x, self.toolbar.frame.size.height, self.theTableView.frame.size.width, 0)] autorelease];
        [self.dbStatusBar setBackgroundColor:[UIColor colorWithRed:0 green:0 blue:1 alpha:0.5]];
        [self.dbStatusBar setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
        //[self.dbStatusBar setTitle:@"bar" forState:UIControlStateNormal];
        [self.view addSubview:self.dbStatusBar];
    }
    
    //grab the doc path
    self.docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    self.triedCreatingFolder = NO;
    
    self.docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
}

-(void) viewDidUnload {
	[super viewDidUnload];
	
	self.splitViewController = nil;
	self.rootPopoverButtonItem = nil;
    
    //save preferences
    NSString *pathStr = [[NSBundle mainBundle] bundlePath];
	NSString *finalPath = [pathStr stringByAppendingPathComponent:@"BBFileViewController.plist"];
	[self.preferences writeToFile:finalPath atomically:YES];

}



- (void)viewWillAppear:(BOOL)animated 
{	
	[super viewWillAppear:animated];
    
    
    self.title = @"Recordings";
    
    if (self.navigationItem.leftBarButtonItem.action==nil)
//        self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc]
//                                       initWithTitle:@"Select"
//                                               style:UIBarButtonItemStylePlain 
//                                              target:self 
//                                              action:@selector(togglePseudoEditMode)] 
//                            autorelease];
    
    if (self.navigationItem.rightBarButtonItem==nil) {
        UIImage *dbImage = [UIImage imageNamed:@"dropbox.png"];
        self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:dbImage style:UIBarButtonItemStylePlain target:self action:@selector(dbButtonPressed)] autorelease];
        self.navigationItem.rightBarButtonItem.width = dbImage.size.width;
    }
    
	self.allFiles = [NSMutableArray arrayWithArray:[BBFile allObjects]];
    
    self.contentSizeForViewInPopover =
        CGSizeMake(310.0, (self.tableView.rowHeight * ([self.allFiles count] +1)));
    
    self.inPseudoEditMode = NO;
    
    [self populateSelectedArray];
	
	[theTableView reloadData];
    
    //react on new file, we have to refresh table and display file
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(newFileAddedViaShare)
                                                 name:@"FileReceivedViaShare"
                                               object:nil];
    
    //check if we should open new share file
    MyAppDelegate * appDelegate = (MyAppDelegate*)[[UIApplication sharedApplication] delegate];
    if([appDelegate sharedFileShouldBeOpened])
    {
        if ([self.allFiles count] > 0)
        {
            NSIndexPath* ipath = [NSIndexPath indexPathForRow: [self.allFiles count]-1 inSection: 0];
            [theTableView scrollToRowAtIndexPath: ipath atScrollPosition: UITableViewScrollPositionTop animated: YES];
            [self tableView:theTableView didSelectRowAtIndexPath:ipath];
        }
        [appDelegate sharedFileIsOpened];
    }


}

//Refresh table to display new shared file
-(void) newFileAddedViaShare
{
    self.allFiles = [NSMutableArray arrayWithArray:[BBFile allObjects]];
    self.contentSizeForViewInPopover =
    CGSizeMake(310.0, (self.tableView.rowHeight * ([self.allFiles count] +1)));
    self.inPseudoEditMode = NO;
    [self populateSelectedArray];
    [theTableView reloadData];
    //scroll to bottom
   
    
    if ([self.allFiles count] > 0)
    {
        NSIndexPath* ipath = [NSIndexPath indexPathForRow: [self.allFiles count]-1 inSection: 0];
        [theTableView scrollToRowAtIndexPath: ipath atScrollPosition: UITableViewScrollPositionTop animated: YES];
        [self tableView:theTableView didSelectRowAtIndexPath:ipath];
    }
    MyAppDelegate * appDelegate = (MyAppDelegate*)[[UIApplication sharedApplication] delegate];
    [appDelegate sharedFileIsOpened];
    
}

-(void) viewWillDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"FileReceivedViaShare" object:nil];
}

#pragma mark - Rotation support



#pragma mark - TableViewDataSource & UITableViewDelegate


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}




// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    
	if (indexPath.section == 0)
	{
		static int numcellsmade = 0;
		numcellsmade += 1;
		
		static NSString *CellIdentifier = @"BBFileTableCell";    
		BBFileTableCell *cell = (BBFileTableCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
		if (cell == nil) 
		{
            
			NSArray *topLevelObjects = [[NSBundle mainBundle] loadNibNamed:@"BBFileTableCell" owner:nil options:nil];
			
			for(id currentObject in topLevelObjects)
			{
				if([currentObject isKindOfClass:[BBFileTableCell class]])
				{
					cell = (BBFileTableCell *)currentObject;
					break;
				}
			}
		}
		
		BBFile *thisFile = [allFiles objectAtIndex:indexPath.row];
		
		if (thisFile.filelength > 0) {
			cell.lengthname.text = [self stringWithFileLengthFromBBFile:thisFile];
		} else {
			cell.lengthname.text = @"";
		}
		
		cell.shortname.text = thisFile.shortname; //[[allFiles objectAtIndex:indexPath.row] shortname];
		cell.subname.text = thisFile.subname; //[[allFiles objectAtIndex:indexPath.row] subname];
        
        if (self.inPseudoEditMode)
        {
            CGRect labelRect =  CGRectMake(36, 11, 216, 21);
            CGRect subRect =    CGRectMake(36, 29, 216, 15);
            
            
            cell.actionButton.hidden = NO;
            if ([[self.selectedArray objectAtIndex:[indexPath row]] boolValue])
                [cell.actionButton setImage:self.selectedImage forState:normal];
            else
                [cell.actionButton setImage:self.unselectedImage forState:normal];
            
            [cell.shortname setFrame:labelRect];
            [cell.subname setFrame:subRect];
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
        
        return cell;
	}
	else if (indexPath.section == 1)
	{
		static NSString *CellIdentifier = @"editMultipleCell";    
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil)
        {
            cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"editMultipleCell"] autorelease];
            
            cell.textLabel.text = @"Edit multiple files";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        return cell;
	}
	
    return NULL;
}
 

//UITableViewDelegate
- (void)tableView:(UITableView *)tableView willDisplayCell:(BBFileTableCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([indexPath indexAtPosition:0] == 0) //section # is 0
    {
        cell.delegate = self;
    }
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0) //tk or is it 1?
	{
		return [allFiles count];
	} else if (section == 1) {
        
        if ([self.selectedArray containsObject:[NSNumber numberWithBool:YES]])
            return 1; //for multiple edit
        else
            return 0;
	}
    return 0;
}

- (void)checkForNewFilesAndReload
{
	self.allFiles = [NSMutableArray arrayWithArray:[BBFile allObjects]];
    [self.theTableView reloadData];
}

#pragma mark - Table view selection

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSLog(@"=== Cell selected! === ");
    
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    
    [self cellActionTriggeredFrom:(BBFileTableCell *)[tableView cellForRowAtIndexPath:indexPath]];
    
}


- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
	
	if ([indexPath indexAtPosition:0] == 0)
    {
		// Note the BBFile for the particular row that's selected.
        [self populateSelectedArrayWithSelectionAt:indexPath.row];
        [self pushActionView];
    }
}

- (void)pushActionView
{
    // Create the action view controller, load it with the delegate, and push it up onto the stack.
    NSMutableArray *theFiles = [[NSMutableArray alloc] initWithObjects:nil];
    
    for (int i = 0; i < [self.selectedArray count]; i++)
    {
        if ([[self.selectedArray objectAtIndex:i] boolValue])
        {
            BBFile *file = [self.allFiles objectAtIndex:i];
            [theFiles addObject:file];
        }
    }
    self.filesSelectedForAction = (NSArray *)theFiles;
    [theFiles release];
    
    BBFileActionViewControllerTBV *actionViewController = [[BBFileActionViewControllerTBV alloc] init];
    actionViewController.delegate = self;
    
    
    [self.navigationController pushViewController:actionViewController animated:YES];
    [actionViewController release];
}




#pragma mark Select multiple functions


- (IBAction)togglePseudoEditMode
{
    //toggle the mode
    self.inPseudoEditMode = !inPseudoEditMode;
    
    //reset the selected array
    [self populateSelectedArray];
    
    //set up animations
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:.25];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
    
    //set new frames
    if(inPseudoEditMode) {
        
        self.navigationItem.leftBarButtonItem.title = @"Select";
        self.navigationItem.leftBarButtonItem.style = UIBarButtonItemStyleDone;
        
        for (NSIndexPath *path in self.theTableView.indexPathsForVisibleRows)
        {
            if ([path indexAtPosition:0] == 0) //section # is 0
            {
                BBFileTableCell *cell = (BBFileTableCell *)[self.theTableView cellForRowAtIndexPath:path];
                
                
                CGRect labelRect =  CGRectMake(36, 11, 216, 21);
                CGRect subRect =    CGRectMake(36, 29, 216, 15);
                
                
                cell.actionButton.hidden = NO;
                [cell.actionButton setImage:self.unselectedImage forState:normal];
                [cell.shortname setFrame:labelRect];
                [cell.subname setFrame:subRect];
                cell.accessoryType = UITableViewCellAccessoryNone;
                
            }
        }
        
    } else { //not in pseudo edit mode
        
        self.navigationItem.leftBarButtonItem.title = @"Select";
        self.navigationItem.leftBarButtonItem.style = UIBarButtonItemStylePlain;
        
        for (NSIndexPath *path in self.theTableView.indexPathsForVisibleRows)
        {
            if ([path indexAtPosition:0] == 0) //section # is 0
            {
                BBFileTableCell *cell = (BBFileTableCell *)[self.theTableView cellForRowAtIndexPath:path];
                
                
                CGRect labelRect =  CGRectMake(13, 11, 216, 21);
                CGRect subRect =    CGRectMake(13, 29, 216, 15);
                
                cell.actionButton.hidden = YES;
                [cell.shortname setFrame:labelRect];
                [cell.subname setFrame:subRect];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }
        }
    }
    
    //do the animation
    [UIView commitAnimations];
    
	[self.theTableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
}



- (void)populateSelectedArray
{
    NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:[allFiles count]];
	for (int i=0; i < [allFiles count]; i++)
		[array addObject:[NSNumber numberWithBool:NO]];
	self.selectedArray = array;
	[array release];
}

- (void)populateSelectedArrayWithSelectionAt:(int)num
{
    NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:[allFiles count]];
	for (int i=0; i < [allFiles count]; i++)
        if (num == i)
            [array addObject:[NSNumber numberWithBool:YES]];
        else
            [array addObject:[NSNumber numberWithBool:NO]];
	self.selectedArray = array;
	[array release];
}


- (void)cellActionTriggeredFrom:(BBFileTableCell *) cell
{
    NSUInteger theRow = [[theTableView indexPathForCell:cell] row];
    NSLog(@"Cell at row %u", theRow);
    
    if ([[self.theTableView indexPathForCell:cell] section] == 0)
    {
        //Check for pseudo edit mode
        if (inPseudoEditMode)
        {
            
            BOOL selected = ![[selectedArray objectAtIndex:theRow] boolValue];
            [selectedArray replaceObjectAtIndex:theRow withObject:[NSNumber numberWithBool:selected]];
            
            NSLog(@"Cell is selected: %i", selected);
            
            if (selected)
            {
                [cell.actionButton setImage:[UIImage imageNamed:@"selected.png"] forState:UIControlStateNormal];
                
                NSLog(@"Swapped image for selectedImage ");
            } else {
                [cell.actionButton setImage:self.unselectedImage forState:UIControlStateNormal];
            }
            
            [self.theTableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
        } else {
            
            [self populateSelectedArrayWithSelectionAt:theRow];
            [self pushActionView];
        }
    } else {
        //Select Multiple Button. selectedArray already set.
        [self pushActionView];
    }
}



#pragma mark - DropBox methods

- (void)dbButtonPressed
{
    if ([[DBSession sharedSession] isLinked])
    {
        //push action sheet
        UIActionSheet *mySheet = [[UIActionSheet alloc] initWithTitle:@"Dropbox" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Disconnect from Dropbox" otherButtonTitles:@"Change login settings", @"Upload now", nil];
        
        mySheet.actionSheetStyle = UIActionSheetStyleBlackOpaque;
//        [mySheet showInView:self.view];
        [mySheet showFromTabBar:self.tabBarController.tabBar];
        [mySheet release];
        
    }
    else
        [self pushDropboxSettings];
}

- (void)pushDropboxSettings
{
     [[DBSession sharedSession] linkFromController:self];
}


- (void)dbDisconnect
{
    self.preferences = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:@"isDBLinked"];
    [self setStatus:@"Disconnected from Dropbox"];
    
    // IF YOU DISCONNECT
    // WHY WOULD YOU THEN TRY TO UPLOAD FILES
    // I AM CONFUSED
    [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(clearStatus) userInfo:nil repeats:NO];
}


- (void)dbUpdate
{
    
    if ([[DBSession sharedSession] isLinked])
    {
        [self setStatus:@"Synchronizing..."];
        [self.restClient loadMetadata:@"/" withHash:filesHash];
        
//        //create a timer here that restClient:(DBRestClient*)client loadedMetadata: can invalidate
//        //timer will call status=@"sync failed"
//        self.syncTimer = [NSTimer scheduledTimerWithTimeInterval:kSyncWaitTime
//                                                          target:self
//                                                        selector:@selector(dbUpdateTimedOut)
//                                                        userInfo:nil
//                                                         repeats:NO];
        
    } else {
        [self setStatus:@""];
    }
}

- (void)dbUpdateTimedOut
{
    [self.syncTimer invalidate];
    [NSTimer scheduledTimerWithTimeInterval:1
                                     target:self
                                   selector:@selector(clearStatus)
                                   userInfo:nil
                                    repeats:NO];
    
    // NO LONGER PUTTING M4As IN SEPARATE FOLDER
    // COMMENTING IN CASE IT BECOMES DESIRABLE IN THE FUTURE
    //try creating the folder and updating again
//    if (!self.triedCreatingFolder) {
//        [self setStatus:@"Creating folder 'BYB files'"];
//        [self.restClient createFolder:@"BYB files"];
//        self.triedCreatingFolder = YES;
//        self.syncTimer = [NSTimer scheduledTimerWithTimeInterval:kSyncWaitTime
//                                                          target:self
//                                                        selector:@selector(dbUpdateTimedOut)
//                                                        userInfo:nil
//                                                         repeats:NO];
//    }
//    else
//    {
//        [self setStatus:@"Upload failed"];
//    }
}

- (void)dbStopUpdate
{
    
    [self setStatus:@""];
    
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    
    CGRect dbBarRect = CGRectMake(self.dbStatusBar.frame.origin.x,
                                  self.theTableView.frame.origin.y,
                                  self.dbStatusBar.frame.size.width,
                                  self.dbStatusBar.frame.size.height);
    [self.dbStatusBar setFrame:dbBarRect];
}

- (void)setStatus:(NSString *)theStatus { //setter
    
    status = theStatus;
    [self.dbStatusBar setTitle:theStatus forState:UIControlStateNormal];
    if ([theStatus isEqualToString:@""])
    {
        CGRect dbBarRect = CGRectMake(self.dbStatusBar.frame.origin.x,
                                      self.dbStatusBar.frame.origin.y,
                                      self.dbStatusBar.frame.size.width, 0);    
        //CGRect tableViewRect = CGRectMake(self.theTableView.frame.origin.x,
        //                                  0,
        //                                  self.theTableView.frame.size.width,
        //                                  self.view.window.frame.size.height);
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:.25];
        [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
        [self.dbStatusBar setFrame:dbBarRect];	
        //[self.theTableView setFrame:tableViewRect];
        [UIView commitAnimations];
    }
    else
    {
        if (self.dbStatusBar.frame.size.height < 20) {
            CGRect dbBarRect = CGRectMake(self.dbStatusBar.frame.origin.x,
                                          self.dbStatusBar.frame.origin.y,
                                          self.dbStatusBar.frame.size.width, 20);    
            //CGRect tableViewRect = CGRectMake(self.theTableView.frame.origin.x,
            //                                  20,
            //                                  self.theTableView.frame.size.width,
            //                                  self.view.window.frame.size.height-20);
            [UIView beginAnimations:nil context:NULL];
            [UIView setAnimationDuration:.25];
            [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
            [self.dbStatusBar setFrame:dbBarRect];	
            //[self.theTableView setFrame:tableViewRect];
            [UIView commitAnimations];
        }
    }
}


- (void)clearStatus
{
    [self setStatus:@""];
}

- (void)compareBBFilesToNewFilePaths:(NSArray *)newPaths
{
    NSMutableArray *filesNeedingUpload   = [NSMutableArray arrayWithCapacity:[self.allFiles count]];
    for (int i = 0; i < [self.allFiles count]; ++i)
        [filesNeedingUpload addObject:[NSNumber numberWithBool:YES]];  //assume all uploads
    
    //for each path
    for (int l = 0; l < [newPaths count]; ++l)
    {
        //for each file
        for (int m = 0; m < [self.allFiles count]; ++m)
        {
            // if there is a match
            if ([[[self.allFiles objectAtIndex:m] filename] isEqualToString:[[newPaths objectAtIndex:l] stringByReplacingOccurrencesOfString:@"/BYB files/" withString:@""]])
            {
                [filesNeedingUpload replaceObjectAtIndex:m withObject:[NSNumber numberWithBool:NO]]; //don't upload that file
            }
        }
        
    }
    
    
    self.allFiles = [NSMutableArray arrayWithArray:[BBFile allObjects]];
    [self.theTableView reloadData];
    
    __block NSInteger count = 0;
    for (int m = 0; m < [filesNeedingUpload count]; ++m)
    {
        if ([[filesNeedingUpload objectAtIndex:m] boolValue])
        {
            NSString *shortName = [[self.allFiles objectAtIndex:m] shortname];
            NSString *actualFilePath = [[self.allFiles objectAtIndex:m] filename];
            NSString *theFile = [shortName stringByAppendingString:@".m4a"];

            NSString *theFilePath = [self.docPath stringByAppendingPathComponent:actualFilePath];
            NSString *dbPath = @"/";
            NSLog(@"Uploading %@ from %@", theFile, theFilePath);
            
            // This is actually where we're uploading
            [self.restClient uploadFile:theFile
                                 toPath:dbPath
                          withParentRev:nil
                               fromPath:theFilePath];
            ++count;
        }
    }
    
    
    NSString *uploadStatus = [NSString stringWithFormat:@"Updated %d files", count];
    [self setStatus:uploadStatus];
    [self.syncTimer invalidate];
    [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(clearStatus) userInfo:nil repeats:NO];
}


#pragma mark DBRestClientDelegate methods


- (void)restClient:(DBRestClient*)client loadedMetadata:(DBMetadata*)metadata
{
    [filesHash release];
    filesHash = [metadata.hash retain];
    
    NSArray* validExtensions = [NSArray arrayWithObjects:@"aif", @"aiff", @"mp4", @"m4a", nil];
    NSMutableArray* newFilePaths = [NSMutableArray new];
    for (DBMetadata* child in metadata.contents) {
    	NSString* extension = [[child.path pathExtension] lowercaseString];
        if (!child.isDirectory && [validExtensions indexOfObject:extension] != NSNotFound) {
            [newFilePaths addObject:child.path];
        }
    }
    
    [self compareBBFilesToNewFilePaths:(NSArray *)newFilePaths];
    self.lastFilePaths = newFilePaths;
    [newFilePaths release];
}


- (void)restClient:(DBRestClient *)client loadMetadataFailedWithError:(NSError *)error
{
    self.preferences = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:@"isDBLinked"];
    NSLog(@"Error loading metadata: %@", error);
    [self clearStatus];
    
    // If we have unlinked, and we get an error, don't worry about it.
    BOOL isLinked = [[self.preferences valueForKey:@"isDBLinked"] boolValue];
//    NSString *pathStr = [[NSBundle mainBundle] bundlePath];
//    NSString *finalPath = [pathStr stringByAppendingPathComponent:@"BBFileViewController.plist"];
//    NSDictionary *pref = [NSDictionary dictionaryWithContentsOfFile:finalPath];
//    BOOL isLinked = [[pref objectForKey:@"isDBLinked"] boolValue];
    
    if (isLinked)
    {
        NSLog(@"We're supposed to be LINKED");
        // If we think we're linked, we need to ask the user to reauthenticate.
        [[DBSession sharedSession] linkFromController:self];
    }
    else
    {
        NSLog(@"We're not linked, we don't think we are, no big deal.");
        // If we don't think we're linked, then we have nothing to do here.
        return;
    }

}


- (void)restClient:(DBRestClient*)client uploadedFile:(NSString*)destPath from:(NSString*)srcPath metadata:(DBMetadata*)metadata
{
    NSLog(@"File uploaded successfully to path: %@", metadata.path);
}

- (void)restClient:(DBRestClient*)client uploadFileFailedWithError:(NSError*)error
{
    NSLog(@"File upload failed with error - %@", error);
}


- (void)restClient:(DBRestClient*)client metadataUnchangedAtPath:(NSString*)path {
    [self compareBBFilesToNewFilePaths:self.lastFilePaths];
    NSLog(@"Metadata unchanged");
}


- (DBRestClient*)restClient
{ //getter
    NSLog(@"Getting that rest client");
    if (restClient == nil) {
    	restClient = [[DBRestClient alloc] initWithSession: [DBSession sharedSession]];
    	restClient.delegate = (id)self;
    }
    NSLog(@"Got that rest client");
    return restClient;
}



#pragma mark DBLoginControllerDelegate methods

- (BOOL) handleOpenURL:(NSURL *)url {
    if ([[DBSession sharedSession] handleOpenURL:url]) {
        
        if ([[DBSession sharedSession] isLinked]) {
            NSLog(@"App linked successfully!");
            self.preferences = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"isDBLinked"];
            [self dbUpdate];
        }
        else {
            [self dbUpdate];
        }
        return YES;
    }
    return NO;
}

#pragma mark - Action Sheet delegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	
    if ([actionSheet.title isEqualToString:@"Dropbox"])
    {
        switch (buttonIndex) {
            case 0:
                [self dbDisconnect];
                break;
            case 1:
                [self pushDropboxSettings];
                break;
            case 2:
                [self dbUpdate];
                break;
            default:
                break;
        }
    }
}



#pragma mark - Helper functions

- (NSString *)stringWithFileLengthFromBBFile:(BBFile *)thisFile {
	int minutes = (int)floor(thisFile.filelength / 60.0);
	int seconds = (int)(thisFile.filelength - minutes*60.0);
	
	if (minutes > 0) {
		return [NSString stringWithFormat:@"%dm %ds", minutes, seconds];
	}
	else {
		return [NSString stringWithFormat:@"%ds", seconds];		
	}
	
	
}

#pragma mark - for BBFileActionViewControllerDelegate
- (void)deleteTheFiles:(NSArray *)theseFiles
{
    for (BBFile *file in theseFiles)
    {
        int index = [self.allFiles indexOfObject:file];
        [[self.allFiles objectAtIndex:index] deleteObject];
        [self.allFiles removeObjectAtIndex:index];
        
        [theTableView reloadData];
    }
}


@end




