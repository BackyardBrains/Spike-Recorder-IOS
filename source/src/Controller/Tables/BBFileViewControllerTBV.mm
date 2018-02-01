//
//  BBFileTableViewControllerTBV.m
//  Backyard Brains
//
//  Created by Zachary King on 9-15-2011
//  Copyright 2011 Backyard Brains. All rights reserved.
//


#import "BBFileViewControllerTBV.h"
#import "MyAppDelegate.h"
#import <ObjectiveDropboxOfficial/ObjectiveDropboxOfficial.h>

#define kSyncWaitTime 10 //seconds

@interface BBFileViewControllerTBV()


@property (nonatomic, retain) NSDictionary *preferences;

//@property (nonatomic, retain) DBRestClient *restClient;
@property (nonatomic, retain) NSString *status;
@property (nonatomic, retain) NSTimer *syncTimer;
@property (nonatomic, retain) NSArray *lastFilePaths;
@property (nonatomic, retain) NSString *docPath;

@end





@implementation BBFileViewControllerTBV

//@synthesize activityIndicator;
@synthesize allFiles;





@synthesize filesSelectedForAction;
@synthesize preferences;
//@synthesize restClient;//DropBox
@synthesize status, syncTimer, lastFilePaths, docPath;



@synthesize dbStatusBar;





#pragma mark - View management

- (void)viewDidLoad {
    
    [super viewDidLoad];
    [self.navigationController setNavigationBarHidden:NO animated:NO];
    //grab preferences
    NSString *pathStr = [[NSBundle mainBundle] bundlePath];
    NSString *finalPath = [pathStr stringByAppendingPathComponent:@"BBFileViewController.plist"];
    self.preferences = [NSDictionary dictionaryWithContentsOfFile:finalPath];
    
    
   
    self.tableView.rowHeight = 54;
    
    
    
    //create the status bar
    if (self.dbStatusBar==nil)
    {
        self.dbStatusBar = [[[UIButton alloc] initWithFrame:CGRectMake(self.tableView.frame.origin.x, 0, self.tableView.frame.size.width, 0)] autorelease];
        [self.dbStatusBar setBackgroundColor:[UIColor colorWithRed:0 green:0 blue:1 alpha:0.5]];
        [self.dbStatusBar setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
        //[self.dbStatusBar setTitle:@"bar" forState:UIControlStateNormal];
        [self.view addSubview:self.dbStatusBar];
    }
    
    //grab the doc path
    self.docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    self.docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
}

-(void) viewDidUnload {
    [super viewDidUnload];
    
    //save preferences
    NSString *pathStr = [[NSBundle mainBundle] bundlePath];
    NSString *finalPath = [pathStr stringByAppendingPathComponent:@"BBFileViewController.plist"];
    [self.preferences writeToFile:finalPath atomically:YES];
    
}



- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:NO];
    self.title = @"Recordings";
    
    if (self.navigationItem.rightBarButtonItem==nil) {
        
        UIButton *button1 = [[[UIButton alloc] init] autorelease];
        button1.frame=CGRectMake(0,0,25,25);
        [button1 setBackgroundImage:[UIImage imageNamed: @"dropbox.png"] forState:UIControlStateNormal];
        [button1 addTarget:self action:@selector(dbButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]initWithCustomView:button1];
        self.navigationItem.rightBarButtonItem.width = 25;
    }
    
    self.allFiles = [NSMutableArray arrayWithArray:[BBFile allObjects]];
    
    self.contentSizeForViewInPopover =
    CGSizeMake(310.0, (self.tableView.rowHeight * ([self.allFiles count] +1)));
    
    
    [self.tableView reloadData];
    
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
            NSIndexPath* ipath = [NSIndexPath indexPathForRow: 0 inSection: 0];
            [self.tableView scrollToRowAtIndexPath: ipath atScrollPosition: UITableViewScrollPositionTop animated: YES];
            [self openActionViewWithFile:[self.allFiles objectAtIndex:0]];
        }
        [appDelegate sharedFileIsOpened];
    }
}


