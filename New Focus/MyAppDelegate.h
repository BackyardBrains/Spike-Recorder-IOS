//
//  MyAppDelegate.h
//  CCGLTouchBasic example
//
//  Created by Matthieu Savary on 09/09/11.
//  Copyright (c) 2011 SMALLAB.ORG. All rights reserved.
//
//  More info on the CCGLTouch project >> http://www.smallab.org/code/ccgl-touch/
//  License & disclaimer >> see license.txt file included in the distribution package
//

#import <UIKit/UIKit.h>

#import "CCGLTouchAppDelegate.h"

#import "ViewAndRecordViewController.h"
#import "MyCinderGLView.h"
#import "BBAudioManager.h"

@interface MyAppDelegate : CCGLTouchAppDelegate <UITabBarControllerDelegate>{
    UIWindow *window;
    UITabBarController *tabBarController;
}
@property (retain, nonatomic) IBOutlet UITabBarController *tabBarController;
@property (retain, nonatomic) IBOutlet UIWindow *window;
@end
