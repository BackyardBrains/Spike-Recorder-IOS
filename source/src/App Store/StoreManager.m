//
//  StoreManager.m
//  Spike Recorder
//
//  Created by Stanislav on 10/16/19.
//  Copyright © 2019 BackyardBrains. All rights reserved.
//

/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 Retrieves product information from the App Store using SKRequestDelegate, SKProductsRequestDelegate, SKProductsResponse, and SKProductsRequest.
 Notifies its observer with a list of products available for sale along with a list of invalid product identifiers. Logs an error message if the
 product request failed.
 */

#import "Section.h"
#import "StoreManager.h"

@interface StoreManager()<SKRequestDelegate, SKProductsRequestDelegate>
/// Keeps track of all valid products. These products are available for sale in the App Store.
@property (strong) NSMutableArray *availableProducts;

/// Keeps track of all invalid product identifiers.
@property (strong) NSMutableArray *invalidProductIdentifiers;

/// Keeps a strong reference to the product request.
@property (strong) SKProductsRequest *productRequest;
@end

@implementation StoreManager

+ (StoreManager *)sharedInstance {
    static dispatch_once_t onceToken;
    static StoreManager * storeManagerSharedInstance;
    
    dispatch_once(&onceToken, ^{
        storeManagerSharedInstance = [[StoreManager alloc] init];
    });
    return storeManagerSharedInstance;
}

- (instancetype)init {
    self = [super init];
    
    if (self != nil) {
        _availableProducts = [[NSMutableArray alloc] initWithCapacity:0];
        _invalidProductIdentifiers = [[NSMutableArray alloc] initWithCapacity:0];
        _storeResponse = [[NSMutableArray alloc] initWithCapacity:0];
        _status = PCSProductRequestStatusNone;
    }
    return self;
}

#pragma mark - Request Information

/// Starts the product request with the specified identifiers.
-(void)startProductRequestWithIdentifiers:(NSArray *)identifiers {
    [self fetchProductsMatchingIdentifiers:identifiers];
}

/// Fetches information about your products from the App Store.
-(void)fetchProductsMatchingIdentifiers:(NSArray *)identifiers {
    // Create a set for the product identifiers.
    NSSet *productIdentifiers = [NSSet setWithArray:identifiers];
    
    // Initialize the product request with the above identifiers.
    self.productRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:productIdentifiers];
    self.productRequest.delegate = self;
    
    // Send the request to the App Store.
    [self.productRequest start];
}

#pragma mark - SKProductsRequestDelegate

/// Used to get the App Store's response to your request and notify your observer.
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    if (self.storeResponse.count > 0) {
        [self.storeResponse removeAllObjects];
    }
    
    // products contains products whose identifiers have been recognized by the App Store. As such, they can be purchased.
    if ((response.products).count > 0) {
        self.availableProducts = [NSMutableArray arrayWithArray:response.products];
        Section *section = [[Section alloc] initWithName:PCSProductsAvailableProducts elements:response.products];
        [self.storeResponse addObject:section];
    }
    
    // invalidProductIdentifiers contains all product identifiers not recognized by the App Store.
    if ((response.invalidProductIdentifiers).count > 0) {
        self.invalidProductIdentifiers = [NSMutableArray arrayWithArray:response.invalidProductIdentifiers];
        Section *section = [[Section alloc] initWithName:PCSProductsInvalidIdentifiers elements:response.invalidProductIdentifiers];
        [self.storeResponse addObject:section];
    }
    
    if (self.storeResponse.count > 0) {
        self.status = PCSStoreResponse;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:PCSProductRequestNotification object:self];
        });
    }
}

#pragma mark - SKRequestDelegate

/// Called when the product request failed.
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    self.status = PCSRequestFailed;
    self.message = error.localizedDescription;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:PCSProductRequestNotification object:self];
    });
}

#pragma mark - Helper Methods

/// - returns: Existing product's title matching the specified product identifier.
-(NSString *)titleMatchingIdentifier:(NSString *)identifier {
    NSString *title = nil;
    
    // Search availableProducts for a product whose productIdentifier property matches identifier. Return its localized title when found.
    for (SKProduct *product in self.availableProducts) {
        if ([product.productIdentifier isEqualToString:identifier]) {
            title = product.localizedTitle;
        }
    }
    return title;
}

/// - returns: Existing product's title associated with the specified payment transaction.
-(NSString *)titleMatchingPaymentTransaction:(SKPaymentTransaction *) transaction {
    NSString *title = [self titleMatchingIdentifier:transaction.payment.productIdentifier];
    return (title != nil) ? title : transaction.payment.productIdentifier;
}

@end
