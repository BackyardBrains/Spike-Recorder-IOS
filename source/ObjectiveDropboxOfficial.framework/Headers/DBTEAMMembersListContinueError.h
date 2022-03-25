///
/// Copyright (c) 2016 Dropbox, Inc. All rights reserved.
///
/// Auto-generated by Stone, do not modify.
///

#import <Foundation/Foundation.h>

#import "DBSerializableProtocol.h"

@class DBTEAMMembersListContinueError;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - API Object

///
/// The `MembersListContinueError` union.
///
/// This class implements the `DBSerializable` protocol (serialize and
/// deserialize instance methods), which is required for all Obj-C SDK API route
/// objects.
///
@interface DBTEAMMembersListContinueError : NSObject <DBSerializable, NSCopying>

#pragma mark - Instance fields

/// The `DBTEAMMembersListContinueErrorTag` enum type represents the possible
/// tag states with which the `DBTEAMMembersListContinueError` union can exist.
typedef NS_ENUM(NSInteger, DBTEAMMembersListContinueErrorTag) {
  /// The cursor is invalid.
  DBTEAMMembersListContinueErrorInvalidCursor,

  /// (no description).
  DBTEAMMembersListContinueErrorOther,

};

/// Represents the union's current tag state.
@property (nonatomic, readonly) DBTEAMMembersListContinueErrorTag tag;

#pragma mark - Constructors

///
/// Initializes union class with tag state of "invalid_cursor".
///
/// Description of the "invalid_cursor" tag state: The cursor is invalid.
///
/// @return An initialized instance.
///
- (instancetype)initWithInvalidCursor;

///
/// Initializes union class with tag state of "other".
///
/// @return An initialized instance.
///
- (instancetype)initWithOther;

- (instancetype)init NS_UNAVAILABLE;

#pragma mark - Tag state methods

///
/// Retrieves whether the union's current tag state has value "invalid_cursor".
///
/// @return Whether the union's current tag state has value "invalid_cursor".
///
- (BOOL)isInvalidCursor;

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
/// The serialization class for the `DBTEAMMembersListContinueError` union.
///
@interface DBTEAMMembersListContinueErrorSerializer : NSObject

///
/// Serializes `DBTEAMMembersListContinueError` instances.
///
/// @param instance An instance of the `DBTEAMMembersListContinueError` API
/// object.
///
/// @return A json-compatible dictionary representation of the
/// `DBTEAMMembersListContinueError` API object.
///
+ (nullable NSDictionary *)serialize:(DBTEAMMembersListContinueError *)instance;

///
/// Deserializes `DBTEAMMembersListContinueError` instances.
///
/// @param dict A json-compatible dictionary representation of the
/// `DBTEAMMembersListContinueError` API object.
///
/// @return An instantiation of the `DBTEAMMembersListContinueError` object.
///
+ (DBTEAMMembersListContinueError *)deserialize:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
