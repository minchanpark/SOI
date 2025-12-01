//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class FriendCheckRespDto {
  /// Returns a new [FriendCheckRespDto] instance.
  FriendCheckRespDto({
    this.phoneNum,
    this.isFriend,
    this.status,
  });

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? phoneNum;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? isFriend;

  FriendCheckRespDtoStatusEnum? status;

  @override
  bool operator ==(Object other) => identical(this, other) || other is FriendCheckRespDto &&
    other.phoneNum == phoneNum &&
    other.isFriend == isFriend &&
    other.status == status;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (phoneNum == null ? 0 : phoneNum!.hashCode) +
    (isFriend == null ? 0 : isFriend!.hashCode) +
    (status == null ? 0 : status!.hashCode);

  @override
  String toString() => 'FriendCheckRespDto[phoneNum=$phoneNum, isFriend=$isFriend, status=$status]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.phoneNum != null) {
      json[r'phoneNum'] = this.phoneNum;
    } else {
      json[r'phoneNum'] = null;
    }
    if (this.isFriend != null) {
      json[r'isFriend'] = this.isFriend;
    } else {
      json[r'isFriend'] = null;
    }
    if (this.status != null) {
      json[r'status'] = this.status;
    } else {
      json[r'status'] = null;
    }
    return json;
  }

  /// Returns a new [FriendCheckRespDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static FriendCheckRespDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "FriendCheckRespDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "FriendCheckRespDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return FriendCheckRespDto(
        phoneNum: mapValueOfType<String>(json, r'phoneNum'),
        isFriend: mapValueOfType<bool>(json, r'isFriend'),
        status: FriendCheckRespDtoStatusEnum.fromJson(json[r'status']),
      );
    }
    return null;
  }

  static List<FriendCheckRespDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <FriendCheckRespDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = FriendCheckRespDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, FriendCheckRespDto> mapFromJson(dynamic json) {
    final map = <String, FriendCheckRespDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = FriendCheckRespDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of FriendCheckRespDto-objects as value to a dart map
  static Map<String, List<FriendCheckRespDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<FriendCheckRespDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = FriendCheckRespDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}


class FriendCheckRespDtoStatusEnum {
  /// Instantiate a new enum with the provided [value].
  const FriendCheckRespDtoStatusEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const PENDING = FriendCheckRespDtoStatusEnum._(r'PENDING');
  static const ACCEPTED = FriendCheckRespDtoStatusEnum._(r'ACCEPTED');
  static const BLOCKED = FriendCheckRespDtoStatusEnum._(r'BLOCKED');
  static const CANCELLED = FriendCheckRespDtoStatusEnum._(r'CANCELLED');

  /// List of all possible values in this [enum][FriendCheckRespDtoStatusEnum].
  static const values = <FriendCheckRespDtoStatusEnum>[
    PENDING,
    ACCEPTED,
    BLOCKED,
    CANCELLED,
  ];

  static FriendCheckRespDtoStatusEnum? fromJson(dynamic value) => FriendCheckRespDtoStatusEnumTypeTransformer().decode(value);

  static List<FriendCheckRespDtoStatusEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <FriendCheckRespDtoStatusEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = FriendCheckRespDtoStatusEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [FriendCheckRespDtoStatusEnum] to String,
/// and [decode] dynamic data back to [FriendCheckRespDtoStatusEnum].
class FriendCheckRespDtoStatusEnumTypeTransformer {
  factory FriendCheckRespDtoStatusEnumTypeTransformer() => _instance ??= const FriendCheckRespDtoStatusEnumTypeTransformer._();

  const FriendCheckRespDtoStatusEnumTypeTransformer._();

  String encode(FriendCheckRespDtoStatusEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a FriendCheckRespDtoStatusEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  FriendCheckRespDtoStatusEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'PENDING': return FriendCheckRespDtoStatusEnum.PENDING;
        case r'ACCEPTED': return FriendCheckRespDtoStatusEnum.ACCEPTED;
        case r'BLOCKED': return FriendCheckRespDtoStatusEnum.BLOCKED;
        case r'CANCELLED': return FriendCheckRespDtoStatusEnum.CANCELLED;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [FriendCheckRespDtoStatusEnumTypeTransformer] instance.
  static FriendCheckRespDtoStatusEnumTypeTransformer? _instance;
}