-(void) viewWillDisappear:(BOOL)animated
{
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"FileReceivedViaShare" object:nil];
    [super viewWillDisappear:animated];
}


-(void) openActionViewWithFile:(BBFile *) file
{
    // Create the action view controller, load it with the delegate, and push it up onto the stack.
    NSMutableArray *theFiles = [[NSMutableArray alloc] initWithObjects:file,nil];
    
    self.filesSelectedForAction = (NSArray *)theFiles;
    [theFiles release];
    
    BBFileActionViewControllerTBV *actionViewController = [[BBFileActionViewControllerTBV alloc] init];
    actionViewController.delegate = self;
    
    
    [self.navigationController pushViewController:actionViewController animated:YES];
    [actionViewController release];
}


//Refresh table to display new shared file
-(void) newFileAddedViaShare
{
    MyAppDelegate * appDelegate = (MyAppDelegate*)[[UIApplication sharedApplication] delegate];
    if([appDelegate sharedFileShouldBeOpened])
    {
        self.allFiles = [NSMutableArray arrayWithArray:[BBFile allObjects]];
        self.contentSizeForViewInPopover =
        CGSizeMake(310.0, (self.tableView.rowHeight * ([self.allFiles count] +1)));
        [self.tableView reloadData];
        //scroll to bottom
        
        
        if ([self.allFiles count] > 0)
        {
            NSIndexPath* ipath = [NSIndexPath indexPathForRow: 0 inSection: 0];
            [self.tableView scrollToRowAtIndexPath: ipath atScrollPosition: UITableViewScrollPositionTop animated: YES];
            [self openActionViewWithFile:[self.allFiles objectAtIndex:0]];
        }
        MyAppDelegate * appDelegate = (MyAppDelegate*)[[UIApplication sharedApplication] delegate];
        [appDelegate sharedFileIsOpened];
    }
}



#pragma mark - Rotation support



#pragma mark - TableViewDataSource & UITableViewDelegate


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
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
        
        
        
        return cell;
    }
   
    
    return NULL;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) //tk or is it 1?
    {
        return [allFiles count];
    }
    return 0;
}



#pragma mark - Table view selection

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSLog(@"=== Cell selected! === ");
    
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    
    BBFileTableCell * cell = (BBFileTableCell *)[self.tableView cellForRowAtIndexPath:indexPath];
    
    [self cellActionTriggeredFrom:cell];
    
}


- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
    if ([indexPath indexAtPosition:0] == 0)
    {
        // Open selected file
        [self pushActionView:indexPath.row];
    }
}

- (void)pushActionView:(int) indexOfFile
{
    // Create the action view controller, load it with the delegate, and push it up onto the stack.
    NSMutableArray *theFiles = [[NSMutableArray alloc] initWithObjects:nil];
    

    BBFile *file = [self.allFiles objectAtIndex:indexOfFile];
    [theFiles addObject:file];
 
    self.filesSelectedForAction = (NSArray *)theFiles;
    [theFiles release];
    
    BBFileActionViewControllerTBV *actionViewController = [[BBFileActionViewControllerTBV alloc] init];
    actionViewController.delegate = self;
    
    
    [self.navigationController pushViewController:actionViewController animated:YES];
    [actionViewController release];
}


- (void)cellActionTriggeredFrom:(BBFileTableCell *) cell
{
    NSUInteger theRow = [[self.tableView indexPathForCell:cell] row];
    [self pushActionView:theRow];
}

#pragma mark - DropBox methods

