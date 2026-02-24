//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ReportCreateRequestDto {
  /// Returns a new [ReportCreateRequestDto] instance.
  ReportCreateRequestDto({
    this.reporterUserId,
    this.targetId,
    this.reportTargetType,
    this.reportType,
    this.reportDetail,
  });

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

  ReportCreateRequestDtoReportTargetTypeEnum? reportTargetType;

  ReportCreateRequestDtoReportTypeEnum? reportType;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? reportDetail;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ReportCreateRequestDto &&
    other.reporterUserId == reporterUserId &&
    other.targetId == targetId &&
    other.reportTargetType == reportTargetType &&
    other.reportType == reportType &&
    other.reportDetail == reportDetail;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (reporterUserId == null ? 0 : reporterUserId!.hashCode) +
    (targetId == null ? 0 : targetId!.hashCode) +
    (reportTargetType == null ? 0 : reportTargetType!.hashCode) +
    (reportType == null ? 0 : reportType!.hashCode) +
    (reportDetail == null ? 0 : reportDetail!.hashCode);

  @override
  String toString() => 'ReportCreateRequestDto[reporterUserId=$reporterUserId, targetId=$targetId, reportTargetType=$reportTargetType, reportType=$reportType, reportDetail=$reportDetail]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
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
    if (this.reportDetail != null) {
      json[r'reportDetail'] = this.reportDetail;
    } else {
      json[r'reportDetail'] = null;
    }
    return json;
  }

  /// Returns a new [ReportCreateRequestDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ReportCreateRequestDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ReportCreateRequestDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ReportCreateRequestDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ReportCreateRequestDto(
        reporterUserId: mapValueOfType<int>(json, r'reporterUserId'),
        targetId: mapValueOfType<int>(json, r'targetId'),
        reportTargetType: ReportCreateRequestDtoReportTargetTypeEnum.fromJson(json[r'reportTargetType']),
        reportType: ReportCreateRequestDtoReportTypeEnum.fromJson(json[r'reportType']),
        reportDetail: mapValueOfType<String>(json, r'reportDetail'),
      );
    }
    return null;
  }

  static List<ReportCreateRequestDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ReportCreateRequestDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ReportCreateRequestDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ReportCreateRequestDto> mapFromJson(dynamic json) {
    final map = <String, ReportCreateRequestDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ReportCreateRequestDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ReportCreateRequestDto-objects as value to a dart map
  static Map<String, List<ReportCreateRequestDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ReportCreateRequestDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ReportCreateRequestDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}


class ReportCreateRequestDtoReportTargetTypeEnum {
  /// Instantiate a new enum with the provided [value].
  const ReportCreateRequestDtoReportTargetTypeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const USER = ReportCreateRequestDtoReportTargetTypeEnum._(r'USER');
  static const POST = ReportCreateRequestDtoReportTargetTypeEnum._(r'POST');
  static const COMMENT = ReportCreateRequestDtoReportTargetTypeEnum._(r'COMMENT');
  static const CATEGORY = ReportCreateRequestDtoReportTargetTypeEnum._(r'CATEGORY');

  /// List of all possible values in this [enum][ReportCreateRequestDtoReportTargetTypeEnum].
  static const values = <ReportCreateRequestDtoReportTargetTypeEnum>[
    USER,
    POST,
    COMMENT,
    CATEGORY,
  ];

  static ReportCreateRequestDtoReportTargetTypeEnum? fromJson(dynamic value) => ReportCreateRequestDtoReportTargetTypeEnumTypeTransformer().decode(value);

  static List<ReportCreateRequestDtoReportTargetTypeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ReportCreateRequestDtoReportTargetTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ReportCreateRequestDtoReportTargetTypeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ReportCreateRequestDtoReportTargetTypeEnum] to String,
/// and [decode] dynamic data back to [ReportCreateRequestDtoReportTargetTypeEnum].
class ReportCreateRequestDtoReportTargetTypeEnumTypeTransformer {
  factory ReportCreateRequestDtoReportTargetTypeEnumTypeTransformer() => _instance ??= const ReportCreateRequestDtoReportTargetTypeEnumTypeTransformer._();

  const ReportCreateRequestDtoReportTargetTypeEnumTypeTransformer._();

  String encode(ReportCreateRequestDtoReportTargetTypeEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a ReportCreateRequestDtoReportTargetTypeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ReportCreateRequestDtoReportTargetTypeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'USER': return ReportCreateRequestDtoReportTargetTypeEnum.USER;
        case r'POST': return ReportCreateRequestDtoReportTargetTypeEnum.POST;
        case r'COMMENT': return ReportCreateRequestDtoReportTargetTypeEnum.COMMENT;
        case r'CATEGORY': return ReportCreateRequestDtoReportTargetTypeEnum.CATEGORY;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [ReportCreateRequestDtoReportTargetTypeEnumTypeTransformer] instance.
  static ReportCreateRequestDtoReportTargetTypeEnumTypeTransformer? _instance;
}



class ReportCreateRequestDtoReportTypeEnum {
  /// Instantiate a new enum with the provided [value].
  const ReportCreateRequestDtoReportTypeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const SPAM = ReportCreateRequestDtoReportTypeEnum._(r'SPAM');
  static const HATE = ReportCreateRequestDtoReportTypeEnum._(r'HATE');
  static const ILLEGAL = ReportCreateRequestDtoReportTypeEnum._(r'ILLEGAL');
  static const ETC = ReportCreateRequestDtoReportTypeEnum._(r'ETC');

  /// List of all possible values in this [enum][ReportCreateRequestDtoReportTypeEnum].
  static const values = <ReportCreateRequestDtoReportTypeEnum>[
    SPAM,
    HATE,
    ILLEGAL,
    ETC,
  ];

  static ReportCreateRequestDtoReportTypeEnum? fromJson(dynamic value) => ReportCreateRequestDtoReportTypeEnumTypeTransformer().decode(value);

  static List<ReportCreateRequestDtoReportTypeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ReportCreateRequestDtoReportTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ReportCreateRequestDtoReportTypeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ReportCreateRequestDtoReportTypeEnum] to String,
/// and [decode] dynamic data back to [ReportCreateRequestDtoReportTypeEnum].
class ReportCreateRequestDtoReportTypeEnumTypeTransformer {
  factory ReportCreateRequestDtoReportTypeEnumTypeTransformer() => _instance ??= const ReportCreateRequestDtoReportTypeEnumTypeTransformer._();

  const ReportCreateRequestDtoReportTypeEnumTypeTransformer._();

  String encode(ReportCreateRequestDtoReportTypeEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a ReportCreateRequestDtoReportTypeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ReportCreateRequestDtoReportTypeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'SPAM': return ReportCreateRequestDtoReportTypeEnum.SPAM;
        case r'HATE': return ReportCreateRequestDtoReportTypeEnum.HATE;
        case r'ILLEGAL': return ReportCreateRequestDtoReportTypeEnum.ILLEGAL;
        case r'ETC': return ReportCreateRequestDtoReportTypeEnum.ETC;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [ReportCreateRequestDtoReportTypeEnumTypeTransformer] instance.
  static ReportCreateRequestDtoReportTypeEnumTypeTransformer? _instance;
}


