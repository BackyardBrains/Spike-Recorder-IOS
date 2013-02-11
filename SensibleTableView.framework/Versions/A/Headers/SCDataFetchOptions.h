/*
 *  SCDataFetchOptions.h
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


@interface SCDataFetchOptions : NSObject
{
    BOOL _sort;
    NSString *_sortKey;
    BOOL _sortAscending;
    BOOL _filter;
    NSPredicate *_filterPredicate;
    NSUInteger _batchSize;
    NSUInteger _batchStartingOffset;
    NSUInteger _batchCurrentOffset;
}

/** Allocates and returns an initialized 'SCDataFetchOptions' object. */
+ (id)options;

+ (id)optionsWithSortKey:(NSString *)key sortAscending:(BOOL)ascending filterPredicate:(NSPredicate *)predicate;

- (id)initWithSortKey:(NSString *)key sortAscending:(BOOL)ascending filterPredicate:(NSPredicate *)predicate;

@property (nonatomic, readwrite) BOOL sort;
@property (nonatomic, copy) NSString *sortKey;
@property (nonatomic, readwrite) BOOL sortAscending;

@property (nonatomic, readwrite) BOOL filter;
@property (nonatomic, strong) NSPredicate *filterPredicate;

/* zero to disable batches. */
@property (nonatomic, readwrite) NSUInteger batchSize;
@property (nonatomic, readwrite) NSUInteger batchStartingOffset;
@property (nonatomic, readonly) NSUInteger batchCurrentOffset;


// convenience methods
- (NSArray *)sortDescriptors;
- (void)sortMutableArray:(NSMutableArray *)array;
- (void)filterMutableArray:(NSMutableArray *)array;


// internal
- (void)setBatchOffset:(NSUInteger)offset;
- (void)incrementBatchOffset;
- (void)resetBatchOffset;


@end






