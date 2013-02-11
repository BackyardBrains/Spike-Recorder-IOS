//
//  SCInputAccessoryView.h
//  SensibleTableView
//
//  Created by Tarek Sakr on 06/04/12.
//  Copyright (c) 2012 Sensible Cocoa. All rights reserved.
//

#import <UIKit/UIKit.h>



@protocol SCInputAccessoryViewDelegate;

@interface SCInputAccessoryView : UIView

@property (nonatomic, unsafe_unretained) id<SCInputAccessoryViewDelegate> delegate;

@property (nonatomic, readonly) UIToolbar *toolbar;

@property (nonatomic, readonly) UISegmentedControl *previousNextSegmentedControl;
@property (nonatomic, readonly) UIBarButtonItem *doneButton;

@property (nonatomic, readwrite) BOOL showClearButton;
@property (nonatomic, readonly) UIBarButtonItem *clearButton;

@property (nonatomic, readwrite) BOOL rewind;


// Internal
- (void)previousTapped;
- (void)nextTapped;
- (void)clearTapped;
- (void)doneTapped;

@end





@protocol SCInputAccessoryViewDelegate <NSObject>

@optional
- (void)inputAccessoryViewPreviousTapped:(SCInputAccessoryView *)inputAccessoryView;
- (void)inputAccessoryViewNextTapped:(SCInputAccessoryView *)inputAccessoryView;
- (void)inputAccessoryViewClearTapped:(SCInputAccessoryView *)inputAccessoryView;
- (void)inputAccessoryViewDoneTapped:(SCInputAccessoryView *)inputAccessoryView;

@end