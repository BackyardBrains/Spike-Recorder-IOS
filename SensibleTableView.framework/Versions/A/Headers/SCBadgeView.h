/*
 *  SCBadgeView.h
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
#import "SCGlobals.h"

/****************************************************************************************/
/*	class SCBadgeView	*/
/****************************************************************************************/ 
/**	
 This class functions as a badge similar to the one used by iPhone's mail application to
 display the number of messages in an inbox. 'SCBadgeView' is most commonly used by SCTableViewCell.
 */
@interface SCBadgeView : UIView
{
	UIColor *color;
	NSString *text;
	UIFont *font;
}

//////////////////////////////////////////////////////////////////////////////////////////
/// @name Configuration
//////////////////////////////////////////////////////////////////////////////////////////

/** The color of the badge. */
@property (nonatomic, strong) UIColor *color;

/** The text displayed by the badge. */
@property (nonatomic, copy) NSString *text;

/** The font of the text. */
@property (nonatomic, strong) UIFont *font;

@end
