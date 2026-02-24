//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ReportResponseDto {
  /// Returns a new [ReportResponseDto] instance.
  ReportResponseDto({
    this.id,
    this.reporterUserId,
    this.targetId,
    this.reportTargetType,
    this.reportType,
    this.reportStatus,
    this.reportDetail,
    this.adminMemo,
    this.createTime,
    this.processTime,
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
  int? reporterUserId;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? targetId;

  ReportResponseDtoReportTargetTypeEnum? reportTargetType;

  ReportResponseDtoReportTypeEnum? reportType;

  ReportResponseDtoReportStatusEnum? reportStatus;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? reportDetail;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? adminMemo;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  DateTime? createTime;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  DateTime? processTime;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ReportResponseDto &&
    other.id == id &&
    other.reporterUserId == reporterUserId &&
    other.targetId == targetId &&
    other.reportTargetType == reportTargetType &&
    other.reportType == reportType &&
    other.reportStatus == reportStatus &&
    other.reportDetail == reportDetail &&
    other.adminMemo == adminMemo &&
    other.createTime == createTime &&
    other.processTime == processTime;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id == null ? 0 : id!.hashCode) +
    (reporterUserId == null ? 0 : reporterUserId!.hashCode) +
    (targetId == null ? 0 : targetId!.hashCode) +
    (reportTargetType == null ? 0 : reportTargetType!.hashCode) +
    (reportType == null ? 0 : reportType!.hashCode) +
    (reportStatus == null ? 0 : reportStatus!.hashCode) +
    (reportDetail == null ? 0 : reportDetail!.hashCode) +
    (adminMemo == null ? 0 : adminMemo!.hashCode) +
    (createTime == null ? 0 : createTime!.hashCode) +
    (processTime == null ? 0 : processTime!.hashCode);

  @override
  String toString() => 'ReportResponseDto[id=$id, reporterUserId=$reporterUserId, targetId=$targetId, reportTargetType=$reportTargetType, reportType=$reportType, reportStatus=$reportStatus, reportDetail=$reportDetail, adminMemo=$adminMemo, createTime=$createTime, processTime=$processTime]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.id != null) {
      json[r'id'] = this.id;
    } else {
      json[r'id'] = null;
    }
    if (this.reporterUserId != null) {
      json[r'reporterUserId'] = this.reporterUserId;
    } else {
      json[r'reporterUserId'] = null;
    }
    if (this.targetId != null) {
      json[r'targetId'] = this.targetId;
    } else {
      json[r'targetId'] = null;
    }
    if (this.reportTargetType != null) {
      json[r'reportTargetType'] = this.reportTargetType;
    } else {
      json[r'reportTargetType'] = null;
    }
    if (this.reportType != null) {
      json[r'reportType'] = this.reportType;
    } else {
      json[r'reportType'] = null;
    }
    if (this.reportStatus != null) {
      json[r'reportStatus'] = this.reportStatus;
    } else {
      json[r'reportStatus'] = null;
    }
    if (this.reportDetail != null) {
      json[r'reportDetail'] = this.reportDetail;
    } else {
      json[r'reportDetail'] = null;
    }
    if (this.adminMemo != null) {
      json[r'adminMemo'] = this.adminMemo;
    } else {
      json[r'adminMemo'] = null;
    }
    if (this.createTime != null) {
      json[r'createTime'] = this.createTime!.toUtc().toIso8601String();
    } else {
      json[r'createTime'] = null;
    }
    if (this.processTime != null) {
      json[r'processTime'] = this.processTime!.toUtc().toIso8601String();
    } else {
      json[r'processTime'] = null;
    }
    return json;
  }

  /// Returns a new [ReportResponseDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ReportResponseDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ReportResponseDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ReportResponseDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ReportResponseDto(
        id: mapValueOfType<int>(json, r'id'),
        reporterUserId: mapValueOfType<int>(json, r'reporterUserId'),
        targetId: mapValueOfType<int>(json, r'targetId'),
        reportTargetType: ReportResponseDtoReportTargetTypeEnum.fromJson(json[r'reportTargetType']),
        reportType: ReportResponseDtoReportTypeEnum.fromJson(json[r'reportType']),
        reportStatus: ReportResponseDtoReportStatusEnum.fromJson(json[r'reportStatus']),
        reportDetail: mapValueOfType<String>(json, r'reportDetail'),
        adminMemo: mapValueOfType<String>(json, r'adminMemo'),
        createTime: mapDateTime(json, r'createTime', r''),
        processTime: mapDateTime(json, r'processTime', r''),
      );
    }
    return null;
  }

  static List<ReportResponseDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ReportResponseDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ReportResponseDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ReportResponseDto> mapFromJson(dynamic json) {
    final map = <String, ReportResponseDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ReportResponseDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ReportResponseDto-objects as value to a dart map
  static Map<String, List<ReportResponseDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ReportResponseDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ReportResponseDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}


class ReportResponseDtoReportTargetTypeEnum {
  /// Instantiate a new enum with the provided [value].
  const ReportResponseDtoReportTargetTypeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const USER = ReportResponseDtoReportTargetTypeEnum._(r'USER');
  static const POST = ReportResponseDtoReportTargetTypeEnum._(r'POST');
  static const COMMENT = ReportResponseDtoReportTargetTypeEnum._(r'COMMENT');
  static const CATEGORY = ReportResponseDtoReportTargetTypeEnum._(r'CATEGORY');

  /// List of all possible values in this [enum][ReportResponseDtoReportTargetTypeEnum].
  static const values = <ReportResponseDtoReportTargetTypeEnum>[
    USER,
    POST,
    COMMENT,
    CATEGORY,
  ];

