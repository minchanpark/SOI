//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class CategoryCreateReqDto {
  /// Returns a new [CategoryCreateReqDto] instance.
  CategoryCreateReqDto({
    this.requesterId,
    this.name,
    this.receiverIds = const [],
    this.isPublic,
  });

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? requesterId;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? name;

  List<int> receiverIds;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? isPublic;

  @override
  bool operator ==(Object other) => identical(this, other) || other is CategoryCreateReqDto &&
    other.requesterId == requesterId &&
    other.name == name &&
    _deepEquality.equals(other.receiverIds, receiverIds) &&
    other.isPublic == isPublic;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (requesterId == null ? 0 : requesterId!.hashCode) +
    (name == null ? 0 : name!.hashCode) +
    (receiverIds.hashCode) +
    (isPublic == null ? 0 : isPublic!.hashCode);

  @override
  String toString() => 'CategoryCreateReqDto[requesterId=$requesterId, name=$name, receiverIds=$receiverIds, isPublic=$isPublic]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.requesterId != null) {
      json[r'requesterId'] = this.requesterId;
    } else {
      json[r'requesterId'] = null;
    }
    if (this.name != null) {
      json[r'name'] = this.name;
    } else {
      json[r'name'] = null;
    }
      json[r'receiverIds'] = this.receiverIds;
    if (this.isPublic != null) {
      json[r'isPublic'] = this.isPublic;
    } else {
      json[r'isPublic'] = null;
    }
    return json;
  }

  /// Returns a new [CategoryCreateReqDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CategoryCreateReqDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "CategoryCreateReqDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "CategoryCreateReqDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return CategoryCreateReqDto(
        requesterId: mapValueOfType<int>(json, r'requesterId'),
        name: mapValueOfType<String>(json, r'name'),
        receiverIds: json[r'receiverIds'] is Iterable
            ? (json[r'receiverIds'] as Iterable).cast<int>().toList(growable: false)
            : const [],
        isPublic: mapValueOfType<bool>(json, r'isPublic'),
      );
    }
    return null;
  }

  static List<CategoryCreateReqDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CategoryCreateReqDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CategoryCreateReqDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CategoryCreateReqDto> mapFromJson(dynamic json) {
    final map = <String, CategoryCreateReqDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CategoryCreateReqDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CategoryCreateReqDto-objects as value to a dart map
  static Map<String, List<CategoryCreateReqDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<CategoryCreateReqDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CategoryCreateReqDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}

