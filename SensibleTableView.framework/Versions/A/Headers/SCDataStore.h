/*
 *  SCDataStore.h
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
#import "SCDataDefinition.h"
#import "SCDataFetchOptions.h"



/* Data store notifications (used internally) */
extern NSString * const SCDataStoreWillDiscardAllUninsertedObjectsNotification;


typedef enum { SCStoreModeSynchronous, SCStoreModeAsynchronous } SCStoreMode;
typedef void(^SCDataStoreSuccess_Block)(NSArray *results);
typedef void(^SCDataStoreFailure_Block)(void);

@interface SCDataStore : NSObject
{
    SCStoreMode _storeMode;
    
    NSObject *_data;
    SCDataDefinition *_defaultDataDefinition;
    NSMutableDictionary *_dataDefinitions;
    
    // Internal (must be managed by subclasses)
    NSMutableArray *_uninsertedObjects;
    NSObject *_boundObject;
    NSString *_boundPropertyName;
    SCDataDefinition *_boundObjectDefinition;
    
    NSDictionary *_defaultsDictionary;
}

+ (id)storeWithDefaultDataDefinition:(SCDataDefinition *)definition;

- (id)initWithDefaultDataDefinition:(SCDataDefinition *)definition;


@property (nonatomic, readwrite) SCStoreMode storeMode;

/** Subclasses should set this to their data. */
@property (nonatomic, strong) NSObject *data;

@property (nonatomic, strong) SCDataDefinition *defaultDataDefinition;

@property (nonatomic, strong) NSDictionary *defaultsDictionary;


- (NSObject *)createNewObjectWithDefinition:(SCDataDefinition *)definition;

/** Any object created with newObjectWithDefinition and not later inserted to the store using insertObject must be discarded using this method.
    @return Returns TRUE if successful.
 */
- (BOOL)discardUninsertedObject:(NSObject *)object;

- (BOOL)insertObject:(NSObject *)object;

- (BOOL)insertObject:(NSObject *)object atOrder:(NSUInteger)order;

- (BOOL)changeOrderForObject:(NSObject *)object toOrder:(NSUInteger)toOrder;

- (BOOL)updateObject:(NSObject *)object;

- (BOOL)deleteObject:(NSObject *)object;

- (NSArray *)fetchObjectsWithOptions:(SCDataFetchOptions *)fetchOptions;

- (NSObject *)valueForPropertyName:(NSString *)propertyName inObject:(NSObject *)object;

- (NSString *)stringValueForPropertyName:(NSString *)propertyName inObject:(NSObject *)object
			separateValuesUsingDelimiter:(NSString *)delimiter;

- (void)setValue:(NSObject *)value forPropertyName:(NSString *)propertyName inObject:(NSObject *)object;



// Asynchronous

- (void)asynchronousFetchObjectsWithOptions:(SCDataFetchOptions *)fetchOptions success:(SCDataStoreSuccess_Block)success_block failure:(SCDataStoreFailure_Block)failure_block;



// validation
- (BOOL)validateInsertForObject:(NSObject *)object;
- (BOOL)validateUpdateForObject:(NSObject *)object;
- (BOOL)validateDeleteForObject:(NSObject *)object;
- (BOOL)validateOrderChangeForObject:(NSObject *)object;




/** Adds a definition to dataDefinitions. */
- (void)addDataDefinition:(SCDataDefinition *)definition;

- (SCDataDefinition *)definitionForObject:(NSObject *)object;








/** Should only be used by the framework. Must be implemented by subclasses. */
- (void)bindStoreToPropertyName:(NSString *)propertyName forObject:(NSObject *)object withDefinition:(SCDataDefinition *)definition;

/** This method is typically called internally by the framework when all unadded objects must be discarded. The method will issue the 'SCDataStoreWillDiscardAllUnaddedObjectsNotification' notification to inform all classes using the store that this will happen. */
- (void)forceDiscardAllUnaddedObjects;


@end


