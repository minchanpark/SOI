//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class FriendCreateByNickNameReqDto {
  /// Returns a new [FriendCreateByNickNameReqDto] instance.
  FriendCreateByNickNameReqDto({
    this.requesterId,
    this.receiverNickName,
  });

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
  String? receiverNickName;

  @override
  bool operator ==(Object other) => identical(this, other) || other is FriendCreateByNickNameReqDto &&
    other.requesterId == requesterId &&
    other.receiverNickName == receiverNickName;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (requesterId == null ? 0 : requesterId!.hashCode) +
    (receiverNickName == null ? 0 : receiverNickName!.hashCode);

  @override
  String toString() => 'FriendCreateByNickNameReqDto[requesterId=$requesterId, receiverNickName=$receiverNickName]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.requesterId != null) {
      json[r'requesterId'] = this.requesterId;
    } else {
      json[r'requesterId'] = null;
    }
    if (this.receiverNickName != null) {
      json[r'receiverNickName'] = this.receiverNickName;
    } else {
      json[r'receiverNickName'] = null;
    }
    return json;
  }

  /// Returns a new [FriendCreateByNickNameReqDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static FriendCreateByNickNameReqDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "FriendCreateByNickNameReqDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "FriendCreateByNickNameReqDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return FriendCreateByNickNameReqDto(
        requesterId: mapValueOfType<int>(json, r'requesterId'),
        receiverNickName: mapValueOfType<String>(json, r'receiverNickName'),
      );
    }
    return null;
  }

  static List<FriendCreateByNickNameReqDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <FriendCreateByNickNameReqDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = FriendCreateByNickNameReqDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, FriendCreateByNickNameReqDto> mapFromJson(dynamic json) {
    final map = <String, FriendCreateByNickNameReqDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = FriendCreateByNickNameReqDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of FriendCreateByNickNameReqDto-objects as value to a dart map
  static Map<String, List<FriendCreateByNickNameReqDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<FriendCreateByNickNameReqDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = FriendCreateByNickNameReqDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}

