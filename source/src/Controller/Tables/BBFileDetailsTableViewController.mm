//
//  BBFileDetailsTableViewController.m
//  Spike Recorder
//
//  Created by Stanislav Mircic on 5/30/16.
//  Copyright © 2016 Datta Lab, Harvard University. All rights reserved.
//

#import "BBFileDetailsTableViewController.h"
#import "BBFileDetailsViewCell.h"
#import "BBCommentDetailsCell.h"

#define COMMENT_ROW 1

#define NORMAL_HEIGHT 44
#define MINIMAL_COMMENT_HEIGHT 117

@interface BBFileDetailsTableViewController ()

@end

@implementation BBFileDetailsTableViewController
@synthesize bbfile;


- (id)initWithBBFile:(BBFile *)theBBFile
{
    if (self = [super init]) {
        self.bbfile = theBBFile;
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(dismissKeyboard)];
    
    [self.view addGestureRecognizer:tap];
}

-(void)dismissKeyboard {
    [[self view] endEditing:TRUE];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewWillDisappear:(BOOL)animated
{
    

    BBCommentDetailsCell *commentCell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:COMMENT_ROW inSection:0]];
    NSString * commentstr = commentCell.textTV.text;
    bbfile.comment = commentstr;
    
    BBFileDetailsViewCell *nameCell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
    NSString * namestr = nameCell.textTI.text;
    bbfile.shortname = namestr;
    
    
    [bbfile saveWithoutArrays];
    [super viewWillDisappear:animated];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {

    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {

    return 7;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(((int)indexPath.row) == COMMENT_ROW)
    {
        return MINIMAL_COMMENT_HEIGHT;
    }
    else
    {
        return NORMAL_HEIGHT;
    }
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    
    
    
    if((int)(indexPath.row) == COMMENT_ROW)
    {
        // IF we are in second (comment) cell make custom cell
        BBCommentDetailsCell *commentCell = [tableView dequeueReusableCellWithIdentifier:@"fileCommentCell"];
        
        if (commentCell == nil) {
            [tableView registerNib:[UINib nibWithNibName:@"BBCommentDetailsCell" bundle:nil] forCellReuseIdentifier:@"fileCommentCell"];
            commentCell = [tableView dequeueReusableCellWithIdentifier:@"fileCommentCell"];
        }

        commentCell.selectionStyle = UITableViewCellSelectionStyleNone;
        commentCell.textTV.text = self.bbfile.comment;
        return commentCell;
    }
    
    
    
    // See if there's an existing cell we can reuse
    BBFileDetailsViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"fileDetailsCell"];
    
    if (cell == nil) {
        [tableView registerNib:[UINib nibWithNibName:@"BBFileDetailsViewCell" bundle:nil] forCellReuseIdentifier:@"fileDetailsCell"];
        cell = [tableView dequeueReusableCellWithIdentifier:@"fileDetailsCell"];
    }
    
    
    // Customize cell
    switch ((int)indexPath.row) {
        case 0:
            cell.nameLabel.text = @"Filename";
            cell.textTI.text = self.bbfile.shortname;
            break;
        case 2:
            cell.nameLabel.text = @"Recorded On";
            cell.textTI.text = self.bbfile.subname;
            [cell.textTI setEnabled:NO];
            break;
        case 3:
            cell.nameLabel.text = @"Sampling rate";
            cell.textTI.text = [NSString stringWithFormat:@"%d",(int)self.bbfile.samplingrate];
            [cell.textTI setEnabled:NO];
            break;
        case 4:
            cell.nameLabel.text = @"Number of channels";
            cell.textTI.text = [NSString stringWithFormat:@"%d",(int)self.bbfile.numberOfChannels];
            [cell.textTI setEnabled:NO];
            break;
        case 5:
            cell.nameLabel.text = @"Gain";
            cell.textTI.text = [NSString stringWithFormat:@"%f",self.bbfile.gain];
            [cell.textTI setEnabled:NO];
            break;
        case 6:
            cell.nameLabel.text = @"File length (s)";
            cell.textTI.text = [NSString stringWithFormat:@"%f",self.bbfile.filelength];
            [cell.textTI setEnabled:NO];
            break;
            
        default:
            cell.nameLabel.text = @"";
            cell.textTI.text = @"";
            break;
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    return cell;
     
    
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
