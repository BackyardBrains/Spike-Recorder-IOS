/*
 *  SCPullToRefreshView.h
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


#import "SCGlobals.h"


typedef enum
{
    SCPullToRefreshViewStatePull,
    SCPullToRefreshViewStateRelease,
    SCPullToRefreshViewStateLoading
} SCPullToRefreshViewState;


@interface SCPullToRefreshView : UIView
{
    __unsafe_unretained UIScrollView *_boundScrollView;
    __unsafe_unretained id _target;
	SEL _startLoadingAction;
}

@property (nonatomic, readonly) SCPullToRefreshViewState state;

@property (nonatomic, readonly) UILabel *stateLabel;
@property (nonatomic, readonly) UILabel *detailTextLabel;
@property (nonatomic, readonly) UIActivityIndicatorView *activityIndicator;

@property (nonatomic, copy) NSString *pullStateText;
@property (nonatomic, copy) NSString *releaseStateText;
@property (nonatomic, copy) NSString *loadingStateText;

@property (nonatomic, readonly) UIImageView *arrowImageView;




// Internal & subclasses
- (void)bindToScrollView:(UIScrollView *)scrollView;
- (void)setTarget:(id)target forStartLoadingAction:(SEL)action;
- (void)boundScrollViewDidScroll;
- (void)boundScrollViewDidEndDragging;
- (void)boundScrollViewDidFinishLoading;




@end
