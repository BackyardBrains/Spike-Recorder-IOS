//
//  StimulationParameterViewController.h
//  New Focus
//
//  Created by Alex Wiltschko on 7/10/12.
//  Copyright (c) 2012 Datta Lab, Harvard University. All rights reserved.
//

#import <SensibleTableView/SensibleTableView.h>
#import "BBAudioManager.h"

@interface StimulationParameterViewController : SCTableViewController
{
    NSMutableDictionary *_valuesDictionary;
    SCTableViewSection *digitalSignalSection;
    SCTableViewSection *pulseSection;
    SCTableViewSection *toneSection;

}
@property (retain, nonatomic) IBOutlet UITableView *tableView;
@end
