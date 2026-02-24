//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class FriendCreateReqDto {
  /// Returns a new [FriendCreateReqDto] instance.
  FriendCreateReqDto({
    this.requesterId,
    this.receiverPhoneNum,
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
  String? receiverPhoneNum;

  @override
  bool operator ==(Object other) => identical(this, other) || other is FriendCreateReqDto &&
    other.requesterId == requesterId &&
    other.receiverPhoneNum == receiverPhoneNum;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (requesterId == null ? 0 : requesterId!.hashCode) +
    (receiverPhoneNum == null ? 0 : receiverPhoneNum!.hashCode);

  @override
  String toString() => 'FriendCreateReqDto[requesterId=$requesterId, receiverPhoneNum=$receiverPhoneNum]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.requesterId != null) {
      json[r'requesterId'] = this.requesterId;
    } else {
      json[r'requesterId'] = null;
    }
    if (this.receiverPhoneNum != null) {
      json[r'receiverPhoneNum'] = this.receiverPhoneNum;
    } else {
      json[r'receiverPhoneNum'] = null;
    }
    return json;
  }

  /// Returns a new [FriendCreateReqDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static FriendCreateReqDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "FriendCreateReqDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "FriendCreateReqDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return FriendCreateReqDto(
        requesterId: mapValueOfType<int>(json, r'requesterId'),
        receiverPhoneNum: mapValueOfType<String>(json, r'receiverPhoneNum'),
      );
    }
    return null;
  }

  static List<FriendCreateReqDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <FriendCreateReqDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = FriendCreateReqDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, FriendCreateReqDto> mapFromJson(dynamic json) {
    final map = <String, FriendCreateReqDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = FriendCreateReqDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of FriendCreateReqDto-objects as value to a dart map
  static Map<String, List<FriendCreateReqDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<FriendCreateReqDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = FriendCreateReqDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}

