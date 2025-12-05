//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PostCreateReqDto {
  /// Returns a new [PostCreateReqDto] instance.
  PostCreateReqDto({
    this.id,
    this.nickname,
    this.content,
    this.postFileKey,
    this.audioFileKey,
    this.categoryId = const [],
    this.waveformData,
    this.duration,
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
  String? postFileKey;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? audioFileKey;

  List<int> categoryId;

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

  @override
  bool operator ==(Object other) => identical(this, other) || other is PostCreateReqDto &&
    other.id == id &&
    other.nickname == nickname &&
    other.content == content &&
    other.postFileKey == postFileKey &&
    other.audioFileKey == audioFileKey &&
    _deepEquality.equals(other.categoryId, categoryId) &&
    other.waveformData == waveformData &&
    other.duration == duration;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id == null ? 0 : id!.hashCode) +
    (nickname == null ? 0 : nickname!.hashCode) +
    (content == null ? 0 : content!.hashCode) +
    (postFileKey == null ? 0 : postFileKey!.hashCode) +
    (audioFileKey == null ? 0 : audioFileKey!.hashCode) +
    (categoryId.hashCode) +
    (waveformData == null ? 0 : waveformData!.hashCode) +
    (duration == null ? 0 : duration!.hashCode);

  @override
  String toString() => 'PostCreateReqDto[id=$id, nickname=$nickname, content=$content, postFileKey=$postFileKey, audioFileKey=$audioFileKey, categoryId=$categoryId, waveformData=$waveformData, duration=$duration]';

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
      json[r'categoryId'] = this.categoryId;
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
    return json;
  }

  /// Returns a new [PostCreateReqDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PostCreateReqDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PostCreateReqDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PostCreateReqDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PostCreateReqDto(
        id: mapValueOfType<int>(json, r'id'),
        nickname: mapValueOfType<String>(json, r'nickname'),
        content: mapValueOfType<String>(json, r'content'),
        postFileKey: mapValueOfType<String>(json, r'postFileKey'),
        audioFileKey: mapValueOfType<String>(json, r'audioFileKey'),
        categoryId: json[r'categoryId'] is Iterable
            ? (json[r'categoryId'] as Iterable).cast<int>().toList(growable: false)
            : const [],
        waveformData: mapValueOfType<String>(json, r'waveformData'),
        duration: mapValueOfType<int>(json, r'duration'),
      );
    }
    return null;
  }

  static List<PostCreateReqDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PostCreateReqDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PostCreateReqDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PostCreateReqDto> mapFromJson(dynamic json) {
    final map = <String, PostCreateReqDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PostCreateReqDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PostCreateReqDto-objects as value to a dart map
  static Map<String, List<PostCreateReqDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PostCreateReqDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PostCreateReqDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}

