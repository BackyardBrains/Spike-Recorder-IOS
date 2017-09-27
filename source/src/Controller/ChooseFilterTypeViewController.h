//
//  ChooseFilterTypeViewController.h
//  Spike Recorder
//
//  Created by Stanislav Mircic on 9/21/17.
//  Copyright © 2017 Datta Lab, Harvard University. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol ChooseFilterTypeDelegateProtocol;

@interface ChooseFilterTypeViewController : UIViewController


@property(nonatomic,assign) id <ChooseFilterTypeDelegateProtocol> delegate;

@property (retain, nonatomic) IBOutlet UIButton *rawButton;
@property (retain, nonatomic) IBOutlet UIButton *heartButton;
@property (retain, nonatomic) IBOutlet UIButton *brainButton;
@property (retain, nonatomic) IBOutlet UIButton *plantButton;
@property (retain, nonatomic) IBOutlet UIButton *customButton;
- (IBAction)rawClick:(id)sender;
- (IBAction)heartClick:(id)sender;
- (IBAction)brainClick:(id)sender;
- (IBAction)plantClick:(id)sender;
- (IBAction)customClick:(id)sender;

-(void) setBackgroundColor;

@end


@protocol ChooseFilterTypeDelegateProtocol
@required
- (void)endSelectionOfFilters:(int) filterType;
@end
