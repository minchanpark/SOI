//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class CategoryInviteReqDto {
  /// Returns a new [CategoryInviteReqDto] instance.
  CategoryInviteReqDto({
    this.requesterId,
    this.receiverId = const [],
    this.categoryId,
  });

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? requesterId;

  List<int> receiverId;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? categoryId;

  @override
  bool operator ==(Object other) => identical(this, other) || other is CategoryInviteReqDto &&
    other.requesterId == requesterId &&
    _deepEquality.equals(other.receiverId, receiverId) &&
    other.categoryId == categoryId;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (requesterId == null ? 0 : requesterId!.hashCode) +
    (receiverId.hashCode) +
    (categoryId == null ? 0 : categoryId!.hashCode);

  @override
  String toString() => 'CategoryInviteReqDto[requesterId=$requesterId, receiverId=$receiverId, categoryId=$categoryId]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.requesterId != null) {
      json[r'requesterId'] = this.requesterId;
    } else {
      json[r'requesterId'] = null;
    }
      json[r'receiverId'] = this.receiverId;
    if (this.categoryId != null) {
      json[r'categoryId'] = this.categoryId;
    } else {
      json[r'categoryId'] = null;
    }
    return json;
  }

  /// Returns a new [CategoryInviteReqDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CategoryInviteReqDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "CategoryInviteReqDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "CategoryInviteReqDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return CategoryInviteReqDto(
        requesterId: mapValueOfType<int>(json, r'requesterId'),
        receiverId: json[r'receiverId'] is Iterable
            ? (json[r'receiverId'] as Iterable).cast<int>().toList(growable: false)
            : const [],
        categoryId: mapValueOfType<int>(json, r'categoryId'),
      );
    }
    return null;
  }

  static List<CategoryInviteReqDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CategoryInviteReqDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CategoryInviteReqDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CategoryInviteReqDto> mapFromJson(dynamic json) {
    final map = <String, CategoryInviteReqDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CategoryInviteReqDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CategoryInviteReqDto-objects as value to a dart map
  static Map<String, List<CategoryInviteReqDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<CategoryInviteReqDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CategoryInviteReqDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}

