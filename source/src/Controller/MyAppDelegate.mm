//
// MyAppDelegate.mm
// Backyard Brains
//

#import "MyAppDelegate.h"
#import "BBAudioFileReader.h"
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>
#import <ObjectiveDropboxOfficial/ObjectiveDropboxOfficial.h>



//Tab bar pages indexes
#define kViewRecordTabBarIndex  0
#define kThresholdTabBarIndex   1
#define kRecordingsTabBarIndex  2
#define kFFTTabBarIndex         3

#define USE_DROPBOX

@implementation MyAppDelegate

@synthesize tabBarController;
//------------------------------ MFI ----------------------------------
static DemoProtocol *demoProtocol;
//------------------------------ MFI ----------------------------------


#pragma mark - CCGLTouchAppDelegate functions

+(DemoProtocol*) getEaManager
{
    return demoProtocol;
}

- (void) enterForeground
{
    NSLog(@"Inside new enter foreground");
    if(self.shouldReinitializeAudio)
    {
        
        NSLog(@"Reinit audio manager");
        [[BBAudioManager bbAudioManager] init];
        self.shouldReinitializeAudio = false;
        
    }
    
}

//
// This "launch" is called on the end of "application: didFinishLaunchingWithOptions"
// in CCGLTouchAppDelegate
//
- (void)launch
{
    //------------------------------ MFI ----------------------------------
         demoProtocol = [[DemoProtocol alloc] init];
        [demoProtocol initProtocol];
    //------------------------------ MFI ----------------------------------
    
    //[Fabric with:@[[Crashlytics class]]];
    
    tabBarController = (UITabBarController *)self.window.rootViewController;
    tabBarController.delegate = self;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if(sharedFileIsWaiting)
    {
        NSLog(@"Shared file notification in launch");
        tabBarController.selectedIndex = kRecordingsTabBarIndex;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"FileReceivedViaShare" object:self];
    }
    else
    {
        NSLog(@"No shared files detected");
        int selectThisIndex = [[defaults valueForKey:@"tabIndex"] intValue];
        tabBarController.selectedIndex = selectThisIndex;
    }
    
    
    
    
    #ifdef USE_DROPBOX
        //DropBox V2
        [DBClientsManager setupWithAppKey:@"r3clmvcekkjiams"];
        
        [UIApplication sharedApplication].idleTimerDisabled = YES;
    #endif
    
   
    

    
}

#pragma mark - Application management

- (void)applicationWillTerminate:(UIApplication *)application {
    
   [[BBAudioManager bbAudioManager] quitAllFunctions];
    NSLog(@"Going into background.");
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:[NSNumber numberWithInt:tabBarController.selectedIndex] forKey:@"tabIndex"];
    [defaults synchronize];
    
    
//------------------------------ MFI ----------------------------------
     demoProtocol = nil;
//------------------------------ MFI ----------------------------------
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    NSLog(@"\n\nApp will resign.\n\n");
}


- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
    //Dropbox auth
    DBOAuthResult *authResult = [DBClientsManager handleRedirectURL:url];
    if (authResult != nil) {
        if ([authResult isSuccess]) {
            NSLog(@"Success! User is logged into Dropbox.");
            return YES;
        } else if ([authResult isCancel]) {
            NSLog(@"Authorization flow was manually canceled by user!");
            return YES;
        } else if ([authResult isError]) {
            NSLog(@"Error: %@", authResult);
            return YES;
        }
        
    }
    
    //File sharing
    if (url) {
        NSLog(@"Scheme: %@", url.scheme);
        if (url.scheme && [url.scheme isEqualToString:@"file"]) {
            
            BBFile * aFile = [[BBFile alloc] initWithUrl:url];
            if ( [[NSFileManager defaultManager] isReadableFileAtPath:[url path]] )
            {
                
                NSURL * newUrl = [aFile fileURL];
                [[NSFileManager defaultManager] copyItemAtURL:url toURL:newUrl error:nil];
                BBAudioFileReader * fileReader = [[BBAudioFileReader alloc]
                                                  initWithAudioFileURL:[aFile fileURL]
                                                  samplingRate:aFile.samplingrate
                                                  numChannels:1];
                
                aFile.filelength = fileReader.duration;
                [fileReader release];
                [aFile save];
                //Flag that indicate that we should open shared file
                //and show it to user
                sharedFileIsWaiting = YES;
                NSLog(@"Shared file notification in openURL");
                //open list of files to show new file at the end of the list
                tabBarController.selectedIndex = kRecordingsTabBarIndex;
                //Post notification
                [[NSNotificationCenter defaultCenter] postNotificationName:@"FileReceivedViaShare" object:self];
                
            }
            [aFile release];
            return YES;
        }
    }
    return NO;
}

#pragma mark - File sharing

//Flag that indicate that we should open shared file
//and show it to user
-(BOOL) sharedFileShouldBeOpened
{
    return sharedFileIsWaiting;
}

//Flag that indicate that we should open shared file
//and show it to user
-(void) sharedFileIsOpened
{
    sharedFileIsWaiting = NO;
}

#pragma mark - Tab Bar functions

//Patch. TODO: Fix this on some other place
- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController
{
    [[BBAudioManager bbAudioManager] endSelection];
}

-(BOOL)tabBarController:(UITabBarController *)tabBarController shouldSelectViewController:(UIViewController *)viewController {
    //disable tab bar while in recording
    if ([[BBAudioManager bbAudioManager] recording]) {
        return NO;
    }
    return YES;
}

#pragma mark - Helper functions

-(void) redirectConsoleLogToDocumentFolder
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                         NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *logPath = [documentsDirectory stringByAppendingPathComponent:@"console.log"];
    freopen([logPath fileSystemRepresentation],"a+",stderr);
}

#pragma mark - Memory management

-(void) dealloc
{
    [tabBarController release];
    [super dealloc];
}

-(void) applicationDidReceiveMemoryWarning:(UIApplication *)application
{
    NSLog(@"\n\nApp received memory warning! APP delagate\n\n");
}

@end
