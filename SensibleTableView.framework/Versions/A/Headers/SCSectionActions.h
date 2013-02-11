/*
 *  SCSectionActions.h
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
@class SCTableViewSection;
@class SCArrayOfItemsSection;
@class SCCustomCell;

typedef void(^SCDetailModelSectionAction_Block)(SCTableViewSection *section, SCTableViewModel *detailModel, NSIndexPath *indexPath);

typedef void(^SCDidFetchSectionItemsAction_Block)(SCArrayOfItemsSection *itemsSection, NSMutableArray *items);
typedef void(^SCDidAddSpecialCellsAction_Block)(SCArrayOfItemsSection *itemsSection, NSMutableArray *items);

typedef UIViewController*(^SCDetailViewControllerForRowAtIndexPathAction_Block)(SCTableViewSection *section, NSIndexPath *indexPath);
typedef SCTableViewModel*(^SCDetailTableViewModelForRowAtIndexPathAction_Block)(SCTableViewSection *section, NSIndexPath *indexPath);

typedef SCCustomCell*(^SCCellForRowAtIndexPathAction_Block)(SCArrayOfItemsSection *itemsSection, NSIndexPath *indexPath);
typedef NSString*(^SCReuseIdForRowAtIndexPathAction_Block)(SCArrayOfItemsSection *itemsSection, NSIndexPath *indexPath);



@interface SCSectionActions : NSObject

@property (nonatomic, copy) SCDetailModelSectionAction_Block detailModelCreated;
@property (nonatomic, copy) SCDetailModelSectionAction_Block detailModelConfigured;
@property (nonatomic, copy) SCDetailModelSectionAction_Block detailModelWillPresent;
@property (nonatomic, copy) SCDetailModelSectionAction_Block detailModelDidPresent;
@property (nonatomic, copy) SCDetailModelSectionAction_Block detailModelWillDismiss;
@property (nonatomic, copy) SCDetailModelSectionAction_Block detailModelDidDismiss;

@property (nonatomic, copy) SCDidFetchSectionItemsAction_Block didFetchItemsFromStore;
@property (nonatomic, copy) SCDidAddSpecialCellsAction_Block didAddSpecialCells;

// Custom detail view controllers
/** Must retrun either SCViewController or SCTableViewController. */
@property (nonatomic, copy) SCDetailViewControllerForRowAtIndexPathAction_Block detailViewControllerForRowAtIndexPath;
@property (nonatomic, copy) SCDetailTableViewModelForRowAtIndexPathAction_Block detailTableViewModelForRowAtIndexPath;

// Custom cells
@property (nonatomic, copy) SCCellForRowAtIndexPathAction_Block cellForRowAtIndexPath;
@property (nonatomic, copy) SCReuseIdForRowAtIndexPathAction_Block reuseIdentifierForRowAtIndexPath;


- (void)setActionsTo:(SCSectionActions *)actions overrideExisting:(BOOL)override;

@end
