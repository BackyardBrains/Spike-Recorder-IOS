//
//  TrialActionsViewController.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 8/10/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "TrialActionsViewController.h"
#import "PlaybackViewController.h"
#import "MBProgressHUD.h"

#import "ZipArchive.h"
#import "GraphDCMDTrialViewController.h"

#define ACTION_GRAPH @"Graph"
#define ACTION_PLAY @"Play"
#define ACTION_SORT @"Find Spikes"
#define ACTION_SHARE @"Share"
#define ACTION_DELETE @"Delete"

#define COPY_SPIKE_SORTING_ALERT 1

@interface TrialActionsViewController ()
{
    NSArray *actionOptions;
    
}
   
@end

@implementation TrialActionsViewController

@synthesize currentTrial;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        actionOptions = [[NSArray arrayWithObjects:
                         ACTION_GRAPH,
                         ACTION_PLAY,
                         ACTION_SORT,
                         ACTION_SHARE,
                         ACTION_DELETE, nil] retain];
    }
    return self;
}

#pragma mark - Export trial




-(void) exportTrial
{
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.labelText = @"Packing...";
    
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        NSString * pathToZip = [self packTrial];
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [MBProgressHUD hideHUDForView:self.view animated:YES];
            
            [self openShareDialogWithFile:pathToZip];
        });
    });
    
}



-(void) openShareDialogWithFile:(NSString *) pathToFile
{
    
    NSURL *url = [NSURL fileURLWithPath:pathToFile];
    UIActivityViewController * activities = [[[UIActivityViewController alloc]
                                              initWithActivityItems:@[@"New experiment trial",url]
                                              applicationActivities:nil] autorelease];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activities.popoverPresentationController.sourceView = self.view;
        [[[self parentViewController] parentViewController] presentViewController:activities animated:YES completion:nil];
        
    }
    else
    {
        [self presentViewController:activities
                           animated:YES
                         completion:nil];
    }
    
}


-(NSString *) packTrial
{
    
    NSError *writeError = nil;

    NSDictionary * expDictionary = [currentTrial createTrialDictionaryWithVersion:YES];
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:expDictionary options:NSJSONWritingPrettyPrinted error:&writeError];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

    
    NSString* pathToFile = [self writeString:jsonString toTextFileWithName:@"trial.json"];
    [jsonString release];
    NSMutableArray * arrayOfFiles = [[[NSMutableArray alloc] initWithCapacity:0] autorelease];
    [arrayOfFiles addObject:pathToFile];
    [arrayOfFiles addObject:[[[currentTrial file] fileURL] path]];
    
    
    NSString * pathToReturn =  [self createZipArchiveWithFiles:arrayOfFiles andName:@"trial.zip"];
    
    return pathToReturn;
}


-(NSString *) writeString:(NSString *) content toTextFileWithName:(NSString *) nameOfFile
{
    //get the documents directory:
    NSArray *paths = NSSearchPathForDirectoriesInDomains
    (NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    //make a file name to write the data to using the documents directory:
    NSString *fileName = [NSString stringWithFormat:@"%@/%@",
                          documentsDirectory, nameOfFile];
    //create content - four lines of text
    //save content to the documents directory
    [content writeToFile:fileName
              atomically:NO
                encoding:NSStringEncodingConversionAllowLossy
                   error:nil];
    return fileName;
}


- (NSString*) createZipArchiveWithFiles:(NSArray*)files andName:(NSString*)nameOFile
{
    ZipArchive* zip = [[[ZipArchive alloc] init] autorelease];
    NSArray *paths = NSSearchPathForDirectoriesInDomains
    (NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *zipPath = [NSString stringWithFormat:@"%@/%@",
                         [paths objectAtIndex:0], nameOFile] ;
    
    
    [zip CreateZipFile2:zipPath];
    for (NSString* file in files) {
        [zip addFileToZip:file newname:[file lastPathComponent]];
        
    }
    [zip CloseZipFile2];
    return zipPath;
}




#pragma mark - Table view/source delegate
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [actionOptions count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"TrialOptionsCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }

    cell.textLabel.text = (NSString *)[actionOptions objectAtIndex:indexPath.row];
    
    
    // set the accessory view:
    cell.accessoryType =  UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
    
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    
    if ([cell.textLabel.text isEqualToString:ACTION_GRAPH])
	{
        if([currentTrial.file.spikesFiltered isEqualToString:FILE_SPIKE_SORTED] )
        {
            GraphDCMDTrialViewController * graphController = [[GraphDCMDTrialViewController alloc] initWithNibName:@"GraphDCMDTrialViewController" bundle:nil] ;
            
            graphController.currentTrial = currentTrial;
           
            [self.navigationController pushViewController:graphController animated:YES];
            [graphController release];
            
            
        }
        else
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Can't show graph" message:@"You must first do the spike sorting."
                                                           delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
            [alert show];
            [alert release];
        }
        
        
    }
    else if ([cell.textLabel.text isEqualToString:ACTION_PLAY])
    {
        if(currentTrial.file)
        {
            PlaybackViewController * playbackController = [[PlaybackViewController alloc] initWithNibName:@"PlaybackViewController" bundle:nil] ;
            
            playbackController.bbfile = currentTrial.file;
            playbackController.showNavigationBar = YES;
            [self.navigationController pushViewController:playbackController animated:YES];
            [playbackController release];
        }
    }
    else if ([cell.textLabel.text isEqualToString:ACTION_SORT])
    {
        if(currentTrial.file)
        {
            MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
            hud.labelText = @"Analyzing Spikes";
            dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                
                if([[BBAnalysisManager bbAnalysisManager] findSpikes:currentTrial.file] != -1)
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        [MBProgressHUD hideHUDForView:self.view animated:YES];
                        SpikesAnalysisViewController *avc = [[SpikesAnalysisViewController alloc] initWithNibName:@"SpikesViewController" bundle:nil];
                        avc.bbfile = currentTrial.file;
                        avc.masterDelegate = self;
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
    }
    else if ([cell.textLabel.text isEqualToString:ACTION_SHARE])
    {
        [self exportTrial];
    }
    else if ([cell.textLabel.text isEqualToString:ACTION_DELETE])
    {
        [self.masterDelegate deleteTrial:self.currentTrial];
    }
}


-(void) spikesSortingFinished
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Apply threshold parameters?" message:@"Do you want to apply same thresholds to sort spikes for all trials?"
                                                   delegate:self cancelButtonTitle:@"No" otherButtonTitles: @"Apply", nil];
    alert.tag = COPY_SPIKE_SORTING_ALERT;
    [alert show];
    [alert release];
}


#pragma mark - Alert view delegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1)
    {
        if(alertView.tag == COPY_SPIKE_SORTING_ALERT)
        {
            //Apply same thresholds to all trials
            MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
            hud.labelText = @"Applying...";
            dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                    //Copy thresholds to all trials
                    [self.masterDelegate applySameThresholdsToAllTrials:self.currentTrial];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [MBProgressHUD hideHUDForView:self.view animated:YES];
                    });
            });
            
            
        }
    }
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    self.title = [NSString stringWithFormat:@"Trial (v:%.3f, S:%.3f)",currentTrial.velocity, currentTrial.size];
}



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
