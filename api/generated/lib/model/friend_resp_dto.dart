//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class FriendRespDto {
  /// Returns a new [FriendRespDto] instance.
  FriendRespDto({
    this.id,
    this.requesterId,
    this.receiverId,
    this.notificationId,
    this.status,
    this.createdAt,
  });

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? id;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? requesterId;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? receiverId;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? notificationId;

  FriendRespDtoStatusEnum? status;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  DateTime? createdAt;

  @override
  bool operator ==(Object other) => identical(this, other) || other is FriendRespDto &&
    other.id == id &&
    other.requesterId == requesterId &&
    other.receiverId == receiverId &&
    other.notificationId == notificationId &&
    other.status == status &&
    other.createdAt == createdAt;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id == null ? 0 : id!.hashCode) +
    (requesterId == null ? 0 : requesterId!.hashCode) +
    (receiverId == null ? 0 : receiverId!.hashCode) +
    (notificationId == null ? 0 : notificationId!.hashCode) +
    (status == null ? 0 : status!.hashCode) +
    (createdAt == null ? 0 : createdAt!.hashCode);

  @override
  String toString() => 'FriendRespDto[id=$id, requesterId=$requesterId, receiverId=$receiverId, notificationId=$notificationId, status=$status, createdAt=$createdAt]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.id != null) {
      json[r'id'] = this.id;
    } else {
      json[r'id'] = null;
    }
    if (this.requesterId != null) {
      json[r'requesterId'] = this.requesterId;
    } else {
      json[r'requesterId'] = null;
    }
    if (this.receiverId != null) {
      json[r'receiverId'] = this.receiverId;
    } else {
      json[r'receiverId'] = null;
    }
    if (this.notificationId != null) {
      json[r'notificationId'] = this.notificationId;
    } else {
      json[r'notificationId'] = null;
    }
    if (this.status != null) {
      json[r'status'] = this.status;
    } else {
      json[r'status'] = null;
    }
    if (this.createdAt != null) {
      json[r'createdAt'] = this.createdAt!.toUtc().toIso8601String();
    } else {
      json[r'createdAt'] = null;
    }
    return json;
  }

  /// Returns a new [FriendRespDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static FriendRespDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "FriendRespDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "FriendRespDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return FriendRespDto(
        id: mapValueOfType<int>(json, r'id'),
        requesterId: mapValueOfType<int>(json, r'requesterId'),
        receiverId: mapValueOfType<int>(json, r'receiverId'),
        notificationId: mapValueOfType<int>(json, r'notificationId'),
        status: FriendRespDtoStatusEnum.fromJson(json[r'status']),
        createdAt: mapDateTime(json, r'createdAt', r''),
      );
    }
    return null;
  }

  static List<FriendRespDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <FriendRespDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = FriendRespDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, FriendRespDto> mapFromJson(dynamic json) {
    final map = <String, FriendRespDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = FriendRespDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of FriendRespDto-objects as value to a dart map
  static Map<String, List<FriendRespDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<FriendRespDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = FriendRespDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}


class FriendRespDtoStatusEnum {
  /// Instantiate a new enum with the provided [value].
  const FriendRespDtoStatusEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const PENDING = FriendRespDtoStatusEnum._(r'PENDING');
  static const ACCEPTED = FriendRespDtoStatusEnum._(r'ACCEPTED');
  static const BLOCKED = FriendRespDtoStatusEnum._(r'BLOCKED');
  static const CANCELLED = FriendRespDtoStatusEnum._(r'CANCELLED');

  /// List of all possible values in this [enum][FriendRespDtoStatusEnum].
  static const values = <FriendRespDtoStatusEnum>[
    PENDING,
    ACCEPTED,
    BLOCKED,
    CANCELLED,
  ];

  static FriendRespDtoStatusEnum? fromJson(dynamic value) => FriendRespDtoStatusEnumTypeTransformer().decode(value);

  static List<FriendRespDtoStatusEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <FriendRespDtoStatusEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = FriendRespDtoStatusEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [FriendRespDtoStatusEnum] to String,
/// and [decode] dynamic data back to [FriendRespDtoStatusEnum].
class FriendRespDtoStatusEnumTypeTransformer {
  factory FriendRespDtoStatusEnumTypeTransformer() => _instance ??= const FriendRespDtoStatusEnumTypeTransformer._();

  const FriendRespDtoStatusEnumTypeTransformer._();

  String encode(FriendRespDtoStatusEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a FriendRespDtoStatusEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  FriendRespDtoStatusEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'PENDING': return FriendRespDtoStatusEnum.PENDING;
        case r'ACCEPTED': return FriendRespDtoStatusEnum.ACCEPTED;
        case r'BLOCKED': return FriendRespDtoStatusEnum.BLOCKED;
        case r'CANCELLED': return FriendRespDtoStatusEnum.CANCELLED;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [FriendRespDtoStatusEnumTypeTransformer] instance.
  static FriendRespDtoStatusEnumTypeTransformer? _instance;
}


