///
/// Copyright (c) 2016 Dropbox, Inc. All rights reserved.
///
/// Auto-generated by Stone, do not modify.
///

#import <Foundation/Foundation.h>

#import "DBSerializableProtocol.h"

@class DBTEAMLOGSharedLinkCopyDetails;
@class DBTEAMLOGUserLogInfo;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - API Object

///
/// The `SharedLinkCopyDetails` struct.
///
/// Added file/folder to Dropbox from shared link.
///
/// This class implements the `DBSerializable` protocol (serialize and
/// deserialize instance methods), which is required for all Obj-C SDK API route
/// objects.
///
@interface DBTEAMLOGSharedLinkCopyDetails : NSObject <DBSerializable, NSCopying>

#pragma mark - Instance fields

/// Shared link owner details. Might be missing due to historical data gap.
@property (nonatomic, readonly, nullable) DBTEAMLOGUserLogInfo *sharedLinkOwner;

#pragma mark - Constructors

///
/// Full constructor for the struct (exposes all instance variables).
///
/// @param sharedLinkOwner Shared link owner details. Might be missing due to
/// historical data gap.
///
/// @return An initialized instance.
///
- (instancetype)initWithSharedLinkOwner:(nullable DBTEAMLOGUserLogInfo *)sharedLinkOwner;

///
/// Convenience constructor (exposes only non-nullable instance variables with
/// no default value).
///
///
/// @return An initialized instance.
///
- (instancetype)initDefault;

- (instancetype)init NS_UNAVAILABLE;

@end

#pragma mark - Serializer Object

///
/// The serialization class for the `SharedLinkCopyDetails` struct.
///
@interface DBTEAMLOGSharedLinkCopyDetailsSerializer : NSObject

///
/// Serializes `DBTEAMLOGSharedLinkCopyDetails` instances.
///
/// @param instance An instance of the `DBTEAMLOGSharedLinkCopyDetails` API
/// object.
///
/// @return A json-compatible dictionary representation of the
/// `DBTEAMLOGSharedLinkCopyDetails` API object.
///
+ (nullable NSDictionary *)serialize:(DBTEAMLOGSharedLinkCopyDetails *)instance;

///
/// Deserializes `DBTEAMLOGSharedLinkCopyDetails` instances.
///
/// @param dict A json-compatible dictionary representation of the
/// `DBTEAMLOGSharedLinkCopyDetails` API object.
///
/// @return An instantiation of the `DBTEAMLOGSharedLinkCopyDetails` object.
///
+ (DBTEAMLOGSharedLinkCopyDetails *)deserialize:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
