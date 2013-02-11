/*
 *  SCCellActions.h
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

@class SCTableViewModel;
@class SCTableViewCell;

typedef void(^SCCellAction_Block)(SCTableViewCell *aCell, NSIndexPath *indexPath);
typedef BOOL(^SCCellValueIsValidAction_Block)(SCTableViewCell *aCell, NSIndexPath *indexPath);
typedef void(^SCCellCustomButtonTappedAction_Block)(SCTableViewCell *aCell, NSIndexPath *indexPath, UIButton *button);

typedef UIViewController*(^SCCellDetailViewControllerAction_Block)(SCTableViewCell *aCell);
typedef SCTableViewModel*(^SCCellDetailTableViewModelAction_Block)(SCTableViewCell *aCell);


/****************************************************************************************/
/*	class SCCellActions	*/
/****************************************************************************************/ 
/**	
 This class functions as a set of cell action blocks. 
 
 Set each cell action to the desired code block. The code blocks set will execute when each action occurs.
 */
@interface SCCellActions : NSObject

@property (nonatomic, copy) SCCellAction_Block willStyle;
@property (nonatomic, copy) SCCellAction_Block willConfigure;
@property (nonatomic, copy) SCCellAction_Block didLayoutSubviews;
@property (nonatomic, copy) SCCellAction_Block willDisplay;
@property (nonatomic, copy) SCCellAction_Block lazyLoad;
@property (nonatomic, copy) SCCellAction_Block willSelect;
@property (nonatomic, copy) SCCellAction_Block didSelect;
@property (nonatomic, copy) SCCellAction_Block willDeselect;
@property (nonatomic, copy) SCCellAction_Block didDeselect;
@property (nonatomic, copy) SCCellAction_Block accessoryButtonTapped;
@property (nonatomic, copy) SCCellAction_Block returnButtonTapped;
@property (nonatomic, copy) SCCellAction_Block valueChanged;
@property (nonatomic, copy) SCCellValueIsValidAction_Block valueIsValid;

@property (nonatomic, copy) SCCellCustomButtonTappedAction_Block customButtonTapped;

@property (nonatomic, copy) SCCellDetailViewControllerAction_Block detailViewController;
@property (nonatomic, copy) SCCellDetailTableViewModelAction_Block detailTableViewModel;


- (void)setActionsTo:(SCCellActions *)actions overrideExisting:(BOOL)override;

@end
