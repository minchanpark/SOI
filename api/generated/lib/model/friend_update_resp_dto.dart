//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class FriendUpdateRespDto {
  /// Returns a new [FriendUpdateRespDto] instance.
  FriendUpdateRespDto({
    this.id,
    this.status,
  });

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? id;

  FriendUpdateRespDtoStatusEnum? status;

  @override
  bool operator ==(Object other) => identical(this, other) || other is FriendUpdateRespDto &&
    other.id == id &&
    other.status == status;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id == null ? 0 : id!.hashCode) +
    (status == null ? 0 : status!.hashCode);

  @override
  String toString() => 'FriendUpdateRespDto[id=$id, status=$status]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.id != null) {
      json[r'id'] = this.id;
    } else {
      json[r'id'] = null;
    }
    if (this.status != null) {
      json[r'status'] = this.status;
    } else {
      json[r'status'] = null;
    }
    return json;
  }

  /// Returns a new [FriendUpdateRespDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static FriendUpdateRespDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "FriendUpdateRespDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "FriendUpdateRespDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return FriendUpdateRespDto(
        id: mapValueOfType<int>(json, r'id'),
        status: FriendUpdateRespDtoStatusEnum.fromJson(json[r'status']),
      );
    }
    return null;
  }

  static List<FriendUpdateRespDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <FriendUpdateRespDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = FriendUpdateRespDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, FriendUpdateRespDto> mapFromJson(dynamic json) {
    final map = <String, FriendUpdateRespDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = FriendUpdateRespDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of FriendUpdateRespDto-objects as value to a dart map
  static Map<String, List<FriendUpdateRespDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<FriendUpdateRespDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = FriendUpdateRespDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}


class FriendUpdateRespDtoStatusEnum {
  /// Instantiate a new enum with the provided [value].
  const FriendUpdateRespDtoStatusEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const PENDING = FriendUpdateRespDtoStatusEnum._(r'PENDING');
  static const ACCEPTED = FriendUpdateRespDtoStatusEnum._(r'ACCEPTED');
  static const BLOCKED = FriendUpdateRespDtoStatusEnum._(r'BLOCKED');
  static const CANCELLED = FriendUpdateRespDtoStatusEnum._(r'CANCELLED');

  /// List of all possible values in this [enum][FriendUpdateRespDtoStatusEnum].
  static const values = <FriendUpdateRespDtoStatusEnum>[
    PENDING,
    ACCEPTED,
    BLOCKED,
    CANCELLED,
  ];

  static FriendUpdateRespDtoStatusEnum? fromJson(dynamic value) => FriendUpdateRespDtoStatusEnumTypeTransformer().decode(value);

  static List<FriendUpdateRespDtoStatusEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <FriendUpdateRespDtoStatusEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = FriendUpdateRespDtoStatusEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [FriendUpdateRespDtoStatusEnum] to String,
/// and [decode] dynamic data back to [FriendUpdateRespDtoStatusEnum].
class FriendUpdateRespDtoStatusEnumTypeTransformer {
  factory FriendUpdateRespDtoStatusEnumTypeTransformer() => _instance ??= const FriendUpdateRespDtoStatusEnumTypeTransformer._();

  const FriendUpdateRespDtoStatusEnumTypeTransformer._();

  String encode(FriendUpdateRespDtoStatusEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a FriendUpdateRespDtoStatusEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  FriendUpdateRespDtoStatusEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'PENDING': return FriendUpdateRespDtoStatusEnum.PENDING;
        case r'ACCEPTED': return FriendUpdateRespDtoStatusEnum.ACCEPTED;
        case r'BLOCKED': return FriendUpdateRespDtoStatusEnum.BLOCKED;
        case r'CANCELLED': return FriendUpdateRespDtoStatusEnum.CANCELLED;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [FriendUpdateRespDtoStatusEnumTypeTransformer] instance.
  static FriendUpdateRespDtoStatusEnumTypeTransformer? _instance;
}


