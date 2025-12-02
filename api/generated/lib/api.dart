//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

library openapi.api;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

part 'api_client.dart';
part 'api_helper.dart';
part 'api_exception.dart';
part 'auth/authentication.dart';
part 'auth/api_key_auth.dart';
part 'auth/oauth.dart';
part 'auth/http_basic_auth.dart';
part 'auth/http_bearer_auth.dart';

part 'api/api_api.dart';
part 'api/category_api_api.dart';
part 'api/comment_api_api.dart';
part 'api/friend_api_api.dart';
part 'api/notification_api_api.dart';
part 'api/post_api_api.dart';
part 'api/user_api_api.dart';

part 'model/api_response_dto_boolean.dart';
part 'model/api_response_dto_friend_resp_dto.dart';
part 'model/api_response_dto_list_category_resp_dto.dart';
part 'model/api_response_dto_list_comment_resp_dto.dart';
part 'model/api_response_dto_list_friend_check_resp_dto.dart';
part 'model/api_response_dto_list_notification_resp_dto.dart';
part 'model/api_response_dto_list_post_resp_dto.dart';
part 'model/api_response_dto_list_string.dart';
part 'model/api_response_dto_list_user_find_resp_dto.dart';
part 'model/api_response_dto_list_user_resp_dto.dart';
part 'model/api_response_dto_long.dart';
part 'model/api_response_dto_notification_get_all_resp_dto.dart';
part 'model/api_response_dto_object.dart';
part 'model/api_response_dto_post_resp_dto.dart';
part 'model/api_response_dto_user_resp_dto.dart';
part 'model/auth_check_req_dto.dart';
part 'model/category_create_req_dto.dart';
part 'model/category_invite_req_dto.dart';
part 'model/category_invite_response_req_dto.dart';
part 'model/category_resp_dto.dart';
part 'model/comment_req_dto.dart';
part 'model/comment_resp_dto.dart';
part 'model/friend_check_resp_dto.dart';
part 'model/friend_create_req_dto.dart';
part 'model/friend_req_dto.dart';
part 'model/friend_resp_dto.dart';
part 'model/friend_update_resp_dto.dart';
part 'model/notification_get_all_resp_dto.dart';
part 'model/notification_resp_dto.dart';
part 'model/post_create_req_dto.dart';
part 'model/post_resp_dto.dart';
part 'model/post_update_req_dto.dart';
part 'model/user_create_req_dto.dart';
part 'model/user_find_resp_dto.dart';
part 'model/user_resp_dto.dart';
part 'model/user_update_req_dto.dart';


/// An [ApiClient] instance that uses the default values obtained from
/// the OpenAPI specification file.
var defaultApiClient = ApiClient();

const _delimiters = {'csv': ',', 'ssv': ' ', 'tsv': '\t', 'pipes': '|'};
const _dateEpochMarker = 'epoch';
const _deepEquality = DeepCollectionEquality();
final _dateFormatter = DateFormat('yyyy-MM-dd');
final _regList = RegExp(r'^List<(.*)>$');
final _regSet = RegExp(r'^Set<(.*)>$');
final _regMap = RegExp(r'^Map<String,(.*)>$');

bool _isEpochMarker(String? pattern) => pattern == _dateEpochMarker || pattern == '/$_dateEpochMarker/';
