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
#import "ZipArchive.h"
#import "MBProgressHUD.h"

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
        
        self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Export" style:UIBarButtonItemStylePlain target:self action:@selector(exportExperiment:)] autorelease];
    }
}

-(void) exportExperiment:(id) sender
{
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.labelText = @"Packing...";
    
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        NSString * pathToZip = [self packExperiment];
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [MBProgressHUD hideHUDForView:self.view animated:YES];
          
            [self openShareDialogWithFile:pathToZip];
        });
    });
    
}



-(void) openShareDialogWithFile:(NSString *) pathToFile
{

    NSString *text = @"Experiment archive";
    NSURL *url = [NSURL fileURLWithPath:pathToFile];
    self.fileNamesToShare = @[@"New experiment archive",url];
    UIActivityViewController * activities = [[[UIActivityViewController alloc]
                                             initWithActivityItems:self.fileNamesToShare
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


-(NSString *) packExperiment
{

    NSError *writeError = nil;
    //TODO:Add start recording ofset to spikes
   NSDictionary * expDictionary = [_experiment createExperimentDictionary];
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:expDictionary options:NSJSONWritingPrettyPrinted error:&writeError];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    // NSLog(@"JSON Output: %@", jsonString);
    
    NSString* pathToFile = [self writeString:jsonString toTextFileWithName:[NSString stringWithFormat:@"%@.json",_experiment.name ]];
    [jsonString release];
    NSMutableArray * arrayOfFiles = [[[NSMutableArray alloc] initWithCapacity:0] autorelease];
    [arrayOfFiles addObject:pathToFile];
    for(int i=0;i<[_experiment.trials count];i++)
    {
        [arrayOfFiles addObject:[[[((BBDCMDTrial *)[_experiment.trials objectAtIndex:i]) file] fileURL] path]];
    }

    NSString * pathToReturn =  [self createZipArchiveWithFiles:arrayOfFiles andName:[NSString stringWithFormat:@"%@.zip",_experiment.name ]] ;

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
