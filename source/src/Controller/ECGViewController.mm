//
//  ECGViewController.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 9/11/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "ECGViewController.h"
#import "BBBTManager.h"
#import "BBECGAnalysis.h"
#import "MyAppDelegate.h"

@interface ECGViewController ()
{
    AVAudioPlayer * beepSound;
}

@end

@implementation ECGViewController
@synthesize activeHeartImg;
//@synthesize healthStore;

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[BBAudioManager bbAudioManager] startECG];

    self.activeHeartImg.image = [UIImage imageNamed:@"nobeat.png"];
    //Config GL view
    if(glView)
    {
        [glView stopAnimation];
        [glView removeFromSuperview];
        [glView release];
        glView = nil;
    }
    glView = [[ECGGraphView alloc] initWithFrame:self.view.frame];
    glView.masterDelegate = self;
    [glView setupWithBaseFreq:[[BBAudioManager bbAudioManager] sourceSamplingRate]];
    [[BBAudioManager bbAudioManager] selectChannel:0];
    
    _channelButton.hidden = [[BBAudioManager bbAudioManager] sourceNumberOfChannels]<2;
    
    [self.view addSubview:glView];
    [self.view sendSubviewToBack:glView];
    [glView startAnimation];
    
    
    MyAppDelegate * appDelegate = (MyAppDelegate*)[[UIApplication sharedApplication] delegate];
   // self.healthStore = appDelegate.healthStore;
    
        //Bluetooth notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(noBTConnection) name:NO_BT_CONNECTION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(btDisconnected) name:BT_DISCONNECTED object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(btSlowConnection) name:BT_SLOW_CONNECTION object:nil];    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(beatTheHeart) name:HEART_BEAT_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reSetupScreen) name:RESETUP_SCREEN_NOTIFICATION object:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
     // [beepSound playAtTime:0];
    dataSouldBeSavedToHK = NO;
    //Try to init health kit
    
  /*  if ([HKHealthStore isHealthDataAvailable]) {
        NSSet *writeDataTypes = [self dataTypesToWrite];
        NSSet *readDataTypes = [self dataTypesToRead];
        
        [self.healthStore requestAuthorizationToShareTypes:writeDataTypes readTypes:readDataTypes completion:^(BOOL success, NSError *error) {
            if (!success) {
                NSLog(@"You didn't allow HealthKit to write hearth rate data. In your app, try to handle this error gracefully when a user decides not to provide access. The error was: %@. If you're using a simulator, try it on a device.", error);
                
                return;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                // Update the user interface based on the current user's health information.
                dataSouldBeSavedToHK = YES;
            });
        }];
    }*/
}


- (void)storeHeartBeatsAtMinute:(double)beats
                      startDate:(NSDate *)startDate endDate:(NSDate *)endDate
                     completion:(void (^)(NSError *error))compeltion
{
   /* HKQuantityType *rateType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate];
    HKQuantity *rateQuantity = [HKQuantity quantityWithUnit:[[HKUnit countUnit] unitDividedByUnit:[HKUnit minuteUnit]]
                                                doubleValue:(double)beats];
    HKQuantitySample *rateSample = [HKQuantitySample quantitySampleWithType:rateType
                                                                   quantity:rateQuantity
                                                                  startDate:startDate
                                                                    endDate:endDate];
    
    [healthStore saveObject:rateSample withCompletion:^(BOOL success, NSError *error) {
        if(compeltion) {
            compeltion(error);
        }
    }];*/
}



// Returns the types of data that Fit wishes to write to HealthKit.
- (NSSet *)dataTypesToWrite {
   // HKQuantityType *heartRateType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate];
    
    return nil;//[NSSet setWithObjects:heartRateType, nil];
}

// Returns the types of data that Fit wishes to read from HealthKit.
- (NSSet *)dataTypesToRead {
    /*HKQuantityType *dietaryCalorieEnergyType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDietaryEnergyConsumed];
    HKQuantityType *activeEnergyBurnType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierActiveEnergyBurned];
    HKQuantityType *heightType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeight];
    HKQuantityType *weightType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierBodyMass];
    HKCharacteristicType *birthdayType = [HKObjectType characteristicTypeForIdentifier:HKCharacteristicTypeIdentifierDateOfBirth];
    HKCharacteristicType *biologicalSexType = [HKObjectType characteristicTypeForIdentifier:HKCharacteristicTypeIdentifierBiologicalSex];
    
    return [NSSet setWithObjects:dietaryCalorieEnergyType, activeEnergyBurnType, heightType, weightType, birthdayType, biologicalSexType, nil];*/
    return nil;
}



- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    NSLog(@"Stopping regular view");
    [glView stopAnimation];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NO_BT_CONNECTION object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:BT_DISCONNECTED object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:BT_SLOW_CONNECTION object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:HEART_BEAT_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:RESETUP_SCREEN_NOTIFICATION object:nil];
}

-(void) changeHeartActive:(BOOL) active
{
    if(active)
    {
        self.activeHeartImg.image = [UIImage imageNamed:@"hasbeat.png"];
    }
    else
    {
        self.activeHeartImg.image = [UIImage imageNamed:@"nobeat.png"];
    }
}

