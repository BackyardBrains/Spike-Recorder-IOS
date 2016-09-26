//
//  UIDeviceExt.m
//  UIDeviceExt
//
//  Created by Jens Schwarzer on 28/01/14.
//  Copyright (c) 2014 marchv. All rights reserved.
//

//
//  References:
//    * pixels-per-centimeter is based on http://en.wikipedia.org/wiki/List_of_displays_by_pixel_density#Apple
//    * device identifiers is based on http://theiphonewiki.com/wiki/Models
//

//
//  WARNING: This code must be updated whenever new iDevices are released
//

#import "UIDeviceExt.h"
#include <sys/utsname.h>

static float _pointsPerCentimeter;
static float _pointsPerInch;

@implementation UIDeviceExt

+(void)initialize {
    struct utsname sysinfo;
    
    if (uname(&sysinfo) == 0) {
        NSString *identifier = [NSString stringWithUTF8String:sysinfo.machine];
        
        // group devices with same points-density
        NSArray *iDevices = @[@{@"identifiers": @[@"iPad1,1",                                      // iPad
                                                  @"iPad2,1", @"iPad2,2", @"iPad2,3", @"iPad2,4",  // iPad 2
                                                  @"iPad3,1", @"iPad3,2", @"iPad3,3",              // iPad 3
                                                  @"iPad3,4", @"iPad3,5", @"iPad3,6",              // iPad 4
                                                  @"iPad4,1",                                      // ipad Air
                                                  @"iPad4,2",                                      // iPad Air
                                                  @"iPad4,3"],                                     // iPad Air
                                @"pointsPerCentimeter":  @52.0f,
                                @"pointsPerInch":       @132.0f},
                              
                              @{@"identifiers": @[@"iPod5,1",                                      // iPod Touch 5th generation
                                                  @"iPhone1,1",                                    // iPhone 2G
                                                  @"iPhone1,2",                                    // iPhone 3G
                                                  @"iPhone2,1",                                    // iPhone 3GS
                                                  @"iPhone3,1", @"iPhone3,2", @"iPhone3,3",        // iPhone 4
                                                  @"iPhone4,1",                                    // iPhone 4S
                                                  @"iPhone5,1", @"iPhone5,2",                      // iPhone 5
                                                  @"iPhone5,3", @"iPhone5,4",                      // iPhone 5C
                                                  @"iPhone6,1", @"iPhone6,2",                      // iPhone 5S
                                                  @"iPhone7,2",                                    // iPhone 6
                                                  @"iPhone8,1",                                    // iPhone 6S
                                                  @"iPhone8,4",                                    // iPhone SE
                                                  @"iPhone9,1",                                    // iPhone 7 (CDMA)
                                                  @"iPhone9,3",                                    // iPhone 7 (GSM)
                                                  
                                                  @"iPad2,5",                                      // iPad mini 1 gen
                                                  @"iPad2,6",                                      // iPad Mini 1 gen
                                                  @"iPad2,7",                                      // iPad Mini 1 gen
                                                  @"iPad4,4",                                      // iPad Mini 2 retina 2 gen
                                                  @"iPad4,5",                                      // iPad Mini 2 retina sec gen
                                                  @"iPad4,6",                                      // iPad Mini 2 Retina sec gen
                                                  @"iPad4,7",                                      // iPad Mini 3
                                                  @"iPad4,8",                                      // iPad Mini 3
                                                  @"iPad4,9",                                      // iPad Mini 3
                                                  @"iPad5,1",                                      // iPad Mini 4
                                                  @"iPad5,2",                                      // iPad Mini 4
                                                  @"iPad6,7",                                      // iPad Pro
                                                  @"iPad6,8",                                      // iPad Pro
                                                  @"iPad5,3",                                      // iPad Air 2
                                                  @"iPad5,4",                                      // iPad Air 2
                                                  @"i386", @"x86_64"],                             // iOS simulator (assuming iPad Mini simulator)
                                @"pointsPerCentimeter":  @64.0f,
                                @"pointsPerInch":       @163.0f},
                              
                              @{@"identifiers": @[@"iPhone7,1",                                    // iPhone 6 Plus
                                                  @"iPhone8,2",                                    // iPhone 6s plus
                                                  @"iPhone9,2",                                    // iPhone 7 plus
                                                  @"iPhone9,4"],                                   // iPhone7 plus
                                @"pointsPerCentimeter":  @78.724f,
                                @"pointsPerInch":       @200.5f}];
        
       
        bool foundDevice = NO;
        for (id deviceClass in iDevices)
        {
            for (NSString *deviceId in [deviceClass objectForKey:@"identifiers"])
            {
                if ([identifier isEqualToString:deviceId]) {
                    foundDevice = YES;
                    _pointsPerCentimeter = [[deviceClass objectForKey:@"pointsPerCentimeter"] floatValue];
                    _pointsPerInch       = [[deviceClass objectForKey:@"pointsPerInch"] floatValue];
                    break;
                }
            }
        }
        if(!foundDevice)
        {
            _pointsPerCentimeter = 64.0f;
            _pointsPerInch = 163.0f;
        }
        
    }
    
    NSAssert(_pointsPerCentimeter > 0.0f || _pointsPerInch > 0.0f, @"Unknown device: %s", sysinfo.machine);
}

+ (float)pointsPerCentimeter { return _pointsPerCentimeter; }
+ (float)pixelsPerCentimeter { return _pointsPerCentimeter * [[UIScreen mainScreen] scale]; } // map from POINTS to PIXELS
                              
+ (float)pointsPerInch { return _pointsPerInch; }
+ (float)pixelsPerInch { return _pointsPerInch * [[UIScreen mainScreen] scale]; } // map from POINTS to PIXELS
                              
@end
