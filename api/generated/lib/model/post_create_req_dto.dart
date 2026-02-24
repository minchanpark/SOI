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
    this.userId,
    this.nickname,
    this.content,
    this.postFileKey = const [],
    this.audioFileKey = const [],
    this.categoryId = const [],
    this.waveformData,
    this.duration,
    this.savedAspectRatio,
    this.isFromGallery,
    this.postType,
  });

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? userId;

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

  List<String> postFileKey;

  List<String> audioFileKey;

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

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  double? savedAspectRatio;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? isFromGallery;

  PostCreateReqDtoPostTypeEnum? postType;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PostCreateReqDto &&
    other.userId == userId &&
    other.nickname == nickname &&
    other.content == content &&
    _deepEquality.equals(other.postFileKey, postFileKey) &&
    _deepEquality.equals(other.audioFileKey, audioFileKey) &&
    _deepEquality.equals(other.categoryId, categoryId) &&
    other.waveformData == waveformData &&
    other.duration == duration &&
    other.savedAspectRatio == savedAspectRatio &&
    other.isFromGallery == isFromGallery &&
    other.postType == postType;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (userId == null ? 0 : userId!.hashCode) +
    (nickname == null ? 0 : nickname!.hashCode) +
    (content == null ? 0 : content!.hashCode) +
    (postFileKey.hashCode) +
    (audioFileKey.hashCode) +
    (categoryId.hashCode) +
    (waveformData == null ? 0 : waveformData!.hashCode) +
    (duration == null ? 0 : duration!.hashCode) +
    (savedAspectRatio == null ? 0 : savedAspectRatio!.hashCode) +
    (isFromGallery == null ? 0 : isFromGallery!.hashCode) +
    (postType == null ? 0 : postType!.hashCode);

  @override
  String toString() => 'PostCreateReqDto[userId=$userId, nickname=$nickname, content=$content, postFileKey=$postFileKey, audioFileKey=$audioFileKey, categoryId=$categoryId, waveformData=$waveformData, duration=$duration, savedAspectRatio=$savedAspectRatio, isFromGallery=$isFromGallery, postType=$postType]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.userId != null) {
      json[r'userId'] = this.userId;
    } else {
      json[r'userId'] = null;
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
      json[r'postFileKey'] = this.postFileKey;
      json[r'audioFileKey'] = this.audioFileKey;
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
    if (this.savedAspectRatio != null) {
      json[r'savedAspectRatio'] = this.savedAspectRatio;
    } else {
      json[r'savedAspectRatio'] = null;
    }
    if (this.isFromGallery != null) {
      json[r'isFromGallery'] = this.isFromGallery;
    } else {
      json[r'isFromGallery'] = null;
    }
    if (this.postType != null) {
      json[r'postType'] = this.postType;
    } else {
      json[r'postType'] = null;
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
        userId: mapValueOfType<int>(json, r'userId'),
        nickname: mapValueOfType<String>(json, r'nickname'),
        content: mapValueOfType<String>(json, r'content'),
        postFileKey: json[r'postFileKey'] is Iterable
            ? (json[r'postFileKey'] as Iterable).cast<String>().toList(growable: false)
            : const [],
        audioFileKey: json[r'audioFileKey'] is Iterable
            ? (json[r'audioFileKey'] as Iterable).cast<String>().toList(growable: false)
            : const [],
        categoryId: json[r'categoryId'] is Iterable
            ? (json[r'categoryId'] as Iterable).cast<int>().toList(growable: false)
            : const [],
        waveformData: mapValueOfType<String>(json, r'waveformData'),
        duration: mapValueOfType<int>(json, r'duration'),
        savedAspectRatio: mapValueOfType<double>(json, r'savedAspectRatio'),
        isFromGallery: mapValueOfType<bool>(json, r'isFromGallery'),
        postType: PostCreateReqDtoPostTypeEnum.fromJson(json[r'postType']),
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


class PostCreateReqDtoPostTypeEnum {
  /// Instantiate a new enum with the provided [value].
  const PostCreateReqDtoPostTypeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const TEXT_ONLY = PostCreateReqDtoPostTypeEnum._(r'TEXT_ONLY');
  static const MULTIMEDIA = PostCreateReqDtoPostTypeEnum._(r'MULTIMEDIA');

  /// List of all possible values in this [enum][PostCreateReqDtoPostTypeEnum].
  static const values = <PostCreateReqDtoPostTypeEnum>[
    TEXT_ONLY,
    MULTIMEDIA,
  ];

  static PostCreateReqDtoPostTypeEnum? fromJson(dynamic value) => PostCreateReqDtoPostTypeEnumTypeTransformer().decode(value);

  static List<PostCreateReqDtoPostTypeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PostCreateReqDtoPostTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PostCreateReqDtoPostTypeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PostCreateReqDtoPostTypeEnum] to String,
/// and [decode] dynamic data back to [PostCreateReqDtoPostTypeEnum].
class PostCreateReqDtoPostTypeEnumTypeTransformer {
  factory PostCreateReqDtoPostTypeEnumTypeTransformer() => _instance ??= const PostCreateReqDtoPostTypeEnumTypeTransformer._();

  const PostCreateReqDtoPostTypeEnumTypeTransformer._();

  String encode(PostCreateReqDtoPostTypeEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PostCreateReqDtoPostTypeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PostCreateReqDtoPostTypeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'TEXT_ONLY': return PostCreateReqDtoPostTypeEnum.TEXT_ONLY;
        case r'MULTIMEDIA': return PostCreateReqDtoPostTypeEnum.MULTIMEDIA;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PostCreateReqDtoPostTypeEnumTypeTransformer] instance.
  static PostCreateReqDtoPostTypeEnumTypeTransformer? _instance;
}


