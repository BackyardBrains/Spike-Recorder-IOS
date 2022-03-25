///
/// Copyright (c) 2016 Dropbox, Inc. All rights reserved.
///
/// Auto-generated by Stone, do not modify.
///

#import <Foundation/Foundation.h>

#import "DBSerializableProtocol.h"

@class DBFILEPROPERTIESModifyTemplateError;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - API Object

///
/// The `ModifyTemplateError` union.
///
/// This class implements the `DBSerializable` protocol (serialize and
/// deserialize instance methods), which is required for all Obj-C SDK API route
/// objects.
///
@interface DBFILEPROPERTIESModifyTemplateError : NSObject <DBSerializable, NSCopying>

#pragma mark - Instance fields

/// The `DBFILEPROPERTIESModifyTemplateErrorTag` enum type represents the
/// possible tag states with which the `DBFILEPROPERTIESModifyTemplateError`
/// union can exist.
typedef NS_ENUM(NSInteger, DBFILEPROPERTIESModifyTemplateErrorTag) {
  /// Template does not exist for the given identifier.
  DBFILEPROPERTIESModifyTemplateErrorTemplateNotFound,

  /// You do not have permission to modify this template.
  DBFILEPROPERTIESModifyTemplateErrorRestrictedContent,

  /// (no description).
  DBFILEPROPERTIESModifyTemplateErrorOther,

  /// A property field key with that name already exists in the template.
  DBFILEPROPERTIESModifyTemplateErrorConflictingPropertyNames,

  /// There are too many properties in the changed template. The maximum
  /// number of properties per template is 32.
  DBFILEPROPERTIESModifyTemplateErrorTooManyProperties,

  /// There are too many templates for the team.
  DBFILEPROPERTIESModifyTemplateErrorTooManyTemplates,

  /// The template name, description or one or more of the property field keys
  /// is too large.
  DBFILEPROPERTIESModifyTemplateErrorTemplateAttributeTooLarge,

};

/// Represents the union's current tag state.
@property (nonatomic, readonly) DBFILEPROPERTIESModifyTemplateErrorTag tag;

/// Template does not exist for the given identifier. @note Ensure the
/// `isTemplateNotFound` method returns true before accessing, otherwise a
/// runtime exception will be raised.
@property (nonatomic, readonly, copy) NSString *templateNotFound;

#pragma mark - Constructors

///
/// Initializes union class with tag state of "template_not_found".
///
/// Description of the "template_not_found" tag state: Template does not exist
/// for the given identifier.
///
/// @param templateNotFound Template does not exist for the given identifier.
///
/// @return An initialized instance.
///
- (instancetype)initWithTemplateNotFound:(NSString *)templateNotFound;

///
/// Initializes union class with tag state of "restricted_content".
///
/// Description of the "restricted_content" tag state: You do not have
/// permission to modify this template.
///
/// @return An initialized instance.
///
- (instancetype)initWithRestrictedContent;

///
/// Initializes union class with tag state of "other".
///
/// @return An initialized instance.
///
- (instancetype)initWithOther;

///
/// Initializes union class with tag state of "conflicting_property_names".
///
/// Description of the "conflicting_property_names" tag state: A property field
/// key with that name already exists in the template.
///
/// @return An initialized instance.
///
- (instancetype)initWithConflictingPropertyNames;

///
/// Initializes union class with tag state of "too_many_properties".
///
/// Description of the "too_many_properties" tag state: There are too many
/// properties in the changed template. The maximum number of properties per
/// template is 32.
///
/// @return An initialized instance.
///
- (instancetype)initWithTooManyProperties;

///
/// Initializes union class with tag state of "too_many_templates".
///
/// Description of the "too_many_templates" tag state: There are too many
/// templates for the team.
///
/// @return An initialized instance.
///
- (instancetype)initWithTooManyTemplates;

///
/// Initializes union class with tag state of "template_attribute_too_large".
///
/// Description of the "template_attribute_too_large" tag state: The template
/// name, description or one or more of the property field keys is too large.
///
/// @return An initialized instance.
///
- (instancetype)initWithTemplateAttributeTooLarge;

- (instancetype)init NS_UNAVAILABLE;

#pragma mark - Tag state methods

///
/// Retrieves whether the union's current tag state has value
/// "template_not_found".
///
/// @note Call this method and ensure it returns true before accessing the
/// `templateNotFound` property, otherwise a runtime exception will be thrown.
///
/// @return Whether the union's current tag state has value
/// "template_not_found".
///
- (BOOL)isTemplateNotFound;

///
/// Retrieves whether the union's current tag state has value
/// "restricted_content".
///
/// @return Whether the union's current tag state has value
/// "restricted_content".
///
- (BOOL)isRestrictedContent;

///
/// Retrieves whether the union's current tag state has value "other".
///
/// @return Whether the union's current tag state has value "other".
///
- (BOOL)isOther;

///
/// Retrieves whether the union's current tag state has value
/// "conflicting_property_names".
///
/// @return Whether the union's current tag state has value
/// "conflicting_property_names".
///
- (BOOL)isConflictingPropertyNames;

///
/// Retrieves whether the union's current tag state has value
/// "too_many_properties".
///
/// @return Whether the union's current tag state has value
/// "too_many_properties".
///
- (BOOL)isTooManyProperties;

///
/// Retrieves whether the union's current tag state has value
/// "too_many_templates".
///
/// @return Whether the union's current tag state has value
/// "too_many_templates".
///
- (BOOL)isTooManyTemplates;

///
/// Retrieves whether the union's current tag state has value
/// "template_attribute_too_large".
///
/// @return Whether the union's current tag state has value
/// "template_attribute_too_large".
///
- (BOOL)isTemplateAttributeTooLarge;

///
/// Retrieves string value of union's current tag state.
///
/// @return A human-readable string representing the union's current tag state.
///
- (NSString *)tagName;

@end

#pragma mark - Serializer Object

///
/// The serialization class for the `DBFILEPROPERTIESModifyTemplateError` union.
///
@interface DBFILEPROPERTIESModifyTemplateErrorSerializer : NSObject

///
/// Serializes `DBFILEPROPERTIESModifyTemplateError` instances.
///
/// @param instance An instance of the `DBFILEPROPERTIESModifyTemplateError` API
/// object.
///
/// @return A json-compatible dictionary representation of the
/// `DBFILEPROPERTIESModifyTemplateError` API object.
///
+ (nullable NSDictionary *)serialize:(DBFILEPROPERTIESModifyTemplateError *)instance;

///
/// Deserializes `DBFILEPROPERTIESModifyTemplateError` instances.
///
/// @param dict A json-compatible dictionary representation of the
/// `DBFILEPROPERTIESModifyTemplateError` API object.
///
/// @return An instantiation of the `DBFILEPROPERTIESModifyTemplateError`
/// object.
///
+ (DBFILEPROPERTIESModifyTemplateError *)deserialize:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
