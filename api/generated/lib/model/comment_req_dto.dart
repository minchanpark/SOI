//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class CommentReqDto {
  /// Returns a new [CommentReqDto] instance.
  CommentReqDto({
    this.userId,
    this.emojiId,
    this.postId,
    this.parentId,
    this.replyUserId,
    this.text,
    this.audioKey,
    this.fileKey,
    this.waveformData,
    this.duration,
    this.locationX,
    this.locationY,
    this.commentType,
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
  int? emojiId;

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
  int? parentId;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? replyUserId;

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
  String? audioKey;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? fileKey;

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
  double? locationX;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  double? locationY;

  CommentReqDtoCommentTypeEnum? commentType;

  @override
  bool operator ==(Object other) => identical(this, other) || other is CommentReqDto &&
    other.userId == userId &&
    other.emojiId == emojiId &&
    other.postId == postId &&
    other.parentId == parentId &&
    other.replyUserId == replyUserId &&
    other.text == text &&
    other.audioKey == audioKey &&
    other.fileKey == fileKey &&
    other.waveformData == waveformData &&
    other.duration == duration &&
    other.locationX == locationX &&
    other.locationY == locationY &&
    other.commentType == commentType;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (userId == null ? 0 : userId!.hashCode) +
    (emojiId == null ? 0 : emojiId!.hashCode) +
    (postId == null ? 0 : postId!.hashCode) +
    (parentId == null ? 0 : parentId!.hashCode) +
    (replyUserId == null ? 0 : replyUserId!.hashCode) +
    (text == null ? 0 : text!.hashCode) +
    (audioKey == null ? 0 : audioKey!.hashCode) +
    (fileKey == null ? 0 : fileKey!.hashCode) +
    (waveformData == null ? 0 : waveformData!.hashCode) +
    (duration == null ? 0 : duration!.hashCode) +
    (locationX == null ? 0 : locationX!.hashCode) +
    (locationY == null ? 0 : locationY!.hashCode) +
    (commentType == null ? 0 : commentType!.hashCode);

  @override
  String toString() => 'CommentReqDto[userId=$userId, emojiId=$emojiId, postId=$postId, parentId=$parentId, replyUserId=$replyUserId, text=$text, audioKey=$audioKey, fileKey=$fileKey, waveformData=$waveformData, duration=$duration, locationX=$locationX, locationY=$locationY, commentType=$commentType]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.userId != null) {
      json[r'userId'] = this.userId;
    } else {
      json[r'userId'] = null;
    }
    if (this.emojiId != null) {
      json[r'emojiId'] = this.emojiId;
    } else {
      json[r'emojiId'] = null;
    }
    if (this.postId != null) {
      json[r'postId'] = this.postId;
    } else {
      json[r'postId'] = null;
    }
    if (this.parentId != null) {
      json[r'parentId'] = this.parentId;
    } else {
      json[r'parentId'] = null;
    }
    if (this.replyUserId != null) {
      json[r'replyUserId'] = this.replyUserId;
    } else {
      json[r'replyUserId'] = null;
    }
    if (this.text != null) {
      json[r'text'] = this.text;
    } else {
      json[r'text'] = null;
    }
    if (this.audioKey != null) {
      json[r'audioKey'] = this.audioKey;
    } else {
      json[r'audioKey'] = null;
    }
    if (this.fileKey != null) {
      json[r'fileKey'] = this.fileKey;
    } else {
      json[r'fileKey'] = null;
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
    if (this.locationX != null) {
      json[r'locationX'] = this.locationX;
    } else {
      json[r'locationX'] = null;
    }
    if (this.locationY != null) {
      json[r'locationY'] = this.locationY;
    } else {
      json[r'locationY'] = null;
    }
    if (this.commentType != null) {
      json[r'commentType'] = this.commentType;
    } else {
      json[r'commentType'] = null;
    }
    return json;
  }

  /// Returns a new [CommentReqDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CommentReqDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "CommentReqDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "CommentReqDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return CommentReqDto(
        userId: mapValueOfType<int>(json, r'userId'),
        emojiId: mapValueOfType<int>(json, r'emojiId'),
        postId: mapValueOfType<int>(json, r'postId'),
        parentId: mapValueOfType<int>(json, r'parentId'),
        replyUserId: mapValueOfType<int>(json, r'replyUserId'),
        text: mapValueOfType<String>(json, r'text'),
        audioKey: mapValueOfType<String>(json, r'audioKey'),
        fileKey: mapValueOfType<String>(json, r'fileKey'),
        waveformData: mapValueOfType<String>(json, r'waveformData'),
        duration: mapValueOfType<int>(json, r'duration'),
        locationX: mapValueOfType<double>(json, r'locationX'),
        locationY: mapValueOfType<double>(json, r'locationY'),
        commentType: CommentReqDtoCommentTypeEnum.fromJson(json[r'commentType']),
      );
    }
    return null;
  }

  static List<CommentReqDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CommentReqDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CommentReqDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CommentReqDto> mapFromJson(dynamic json) {
    final map = <String, CommentReqDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CommentReqDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CommentReqDto-objects as value to a dart map
  static Map<String, List<CommentReqDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<CommentReqDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CommentReqDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}


class CommentReqDtoCommentTypeEnum {
  /// Instantiate a new enum with the provided [value].
  const CommentReqDtoCommentTypeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const EMOJI = CommentReqDtoCommentTypeEnum._(r'EMOJI');
  static const TEXT = CommentReqDtoCommentTypeEnum._(r'TEXT');
  static const AUDIO = CommentReqDtoCommentTypeEnum._(r'AUDIO');
  static const PHOTO = CommentReqDtoCommentTypeEnum._(r'PHOTO');
  static const REPLY = CommentReqDtoCommentTypeEnum._(r'REPLY');

  /// List of all possible values in this [enum][CommentReqDtoCommentTypeEnum].
  static const values = <CommentReqDtoCommentTypeEnum>[
    EMOJI,
    TEXT,
    AUDIO,
    PHOTO,
    REPLY,
  ];

  static CommentReqDtoCommentTypeEnum? fromJson(dynamic value) => CommentReqDtoCommentTypeEnumTypeTransformer().decode(value);

  static List<CommentReqDtoCommentTypeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CommentReqDtoCommentTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CommentReqDtoCommentTypeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [CommentReqDtoCommentTypeEnum] to String,
/// and [decode] dynamic data back to [CommentReqDtoCommentTypeEnum].
class CommentReqDtoCommentTypeEnumTypeTransformer {
  factory CommentReqDtoCommentTypeEnumTypeTransformer() => _instance ??= const CommentReqDtoCommentTypeEnumTypeTransformer._();

  const CommentReqDtoCommentTypeEnumTypeTransformer._();

  String encode(CommentReqDtoCommentTypeEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a CommentReqDtoCommentTypeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  CommentReqDtoCommentTypeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'EMOJI': return CommentReqDtoCommentTypeEnum.EMOJI;
        case r'TEXT': return CommentReqDtoCommentTypeEnum.TEXT;
        case r'AUDIO': return CommentReqDtoCommentTypeEnum.AUDIO;
        case r'PHOTO': return CommentReqDtoCommentTypeEnum.PHOTO;
        case r'REPLY': return CommentReqDtoCommentTypeEnum.REPLY;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [CommentReqDtoCommentTypeEnumTypeTransformer] instance.
  static CommentReqDtoCommentTypeEnumTypeTransformer? _instance;
}


