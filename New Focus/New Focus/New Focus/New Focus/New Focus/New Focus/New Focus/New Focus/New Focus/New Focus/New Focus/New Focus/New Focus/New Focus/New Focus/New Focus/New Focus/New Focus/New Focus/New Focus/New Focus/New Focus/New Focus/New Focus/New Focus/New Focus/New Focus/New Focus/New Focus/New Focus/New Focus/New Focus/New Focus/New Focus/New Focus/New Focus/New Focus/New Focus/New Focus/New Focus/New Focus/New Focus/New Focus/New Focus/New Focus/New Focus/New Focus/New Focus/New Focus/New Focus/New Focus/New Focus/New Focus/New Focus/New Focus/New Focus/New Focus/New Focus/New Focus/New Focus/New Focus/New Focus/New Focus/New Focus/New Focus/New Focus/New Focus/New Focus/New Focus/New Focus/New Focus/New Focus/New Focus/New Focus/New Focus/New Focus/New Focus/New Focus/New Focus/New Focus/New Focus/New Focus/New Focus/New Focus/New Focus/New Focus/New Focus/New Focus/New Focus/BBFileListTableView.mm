//
//  BBFileListTableView.m
//  New Focus
//
//  Created by Alex Wiltschko on 7/8/12.
//  Copyright (c) 2012 Datta Lab, Harvard University. All rights reserved.
//

#import "BBFileListTableView.h"

// We need to make a very simple class
// that will describe the actions we can do with a single file.
// We're doing this, because it's easy with SensibleCocoa TableViews to automatically
// generate tables from objects.

@interface BBFileListTableView()

@property (nonatomic, retain) NSMutableArray *bbFiles;

@end

@implementation BBFileListTableView
@synthesize bbFiles;


- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Recordings";
    
    self.navigationBarType = SCNavigationBarTypeEditLeft;
    
    // Grab the BBFiles
    bbFiles = [NSMutableArray arrayWithArray:[BBFile allObjects]];
    
    SCClassDefinition *fileDef = [SCClassDefinition
                                  definitionWithClass:[BBFile class]
                                  propertyNamesString:@"shortname;subname;filelength"];
    
    SCArrayOfObjectsSection *filesSection = [SCArrayOfObjectsSection sectionWithHeaderTitle:nil items:bbFiles itemsDefinition:fileDef];
    
    filesSection.cellActions.willConfigure = ^(SCTableViewCell *cell, NSIndexPath *indexPath) {
        
        BBFile *currentFile = [bbFiles objectAtIndex:indexPath.row];
        
        cell.height =  60;
        cell.textLabel.text = currentFile.shortname;
        cell.detailTextLabel.text = currentFile.subname;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        UILabel *time = [[UILabel alloc] initWithFrame:CGRectMake(200, 16, 80, 25)];
        
        int minutes = (int)floor(currentFile.filelength / 60.0);
        int seconds = (int)(currentFile.filelength - minutes*60.0);
        
        if (minutes > 0) {
            time.text = [NSString stringWithFormat:@"%dm %ds", minutes, seconds];
        }
        else {
            time.text =  [NSString stringWithFormat:@"%ds", seconds];		
        }

        time.textAlignment = NSTextAlignmentRight;
        time.font = [UIFont fontWithName:@"Helvetica" size:16];
        [cell addSubview:time];
        [time release];
        

        
    };
    
    filesSection.cellActions.didSelect = ^(SCTableViewCell *cell, NSIndexPath *indexPath) {
        
        // Launch a detail view here.
        BBFileDetailViewController *bbdvc = [[BBFileDetailViewController alloc] initWithBBFile:[bbFiles objectAtIndex:indexPath.row]];
        [self.navigationController pushViewController:bbdvc animated:YES];
        [bbdvc release];
        
        [self.tableViewModel.modeledTableView deselectRowAtIndexPath:indexPath animated:YES];
    };
                                           

    self.navigationBarType = SCNavigationBarTypeEditLeft;
    
    [self.tableViewModel addSection:filesSection];
    

    // File Definition
    // ========================================
    
    // File Definition
    // ========================================
    /*
    SCClassDefinition *fileDef = [SCClassDefinition
                                  definitionWithClass:[BBFile class]
                                  propertyNamesString:@"shortname;comment;subname;samplingrate;gain;filelength;play"];
    
    SCPropertyDefinition *titlePropertyDef = [fileDef propertyDefinitionWithName:@"shortname"];
    titlePropertyDef.type = SCPropertyTypeTextField;
    titlePropertyDef.title = @"Filename";
    
    SCPropertyDefinition *dateDef = [fileDef propertyDefinitionWithName:@"subname"];
    dateDef.type = SCPropertyTypeLabel;
    dateDef.title = @"Recorded On:";
    
    SCPropertyDefinition *samplingRateDef = [fileDef propertyDefinitionWithName:@"samplingrate"];
    samplingRateDef.type = SCPropertyTypeLabel;
    samplingRateDef.title = @"Sampling Rate:";
    
    SCPropertyDefinition *gainDef = [fileDef propertyDefinitionWithName:@"gain"];
    gainDef.type = SCPropertyTypeLabel;
    gainDef.title = @"Gain:";
    
    SCPropertyDefinition *fileLengthDef = [fileDef propertyDefinitionWithName:@"filelength"];
    fileLengthDef.type = SCPropertyTypeLabel;
    fileLengthDef.title = @"File Length (s):";    
    
    SCPropertyDefinition *descPropertyDef = [fileDef
                                             propertyDefinitionWithName:@"comment"];
    descPropertyDef.type = SCPropertyTypeTextView;
    descPropertyDef.attributes = [SCTextViewAttributes attributesWithMinimumHeight:88 maximumHeight:1000 autoResize:YES editable:YES];
    descPropertyDef.title = @"Comment";

    
    // Menu Definitions
    // ========================================
    SCClassDefinition *menuDef = [SCClassDefinition definitionWithClass:[SingleFileMenu class] propertyNamesString:@"file;play;email;download"];
    
    SCPropertyDefinition *filePropertyDef = [menuDef propertyDefinitionWithName:@"file"];
    filePropertyDef.type = SCPropertyTypeObject;
    filePropertyDef.attributes = [SCObjectAttributes attributesWithObjectDefinition:fileDef];
    filePropertyDef.title = @"File Details";
    
    SCPropertyDefinition *playPropertyDef = [menuDef propertyDefinitionWithName:@"play"];
    playPropertyDef.type = SCPropertyTypeObjectSelection;
    playPropertyDef.title = @"Play";
    playPropertyDef.cellActions.didSelect = ^(SCTableViewCell *cell, NSIndexPath *indexPath) {
        NSLog(@"POP UP THE PLAY VIEW CONTROLLER");
        [self.tableViewModel.modeledTableView deselectRowAtIndexPath:indexPath animated:YES];
    };
    playPropertyDef.cellActions.detailViewController = ^UIViewController*(SCTableViewCell *cell) {
        NSLog(@"Wait what?");
        return nil;
    };

    
    SCPropertyDefinition *emailPropertyDef = [menuDef propertyDefinitionWithName:@"email"];
    emailPropertyDef.type = SCPropertyTypeLabel;
    emailPropertyDef.title = @"Email";
    
    SCPropertyDefinition *downloadPropertyDef = [menuDef propertyDefinitionWithName:@"download"];
    downloadPropertyDef.type = SCPropertyTypeLabel;
    downloadPropertyDef.title = @"Download";

    
    
    // Show the filename, subname and duration.
	// Create an array of objects section
//	SCArrayOfObjectsSection *filesSection = [SCArrayOfObjectsSection sectionWithHeaderTitle:nil items:bbFiles itemsDefinition:fileDef];
    SCArrayOfObjectsSection *menuSection = [SCArrayOfObjectsSection sectionWithHeaderTitle:nil items:menuItems itemsDefinition:menuDef];
    menuSection.cellActions.willDisplay = ^(SCTableViewCell *cell, NSIndexPath *indexPath)
    {
        cell.textLabel.text = [[bbFiles objectAtIndex:indexPath.row] filename];
    };

    menuSection.sectionActions.detailModelWillPresent = ^(SCTableViewSection *section, SCTableViewModel *detailModel, NSIndexPath *indexPath)
    {
        NSLog(@"WHAAAT");
        section.cellActions.willSelect = ^(SCTableViewCell *cell, NSIndexPath *indexPath) {
            NSLog(@"SERIOUSLY WHAAAAT");  
        };
    };    
    
//    filesSection.cellActions.willConfigure = ^(SCTableViewCell *cell, NSIndexPath *indexPath)
//    {
//        cell.height = 70;
//    };
                                             
//	[self.tableViewModel addSection:menuSection];

    
    // On clicky, pop to a selection menu with
    // - File Details
    // - Play
    // - Email
    // - Download
    
    // File details shows
    // filename (editable), comment (editable), date, sampling rate, gain, file length
     */
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}


@end
