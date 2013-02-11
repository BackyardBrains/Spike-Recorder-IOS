//
//  StimulationParameterViewController.m
//  New Focus
//
//  Created by Alex Wiltschko on 7/10/12.
//  Copyright (c) 2012 Datta Lab, Harvard University. All rights reserved.
//

#import "StimulationParameterViewController.h"

@interface StimulationParameterViewController()
{
    BBAudioManager *bbAudioManager;
    SCSwitchCell *isStimulatingCell;
}

@property (nonatomic, retain) SCSwitchCell *isStimulatingCell;

@end

@implementation StimulationParameterViewController
@synthesize tableView = _tableView;
@synthesize isStimulatingCell;

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"stimulating"])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"Switch control: %@", isStimulatingCell.switchControl);
            BOOL isStimulating = [[BBAudioManager bbAudioManager] stimulating];
            NSLog(@"Stimulating? %d", isStimulating);
            [isStimulatingCell.switchControl setOn:isStimulating animated:YES];
        });
    }

}


- (void)viewWillUnload
{
    [[BBAudioManager bbAudioManager] removeObserver:self forKeyPath:@"stimulating"];

}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[BBAudioManager bbAudioManager] saveSettingsToUserDefaults];

}

- (void)viewDidLoad
{
        
    [super viewDidLoad];
    
    // Setup some KVO, so that the stimulation switch listens to
    [[BBAudioManager bbAudioManager] addObserver:self forKeyPath:@"stimulating" options:NSKeyValueObservingOptionNew context:NULL];

    
    self.title = @"Stimulation";
    self.navigationBarType = SCNavigationBarTypeDoneLeft;
    
    bbAudioManager = [BBAudioManager bbAudioManager];
    
    // Section containing just a stim on/off switch
    SCTableViewSection *stimulationToggleSection = [SCTableViewSection sectionWithHeaderTitle:nil];
    BOOL stimulationIsOn = bbAudioManager.stimulating;
    
    self.isStimulatingCell = [SCSwitchCell cellWithText:@"Stimulation" boundObject:nil switchOnPropertyName:nil];
    self.isStimulatingCell.switchControl.on = stimulationIsOn;
    self.isStimulatingCell.cellActions.valueChanged = ^(SCTableViewCell *cell, NSIndexPath *indexPath) {
        SCSwitchCell *theCell = (SCSwitchCell *)cell;
        BOOL shouldStimulate = theCell.switchControl.on;

        if (shouldStimulate) {
            [bbAudioManager startStimulating:bbAudioManager.stimulationType];
        }
        else {
            [bbAudioManager stopStimulating];
        }
        
    };
    
    [stimulationToggleSection addCell:isStimulatingCell];
    [self.tableViewModel addSection:stimulationToggleSection];
    
    

    // We're now going to define some INITIALLY HIDDEN SECTIONS
    // These are the preferences that belong to each one of the stimulation types. 
    // ================================================================================
    // ================================================================================
    
    
    
    
    
    
    
    // Digital signal section
    // ==================================================
    
    digitalSignalSection = [SCTableViewSection sectionWithHeaderTitle:@"Digital Signal Settings"];

    
    // Declare ahead of time, the frequency cell and pulse-width cell.
    // They influence each other.
    SCNumericTextFieldCell *frequencyCell = [SCNumericTextFieldCell cellWithText:@"Frequency" boundObject:nil boundPropertyName:nil];
    SCNumericTextFieldCell *pulseWidthCell = [SCNumericTextFieldCell cellWithText:@"Pulse Width (ms)" boundObject:nil boundPropertyName:nil];
    
    
    // Frequency cell
    float pulseFrequency = bbAudioManager.stimulationDigitalFrequency;
    NSString *pulseFrequencyString = [NSString stringWithFormat:@"%6.0f", pulseFrequency];
    frequencyCell.textField.text = pulseFrequencyString;
    frequencyCell.cellActions.valueChanged = ^(SCTableViewCell *cell, NSIndexPath *indexPath) {
        SCNumericTextFieldCell *theCell = (SCNumericTextFieldCell *)cell;
        
        NSNumberFormatter * f = [[NSNumberFormatter alloc] init];
        [f setNumberStyle:NSNumberFormatterDecimalStyle];
        NSNumber * myNumber = [f numberFromString:theCell.textField.text];
        [f release];
        
        bbAudioManager.stimulationDigitalFrequency = [myNumber floatValue];
        float pulseWidth = 1000.0 * bbAudioManager.stimulationDigitalDutyCycle / bbAudioManager.stimulationDigitalFrequency;
        NSLog(@"New pulse width: %f", pulseWidth);
        pulseWidthCell.textField.text = [NSString stringWithFormat:@"%0.1f", pulseWidth];
        
    };

    
    // Pulse-width cell
    float dutyCycle = bbAudioManager.stimulationDigitalDutyCycle;
    float pulseWidth = dutyCycle * (1000.0f / bbAudioManager.stimulationDigitalFrequency);
    NSString *pulseWidthString = [NSString stringWithFormat:@"%d", (int)pulseWidth];
    pulseWidthCell.textField.text = pulseWidthString;
    pulseWidthCell.cellActions.valueChanged = ^(SCTableViewCell *cell, NSIndexPath *indexPath) {
        SCNumericTextFieldCell *theCell = (SCNumericTextFieldCell *)cell;
        
        NSNumberFormatter * f = [[NSNumberFormatter alloc] init];
        [f setNumberStyle:NSNumberFormatterDecimalStyle];
        NSNumber * myNumber = [f numberFromString:theCell.textField.text];
        [f release];
        
        bbAudioManager.stimulationDigitalDutyCycle = [myNumber floatValue] * bbAudioManager.stimulationDigitalFrequency / 1000.0;
        
    };

    
    
    // Digital Signal Duration cell
    int numDigitalPulses = bbAudioManager.numPulsesInDigitalStimulation;
    NSString *numDigitalPulsesString = [NSString stringWithFormat:@"%d", numDigitalPulses];
    SCNumericTextFieldCell *numDigitalPulsesCell = [SCNumericTextFieldCell cellWithText:@"Number of Pulses" boundObject:nil boundPropertyName:nil];
    numDigitalPulsesCell.textField.text = numDigitalPulsesString;
    numDigitalPulsesCell.cellActions.valueChanged = ^(SCTableViewCell *cell, NSIndexPath *indexPath) {
        SCNumericTextFieldCell *theCell = (SCNumericTextFieldCell *)cell;
        
        NSNumberFormatter * f = [[NSNumberFormatter alloc] init];
        [f setNumberStyle:NSNumberFormatterDecimalStyle];
        NSNumber * myNumber = [f numberFromString:theCell.textField.text];
        [f release];
        
        bbAudioManager.numPulsesInDigitalStimulation = [myNumber intValue];
        
    };

    
    // Continuous switch cell
    BOOL isPulsed = bbAudioManager.stimulationType == BBStimulationTypeDigitalControlPulse;
    SCSwitchCell *isPulsedSwitchedCell = [SCSwitchCell cellWithText:@"Pulsed" boundObject:nil switchOnPropertyName:nil];
    isPulsedSwitchedCell.switchControl.on = isPulsed; // set up before
    isPulsedSwitchedCell.cellActions.valueChanged = ^(SCTableViewCell *cell, NSIndexPath *indexPath) {
        SCSwitchCell *theCell = (SCSwitchCell *)cell;
        BOOL shouldBePulsed = theCell.switchControl.on;
        
        if (shouldBePulsed) {
            [bbAudioManager startStimulating:BBStimulationTypeDigitalControlPulse];

        }
        else {
            [bbAudioManager startStimulating:BBStimulationTypeDigitalControl];

        }
        
        [numDigitalPulsesCell setEnabled:shouldBePulsed];
        
    };
    
    
    // Calibration cell
    // Create an object that contains the stimulation frequency    
    NSLog(@"Stimulation pulse frequency: %f", bbAudioManager.stimulationDigitalMessageFrequency);
    SCClassDefinition *classDef = [SCClassDefinition definitionWithClass:[bbAudioManager class] propertyNamesString:@"Carrier Frequency:(stimulationDigitalMessageFrequency)"];
    SCPropertyDefinition *stimFreq = [classDef propertyDefinitionWithName:@"stimulationDigitalMessageFrequency"];
    stimFreq.type = SCPropertyTypeSlider;
    stimFreq.cellActions.didLayoutSubviews = ^(SCTableViewCell *cell, NSIndexPath
                                               *indexPath)
    {
        SCSliderCell *theCell = (SCSliderCell *)cell;
        theCell.slider.minimumValue = 5000;
        theCell.slider.maximumValue = 25000;
        theCell.slider.continuous = YES;
        theCell.textLabel.text = [NSString stringWithFormat:@"%d Hz", (int)theCell.slider.value];
        theCell.textLabel.adjustsFontSizeToFitWidth = YES;
    };
    stimFreq.cellActions.valueChanged = ^(SCTableViewCell *cell, NSIndexPath *indexPath)
    {
        SCSliderCell *theCell = (SCSliderCell *)cell;
        theCell.textLabel.text = [NSString stringWithFormat:@"%d Hz", (int)theCell.slider.value];
        bbAudioManager.stimulationDigitalMessageFrequency = (float)theCell.slider.value;
        
    };
    
    SCObjectCell *calibrateButtonCell = [SCObjectCell cellWithBoundObject:bbAudioManager boundObjectDefinition:classDef];
    calibrateButtonCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    calibrateButtonCell.cellActions.didLayoutSubviews = ^(SCTableViewCell *cell, NSIndexPath
                                                      *indexPath)
    {
        cell.textLabel.text = @"Calibrate";
    };

    [digitalSignalSection addCell:isPulsedSwitchedCell];
    [digitalSignalSection addCell:frequencyCell];
    [digitalSignalSection addCell:pulseWidthCell];
    [digitalSignalSection addCell:numDigitalPulsesCell];
    [digitalSignalSection addCell:calibrateButtonCell];
    [pulseWidthCell retain];
    [frequencyCell retain];
    [numDigitalPulsesCell retain];
    [digitalSignalSection retain];
    
    [numDigitalPulsesCell setEnabled:isPulsed];

    
    
    
    
    
    
    
    // Pulse signal (finite number of cycles) section
    // ==================================================
    pulseSection = [SCTableViewSection sectionWithHeaderTitle:@"Pulse Settings" footerTitle:@"1 millisecond pulses used for stimulation"];
    
    // Pulse frequency cell
    // Tone Frequency cell
    float biphasicPulseFrequency = bbAudioManager.stimulationPulseFrequency;
    NSString *biphasicPulseFrequencyString = [NSString stringWithFormat:@"%d Hz", (int)biphasicPulseFrequency];
    SCSliderCell *pulseFrequencyCell = [SCSliderCell cellWithText:biphasicPulseFrequencyString boundObject:nil sliderValuePropertyName:nil];
    pulseFrequencyCell.slider.minimumValue = 0.1f;
    pulseFrequencyCell.slider.maximumValue = 100.0f;
    pulseFrequencyCell.slider.value = biphasicPulseFrequency;
    pulseFrequencyCell.slider.continuous = YES;
    pulseFrequencyCell.textLabel.adjustsFontSizeToFitWidth = YES;
    pulseFrequencyCell.cellActions.valueChanged = ^(SCTableViewCell *cell, NSIndexPath *indexPath) {
        SCSliderCell *theCell = (SCSliderCell *)cell;
        bbAudioManager.stimulationPulseFrequency = theCell.slider.value;
        theCell.textLabel.text = [NSString stringWithFormat:@"%d Hz", (int)theCell.slider.value];
    };

    
    // Number of pulses cell
    int numBiphasicPulses = bbAudioManager.numPulsesInBiphasicStimulation;
    NSString *numPulsesString = [NSString stringWithFormat:@"%d", numBiphasicPulses];
    SCNumericTextFieldCell *numPulsesCell = [SCNumericTextFieldCell cellWithText:@"Number of Pulses" boundObject:nil boundPropertyName:nil];
    numPulsesCell.textField.text = numPulsesString;
    numPulsesCell.cellActions.valueChanged = ^(SCTableViewCell *cell, NSIndexPath *indexPath) {
        SCNumericTextFieldCell *theCell = (SCNumericTextFieldCell *)cell;
        
        NSNumberFormatter * f = [[NSNumberFormatter alloc] init];
        [f setNumberStyle:NSNumberFormatterDecimalStyle];
        NSNumber * myNumber = [f numberFromString:theCell.textField.text];
        [f release];
        
        bbAudioManager.numPulsesInBiphasicStimulation = [myNumber intValue];
        
    };
    
    [pulseSection addCell:pulseFrequencyCell];
    [pulseSection addCell:numPulsesCell];
    [pulseSection retain];
    
    
    
    
    
    
    
    // Pure Tone section
    // ==================================================
    toneSection = [SCTableViewSection sectionWithHeaderTitle:@"Tone Settings"];
    
    // Tone Frequency cell
    float toneFrequency = bbAudioManager.stimulationToneFrequency;
    NSString *toneFrequencyString = [NSString stringWithFormat:@"%d Hz", (int)toneFrequency];
    SCSliderCell *toneFrequencyCell = [SCSliderCell cellWithText:toneFrequencyString boundObject:nil sliderValuePropertyName:nil];
    toneFrequencyCell.slider.minimumValue = 60.0f;
    toneFrequencyCell.slider.maximumValue = 20000.0f;
    toneFrequencyCell.slider.value = toneFrequency;
    toneFrequencyCell.slider.continuous = YES;
    toneFrequencyCell.textLabel.adjustsFontSizeToFitWidth = YES;
    toneFrequencyCell.cellActions.valueChanged = ^(SCTableViewCell *cell, NSIndexPath *indexPath) {
        SCSliderCell *theCell = (SCSliderCell *)cell;
        bbAudioManager.stimulationToneFrequency = theCell.slider.value;
        theCell.textLabel.text = [NSString stringWithFormat:@"%d Hz", (int)theCell.slider.value];
    };
    [toneSection addCell:toneFrequencyCell];
    
    
    
    // Pulsed tone duration cell
    BOOL toneIsContinuous = (bbAudioManager.stimulationType == BBStimulationTypeTonePulse) ? false : true;
    float toneDuration = bbAudioManager.stimulationToneDuration;
    NSString *toneDurationString = [NSString stringWithFormat:@"%1.1f s", toneDuration];
    SCSliderCell *toneLengthCell = [SCSliderCell cellWithText:toneDurationString boundObject:nil sliderValuePropertyName:nil];
    toneLengthCell.slider.minimumValue = 0.5;
    toneLengthCell.slider.maximumValue = 60.0f;
    toneLengthCell.slider.value = toneDuration;
    toneLengthCell.slider.continuous = YES;
    toneLengthCell.textLabel.adjustsFontSizeToFitWidth = YES;
    
    toneLengthCell.cellActions.valueChanged = ^(SCTableViewCell *cell, NSIndexPath *indexPath) {
        SCSliderCell *theCell = (SCSliderCell *)cell;
        bbAudioManager.stimulationToneDuration = theCell.slider.value;
        theCell.textLabel.text = [NSString stringWithFormat:@"%1.1f s", theCell.slider.value];
    };
    
    [toneLengthCell setEnabled:!toneIsContinuous];
    [toneSection retain];

    // Continuous switch cell
    SCSwitchCell *continuousToneCell = [SCSwitchCell cellWithText:@"Continuous" boundObject:nil switchOnPropertyName:nil];
    continuousToneCell.switchControl.on = toneIsContinuous; // set up before
    continuousToneCell.cellActions.valueChanged = ^(SCTableViewCell *cell, NSIndexPath *indexPath) {
        SCSwitchCell *theCell = (SCSwitchCell *)cell;
        BOOL isContinuous = theCell.switchControl.on;
        if (isContinuous) {
            [bbAudioManager startStimulating:BBStimulationTypeTone];
            [toneLengthCell setEnabled:FALSE];
        }
        else {
            [bbAudioManager startStimulating:BBStimulationTypeTonePulse];
            [toneLengthCell setEnabled:TRUE];
        }
        
    };

    [toneSection addCell:continuousToneCell];
    [toneSection addCell:toneLengthCell];

    
    // ================================================================================
    // ================================================================================
    // End of the hidden sections (these will be shown selectively by the selection section next
    
    
    // The section of three stimulation options
    // ========================================
    SCSelectionSection *selectionSection = [SCSelectionSection
                                            sectionWithHeaderTitle:@"Stimulation Type" 
                                            boundObject:nil 
                                            selectionStringPropertyName:@"Digital Signal" 
                                            items:[NSMutableArray arrayWithObjects:@"Digital Signal", @"Pulse", @"Tone", nil]];
    
    int selectionIndex = 0;
    if (bbAudioManager.stimulationType == BBStimulationTypeDigitalControl || bbAudioManager.stimulationType == BBStimulationTypeDigitalControlPulse) {
        selectionIndex = 0;
    }
    else if (bbAudioManager.stimulationType == BBStimulationTypeBiphasic) {
        selectionIndex = 1;
    }
    else if (bbAudioManager.stimulationType == BBStimulationTypeTone || bbAudioManager.stimulationType == BBStimulationTypeTonePulse) {
        selectionIndex = 2;
    }
    
    int theSectionIndexWithAllTheOptionsInIt = 2;
    selectionSection.selectedItemIndex = [NSNumber numberWithInt:selectionIndex]; // the stimulation type is an enum with integer values.
    selectionSection.cellActions.didSelect = ^(SCTableViewCell *cell, NSIndexPath *indexPath) 
    {
        NSLog(@"Index selected: %d", indexPath.row);
        NSLog(@"We have %d sections", self.tableViewModel.sectionCount);
        
        if (indexPath.row == 0) { // Digital Signal
            NSLog(@"Let's do this");
            bbAudioManager.stimulationType = BBStimulationTypeDigitalControl;
            [self.tableViewModel removeSectionAtIndex:theSectionIndexWithAllTheOptionsInIt];
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:theSectionIndexWithAllTheOptionsInIt] withRowAnimation:UITableViewRowAnimationFade];
            [self.tableViewModel insertSection:digitalSignalSection atIndex:theSectionIndexWithAllTheOptionsInIt];
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:theSectionIndexWithAllTheOptionsInIt] withRowAnimation:UITableViewRowAnimationFade];
        }
        
        else if (indexPath.row == 1) { // Pulse
            bbAudioManager.stimulationType = BBStimulationTypeBiphasic;
            [self.tableViewModel removeSectionAtIndex:theSectionIndexWithAllTheOptionsInIt];
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:theSectionIndexWithAllTheOptionsInIt] withRowAnimation:UITableViewRowAnimationFade];
            [self.tableViewModel insertSection:pulseSection atIndex:theSectionIndexWithAllTheOptionsInIt];
             [self.tableView insertSections:[NSIndexSet indexSetWithIndex:theSectionIndexWithAllTheOptionsInIt] withRowAnimation:UITableViewRowAnimationFade];
             }
             
             else if (indexPath.row == 2) { // Tone
                 bbAudioManager.stimulationType = BBStimulationTypeTone;
                 [self.tableViewModel removeSectionAtIndex:theSectionIndexWithAllTheOptionsInIt];
                 [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:theSectionIndexWithAllTheOptionsInIt] withRowAnimation:UITableViewRowAnimationFade];
                 [self.tableViewModel insertSection:toneSection atIndex:theSectionIndexWithAllTheOptionsInIt];
                 [self.tableView insertSections:[NSIndexSet indexSetWithIndex:theSectionIndexWithAllTheOptionsInIt] withRowAnimation:UITableViewRowAnimationFade];
        }
        
        if (bbAudioManager.stimulating)
            [bbAudioManager startStimulating:bbAudioManager.stimulationType];
        
        [self.tableViewModel.modeledTableView deselectRowAtIndexPath:indexPath animated:YES];
    };
    
    [self.tableViewModel addSection:selectionSection];
    
    
    // Now, decide which preference section gets added
    NSLog(@"We have a stimulation type of: %d", bbAudioManager.stimulationType);
    if (bbAudioManager.stimulationType == BBStimulationTypeDigitalControl || bbAudioManager.stimulationType == BBStimulationTypeDigitalControlPulse) {
        NSLog(@"Digital signal");
        [self.tableViewModel addSection:digitalSignalSection];
    }
    else if (bbAudioManager.stimulationType == BBStimulationTypeBiphasic) {
        NSLog(@"Pulse signal");
        [self.tableViewModel addSection:pulseSection];
    }
    else if (bbAudioManager.stimulationType == BBStimulationTypeTone || bbAudioManager.stimulationType == BBStimulationTypeTonePulse) {
        NSLog(@"Tone signal");
        [self.tableViewModel addSection:toneSection];
    }

    
    
    

}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}


- (void)doneButtonAction
{
    [self.presentingViewController dismissModalViewControllerAnimated:YES];
}


- (void)dealloc {
    [_tableView release];
    [super dealloc];
}
- (void)viewDidUnload {
    [self setTableView:nil];
    [super viewDidUnload];
}
@end
