/*
 *  SCDetailViewControllerOptions.h
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

#import "SCViewControllerTypedefs.h"


@interface SCDetailViewControllerOptions : NSObject


@property (nonatomic, readwrite) SCPresentationMode presentationMode;

/** The modal presentation style of the detail view. Default: UIModalPresentationPageSheet.
 @warning Note: Only applicable if presentationMode equals SCPresentationModeModal. */
@property (nonatomic, readwrite) UIModalPresentationStyle modalPresentationStyle;

/** The navigation bar type of the detail view controller. Default: SCNavigationBarTypeAuto. Set to SCNavigationBarTypeNone to have simple back button navigation. */
@property (nonatomic, readwrite) SCNavigationBarType navigationBarType;

/** The title of the detail view controller. Set to nil to have the presenting control set a title automatically. Default: nil. */
@property (nonatomic, copy) NSString *title;

/** The style of the detail view controller's table view. Default: Depends on the control presenting the view controller. */
@property (nonatomic, readwrite) UITableViewStyle tableViewStyle;

/** Indicates whether the bar at the bottom of the screen is hidden when the detail view controller is pushed. Default: TRUE. */
@property (nonatomic, readwrite) BOOL hidesBottomBarWhenPushed;

@end


