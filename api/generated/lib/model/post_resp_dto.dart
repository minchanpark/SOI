//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PostRespDto {
  /// Returns a new [PostRespDto] instance.
  PostRespDto({
    this.id,
    this.nickname,
    this.content,
    this.userProfileImageKey,
    this.postFileKey,
    this.audioFileKey,
    this.waveformData,
    this.duration,
    this.isActive,
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
  String? nickname;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? content;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? userProfileImageKey;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? postFileKey;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? audioFileKey;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? waveformData;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? duration;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? isActive;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  DateTime? createdAt;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PostRespDto &&
    other.id == id &&
    other.nickname == nickname &&
    other.content == content &&
    other.userProfileImageKey == userProfileImageKey &&
    other.postFileKey == postFileKey &&
    other.audioFileKey == audioFileKey &&
    other.waveformData == waveformData &&
    other.duration == duration &&
    other.isActive == isActive &&
    other.createdAt == createdAt;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id == null ? 0 : id!.hashCode) +
    (nickname == null ? 0 : nickname!.hashCode) +
    (content == null ? 0 : content!.hashCode) +
    (userProfileImageKey == null ? 0 : userProfileImageKey!.hashCode) +
    (postFileKey == null ? 0 : postFileKey!.hashCode) +
    (audioFileKey == null ? 0 : audioFileKey!.hashCode) +
    (waveformData == null ? 0 : waveformData!.hashCode) +
    (duration == null ? 0 : duration!.hashCode) +
    (isActive == null ? 0 : isActive!.hashCode) +
    (createdAt == null ? 0 : createdAt!.hashCode);

  @override
  String toString() => 'PostRespDto[id=$id, nickname=$nickname, content=$content, userProfileImageKey=$userProfileImageKey, postFileKey=$postFileKey, audioFileKey=$audioFileKey, waveformData=$waveformData, duration=$duration, isActive=$isActive, createdAt=$createdAt]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.id != null) {
      json[r'id'] = this.id;
    } else {
      json[r'id'] = null;
    }
    if (this.nickname != null) {
      json[r'nickname'] = this.nickname;
    } else {
      json[r'nickname'] = null;
    }
    if (this.content != null) {
      json[r'content'] = this.content;
    } else {
      json[r'content'] = null;
    }
    if (this.userProfileImageKey != null) {
      json[r'userProfileImageKey'] = this.userProfileImageKey;
    } else {
      json[r'userProfileImageKey'] = null;
    }
    if (this.postFileKey != null) {
      json[r'postFileKey'] = this.postFileKey;
    } else {
      json[r'postFileKey'] = null;
    }
    if (this.audioFileKey != null) {
      json[r'audioFileKey'] = this.audioFileKey;
    } else {
      json[r'audioFileKey'] = null;
    }
    if (this.waveformData != null) {
      json[r'waveformData'] = this.waveformData;
    } else {
      json[r'waveformData'] = null;
    }
    if (this.duration != null) {
      json[r'duration'] = this.duration;
    } else {
      json[r'duration'] = null;
    }
    if (this.isActive != null) {
      json[r'is_active'] = this.isActive;
    } else {
      json[r'is_active'] = null;
    }
    if (this.createdAt != null) {
      json[r'createdAt'] = this.createdAt!.toUtc().toIso8601String();
    } else {
      json[r'createdAt'] = null;
    }
    return json;
  }

  /// Returns a new [PostRespDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PostRespDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PostRespDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PostRespDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PostRespDto(
        id: mapValueOfType<int>(json, r'id'),
        nickname: mapValueOfType<String>(json, r'nickname'),
        content: mapValueOfType<String>(json, r'content'),
        userProfileImageKey: mapValueOfType<String>(json, r'userProfileImageKey'),
        postFileKey: mapValueOfType<String>(json, r'postFileKey'),
        audioFileKey: mapValueOfType<String>(json, r'audioFileKey'),
        waveformData: mapValueOfType<String>(json, r'waveformData'),
        duration: mapValueOfType<int>(json, r'duration'),
        isActive: mapValueOfType<bool>(json, r'is_active'),
        createdAt: mapDateTime(json, r'createdAt', r''),
      );
    }
    return null;
  }

  static List<PostRespDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PostRespDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PostRespDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PostRespDto> mapFromJson(dynamic json) {
    final map = <String, PostRespDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PostRespDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PostRespDto-objects as value to a dart map
  static Map<String, List<PostRespDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PostRespDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PostRespDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}

