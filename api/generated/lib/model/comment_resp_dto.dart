//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class CommentRespDto {
  /// Returns a new [CommentRespDto] instance.
  CommentRespDto({
    this.id,
    this.userProfileUrl,
    this.userProfileKey,
    this.userId,
    this.nickname,
    this.text,
    this.emojiId,
    this.replyUserName,
    this.audioUrl,
    this.waveFormData,
    this.duration,
    this.locationX,
    this.locationY,
    this.commentType,
    this.fileUrl,
    this.fileKey,
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
  String? userProfileUrl;

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
  String? text;

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
  String? replyUserName;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? audioUrl;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? waveFormData;

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

  CommentRespDtoCommentTypeEnum? commentType;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? fileUrl;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? fileKey;

  @override
  bool operator ==(Object other) => identical(this, other) || other is CommentRespDto &&
    other.id == id &&
    other.userProfileUrl == userProfileUrl &&
    other.userProfileKey == userProfileKey &&
    other.userId == userId &&
    other.nickname == nickname &&
    other.text == text &&
    other.emojiId == emojiId &&
    other.replyUserName == replyUserName &&
    other.audioUrl == audioUrl &&
    other.waveFormData == waveFormData &&
    other.duration == duration &&
    other.locationX == locationX &&
    other.locationY == locationY &&
    other.commentType == commentType &&
    other.fileUrl == fileUrl &&
    other.fileKey == fileKey;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id == null ? 0 : id!.hashCode) +
    (userProfileUrl == null ? 0 : userProfileUrl!.hashCode) +
    (userProfileKey == null ? 0 : userProfileKey!.hashCode) +
    (userId == null ? 0 : userId!.hashCode) +
    (nickname == null ? 0 : nickname!.hashCode) +
    (text == null ? 0 : text!.hashCode) +
    (emojiId == null ? 0 : emojiId!.hashCode) +
    (replyUserName == null ? 0 : replyUserName!.hashCode) +
    (audioUrl == null ? 0 : audioUrl!.hashCode) +
    (waveFormData == null ? 0 : waveFormData!.hashCode) +
    (duration == null ? 0 : duration!.hashCode) +
    (locationX == null ? 0 : locationX!.hashCode) +
    (locationY == null ? 0 : locationY!.hashCode) +
    (commentType == null ? 0 : commentType!.hashCode) +
    (fileUrl == null ? 0 : fileUrl!.hashCode) +
    (fileKey == null ? 0 : fileKey!.hashCode);

  @override
  String toString() => 'CommentRespDto[id=$id, userProfileUrl=$userProfileUrl, userProfileKey=$userProfileKey, userId=$userId, nickname=$nickname, text=$text, emojiId=$emojiId, replyUserName=$replyUserName, audioUrl=$audioUrl, waveFormData=$waveFormData, duration=$duration, locationX=$locationX, locationY=$locationY, commentType=$commentType, fileUrl=$fileUrl, fileKey=$fileKey]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.id != null) {
      json[r'id'] = this.id;
    } else {
      json[r'id'] = null;
    }
    if (this.userProfileUrl != null) {
      json[r'userProfileUrl'] = this.userProfileUrl;
    } else {
      json[r'userProfileUrl'] = null;
    }
    if (this.userProfileKey != null) {
      json[r'userProfileKey'] = this.userProfileKey;
    } else {
      json[r'userProfileKey'] = null;
    }
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
    if (this.text != null) {
      json[r'text'] = this.text;
    } else {
      json[r'text'] = null;
    }
    if (this.emojiId != null) {
      json[r'emojiId'] = this.emojiId;
    } else {
      json[r'emojiId'] = null;
    }
    if (this.replyUserName != null) {
      json[r'replyUserName'] = this.replyUserName;
    } else {
      json[r'replyUserName'] = null;
    }
    if (this.audioUrl != null) {
      json[r'audioUrl'] = this.audioUrl;
    } else {
      json[r'audioUrl'] = null;
    }
    if (this.waveFormData != null) {
      json[r'waveFormData'] = this.waveFormData;
    } else {
      json[r'waveFormData'] = null;
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
    if (this.fileUrl != null) {
      json[r'fileUrl'] = this.fileUrl;
    } else {
      json[r'fileUrl'] = null;
    }
    if (this.fileKey != null) {
      json[r'fileKey'] = this.fileKey;
    } else {
      json[r'fileKey'] = null;
    }
    return json;
  }

  /// Returns a new [CommentRespDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CommentRespDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "CommentRespDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "CommentRespDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return CommentRespDto(
        id: mapValueOfType<int>(json, r'id'),
        userProfileUrl: mapValueOfType<String>(json, r'userProfileUrl'),
        userProfileKey: mapValueOfType<String>(json, r'userProfileKey'),
        userId: mapValueOfType<int>(json, r'userId'),
        nickname: mapValueOfType<String>(json, r'nickname'),
        text: mapValueOfType<String>(json, r'text'),
        emojiId: mapValueOfType<int>(json, r'emojiId'),
        replyUserName: mapValueOfType<String>(json, r'replyUserName'),
        audioUrl: mapValueOfType<String>(json, r'audioUrl'),
        waveFormData: mapValueOfType<String>(json, r'waveFormData'),
        duration: mapValueOfType<int>(json, r'duration'),
        locationX: mapValueOfType<double>(json, r'locationX'),
        locationY: mapValueOfType<double>(json, r'locationY'),
        commentType: CommentRespDtoCommentTypeEnum.fromJson(json[r'commentType']),
        fileUrl: mapValueOfType<String>(json, r'fileUrl'),
        fileKey: mapValueOfType<String>(json, r'fileKey'),
      );
    }
    return null;
  }

  static List<CommentRespDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CommentRespDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CommentRespDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CommentRespDto> mapFromJson(dynamic json) {
    final map = <String, CommentRespDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CommentRespDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CommentRespDto-objects as value to a dart map
  static Map<String, List<CommentRespDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<CommentRespDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CommentRespDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}


