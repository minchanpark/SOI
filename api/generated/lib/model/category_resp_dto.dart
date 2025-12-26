//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class CategoryRespDto {
  /// Returns a new [CategoryRespDto] instance.
  CategoryRespDto({
    this.id,
    this.name,
    this.nicknames = const [],
    this.categoryPhotoKey,
    this.isNew,
    this.totalUserNum,
    this.isPinned,
    this.usersProfileKey = const [],
    this.pinnedAt,
    this.lastPhotoUploadedAt,
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
  String? name;

  List<String> nicknames;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? categoryPhotoKey;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? isNew;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? totalUserNum;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? isPinned;

  List<String> usersProfileKey;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  DateTime? pinnedAt;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  DateTime? lastPhotoUploadedAt;

  @override
  bool operator ==(Object other) => identical(this, other) || other is CategoryRespDto &&
    other.id == id &&
    other.name == name &&
    _deepEquality.equals(other.nicknames, nicknames) &&
    other.categoryPhotoKey == categoryPhotoKey &&
    other.isNew == isNew &&
    other.totalUserNum == totalUserNum &&
    other.isPinned == isPinned &&
    _deepEquality.equals(other.usersProfileKey, usersProfileKey) &&
    other.pinnedAt == pinnedAt &&
    other.lastPhotoUploadedAt == lastPhotoUploadedAt;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id == null ? 0 : id!.hashCode) +
    (name == null ? 0 : name!.hashCode) +
    (nicknames.hashCode) +
    (categoryPhotoKey == null ? 0 : categoryPhotoKey!.hashCode) +
    (isNew == null ? 0 : isNew!.hashCode) +
    (totalUserNum == null ? 0 : totalUserNum!.hashCode) +
    (isPinned == null ? 0 : isPinned!.hashCode) +
    (usersProfileKey.hashCode) +
    (pinnedAt == null ? 0 : pinnedAt!.hashCode) +
    (lastPhotoUploadedAt == null ? 0 : lastPhotoUploadedAt!.hashCode);

  @override
  String toString() => 'CategoryRespDto[id=$id, name=$name, nicknames=$nicknames, categoryPhotoKey=$categoryPhotoKey, isNew=$isNew, totalUserNum=$totalUserNum, isPinned=$isPinned, usersProfileKey=$usersProfileKey, pinnedAt=$pinnedAt, lastPhotoUploadedAt=$lastPhotoUploadedAt]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.id != null) {
      json[r'id'] = this.id;
    } else {
      json[r'id'] = null;
    }
    if (this.name != null) {
      json[r'name'] = this.name;
    } else {
      json[r'name'] = null;
    }
      json[r'nicknames'] = this.nicknames;
    if (this.categoryPhotoKey != null) {
      json[r'categoryPhotoKey'] = this.categoryPhotoKey;
    } else {
      json[r'categoryPhotoKey'] = null;
    }
    if (this.isNew != null) {
      json[r'isNew'] = this.isNew;
    } else {
      json[r'isNew'] = null;
    }
    if (this.totalUserNum != null) {
      json[r'totalUserNum'] = this.totalUserNum;
    } else {
      json[r'totalUserNum'] = null;
    }
    if (this.isPinned != null) {
      json[r'isPinned'] = this.isPinned;
    } else {
      json[r'isPinned'] = null;
    }
      json[r'usersProfileKey'] = this.usersProfileKey;
    if (this.pinnedAt != null) {
      json[r'pinnedAt'] = this.pinnedAt!.toUtc().toIso8601String();
    } else {
      json[r'pinnedAt'] = null;
    }
    if (this.lastPhotoUploadedAt != null) {
      json[r'lastPhotoUploadedAt'] = this.lastPhotoUploadedAt!.toUtc().toIso8601String();
    } else {
      json[r'lastPhotoUploadedAt'] = null;
    }
    return json;
  }

  /// Returns a new [CategoryRespDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CategoryRespDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "CategoryRespDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "CategoryRespDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return CategoryRespDto(
        id: mapValueOfType<int>(json, r'id'),
        name: mapValueOfType<String>(json, r'name'),
        nicknames: json[r'nicknames'] is Iterable
            ? (json[r'nicknames'] as Iterable).cast<String>().toList(growable: false)
            : const [],
        categoryPhotoKey: mapValueOfType<String>(json, r'categoryPhotoKey'),
        isNew: mapValueOfType<bool>(json, r'isNew'),
        totalUserNum: mapValueOfType<int>(json, r'totalUserNum'),
        isPinned: mapValueOfType<bool>(json, r'isPinned'),
        usersProfileKey: json[r'usersProfileKey'] is Iterable
            ? (json[r'usersProfileKey'] as Iterable).cast<String>().toList(growable: false)
            : const [],
        pinnedAt: mapDateTime(json, r'pinnedAt', r''),
        lastPhotoUploadedAt: mapDateTime(json, r'lastPhotoUploadedAt', r''),
      );
    }
    return null;
  }

  static List<CategoryRespDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CategoryRespDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CategoryRespDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CategoryRespDto> mapFromJson(dynamic json) {
    final map = <String, CategoryRespDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CategoryRespDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CategoryRespDto-objects as value to a dart map
  static Map<String, List<CategoryRespDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<CategoryRespDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CategoryRespDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}

