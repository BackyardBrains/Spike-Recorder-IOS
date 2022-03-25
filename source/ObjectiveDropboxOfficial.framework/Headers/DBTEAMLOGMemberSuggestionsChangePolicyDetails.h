///
/// Copyright (c) 2016 Dropbox, Inc. All rights reserved.
///
/// Auto-generated by Stone, do not modify.
///

#import <Foundation/Foundation.h>

#import "DBSerializableProtocol.h"

@class DBTEAMLOGMemberSuggestionsChangePolicyDetails;
@class DBTEAMLOGMemberSuggestionsPolicy;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - API Object

///
/// The `MemberSuggestionsChangePolicyDetails` struct.
///
/// Enabled/disabled option for team members to suggest people to add to team.
///
/// This class implements the `DBSerializable` protocol (serialize and
/// deserialize instance methods), which is required for all Obj-C SDK API route
/// objects.
///
@interface DBTEAMLOGMemberSuggestionsChangePolicyDetails : NSObject <DBSerializable, NSCopying>

#pragma mark - Instance fields

/// New team member suggestions policy.
@property (nonatomic, readonly) DBTEAMLOGMemberSuggestionsPolicy *dNewValue;

/// Previous team member suggestions policy. Might be missing due to historical
/// data gap.
@property (nonatomic, readonly, nullable) DBTEAMLOGMemberSuggestionsPolicy *previousValue;

#pragma mark - Constructors

///
/// Full constructor for the struct (exposes all instance variables).
///
/// @param dNewValue New team member suggestions policy.
/// @param previousValue Previous team member suggestions policy. Might be
/// missing due to historical data gap.
///
/// @return An initialized instance.
///
- (instancetype)initWithDNewValue:(DBTEAMLOGMemberSuggestionsPolicy *)dNewValue
                    previousValue:(nullable DBTEAMLOGMemberSuggestionsPolicy *)previousValue;

///
/// Convenience constructor (exposes only non-nullable instance variables with
/// no default value).
///
/// @param dNewValue New team member suggestions policy.
///
/// @return An initialized instance.
///
- (instancetype)initWithDNewValue:(DBTEAMLOGMemberSuggestionsPolicy *)dNewValue;

- (instancetype)init NS_UNAVAILABLE;

@end

#pragma mark - Serializer Object

///
/// The serialization class for the `MemberSuggestionsChangePolicyDetails`
/// struct.
///
@interface DBTEAMLOGMemberSuggestionsChangePolicyDetailsSerializer : NSObject

///
/// Serializes `DBTEAMLOGMemberSuggestionsChangePolicyDetails` instances.
///
/// @param instance An instance of the
/// `DBTEAMLOGMemberSuggestionsChangePolicyDetails` API object.
///
/// @return A json-compatible dictionary representation of the
/// `DBTEAMLOGMemberSuggestionsChangePolicyDetails` API object.
///
+ (nullable NSDictionary *)serialize:(DBTEAMLOGMemberSuggestionsChangePolicyDetails *)instance;

///
/// Deserializes `DBTEAMLOGMemberSuggestionsChangePolicyDetails` instances.
///
/// @param dict A json-compatible dictionary representation of the
/// `DBTEAMLOGMemberSuggestionsChangePolicyDetails` API object.
///
/// @return An instantiation of the
/// `DBTEAMLOGMemberSuggestionsChangePolicyDetails` object.
///
+ (DBTEAMLOGMemberSuggestionsChangePolicyDetails *)deserialize:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
