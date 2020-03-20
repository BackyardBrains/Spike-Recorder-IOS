//
//  ConfigViewController.m
//  Spike Recorder
//
//  Created by Stanislav on 15/03/2020.
//  Copyright © 2020 BackyardBrains. All rights reserved.
//

#import "ConfigViewController.h"
#import "ChannelColorsTableViewCell.h"
@interface ConfigViewController ()

@end

@implementation ConfigViewController
@synthesize selectNotchFilter;
@synthesize lowTI;
@synthesize highTI;
@synthesize channelsTableView;
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    //UIFont *font = [UIFont fontWithName:@"ComicBook-BoldItalic" size:16.0f];
    //NSDictionary *attributes = [NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName];
    //[self.selectNotch setTitleTextAttributes:attributes forState:UIControlStateNormal];
    //[[UISegmentedControl appearance] setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[UIFont fontWithName:@"ComicBook-BoldItalic" size:16.0], NSFontAttributeName, nil] forState:UIControlStateNormal];
    [selectNotchFilter setTitleTextAttributes:@{NSFontAttributeName :[UIFont fontWithName:@"ComicBook-BoldItalic" size:16.0] } forState:UIControlStateNormal];
    //[[UISegmentedControl appearance] setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[UIFont fontWithName:@"ComicBook-BoldItalic" size:16.0], UITextAttributeFont, nil] forState:UIControlStateNormal];
     [lowTI setText:@"34"];
     [highTI setText:@"506"];
    channelsTableView.dataSource = self;
    channelsTableView.delegate = self;
    //[selectNotch setTintColor:[UIColor blackColor]];
   
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 4;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
     static NSString *CellIdentifier = @"ChannelColorsTableViewCell";
    ChannelColorsTableViewCell *cell =[channelsTableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[ChannelColorsTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    cell.colorChooser.nameLabel.text = [NSString stringWithFormat:@"Channel %ld", (long)indexPath.row];

    return cell;
}
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (void)dealloc {
    [lowTI release];
    [selectNotchFilter release];
    [highTI release];
    [channelsTableView release];
    [super dealloc];
}
@end