-(void) beatTheHeart
{
    if([[BBAudioManager bbAudioManager] heartBeatPresent])
    {
       // AudioServicesPlaySystemSound(beepSound);
        
       // [beepSound seekToTime:CMTimeMake(0,1)];   // rewind if play occurs repeatedly and loading is only on init
       // [beepSound play];
        [beepSound playAtTime:0];
        //Save data to HealthKit if user enabled it
        if(dataSouldBeSavedToHK)
        {
            NSDate * currentDate = [[NSDate alloc] init];
            [self storeHeartBeatsAtMinute:[[BBAudioManager bbAudioManager] heartRate] startDate:currentDate endDate:currentDate completion:nil];
        
        }
        
        
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
     
            self.activeHeartImg.alpha = 0.6;
            [UIView animateWithDuration:0.2 animations:^(void) {
                self.activeHeartImg.alpha = 1.0;
            }
            completion:^ (BOOL finished)
             {
                 if (finished) {
                     [UIView animateWithDuration:0.2 animations:^(void){
                     // Revert image view to original.
                        self.activeHeartImg.alpha = 0.8;
                        [self.activeHeartImg.layer removeAllAnimations];
                        [self.activeHeartImg setNeedsDisplay];
                      }];
                 }
             }
             
             
             ];
            
        });
    
    }
}


#pragma mark - Channel code

- (IBAction)channelButtonClick:(id)sender {
    SAFE_ARC_RELEASE(popover); popover=nil;
    
    //the controller we want to present as a popover
    BBChannelSelectionTableViewController *controller = [[BBChannelSelectionTableViewController alloc] initWithStyle:UITableViewStylePlain];
    
    controller.delegate = self;
    popover = [[FPPopoverController alloc] initWithViewController:controller];
    popover.border = NO;
    popover.tint = FPPopoverWhiteTint;
    
    
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        popover.contentSize = CGSizeMake(300, 500);
    }
    else {
        popover.contentSize = CGSizeMake(200, 300);
    }
    
    popover.arrowDirection = FPPopoverArrowDirectionAny;
    [popover presentPopoverFromView:sender];
}


-(NSMutableArray *) getAllRows
{
    NSMutableArray * allChannelsLabels = [[[NSMutableArray alloc] init] autorelease];
    for(int i=0;i<[[BBAudioManager bbAudioManager] sourceNumberOfChannels];i++)
    {
        [allChannelsLabels addObject:[NSString stringWithFormat:@"Channel %d",i+1]];
    }
    return allChannelsLabels;
}


- (void)rowSelected:(NSInteger) rowIndex
{
    [[BBAudioManager bbAudioManager] selectChannel:rowIndex];
    [popover dismissPopoverAnimated:YES];
}

#pragma mark - BT stuff


-(void) noBTConnection
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No Bluetooth connection."
                                                    message:@"Please pair with BYB bluetooth device in Bluetooth settings."
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
    [alert release];
}

-(void) btDisconnected
{
    if([[BBAudioManager bbAudioManager] btOn])
    {
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No Bluetooth connection."
                                                        message:@"Bluetooth device disconnected. Get in range of the device and try to pair with the device in Bluetooth settings again."
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        [alert release];
    }
}


-(void) btSlowConnection
{
   /* if([[BBAudioManager bbAudioManager] btOn])
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Slow Bluetooth connection."
                                                        message:@"Bluetooth connection is very slow. Try moving closer to Bluetooth device and start session again."
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        [alert release];
    }*/
    
}

-(void) reSetupScreen
{
    NSLog(@"Resetup screen");
    [[BBAudioManager bbAudioManager] startECG];
    
    self.activeHeartImg.image = [UIImage imageNamed:@"nobeat.png"];
    //Config GL view
    if(glView)
    {
        [glView stopAnimation];
        [glView removeFromSuperview];
        [glView release];
        glView = nil;
    }
    glView = [[ECGGraphView alloc] initWithFrame:self.view.frame];
    glView.masterDelegate = self;
    [glView setupWithBaseFreq:[[BBAudioManager bbAudioManager] sourceSamplingRate]];
    [[BBAudioManager bbAudioManager] selectChannel:0];
    
    _channelButton.hidden = [[BBAudioManager bbAudioManager] sourceNumberOfChannels]<2;
    
    [self.view addSubview:glView];
    [self.view sendSubviewToBack:glView];
    [glView startAnimation];
}

#pragma mark - View code

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
  /*  NSURL *soundURL = [[NSBundle mainBundle] URLForResource:@"beep"
                                              withExtension:@"wav"];
    AudioServicesCreateSystemSoundID((CFURLRef)soundURL, &beepSound);*/
    beepSound = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSBundle.mainBundle URLForResource:@"beep" withExtension:@"wav"] error:NULL];
    beepSound.volume = 0.5;
  
      // OR...
   // beepSound.currentTime = 0;
   // [beepSound play];
    
    
   // beepSound = [AVPlayer playerWithURL:[NSBundle.mainBundle URLForResource:@"beep" withExtension:@"wav"]];
    // Note, no volume on this :(
   // [beepSound seekToTime:CMTimeMake(0,1)];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    [_channelButton release];
    [activeHeartImg release];
    // AudioServicesDisposeSystemSoundID(beepSound);
    [super dealloc];
}


@end