- (void)dbButtonPressed
{
    DBUserClient *client = [DBClientsManager authorizedClient];
    
    if (client)
    {
        //push action sheet
        UIActionSheet *mySheet = [[UIActionSheet alloc] initWithTitle:@"Dropbox" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Disconnect from Dropbox" otherButtonTitles:@"Change login settings", @"Upload now", nil];
        
        mySheet.actionSheetStyle = UIActionSheetStyleBlackOpaque;
        //        [mySheet showInView:self.view];
        [mySheet showFromTabBar:self.tabBarController.tabBar];
        [mySheet release];
        
    }
    else
    {
        [self pushDropboxSettings];
    }
}


+ (UIViewController*)topMostController
{
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
    
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    
    return topController;
}




- (void)pushDropboxSettings
{
    [DBClientsManager authorizeFromController:[UIApplication sharedApplication]
                                   controller:[[self class] topMostController]
                                      openURL:^(NSURL *url) {
                                          [[UIApplication sharedApplication] openURL:url];
                                      }];
}


- (void)dbDisconnect
{
    self.preferences = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:@"isDBLinked"];
    [self setStatus:@"Disconnected from Dropbox"];
    [DBClientsManager unlinkAndResetClients];
    // IF YOU DISCONNECT
    // WHY WOULD YOU THEN TRY TO UPLOAD FILES
    // I AM CONFUSED
    [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(clearStatus) userInfo:nil repeats:NO];
}


- (void)dbUpdate
{
    
    DBUserClient *client = [DBClientsManager authorizedClient];
    if (client)
    {
        [self setStatus:@"Connecting to DropBox..."];
        filePathsOnDropBox = [NSMutableArray new];
            [[client.filesRoutes listFolder:@""]
             setResponseBlock:^(DBFILESListFolderResult *response, DBFILESListFolderError *routeError, DBRequestError *networkError) {
                 if (response) {
                     NSArray<DBFILESMetadata *> *entries = response.entries;
                     NSString *cursor = response.cursor;
                     BOOL hasMore = [response.hasMore boolValue];
                     
                     
                     NSArray* validExtensions = [NSArray arrayWithObjects:@"aif", @"aiff", @"mp4", @"m4a", @"wav", nil];

                  
                     for (DBFILESMetadata *entry in entries)
                     {
                         if ([entry isKindOfClass:[DBFILESFileMetadata class]])
                         {
                             DBFILESFileMetadata *fileMetadata = (DBFILESFileMetadata *)entry;
                             NSString* extension = [fileMetadata.pathLower pathExtension];
                             if([validExtensions indexOfObject:extension] != NSNotFound)
                             {
                                 [filePathsOnDropBox addObject:fileMetadata.pathDisplay];
                             }
                         }
                     }

                     if (hasMore) {
                         NSLog(@"Folder is large enough where we need to call `listFolderContinue:`");
                         
                         [self listFolderContinueWithClient:client cursor:cursor];
                     } else {
                         NSLog(@"List folder complete.");
                         [self compareBBFilesToNewFilePaths:filePathsOnDropBox];
                     }
                 } else {
                     NSLog(@"%@\n%@\n", routeError, networkError);
                     [self setStatus:@"Connection failed"];
                     [self.syncTimer invalidate];
                     [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(clearStatus) userInfo:nil repeats:NO];
                 }
             }];
    
    }
}


- (void)listFolderContinueWithClient:(DBUserClient *)client cursor:(NSString *)cursor
{
    
    [[client.filesRoutes listFolderContinue:cursor]
     setResponseBlock:^(DBFILESListFolderResult *response, DBFILESListFolderContinueError *routeError,
                        DBRequestError *networkError) {
         if (response) {
             NSArray<DBFILESMetadata *> *entries = response.entries;
             NSString *cursor = response.cursor;
             BOOL hasMore = [response.hasMore boolValue];
             
             NSArray* validExtensions = [NSArray arrayWithObjects:@"aif", @"aiff", @"mp4", @"m4a", @"wav", nil];
             for (DBFILESMetadata *entry in entries)
             {
                 if ([entry isKindOfClass:[DBFILESFileMetadata class]])
                 {
                     DBFILESFileMetadata *fileMetadata = (DBFILESFileMetadata *)entry;
                     NSString* extension = [fileMetadata.pathLower pathExtension];
                     if([validExtensions indexOfObject:extension] != NSNotFound)
                     {
                         [filePathsOnDropBox addObject:fileMetadata.pathDisplay];
                     }
                 }
             }
             
             if (hasMore) {
                 [self listFolderContinueWithClient:client cursor:cursor];
             } else {
                 NSLog(@"List folder complete.");
                 [self compareBBFilesToNewFilePaths:filePathsOnDropBox];
             }
         } else {
             NSLog(@"%@\n%@\n", routeError, networkError);
             [self setStatus:@"Connection failed"];
             [self.syncTimer invalidate];
             [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(clearStatus) userInfo:nil repeats:NO];
         }
     }];
}





