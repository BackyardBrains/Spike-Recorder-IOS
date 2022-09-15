//
// MyAppDelegate.mm
// Backyard Brains
//

#import "MyAppDelegate.h"
#import "ZipArchive.h"
#import "BBEvent.h"
#import "BBAudioFileReader.h"
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>
#import <ObjectiveDropboxOfficial/ObjectiveDropboxOfficial.h>



//Tab bar pages indexes
#define kViewRecordTabBarIndex  0
#define kThresholdTabBarIndex   1
#define kRecordingsTabBarIndex  2
#define kFFTTabBarIndex         3

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
    
    //DropBox V2
    [DBClientsManager setupWithAppKey:@"r3clmvcekkjiams"];
    
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    
   
    
//------------------------------ MFI ----------------------------------
     demoProtocol = [[DemoProtocol alloc] init];
    [demoProtocol initProtocol];
//------------------------------ MFI ----------------------------------
    
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

- (NSString *)findExtensionOfFileInUrl:(NSURL *)url{

    NSString *urlString = [url absoluteString];
    NSArray *componentsArray = [urlString componentsSeparatedByString:@"."];
    NSString *fileExtension = [componentsArray lastObject];
    return  fileExtension;
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
    if (url)
    {
        NSLog(@"Scheme: %@", url.scheme);
        if (url.scheme && [url.scheme isEqualToString:@"file"])
        {
            
            if([[[self findExtensionOfFileInUrl:url] lowercaseString] isEqualToString:@"byb"])
            {
                
                
                
                NSError *error = nil;
                NSArray *paths =  NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);//NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
                NSString *zipPath = [url absoluteString];
                NSString *path = [paths objectAtIndex:0];
                NSString *fullPathOfZip = [NSString stringWithFormat:@"%@/%@", path, [url lastPathComponent]];
                
                NSData *data = [NSData dataWithContentsOfURL:url options:0 error:&error];
                [data writeToFile:fullPathOfZip options:0 error:&error];

                      
                // TODO: Unzip
                ZipArchive *za = [[ZipArchive alloc] init];

               if ([za UnzipOpenFile: fullPathOfZip])
               {
                    BOOL ret = [za UnzipFileTo: path overWrite: YES];
                    if (NO == ret){} [za UnzipCloseFile];
                    NSString *extractedWavFilePath = [path stringByAppendingPathComponent:@"signal.wav"];
                    NSString *newWavFilePath = [NSString stringWithFormat:@"%@/%@.wav",path, [[url lastPathComponent] stringByDeletingPathExtension]];
                   
                   //NSString *newWavName = [NSString stringWithFormat:@"%@/signal42.wav",path];
                   //NSString *headerFilePath = [path stringByAppendingPathComponent:@"header.xml"];
                    //NSString *textString = [NSString stringWithContentsOfFile:headerFilePath encoding:NSASCIIStringEncoding error:nil];
                   //NSURL *originalWavURL = [NSURL URLWithString:wavFilePath];
                   NSURL *newWavFilePathURL =  [NSURL URLWithString:newWavFilePath];
                   
                   error = nil;
                   [[NSFileManager defaultManager]  copyItemAtPath:extractedWavFilePath
                                                            toPath:newWavFilePath
                                                             error:&error];
                
                   BBFile * aFile = [[BBFile alloc] initWithUrl:newWavFilePathURL];
                   
                   if ( [[NSFileManager defaultManager] isReadableFileAtPath:[newWavFilePathURL path]] )
                   {
                       NSURL * newUrl = [aFile fileURL];
                       NSString *newPath =[newUrl path];
                       error = nil;
                       
                       [[NSFileManager defaultManager]  copyItemAtPath:newWavFilePath
                                                                toPath:newPath
                                                                 error:&error];
                       
                       error = nil;
                       [[NSFileManager defaultManager]  removeItemAtPath:newWavFilePath error:&error];
                       BBAudioFileReader * fileReader = [[BBAudioFileReader alloc]
                                                             initWithAudioFileURL:[aFile fileURL]
                                                             samplingRate:aFile.samplingrate
                                                             numChannels:aFile.numberOfChannels];
                           
                       aFile.filelength = fileReader.duration;
                       
                       
                       NSString *eventsFileName = [NSString stringWithFormat:@"%@/signal-events.txt",path];
                       if ([[NSFileManager defaultManager] isReadableFileAtPath:eventsFileName])
                       {
                           //there is a
                           NSString *textString = [NSString stringWithContentsOfFile:eventsFileName encoding:NSASCIIStringEncoding error:nil];
                           NSArray *fileLines = [textString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
                           for (int i=2;i<[fileLines count];i++)
                           {
                               NSString* newLineToParse = [fileLines objectAtIndex:i];
                               
                               
                               NSArray *items = [newLineToParse componentsSeparatedByString:@",\t"];
                               if([items count]>1)
                               {
                                   NSString * nameOfEvent = [items objectAtIndex:0];
                                   int eventType = [nameOfEvent intValue];
                                   if(eventType ==0)
                                   {
                                       NSLog(@"Reading events that do not have numberic name.");
                                       continue;
                                   }
                                   
                                   NSString * timeString = [items objectAtIndex:1];
                                   float eventTime = [timeString floatValue];
                                   if(eventTime >0.0)
                                   {
                                       BBEvent * tempEvent = [[BBEvent alloc] initWithValue:eventType index:eventTime*aFile.samplingrate andTime:eventTime];
                                        [[aFile allEvents] addObject:tempEvent];
                                   }
                               }
                           }
                           [[NSFileManager defaultManager]  removeItemAtPath:eventsFileName error:&error];
                       }
                       
                       
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
                      // }
                       [aFile release];
                       return YES;
                    }
               }
                
                
            }//end of BYB file type processing
            else
            {
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