  static ReportResponseDtoReportTargetTypeEnum? fromJson(dynamic value) => ReportResponseDtoReportTargetTypeEnumTypeTransformer().decode(value);

  static List<ReportResponseDtoReportTargetTypeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ReportResponseDtoReportTargetTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ReportResponseDtoReportTargetTypeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ReportResponseDtoReportTargetTypeEnum] to String,
/// and [decode] dynamic data back to [ReportResponseDtoReportTargetTypeEnum].
class ReportResponseDtoReportTargetTypeEnumTypeTransformer {
  factory ReportResponseDtoReportTargetTypeEnumTypeTransformer() => _instance ??= const ReportResponseDtoReportTargetTypeEnumTypeTransformer._();

  const ReportResponseDtoReportTargetTypeEnumTypeTransformer._();

  String encode(ReportResponseDtoReportTargetTypeEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a ReportResponseDtoReportTargetTypeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ReportResponseDtoReportTargetTypeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'USER': return ReportResponseDtoReportTargetTypeEnum.USER;
        case r'POST': return ReportResponseDtoReportTargetTypeEnum.POST;
        case r'COMMENT': return ReportResponseDtoReportTargetTypeEnum.COMMENT;
        case r'CATEGORY': return ReportResponseDtoReportTargetTypeEnum.CATEGORY;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [ReportResponseDtoReportTargetTypeEnumTypeTransformer] instance.
  static ReportResponseDtoReportTargetTypeEnumTypeTransformer? _instance;
}



class ReportResponseDtoReportTypeEnum {
  /// Instantiate a new enum with the provided [value].
  const ReportResponseDtoReportTypeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const SPAM = ReportResponseDtoReportTypeEnum._(r'SPAM');
  static const HATE = ReportResponseDtoReportTypeEnum._(r'HATE');
  static const ILLEGAL = ReportResponseDtoReportTypeEnum._(r'ILLEGAL');
  static const ETC = ReportResponseDtoReportTypeEnum._(r'ETC');

  /// List of all possible values in this [enum][ReportResponseDtoReportTypeEnum].
  static const values = <ReportResponseDtoReportTypeEnum>[
    SPAM,
    HATE,
    ILLEGAL,
    ETC,
  ];

  static ReportResponseDtoReportTypeEnum? fromJson(dynamic value) => ReportResponseDtoReportTypeEnumTypeTransformer().decode(value);

  static List<ReportResponseDtoReportTypeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ReportResponseDtoReportTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ReportResponseDtoReportTypeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ReportResponseDtoReportTypeEnum] to String,
/// and [decode] dynamic data back to [ReportResponseDtoReportTypeEnum].
class ReportResponseDtoReportTypeEnumTypeTransformer {
  factory ReportResponseDtoReportTypeEnumTypeTransformer() => _instance ??= const ReportResponseDtoReportTypeEnumTypeTransformer._();

  const ReportResponseDtoReportTypeEnumTypeTransformer._();

  String encode(ReportResponseDtoReportTypeEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a ReportResponseDtoReportTypeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ReportResponseDtoReportTypeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'SPAM': return ReportResponseDtoReportTypeEnum.SPAM;
        case r'HATE': return ReportResponseDtoReportTypeEnum.HATE;
        case r'ILLEGAL': return ReportResponseDtoReportTypeEnum.ILLEGAL;
        case r'ETC': return ReportResponseDtoReportTypeEnum.ETC;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [ReportResponseDtoReportTypeEnumTypeTransformer] instance.
  static ReportResponseDtoReportTypeEnumTypeTransformer? _instance;
}



class ReportResponseDtoReportStatusEnum {
  /// Instantiate a new enum with the provided [value].
  const ReportResponseDtoReportStatusEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const PADDING = ReportResponseDtoReportStatusEnum._(r'PADDING');
  static const IN_PROGRESS = ReportResponseDtoReportStatusEnum._(r'IN_PROGRESS');
  static const RESOLVED = ReportResponseDtoReportStatusEnum._(r'RESOLVED');
  static const REJECTED = ReportResponseDtoReportStatusEnum._(r'REJECTED');

  /// List of all possible values in this [enum][ReportResponseDtoReportStatusEnum].
  static const values = <ReportResponseDtoReportStatusEnum>[
    PADDING,
    IN_PROGRESS,
    RESOLVED,
    REJECTED,
  ];

  static ReportResponseDtoReportStatusEnum? fromJson(dynamic value) => ReportResponseDtoReportStatusEnumTypeTransformer().decode(value);

  static List<ReportResponseDtoReportStatusEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ReportResponseDtoReportStatusEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ReportResponseDtoReportStatusEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ReportResponseDtoReportStatusEnum] to String,
/// and [decode] dynamic data back to [ReportResponseDtoReportStatusEnum].
class ReportResponseDtoReportStatusEnumTypeTransformer {
  factory ReportResponseDtoReportStatusEnumTypeTransformer() => _instance ??= const ReportResponseDtoReportStatusEnumTypeTransformer._();

  const ReportResponseDtoReportStatusEnumTypeTransformer._();

  String encode(ReportResponseDtoReportStatusEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a ReportResponseDtoReportStatusEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ReportResponseDtoReportStatusEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'PADDING': return ReportResponseDtoReportStatusEnum.PADDING;
        case r'IN_PROGRESS': return ReportResponseDtoReportStatusEnum.IN_PROGRESS;
        case r'RESOLVED': return ReportResponseDtoReportStatusEnum.RESOLVED;
        case r'REJECTED': return ReportResponseDtoReportStatusEnum.REJECTED;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [ReportResponseDtoReportStatusEnumTypeTransformer] instance.
  static ReportResponseDtoReportStatusEnumTypeTransformer? _instance;
}