class CommentRespDtoCommentTypeEnum {
  /// Instantiate a new enum with the provided [value].
  const CommentRespDtoCommentTypeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const EMOJI = CommentRespDtoCommentTypeEnum._(r'EMOJI');
  static const TEXT = CommentRespDtoCommentTypeEnum._(r'TEXT');
  static const AUDIO = CommentRespDtoCommentTypeEnum._(r'AUDIO');
  static const PHOTO = CommentRespDtoCommentTypeEnum._(r'PHOTO');
  static const REPLY = CommentRespDtoCommentTypeEnum._(r'REPLY');

  /// List of all possible values in this [enum][CommentRespDtoCommentTypeEnum].
  static const values = <CommentRespDtoCommentTypeEnum>[
    EMOJI,
    TEXT,
    AUDIO,
    PHOTO,
    REPLY,
  ];

  static CommentRespDtoCommentTypeEnum? fromJson(dynamic value) => CommentRespDtoCommentTypeEnumTypeTransformer().decode(value);

  static List<CommentRespDtoCommentTypeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CommentRespDtoCommentTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CommentRespDtoCommentTypeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [CommentRespDtoCommentTypeEnum] to String,
/// and [decode] dynamic data back to [CommentRespDtoCommentTypeEnum].
class CommentRespDtoCommentTypeEnumTypeTransformer {
  factory CommentRespDtoCommentTypeEnumTypeTransformer() => _instance ??= const CommentRespDtoCommentTypeEnumTypeTransformer._();

  const CommentRespDtoCommentTypeEnumTypeTransformer._();

  String encode(CommentRespDtoCommentTypeEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a CommentRespDtoCommentTypeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  CommentRespDtoCommentTypeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'EMOJI': return CommentRespDtoCommentTypeEnum.EMOJI;
        case r'TEXT': return CommentRespDtoCommentTypeEnum.TEXT;
        case r'AUDIO': return CommentRespDtoCommentTypeEnum.AUDIO;
        case r'PHOTO': return CommentRespDtoCommentTypeEnum.PHOTO;
        case r'REPLY': return CommentRespDtoCommentTypeEnum.REPLY;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [CommentRespDtoCommentTypeEnumTypeTransformer] instance.
  static CommentRespDtoCommentTypeEnumTypeTransformer? _instance;
}


