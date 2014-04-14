//
//  DigitalSignalParameterViewController.m
//  New Focus
//
//  Created by Alex Wiltschko on 7/10/12.
//  Copyright (c) 2012 Datta Lab, Harvard University. All rights reserved.
//

#import "DigitalSignalParameterViewController.h"

@implementation DigitalSignalParameterViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
    self.title = @"Stimulation";
    
    bbAudioManager = [BBAudioManager bbAudioManager];
    
    // Selection section of stimulation type
    SCSelectionSection *selectionSection = [SCSelectionSection 
                                            sectionWithHeaderTitle:@"Stimulation Type"
                                            boundObject:nil
                                            selectionStringPropertyName:@"Digital Signal"
                                            items:[NSArray arrayWithObjects:@"Digital Signal", @"Pulse", @"Tone", nil]];
    [self.tableViewModel addSection:selectionSection];
    
    // Section for digital signal parameters
    
    // Section for pulse parameters
    
    // Section for tone parameters
    
    // Just the stimulation switch section
    // ========================================
//	SCTableViewSection *justStimulationButtonSection = [SCTableViewSection section];
//	[self.tableViewModel addSection:justStimulationButtonSection];
//	
//    SCSwitchCell *switchCell = [SCSwitchCell cellWithText:@"Stimulation" boundObject:dictionaryToBind switchOnPropertyName:@"stimulationOnOrOff"];
//	[justStimulationButtonSection addCell:switchCell];
//    
//    justStimulationButtonSection.cellActions.valueChanged = ^(SCTableViewCell *cell, NSIndexPath *indexPath)
//    {
//        BOOL stimulate = [[dictionaryToBind valueForKey:@"stimulationOnOrOff"] boolValue];
//        
//        if (stimulate) {
//            NSLog(@"Start stimulating!");
//            [bbAudioManager startStimulating:bbAudioManager.stimulationType];    
//        }
//        else {
//            [bbAudioManager stopStimulating];
//        }
//        
//        NSLog(@"Stimulate? %d", stimulate);
//        
//    };
//    
//    
//    // The section of three stimulation options
//    // ========================================
//    SCArrayOfStringsSection *stimulationOptionSection = [SCArrayOfStringsSection 
//                                                         sectionWithHeaderTitle:@"Stimulation Type" 
//                                                         items:[NSMutableArray arrayWithObjects:@"Digital Signal", @"Pulse", @"Tone", nil]];
//    stimulationOptionSection.cellActions.didSelect = ^(SCTableViewCell *cell, NSIndexPath *indexPath) 
//    {
//        NSLog(@"Selected thingy %d", indexPath.row);
//        
//        if (indexPath.row == 0) { // Digital Signal
//            DigitalSignalParameterViewController *dspvc = [[DigitalSignalParameterViewController alloc] initWithStyle:UITableViewStyleGrouped];
//            [self.navigationController pushViewController:dspvc animated:YES];
//        }
//        else if (indexPath.row == 1) { // Pulse
//            
//        }
//        
//        else if (indexPath.row == 2) { // Tone
//            
//        }
//        
//        [self.tableViewModel.modeledTableView deselectRowAtIndexPath:indexPath animated:YES];
//    };
//    
//    [self.tableViewModel addSection:stimulationOptionSection];
    
    //    SCLabelCell *toneCell = [SCLabelCell cellWithText:@"2000 Hz"];
    //    [stimulationOptionSection addCell:toneCell];    
    //    [self.tableViewModel addSection:stimulationOptionSection];
    
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}


@end
