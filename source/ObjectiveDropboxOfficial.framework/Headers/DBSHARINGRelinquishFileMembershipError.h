///
/// Copyright (c) 2016 Dropbox, Inc. All rights reserved.
///
/// Auto-generated by Stone, do not modify.
///

#import <Foundation/Foundation.h>

#import "DBSerializableProtocol.h"

@class DBSHARINGRelinquishFileMembershipError;
@class DBSHARINGSharingFileAccessError;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - API Object

///
/// The `RelinquishFileMembershipError` union.
///
/// This class implements the `DBSerializable` protocol (serialize and
/// deserialize instance methods), which is required for all Obj-C SDK API route
/// objects.
///
@interface DBSHARINGRelinquishFileMembershipError : NSObject <DBSerializable, NSCopying>

#pragma mark - Instance fields

/// The `DBSHARINGRelinquishFileMembershipErrorTag` enum type represents the
/// possible tag states with which the `DBSHARINGRelinquishFileMembershipError`
/// union can exist.
typedef NS_ENUM(NSInteger, DBSHARINGRelinquishFileMembershipErrorTag) {
  /// (no description).
  DBSHARINGRelinquishFileMembershipErrorAccessError,

  /// The current user has access to the shared file via a group.  You can't
  /// relinquish membership to a file shared via groups.
  DBSHARINGRelinquishFileMembershipErrorGroupAccess,

  /// The current user does not have permission to perform this action.
  DBSHARINGRelinquishFileMembershipErrorNoPermission,

  /// (no description).
  DBSHARINGRelinquishFileMembershipErrorOther,

};

/// Represents the union's current tag state.
@property (nonatomic, readonly) DBSHARINGRelinquishFileMembershipErrorTag tag;

/// (no description). @note Ensure the `isAccessError` method returns true
/// before accessing, otherwise a runtime exception will be raised.
@property (nonatomic, readonly) DBSHARINGSharingFileAccessError *accessError;

#pragma mark - Constructors

///
/// Initializes union class with tag state of "access_error".
///
/// @param accessError (no description).
///
/// @return An initialized instance.
///
- (instancetype)initWithAccessError:(DBSHARINGSharingFileAccessError *)accessError;

///
/// Initializes union class with tag state of "group_access".
///
/// Description of the "group_access" tag state: The current user has access to
/// the shared file via a group.  You can't relinquish membership to a file
/// shared via groups.
///
/// @return An initialized instance.
///
- (instancetype)initWithGroupAccess;

///
/// Initializes union class with tag state of "no_permission".
///
/// Description of the "no_permission" tag state: The current user does not have
/// permission to perform this action.
///
/// @return An initialized instance.
///
- (instancetype)initWithNoPermission;

///
/// Initializes union class with tag state of "other".
///
/// @return An initialized instance.
///
- (instancetype)initWithOther;

- (instancetype)init NS_UNAVAILABLE;

#pragma mark - Tag state methods

///
/// Retrieves whether the union's current tag state has value "access_error".
///
/// @note Call this method and ensure it returns true before accessing the
/// `accessError` property, otherwise a runtime exception will be thrown.
///
/// @return Whether the union's current tag state has value "access_error".
///
- (BOOL)isAccessError;

///
/// Retrieves whether the union's current tag state has value "group_access".
///
/// @return Whether the union's current tag state has value "group_access".
///
- (BOOL)isGroupAccess;

///
/// Retrieves whether the union's current tag state has value "no_permission".
///
/// @return Whether the union's current tag state has value "no_permission".
///
- (BOOL)isNoPermission;

///
/// Retrieves whether the union's current tag state has value "other".
///
/// @return Whether the union's current tag state has value "other".
///
- (BOOL)isOther;

///
/// Retrieves string value of union's current tag state.
///
/// @return A human-readable string representing the union's current tag state.
///
- (NSString *)tagName;

@end

#pragma mark - Serializer Object

///
/// The serialization class for the `DBSHARINGRelinquishFileMembershipError`
/// union.
///
@interface DBSHARINGRelinquishFileMembershipErrorSerializer : NSObject

///
/// Serializes `DBSHARINGRelinquishFileMembershipError` instances.
///
/// @param instance An instance of the `DBSHARINGRelinquishFileMembershipError`
/// API object.
///
/// @return A json-compatible dictionary representation of the
/// `DBSHARINGRelinquishFileMembershipError` API object.
///
+ (nullable NSDictionary *)serialize:(DBSHARINGRelinquishFileMembershipError *)instance;

///
/// Deserializes `DBSHARINGRelinquishFileMembershipError` instances.
///
/// @param dict A json-compatible dictionary representation of the
/// `DBSHARINGRelinquishFileMembershipError` API object.
///
/// @return An instantiation of the `DBSHARINGRelinquishFileMembershipError`
/// object.
///
+ (DBSHARINGRelinquishFileMembershipError *)deserialize:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
