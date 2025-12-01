//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class CategoryInviteResponseReqDto {
  /// Returns a new [CategoryInviteResponseReqDto] instance.
  CategoryInviteResponseReqDto({
    this.categoryId,
    this.responserId,
    this.status,
  });

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? categoryId;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? responserId;

  CategoryInviteResponseReqDtoStatusEnum? status;

  @override
  bool operator ==(Object other) => identical(this, other) || other is CategoryInviteResponseReqDto &&
    other.categoryId == categoryId &&
    other.responserId == responserId &&
    other.status == status;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (categoryId == null ? 0 : categoryId!.hashCode) +
    (responserId == null ? 0 : responserId!.hashCode) +
    (status == null ? 0 : status!.hashCode);

  @override
  String toString() => 'CategoryInviteResponseReqDto[categoryId=$categoryId, responserId=$responserId, status=$status]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.categoryId != null) {
      json[r'categoryId'] = this.categoryId;
    } else {
      json[r'categoryId'] = null;
    }
    if (this.responserId != null) {
      json[r'responserId'] = this.responserId;
    } else {
      json[r'responserId'] = null;
    }
    if (this.status != null) {
      json[r'status'] = this.status;
    } else {
      json[r'status'] = null;
    }
    return json;
  }

  /// Returns a new [CategoryInviteResponseReqDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CategoryInviteResponseReqDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "CategoryInviteResponseReqDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "CategoryInviteResponseReqDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return CategoryInviteResponseReqDto(
        categoryId: mapValueOfType<int>(json, r'categoryId'),
        responserId: mapValueOfType<int>(json, r'responserId'),
        status: CategoryInviteResponseReqDtoStatusEnum.fromJson(json[r'status']),
      );
    }
    return null;
  }

  static List<CategoryInviteResponseReqDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CategoryInviteResponseReqDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CategoryInviteResponseReqDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CategoryInviteResponseReqDto> mapFromJson(dynamic json) {
    final map = <String, CategoryInviteResponseReqDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CategoryInviteResponseReqDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CategoryInviteResponseReqDto-objects as value to a dart map
  static Map<String, List<CategoryInviteResponseReqDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<CategoryInviteResponseReqDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CategoryInviteResponseReqDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}


class CategoryInviteResponseReqDtoStatusEnum {
  /// Instantiate a new enum with the provided [value].
  const CategoryInviteResponseReqDtoStatusEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const PENDING = CategoryInviteResponseReqDtoStatusEnum._(r'PENDING');
  static const ACCEPTED = CategoryInviteResponseReqDtoStatusEnum._(r'ACCEPTED');
  static const DECLINED = CategoryInviteResponseReqDtoStatusEnum._(r'DECLINED');
  static const EXPIRED = CategoryInviteResponseReqDtoStatusEnum._(r'EXPIRED');

  /// List of all possible values in this [enum][CategoryInviteResponseReqDtoStatusEnum].
  static const values = <CategoryInviteResponseReqDtoStatusEnum>[
    PENDING,
    ACCEPTED,
    DECLINED,
    EXPIRED,
  ];

  static CategoryInviteResponseReqDtoStatusEnum? fromJson(dynamic value) => CategoryInviteResponseReqDtoStatusEnumTypeTransformer().decode(value);

  static List<CategoryInviteResponseReqDtoStatusEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CategoryInviteResponseReqDtoStatusEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CategoryInviteResponseReqDtoStatusEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [CategoryInviteResponseReqDtoStatusEnum] to String,
/// and [decode] dynamic data back to [CategoryInviteResponseReqDtoStatusEnum].
class CategoryInviteResponseReqDtoStatusEnumTypeTransformer {
  factory CategoryInviteResponseReqDtoStatusEnumTypeTransformer() => _instance ??= const CategoryInviteResponseReqDtoStatusEnumTypeTransformer._();

  const CategoryInviteResponseReqDtoStatusEnumTypeTransformer._();

  String encode(CategoryInviteResponseReqDtoStatusEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a CategoryInviteResponseReqDtoStatusEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  CategoryInviteResponseReqDtoStatusEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'PENDING': return CategoryInviteResponseReqDtoStatusEnum.PENDING;
        case r'ACCEPTED': return CategoryInviteResponseReqDtoStatusEnum.ACCEPTED;
        case r'DECLINED': return CategoryInviteResponseReqDtoStatusEnum.DECLINED;
        case r'EXPIRED': return CategoryInviteResponseReqDtoStatusEnum.EXPIRED;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [CategoryInviteResponseReqDtoStatusEnumTypeTransformer] instance.
  static CategoryInviteResponseReqDtoStatusEnumTypeTransformer? _instance;
}


