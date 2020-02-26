//
//  StoreObserver.h
//  Spike Recorder
//
//  Created by Stanislav on 10/16/19.
//  Copyright © 2019 BackyardBrains. All rights reserved.
//

#import <Foundation/Foundation.h>
/*
 Implements the SKPaymentTransactionObserver protocol. Handles purchasing and restoring products using paymentQueue:updatedTransactions: .
 */

#import <StoreKit/StoreKit.h>
//#import "AppConfiguration.h"


typedef NS_ENUM(NSInteger, PCSPurchaseStatus) {
    PCSPurchaseFailed, // Indicates that the purchase was unsuccessful.
    PCSPPurchaseSucceeded, // Indicates that the purchase was successful.
    PCSRestoreFailed, // Indicates that restoring purchases was unsuccessful.
    PCSRestoreSucceeded, // Indicates that restoring purchases was successful.
    PCSNoRestorablePurchases, // Indicates that there are no restorable purchases.
    PCSPurchaseStatusNone // The PCSPurchase notification has not occured yet. This is the default value.
};

//NSString *const PCSProductRequestNotification = @"ProductRequestNotification";
//NSString *const PCSPurchaseNotification = @"PurchaseNotification";
//NSString *const PCSRestoredWasCalledNotification = @"restoredWasCalledNotification";

@interface StoreObserver : NSObject <SKPaymentTransactionObserver>
+ (StoreObserver *)sharedInstance;

/**
 Indicates whether the user is allowed to make payments.
 - returns: true if the user is allowed to make payments and false, otherwise. Tell StoreManager to query the App Store when the user is allowed to
 make payments and there are product identifiers to be queried.
 */
@property (NS_NONATOMIC_IOSONLY, readonly) BOOL isAuthorizedForPayments;

/// Indicates the cause of the purchase failure.
@property (nonatomic, copy) NSString *message;

/// Keeps track of all purchases.
@property (strong) NSMutableArray *productsPurchased;

/// Keeps track of all restored purchases.
@property (strong) NSMutableArray *productsRestored;

/// Indicates the purchase status.
@property (nonatomic) PCSPurchaseStatus status;

/// Implements the purchase of a product.
-(void)buy:(SKProduct *)product;

/// Implements the restoration of previously completed purchases.
-(void)restore;
@end

