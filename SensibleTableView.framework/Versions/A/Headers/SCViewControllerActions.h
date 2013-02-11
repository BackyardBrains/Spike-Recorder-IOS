/*
 *  SCViewControllerActions.h
 *  Sensible TableView
 *  Version: 3.0.5
 *
 *
 *	THIS SOURCE CODE AND ANY ACCOMPANYING DOCUMENTATION ARE PROTECTED BY UNITED STATES 
 *	INTELLECTUAL PROPERTY LAW AND INTERNATIONAL TREATIES. UNAUTHORIZED REPRODUCTION OR 
 *	DISTRIBUTION IS SUBJECT TO CIVIL AND CRIMINAL PENALTIES. YOU SHALL NOT DEVELOP NOR
 *	MAKE AVAILABLE ANY WORK THAT COMPETES WITH A SENSIBLE COCOA PRODUCT DERIVED FROM THIS 
 *	SOURCE CODE. THIS SOURCE CODE MAY NOT BE RESOLD OR REDISTRIBUTED ON A STAND ALONE BASIS.
 *
 *	USAGE OF THIS SOURCE CODE IS BOUND BY THE LICENSE AGREEMENT PROVIDED WITH THE 
 *	DOWNLOADED PRODUCT.
 *
 *  Copyright 2012 Sensible Cocoa. All rights reserved.
 *
 *
 *	This notice may not be removed from this file.
 *
 */

#import <Foundation/Foundation.h>


@class SCViewController;

typedef void(^SCViewControllerAction_Block)(SCViewController *viewController);

/****************************************************************************************/
/*	class SCViewControllerActions	*/
/****************************************************************************************/ 
/**	
 This class functions as a set of view controller action blocks. 
 
 Set each view controller action to the desired code block. The code blocks set will execute when each action occurs.
 */
@interface SCViewControllerActions : NSObject

@property (nonatomic, copy) SCViewControllerAction_Block willAppear;
@property (nonatomic, copy) SCViewControllerAction_Block didAppear;
@property (nonatomic, copy) SCViewControllerAction_Block willDisappear;
@property (nonatomic, copy) SCViewControllerAction_Block didDisappear;

@property (nonatomic, copy) SCViewControllerAction_Block willPresent;
@property (nonatomic, copy) SCViewControllerAction_Block didPresent;
@property (nonatomic, copy) SCViewControllerAction_Block willDismiss;
@property (nonatomic, copy) SCViewControllerAction_Block didDismiss;

@end
