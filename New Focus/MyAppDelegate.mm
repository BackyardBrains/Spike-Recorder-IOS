//
//  MyAppDelegate.mm
//  CCGLTouchBasic example
//
//  Created by Matthieu Savary on 09/09/11.
//  Copyright (c) 2011 SMALLAB.ORG. All rights reserved.
//
//  More info on the CCGLTouch project >> http://www.smallab.org/code/ccgl-touch/
//  License & disclaimer >> see license.txt file included in the distribution package
//

#import "MyAppDelegate.h"
#import <DropboxSDK/DropboxSDK.h>
#import "BBAudioFileReader.h"
#import "TestFlight.h"
#define kViewRecordTabBarIndex 0
#define kThresholdTabBarIndex 1
#define kFFTTabBarIndex 2
#define kRecordingsTabBarIndex 3

@implementation MyAppDelegate
@synthesize tabBarController;
@synthesize window;


- (void)launch
{    
   
    // start of your application:didFinishLaunchingWithOptions // ...
    [TestFlight takeOff:@"da7a715d-e6da-44e9-97a8-05b75525a9db"];

    // Hide the status bar
//    [[UIApplication sharedApplication] setStatusBarHidden:YES animated:NO];
    
    // viewController as the root view for our window
    // This works for iOS 5, but not iOS 6. Very confusing.
//    [window addSubview:tabBarController.view];
    
    // This is the line that we need for iOS 6.
    // TODO: test on iOS 5.
    window.rootViewController = tabBarController;
    tabBarController.delegate = self;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if(sharedFileIsWaiting)
    {
        NSLog(@"Shared file notification in lounch");
        tabBarController.selectedIndex = kRecordingsTabBarIndex;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"FileReceivedViaShare" object:self];
    }
    else
    {
        NSLog(@"No shared files detected");
        int selectThisIndex = [[defaults valueForKey:@"tabIndex"] intValue];
        tabBarController.selectedIndex = selectThisIndex;
    }
    [window makeKeyAndVisible];

    //dropbox session
    DBSession *dbSession = [[[DBSession alloc]
                            initWithAppKey:@"ce7f9ip8scc9xyb"
                            appSecret:@"jbvj3k3xchx7qig"
                            root:kDBRootAppFolder] autorelease];

    [DBSession setSharedSession:dbSession];
}


- (void)applicationWillTerminate:(UIApplication *)application {
    
    NSLog(@"Going into background.");
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:[NSNumber numberWithInt:tabBarController.selectedIndex] forKey:@"tabIndex"];
    [defaults synchronize];
    
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    //dropbox session
    if ([[DBSession sharedSession] handleOpenURL:url]) {
        if ([[DBSession sharedSession] isLinked]) {
            NSLog(@"App linked successfully!");
            // At this point you can start making API calls
        }
        return YES;
    }
    // Add whatever other url handling code your app requires here
    return NO;
}

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

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    if ([[DBSession sharedSession] handleOpenURL:url]) {
        if ([[DBSession sharedSession] isLinked]) {
            NSLog(@"App linked successfully!");
            // At this point you can start making API calls
        }
        return YES;
    }

    //Audio file handling. Used for sharing.
    if (url) {
        NSLog(@"Scheme: %@", url.scheme);
        if (url.scheme && [url.scheme isEqualToString:@"file"]) {
            
            //TODO: Find some better place to save file
            
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
        }
    }

    return YES;
}

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

- (void)dealloc
{
    [tabBarController release];
    [window release];
    [super dealloc];
}

@end
