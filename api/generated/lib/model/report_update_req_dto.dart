//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ReportUpdateReqDto {
  /// Returns a new [ReportUpdateReqDto] instance.
  ReportUpdateReqDto({
    this.id,
    this.reportStatus,
    this.adminMemo,
  });

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? id;

  ReportUpdateReqDtoReportStatusEnum? reportStatus;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? adminMemo;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ReportUpdateReqDto &&
    other.id == id &&
    other.reportStatus == reportStatus &&
    other.adminMemo == adminMemo;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id == null ? 0 : id!.hashCode) +
    (reportStatus == null ? 0 : reportStatus!.hashCode) +
    (adminMemo == null ? 0 : adminMemo!.hashCode);

  @override
  String toString() => 'ReportUpdateReqDto[id=$id, reportStatus=$reportStatus, adminMemo=$adminMemo]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.id != null) {
      json[r'id'] = this.id;
    } else {
      json[r'id'] = null;
    }
    if (this.reportStatus != null) {
      json[r'reportStatus'] = this.reportStatus;
    } else {
      json[r'reportStatus'] = null;
    }
    if (this.adminMemo != null) {
      json[r'adminMemo'] = this.adminMemo;
    } else {
      json[r'adminMemo'] = null;
    }
    return json;
  }

  /// Returns a new [ReportUpdateReqDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ReportUpdateReqDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ReportUpdateReqDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ReportUpdateReqDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ReportUpdateReqDto(
        id: mapValueOfType<int>(json, r'id'),
        reportStatus: ReportUpdateReqDtoReportStatusEnum.fromJson(json[r'reportStatus']),
        adminMemo: mapValueOfType<String>(json, r'adminMemo'),
      );
    }
    return null;
  }

  static List<ReportUpdateReqDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ReportUpdateReqDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ReportUpdateReqDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ReportUpdateReqDto> mapFromJson(dynamic json) {
    final map = <String, ReportUpdateReqDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ReportUpdateReqDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ReportUpdateReqDto-objects as value to a dart map
  static Map<String, List<ReportUpdateReqDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ReportUpdateReqDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ReportUpdateReqDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}


class ReportUpdateReqDtoReportStatusEnum {
  /// Instantiate a new enum with the provided [value].
  const ReportUpdateReqDtoReportStatusEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const PADDING = ReportUpdateReqDtoReportStatusEnum._(r'PADDING');
  static const IN_PROGRESS = ReportUpdateReqDtoReportStatusEnum._(r'IN_PROGRESS');
  static const RESOLVED = ReportUpdateReqDtoReportStatusEnum._(r'RESOLVED');
  static const REJECTED = ReportUpdateReqDtoReportStatusEnum._(r'REJECTED');

  /// List of all possible values in this [enum][ReportUpdateReqDtoReportStatusEnum].
  static const values = <ReportUpdateReqDtoReportStatusEnum>[
    PADDING,
    IN_PROGRESS,
    RESOLVED,
    REJECTED,
  ];

  static ReportUpdateReqDtoReportStatusEnum? fromJson(dynamic value) => ReportUpdateReqDtoReportStatusEnumTypeTransformer().decode(value);

  static List<ReportUpdateReqDtoReportStatusEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ReportUpdateReqDtoReportStatusEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ReportUpdateReqDtoReportStatusEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ReportUpdateReqDtoReportStatusEnum] to String,
/// and [decode] dynamic data back to [ReportUpdateReqDtoReportStatusEnum].
class ReportUpdateReqDtoReportStatusEnumTypeTransformer {
  factory ReportUpdateReqDtoReportStatusEnumTypeTransformer() => _instance ??= const ReportUpdateReqDtoReportStatusEnumTypeTransformer._();

  const ReportUpdateReqDtoReportStatusEnumTypeTransformer._();

  String encode(ReportUpdateReqDtoReportStatusEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a ReportUpdateReqDtoReportStatusEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ReportUpdateReqDtoReportStatusEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'PADDING': return ReportUpdateReqDtoReportStatusEnum.PADDING;
        case r'IN_PROGRESS': return ReportUpdateReqDtoReportStatusEnum.IN_PROGRESS;
        case r'RESOLVED': return ReportUpdateReqDtoReportStatusEnum.RESOLVED;
        case r'REJECTED': return ReportUpdateReqDtoReportStatusEnum.REJECTED;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [ReportUpdateReqDtoReportStatusEnumTypeTransformer] instance.
  static ReportUpdateReqDtoReportStatusEnumTypeTransformer? _instance;
}


