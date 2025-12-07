//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class NotificationRespDto {
  /// Returns a new [NotificationRespDto] instance.
  NotificationRespDto({
    this.text,
    this.name,
    this.nickname,
    this.userProfileKey,
    this.imageUrl,
    this.relatedId,
  });

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? text;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? name;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? nickname;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? userProfileKey;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? imageUrl;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? relatedId;

  @override
  bool operator ==(Object other) => identical(this, other) || other is NotificationRespDto &&
    other.text == text &&
    other.name == name &&
    other.nickname == nickname &&
    other.userProfileKey == userProfileKey &&
    other.imageUrl == imageUrl &&
    other.relatedId == relatedId;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (text == null ? 0 : text!.hashCode) +
    (name == null ? 0 : name!.hashCode) +
    (nickname == null ? 0 : nickname!.hashCode) +
    (userProfileKey == null ? 0 : userProfileKey!.hashCode) +
    (imageUrl == null ? 0 : imageUrl!.hashCode) +
    (relatedId == null ? 0 : relatedId!.hashCode);

  @override
  String toString() => 'NotificationRespDto[text=$text, name=$name, nickname=$nickname, userProfileKey=$userProfileKey, imageUrl=$imageUrl, relatedId=$relatedId]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.text != null) {
      json[r'text'] = this.text;
    } else {
      json[r'text'] = null;
    }
    if (this.name != null) {
      json[r'name'] = this.name;
    } else {
      json[r'name'] = null;
    }
    if (this.nickname != null) {
      json[r'nickname'] = this.nickname;
    } else {
      json[r'nickname'] = null;
    }
    if (this.userProfileKey != null) {
      json[r'userProfileKey'] = this.userProfileKey;
    } else {
      json[r'userProfileKey'] = null;
    }
    if (this.imageUrl != null) {
      json[r'imageUrl'] = this.imageUrl;
    } else {
      json[r'imageUrl'] = null;
    }
    if (this.relatedId != null) {
      json[r'relatedId'] = this.relatedId;
    } else {
      json[r'relatedId'] = null;
    }
    return json;
  }

  /// Returns a new [NotificationRespDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static NotificationRespDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "NotificationRespDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "NotificationRespDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return NotificationRespDto(
        text: mapValueOfType<String>(json, r'text'),
        name: mapValueOfType<String>(json, r'name'),
        nickname: mapValueOfType<String>(json, r'nickname'),
        userProfileKey: mapValueOfType<String>(json, r'userProfileKey'),
        imageUrl: mapValueOfType<String>(json, r'imageUrl'),
        relatedId: mapValueOfType<int>(json, r'relatedId'),
      );
    }
    return null;
  }

  static List<NotificationRespDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <NotificationRespDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = NotificationRespDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, NotificationRespDto> mapFromJson(dynamic json) {
    final map = <String, NotificationRespDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = NotificationRespDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of NotificationRespDto-objects as value to a dart map
  static Map<String, List<NotificationRespDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<NotificationRespDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = NotificationRespDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}

