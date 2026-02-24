//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PostUpdateReqDto {
  /// Returns a new [PostUpdateReqDto] instance.
  PostUpdateReqDto({
    this.postId,
    this.categoryId,
    this.nickname,
    this.content,
    this.postFileKey,
    this.audioFileKey,
    this.waveformData,
    this.duration,
    this.isFromGallery,
    this.savedAspectRatio,
    this.postType,
  });

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? postId;

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
  bool? isFromGallery;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  double? savedAspectRatio;

  PostUpdateReqDtoPostTypeEnum? postType;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PostUpdateReqDto &&
    other.postId == postId &&
    other.categoryId == categoryId &&
    other.nickname == nickname &&
    other.content == content &&
    other.postFileKey == postFileKey &&
    other.audioFileKey == audioFileKey &&
    other.waveformData == waveformData &&
    other.duration == duration &&
    other.isFromGallery == isFromGallery &&
    other.savedAspectRatio == savedAspectRatio &&
    other.postType == postType;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (postId == null ? 0 : postId!.hashCode) +
    (categoryId == null ? 0 : categoryId!.hashCode) +
    (nickname == null ? 0 : nickname!.hashCode) +
    (content == null ? 0 : content!.hashCode) +
    (postFileKey == null ? 0 : postFileKey!.hashCode) +
    (audioFileKey == null ? 0 : audioFileKey!.hashCode) +
    (waveformData == null ? 0 : waveformData!.hashCode) +
    (duration == null ? 0 : duration!.hashCode) +
    (isFromGallery == null ? 0 : isFromGallery!.hashCode) +
    (savedAspectRatio == null ? 0 : savedAspectRatio!.hashCode) +
    (postType == null ? 0 : postType!.hashCode);

  @override
  String toString() => 'PostUpdateReqDto[postId=$postId, categoryId=$categoryId, nickname=$nickname, content=$content, postFileKey=$postFileKey, audioFileKey=$audioFileKey, waveformData=$waveformData, duration=$duration, isFromGallery=$isFromGallery, savedAspectRatio=$savedAspectRatio, postType=$postType]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.postId != null) {
      json[r'postId'] = this.postId;
    } else {
      json[r'postId'] = null;
    }
    if (this.categoryId != null) {
      json[r'categoryId'] = this.categoryId;
    } else {
      json[r'categoryId'] = null;
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
    if (this.isFromGallery != null) {
      json[r'isFromGallery'] = this.isFromGallery;
    } else {
      json[r'isFromGallery'] = null;
    }
    if (this.savedAspectRatio != null) {
      json[r'savedAspectRatio'] = this.savedAspectRatio;
    } else {
      json[r'savedAspectRatio'] = null;
    }
    if (this.postType != null) {
      json[r'postType'] = this.postType;
    } else {
      json[r'postType'] = null;
    }
    return json;
  }

  /// Returns a new [PostUpdateReqDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PostUpdateReqDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PostUpdateReqDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PostUpdateReqDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PostUpdateReqDto(
        postId: mapValueOfType<int>(json, r'postId'),
        categoryId: mapValueOfType<int>(json, r'categoryId'),
        nickname: mapValueOfType<String>(json, r'nickname'),
        content: mapValueOfType<String>(json, r'content'),
        postFileKey: mapValueOfType<String>(json, r'postFileKey'),
        audioFileKey: mapValueOfType<String>(json, r'audioFileKey'),
        waveformData: mapValueOfType<String>(json, r'waveformData'),
        duration: mapValueOfType<int>(json, r'duration'),
        isFromGallery: mapValueOfType<bool>(json, r'isFromGallery'),
        savedAspectRatio: mapValueOfType<double>(json, r'savedAspectRatio'),
        postType: PostUpdateReqDtoPostTypeEnum.fromJson(json[r'postType']),
      );
    }
    return null;
  }

  static List<PostUpdateReqDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PostUpdateReqDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PostUpdateReqDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PostUpdateReqDto> mapFromJson(dynamic json) {
    final map = <String, PostUpdateReqDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PostUpdateReqDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PostUpdateReqDto-objects as value to a dart map
  static Map<String, List<PostUpdateReqDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PostUpdateReqDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PostUpdateReqDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}


class PostUpdateReqDtoPostTypeEnum {
  /// Instantiate a new enum with the provided [value].
  const PostUpdateReqDtoPostTypeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const TEXT_ONLY = PostUpdateReqDtoPostTypeEnum._(r'TEXT_ONLY');
  static const MULTIMEDIA = PostUpdateReqDtoPostTypeEnum._(r'MULTIMEDIA');

  /// List of all possible values in this [enum][PostUpdateReqDtoPostTypeEnum].
  static const values = <PostUpdateReqDtoPostTypeEnum>[
    TEXT_ONLY,
    MULTIMEDIA,
  ];

  static PostUpdateReqDtoPostTypeEnum? fromJson(dynamic value) => PostUpdateReqDtoPostTypeEnumTypeTransformer().decode(value);

  static List<PostUpdateReqDtoPostTypeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PostUpdateReqDtoPostTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PostUpdateReqDtoPostTypeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PostUpdateReqDtoPostTypeEnum] to String,
/// and [decode] dynamic data back to [PostUpdateReqDtoPostTypeEnum].
class PostUpdateReqDtoPostTypeEnumTypeTransformer {
  factory PostUpdateReqDtoPostTypeEnumTypeTransformer() => _instance ??= const PostUpdateReqDtoPostTypeEnumTypeTransformer._();

  const PostUpdateReqDtoPostTypeEnumTypeTransformer._();

  String encode(PostUpdateReqDtoPostTypeEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PostUpdateReqDtoPostTypeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PostUpdateReqDtoPostTypeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'TEXT_ONLY': return PostUpdateReqDtoPostTypeEnum.TEXT_ONLY;
        case r'MULTIMEDIA': return PostUpdateReqDtoPostTypeEnum.MULTIMEDIA;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PostUpdateReqDtoPostTypeEnumTypeTransformer] instance.
  static PostUpdateReqDtoPostTypeEnumTypeTransformer? _instance;
}


