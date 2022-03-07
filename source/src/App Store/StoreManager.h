//
//  StoreManager.h
//  Spike Recorder
//
//  Created by Stanislav on 10/16/19.
//  Copyright © 2019 BackyardBrains. All rights reserved.
//

/*
 Retrieves product information from the App Store using SKRequestDelegate, SKProductsRequestDelegate, SKProductsResponse, and SKProductsRequest.
 Notifies its observer with a list of products available for sale along with a list of invalid product identifiers. Logs an error message if the
 product request failed.
 */

#import <StoreKit/StoreKit.h>
//#import "AppConfiguration.h"

typedef NS_ENUM(NSInteger, PCSProductRequestStatus) {
    PCSIdentifiersNotFound, // indicates that there are some invalid product identifiers.
    PCSProductsFound,// Indicates that there are some valid products.
    PCSRequestFailed, // Indicates that the product request has failed.
    PCSStoreResponse, // Indicates that there are some valid products, invalid product identifiers, or both available.
    PCSProductRequestStatusNone // The PCSProductRequest notification has not occured yet. This is the default value.
};



NSString *const PCSProductsAvailableProducts = @"AVAILABLE PRODUCTS";
NSString *const PCSProductsInvalidIdentifiers = @"INVALID PRODUCT IDENTIFIERS";

NSString *const PCSProductRequestNotification = @"ProductRequestNotification";
NSString *const PCSPurchaseNotification = @"PurchaseNotification";
NSString *const PCSRestoredWasCalledNotification = @"restoredWasCalledNotification";

@interface StoreManager : NSObject
+ (StoreManager *)sharedInstance;

/// Indicates the cause of the product request failure.
@property (nonatomic, copy) NSString *message;

/// Provides the status of the product request.
@property (nonatomic) PCSProductRequestStatus status;

/// Keeps track of all valid products (these products are available for sale in the App Store) and of all invalid product identifiers.
@property (strong) NSMutableArray *storeResponse;

/// Starts the product request with the specified identifiers.
-(void)startProductRequestWithIdentifiers:(NSArray *)identifiers;

/// - returns: Existing product's title matching the specified product identifier.
-(NSString *)titleMatchingIdentifier:(NSString *)identifier;

/// - returns: Existing product's title associated with the specified payment transaction.
-(NSString *)titleMatchingPaymentTransaction:(SKPaymentTransaction *)transaction;
@end
