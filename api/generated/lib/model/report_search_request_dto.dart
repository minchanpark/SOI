//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ReportSearchRequestDto {
  /// Returns a new [ReportSearchRequestDto] instance.
  ReportSearchRequestDto({
    this.reportType,
    this.reportStatus,
    this.reportTargetType,
    this.sortOptionDto,
    this.page,
  });

  ReportSearchRequestDtoReportTypeEnum? reportType;

  ReportSearchRequestDtoReportStatusEnum? reportStatus;

  ReportSearchRequestDtoReportTargetTypeEnum? reportTargetType;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  SortOptionDto? sortOptionDto;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? page;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ReportSearchRequestDto &&
    other.reportType == reportType &&
    other.reportStatus == reportStatus &&
    other.reportTargetType == reportTargetType &&
    other.sortOptionDto == sortOptionDto &&
    other.page == page;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (reportType == null ? 0 : reportType!.hashCode) +
    (reportStatus == null ? 0 : reportStatus!.hashCode) +
    (reportTargetType == null ? 0 : reportTargetType!.hashCode) +
    (sortOptionDto == null ? 0 : sortOptionDto!.hashCode) +
    (page == null ? 0 : page!.hashCode);

  @override
  String toString() => 'ReportSearchRequestDto[reportType=$reportType, reportStatus=$reportStatus, reportTargetType=$reportTargetType, sortOptionDto=$sortOptionDto, page=$page]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
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
    if (this.reportTargetType != null) {
      json[r'reportTargetType'] = this.reportTargetType;
    } else {
      json[r'reportTargetType'] = null;
    }
    if (this.sortOptionDto != null) {
      json[r'sortOptionDto'] = this.sortOptionDto;
    } else {
      json[r'sortOptionDto'] = null;
    }
    if (this.page != null) {
      json[r'page'] = this.page;
    } else {
      json[r'page'] = null;
    }
    return json;
  }

  /// Returns a new [ReportSearchRequestDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ReportSearchRequestDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ReportSearchRequestDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ReportSearchRequestDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ReportSearchRequestDto(
        reportType: ReportSearchRequestDtoReportTypeEnum.fromJson(json[r'reportType']),
        reportStatus: ReportSearchRequestDtoReportStatusEnum.fromJson(json[r'reportStatus']),
        reportTargetType: ReportSearchRequestDtoReportTargetTypeEnum.fromJson(json[r'reportTargetType']),
        sortOptionDto: SortOptionDto.fromJson(json[r'sortOptionDto']),
        page: mapValueOfType<int>(json, r'page'),
      );
    }
    return null;
  }

  static List<ReportSearchRequestDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ReportSearchRequestDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ReportSearchRequestDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ReportSearchRequestDto> mapFromJson(dynamic json) {
    final map = <String, ReportSearchRequestDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ReportSearchRequestDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ReportSearchRequestDto-objects as value to a dart map
  static Map<String, List<ReportSearchRequestDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ReportSearchRequestDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ReportSearchRequestDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}


class ReportSearchRequestDtoReportTypeEnum {
  /// Instantiate a new enum with the provided [value].
  const ReportSearchRequestDtoReportTypeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const SPAM = ReportSearchRequestDtoReportTypeEnum._(r'SPAM');
  static const HATE = ReportSearchRequestDtoReportTypeEnum._(r'HATE');
  static const ILLEGAL = ReportSearchRequestDtoReportTypeEnum._(r'ILLEGAL');
  static const ETC = ReportSearchRequestDtoReportTypeEnum._(r'ETC');

  /// List of all possible values in this [enum][ReportSearchRequestDtoReportTypeEnum].
  static const values = <ReportSearchRequestDtoReportTypeEnum>[
    SPAM,
    HATE,
    ILLEGAL,
    ETC,
  ];

  static ReportSearchRequestDtoReportTypeEnum? fromJson(dynamic value) => ReportSearchRequestDtoReportTypeEnumTypeTransformer().decode(value);

  static List<ReportSearchRequestDtoReportTypeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ReportSearchRequestDtoReportTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ReportSearchRequestDtoReportTypeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ReportSearchRequestDtoReportTypeEnum] to String,
/// and [decode] dynamic data back to [ReportSearchRequestDtoReportTypeEnum].
class ReportSearchRequestDtoReportTypeEnumTypeTransformer {
  factory ReportSearchRequestDtoReportTypeEnumTypeTransformer() => _instance ??= const ReportSearchRequestDtoReportTypeEnumTypeTransformer._();

  const ReportSearchRequestDtoReportTypeEnumTypeTransformer._();

