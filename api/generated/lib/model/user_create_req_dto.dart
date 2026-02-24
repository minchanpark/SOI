//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class UserCreateReqDto {
  /// Returns a new [UserCreateReqDto] instance.
  UserCreateReqDto({
    this.name,
    this.nickname,
    this.phoneNum,
    this.birthDate,
    this.profileImageKey,
    this.serviceAgreed,
    this.privacyPolicyAgreed,
    this.marketingAgreed,
  });

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? name;

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
  String? phoneNum;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? birthDate;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? profileImageKey;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? serviceAgreed;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? privacyPolicyAgreed;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? marketingAgreed;

  @override
  bool operator ==(Object other) => identical(this, other) || other is UserCreateReqDto &&
    other.name == name &&
    other.nickname == nickname &&
    other.phoneNum == phoneNum &&
    other.birthDate == birthDate &&
    other.profileImageKey == profileImageKey &&
    other.serviceAgreed == serviceAgreed &&
    other.privacyPolicyAgreed == privacyPolicyAgreed &&
    other.marketingAgreed == marketingAgreed;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (name == null ? 0 : name!.hashCode) +
    (nickname == null ? 0 : nickname!.hashCode) +
    (phoneNum == null ? 0 : phoneNum!.hashCode) +
    (birthDate == null ? 0 : birthDate!.hashCode) +
    (profileImageKey == null ? 0 : profileImageKey!.hashCode) +
    (serviceAgreed == null ? 0 : serviceAgreed!.hashCode) +
    (privacyPolicyAgreed == null ? 0 : privacyPolicyAgreed!.hashCode) +
    (marketingAgreed == null ? 0 : marketingAgreed!.hashCode);

  @override
  String toString() => 'UserCreateReqDto[name=$name, nickname=$nickname, phoneNum=$phoneNum, birthDate=$birthDate, profileImageKey=$profileImageKey, serviceAgreed=$serviceAgreed, privacyPolicyAgreed=$privacyPolicyAgreed, marketingAgreed=$marketingAgreed]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.name != null) {
      json[r'name'] = this.name;
    } else {
      json[r'name'] = null;
    }
    if (this.nickname != null) {
      json[r'nickname'] = this.nickname;
    } else {
      json[r'nickname'] = null;
    }
    if (this.phoneNum != null) {
      json[r'phoneNum'] = this.phoneNum;
    } else {
      json[r'phoneNum'] = null;
    }
    if (this.birthDate != null) {
      json[r'birthDate'] = this.birthDate;
    } else {
      json[r'birthDate'] = null;
    }
    if (this.profileImageKey != null) {
      json[r'profileImageKey'] = this.profileImageKey;
    } else {
      json[r'profileImageKey'] = null;
    }
    if (this.serviceAgreed != null) {
      json[r'serviceAgreed'] = this.serviceAgreed;
    } else {
      json[r'serviceAgreed'] = null;
    }
    if (this.privacyPolicyAgreed != null) {
      json[r'privacyPolicyAgreed'] = this.privacyPolicyAgreed;
    } else {
      json[r'privacyPolicyAgreed'] = null;
    }
    if (this.marketingAgreed != null) {
      json[r'marketingAgreed'] = this.marketingAgreed;
    } else {
      json[r'marketingAgreed'] = null;
    }
    return json;
  }

  /// Returns a new [UserCreateReqDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static UserCreateReqDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "UserCreateReqDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "UserCreateReqDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return UserCreateReqDto(
        name: mapValueOfType<String>(json, r'name'),
        nickname: mapValueOfType<String>(json, r'nickname'),
        phoneNum: mapValueOfType<String>(json, r'phoneNum'),
        birthDate: mapValueOfType<String>(json, r'birthDate'),
        profileImageKey: mapValueOfType<String>(json, r'profileImageKey'),
        serviceAgreed: mapValueOfType<bool>(json, r'serviceAgreed'),
        privacyPolicyAgreed: mapValueOfType<bool>(json, r'privacyPolicyAgreed'),
        marketingAgreed: mapValueOfType<bool>(json, r'marketingAgreed'),
      );
    }
    return null;
  }

  static List<UserCreateReqDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <UserCreateReqDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = UserCreateReqDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, UserCreateReqDto> mapFromJson(dynamic json) {
    final map = <String, UserCreateReqDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = UserCreateReqDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of UserCreateReqDto-objects as value to a dart map
  static Map<String, List<UserCreateReqDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<UserCreateReqDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = UserCreateReqDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}

