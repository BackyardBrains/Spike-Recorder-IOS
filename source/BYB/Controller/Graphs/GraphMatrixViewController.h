//
//  GraphMatrixViewController.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 7/4/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BBFile.h"

@interface GraphMatrixViewController : UIViewController <UICollectionViewDataSource, UICollectionViewDelegate>

@property (retain, nonatomic) IBOutlet UICollectionView *collectionView;

@property (retain, nonatomic) BBFile *bbfile;

@end