- (void)dbUpdateTimedOut
{
}

- (void)dbStopUpdate
{
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    
    CGRect dbBarRect = CGRectMake(self.dbStatusBar.frame.origin.x,
                                  self.tableView.frame.origin.y,
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
        //CGRect tableViewRect = CGRectMake(self.tableView.frame.origin.x,
        //                                  0,
        //                                  self.tableView.frame.size.width,
        //                                  self.view.window.frame.size.height);
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:.25];
        [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
        [self.dbStatusBar setFrame:dbBarRect];
        //[self.tableView setFrame:tableViewRect];
        [UIView commitAnimations];
    }
    else
    {
        if (self.dbStatusBar.frame.size.height < 20) {
            CGRect dbBarRect = CGRectMake(self.dbStatusBar.frame.origin.x,
                                          self.dbStatusBar.frame.origin.y,
                                          self.dbStatusBar.frame.size.width, 20);
            //CGRect tableViewRect = CGRectMake(self.tableView.frame.origin.x,
            //                                  20,
            //                                  self.tableView.frame.size.width,
            //                                  self.view.window.frame.size.height-20);
            [UIView beginAnimations:nil context:NULL];
            [UIView setAnimationDuration:.25];
            [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
            [self.dbStatusBar setFrame:dbBarRect];
            //[self.tableView setFrame:tableViewRect];
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
    
    //Check if we have already the same files on DropBox
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
            NSString * currentLocalFile = [[[[self.allFiles objectAtIndex:m] fileURL] lastPathComponent] stringByReplacingOccurrencesOfString:@".m4a" withString:@".wav"];
            NSString * fileOnDropBox = [[newPaths objectAtIndex:l] stringByReplacingOccurrencesOfString:@"/" withString:@""];
            if ([currentLocalFile isEqualToString:fileOnDropBox])
            {
                [filesNeedingUpload replaceObjectAtIndex:m withObject:[NSNumber numberWithBool:NO]]; //don't upload that file
            }
        }
        
    }
    
    
    self.allFiles = [NSMutableArray arrayWithArray:[BBFile allObjects]];
    [self.tableView reloadData];
    
    
    //Prepare for upload (make dictionary with settings for each file). Needed for batch upload
    __block NSInteger count = 0;
    NSMutableDictionary<NSURL *, DBFILESCommitInfo *> *uploadFilesUrlsToCommitInfo = [NSMutableDictionary new];
    for (int m = 0; m < [filesNeedingUpload count]; ++m)
    {
        if ([[filesNeedingUpload objectAtIndex:m] boolValue])
        {
            NSString *theFile = [[[[self.allFiles objectAtIndex:m] fileURL] lastPathComponent] stringByReplacingOccurrencesOfString:@".m4a" withString:@".wav"];
            NSString *dbPath = @"/";
            NSString *theFilePath = [dbPath stringByAppendingPathComponent:theFile];
            
            
            NSLog(@"Uploading %@ from %@", theFile, theFilePath);
            DBFILESCommitInfo *commitInfo = [[DBFILESCommitInfo alloc] initWithPath:theFilePath];
            [uploadFilesUrlsToCommitInfo setObject:commitInfo forKey:[[self.allFiles objectAtIndex:m] fileURL]];

            ++count;
        }
    }
    

    //Now batch upload files that are not already there on DropBox
    if(count>0)
    {
        if(count == 1)
        {
            [self setStatus: @"Uploading 1 file"];
        }
        else
        {
            [self setStatus: [NSString stringWithFormat:@"Uploading %ld files",(long)count]];
        }
        DBUserClient *client = [DBClientsManager authorizedClient];
        
        
        [client.filesRoutes batchUploadFiles:uploadFilesUrlsToCommitInfo
                                       queue:nil
                               progressBlock:^(int64_t uploaded, int64_t uploadedTotal, int64_t expectedToUploadTotal) {
                                   NSLog(@"Uploaded: %lld  UploadedTotal: %lld  ExpectedToUploadTotal: %lld", uploaded, uploadedTotal,
                                         expectedToUploadTotal);
                               }
                               responseBlock:^(NSDictionary<NSURL *, DBFILESUploadSessionFinishBatchResultEntry *> *fileUrlsToBatchResultEntries,
                                               DBASYNCPollError *finishBatchRouteError, DBRequestError *finishBatchRequestError,
                                               NSDictionary<NSURL *, DBRequestError *> *fileUrlsToRequestErrors) {
                                   
                                   NSString *uploadStatus;
                                   if (fileUrlsToBatchResultEntries) {
                                       NSLog(@"Call to `/upload_session/finish_batch/check` succeeded");
                                       for (NSURL *clientSideFileUrl in fileUrlsToBatchResultEntries) {
                                           DBFILESUploadSessionFinishBatchResultEntry *resultEntry = fileUrlsToBatchResultEntries[clientSideFileUrl];
                                           if ([resultEntry isSuccess]) {
                                               NSString *dropboxFilePath = resultEntry.success.pathDisplay;
                                               NSLog(@"File successfully uploaded from %@ on local machine to %@ in Dropbox.",
                                                     [clientSideFileUrl path], dropboxFilePath);
                                               uploadStatus = @"Files uploaded";
                                           } else if ([resultEntry isFailure]) {
                                               // This particular file was not uploaded successfully, although the other
                                               // files may have been uploaded successfully. Perhaps implement some retry
                                               // logic here based on `uploadNetworkError` or `uploadSessionFinishError`
                                               //DBRequestError *uploadNetworkError = fileUrlsToRequestErrors[clientSideFileUrl];
                                               //DBFILESUploadSessionFinishError *uploadSessionFinishError = resultEntry.failure;
                                               
                                               // implement appropriate retry logic
                                               uploadStatus = @"Upload failed (#1)";
                                           }
                                       }
                                   }
                                   
                                   if (finishBatchRouteError) {
                                       NSLog(@"Either bug in SDK code, or transient error on Dropbox server");
                                       NSLog(@"%@", finishBatchRouteError);
                                       uploadStatus = @"Upload failed (#2)";
                                   } else if (finishBatchRequestError) {
                                       NSLog(@"Request error from calling `/upload_session/finish_batch/check`");
                                       NSLog(@"%@", finishBatchRequestError);
                                       uploadStatus = @"Upload failed (#3)";
                                   } else if ([fileUrlsToRequestErrors count] > 0) {
                                       NSLog(@"Other additional errors (e.g. file doesn't exist client-side, etc.).");
                                       NSLog(@"%@", fileUrlsToRequestErrors);
                                       uploadStatus = @"Upload failed (#4)";
                                   }
                                   
                                   
                                   [self setStatus:uploadStatus];
                                   [self.syncTimer invalidate];
                                   [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(clearStatus) userInfo:nil repeats:NO];
                               }];
        
    }
    else
    {
        [self setStatus:@"No new files to upload"];
        [self.syncTimer invalidate];
        [NSTimer scheduledTimerWithTimeInterval:2.0f target:self selector:@selector(clearStatus) userInfo:nil repeats:NO];
    }

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
        
        [self.tableView reloadData];
    }
}


#pragma mark - Memory management

- (void)dealloc
{
    [dbStatusBar release];
    [allFiles release];
    [filesSelectedForAction release];
    [docPath release];
    [preferences release];
    [status release];
    [syncTimer release];
    [lastFilePaths release];
    [super dealloc];
}



@end