  String encode(ReportSearchRequestDtoReportTypeEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a ReportSearchRequestDtoReportTypeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ReportSearchRequestDtoReportTypeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'SPAM': return ReportSearchRequestDtoReportTypeEnum.SPAM;
        case r'HATE': return ReportSearchRequestDtoReportTypeEnum.HATE;
        case r'ILLEGAL': return ReportSearchRequestDtoReportTypeEnum.ILLEGAL;
        case r'ETC': return ReportSearchRequestDtoReportTypeEnum.ETC;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [ReportSearchRequestDtoReportTypeEnumTypeTransformer] instance.
  static ReportSearchRequestDtoReportTypeEnumTypeTransformer? _instance;
}



class ReportSearchRequestDtoReportStatusEnum {
  /// Instantiate a new enum with the provided [value].
  const ReportSearchRequestDtoReportStatusEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const PADDING = ReportSearchRequestDtoReportStatusEnum._(r'PADDING');
  static const IN_PROGRESS = ReportSearchRequestDtoReportStatusEnum._(r'IN_PROGRESS');
  static const RESOLVED = ReportSearchRequestDtoReportStatusEnum._(r'RESOLVED');
  static const REJECTED = ReportSearchRequestDtoReportStatusEnum._(r'REJECTED');

  /// List of all possible values in this [enum][ReportSearchRequestDtoReportStatusEnum].
  static const values = <ReportSearchRequestDtoReportStatusEnum>[
    PADDING,
    IN_PROGRESS,
    RESOLVED,
    REJECTED,
  ];

  static ReportSearchRequestDtoReportStatusEnum? fromJson(dynamic value) => ReportSearchRequestDtoReportStatusEnumTypeTransformer().decode(value);

  static List<ReportSearchRequestDtoReportStatusEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ReportSearchRequestDtoReportStatusEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ReportSearchRequestDtoReportStatusEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ReportSearchRequestDtoReportStatusEnum] to String,
/// and [decode] dynamic data back to [ReportSearchRequestDtoReportStatusEnum].
class ReportSearchRequestDtoReportStatusEnumTypeTransformer {
  factory ReportSearchRequestDtoReportStatusEnumTypeTransformer() => _instance ??= const ReportSearchRequestDtoReportStatusEnumTypeTransformer._();

  const ReportSearchRequestDtoReportStatusEnumTypeTransformer._();

  String encode(ReportSearchRequestDtoReportStatusEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a ReportSearchRequestDtoReportStatusEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ReportSearchRequestDtoReportStatusEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'PADDING': return ReportSearchRequestDtoReportStatusEnum.PADDING;
        case r'IN_PROGRESS': return ReportSearchRequestDtoReportStatusEnum.IN_PROGRESS;
        case r'RESOLVED': return ReportSearchRequestDtoReportStatusEnum.RESOLVED;
        case r'REJECTED': return ReportSearchRequestDtoReportStatusEnum.REJECTED;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [ReportSearchRequestDtoReportStatusEnumTypeTransformer] instance.
  static ReportSearchRequestDtoReportStatusEnumTypeTransformer? _instance;
}



class ReportSearchRequestDtoReportTargetTypeEnum {
  /// Instantiate a new enum with the provided [value].
  const ReportSearchRequestDtoReportTargetTypeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const USER = ReportSearchRequestDtoReportTargetTypeEnum._(r'USER');
  static const POST = ReportSearchRequestDtoReportTargetTypeEnum._(r'POST');
  static const COMMENT = ReportSearchRequestDtoReportTargetTypeEnum._(r'COMMENT');
  static const CATEGORY = ReportSearchRequestDtoReportTargetTypeEnum._(r'CATEGORY');

  /// List of all possible values in this [enum][ReportSearchRequestDtoReportTargetTypeEnum].
  static const values = <ReportSearchRequestDtoReportTargetTypeEnum>[
    USER,
    POST,
    COMMENT,
    CATEGORY,
  ];

  static ReportSearchRequestDtoReportTargetTypeEnum? fromJson(dynamic value) => ReportSearchRequestDtoReportTargetTypeEnumTypeTransformer().decode(value);

  static List<ReportSearchRequestDtoReportTargetTypeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ReportSearchRequestDtoReportTargetTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ReportSearchRequestDtoReportTargetTypeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ReportSearchRequestDtoReportTargetTypeEnum] to String,
/// and [decode] dynamic data back to [ReportSearchRequestDtoReportTargetTypeEnum].
class ReportSearchRequestDtoReportTargetTypeEnumTypeTransformer {
  factory ReportSearchRequestDtoReportTargetTypeEnumTypeTransformer() => _instance ??= const ReportSearchRequestDtoReportTargetTypeEnumTypeTransformer._();

  const ReportSearchRequestDtoReportTargetTypeEnumTypeTransformer._();

  String encode(ReportSearchRequestDtoReportTargetTypeEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a ReportSearchRequestDtoReportTargetTypeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ReportSearchRequestDtoReportTargetTypeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'USER': return ReportSearchRequestDtoReportTargetTypeEnum.USER;
        case r'POST': return ReportSearchRequestDtoReportTargetTypeEnum.POST;
        case r'COMMENT': return ReportSearchRequestDtoReportTargetTypeEnum.COMMENT;
        case r'CATEGORY': return ReportSearchRequestDtoReportTargetTypeEnum.CATEGORY;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [ReportSearchRequestDtoReportTargetTypeEnumTypeTransformer] instance.
  static ReportSearchRequestDtoReportTargetTypeEnumTypeTransformer? _instance;
}


