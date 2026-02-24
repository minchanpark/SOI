import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/api_exception.dart';
import 'package:soi/api/services/user_service.dart';
import 'package:soi_api_client/api.dart';

class _FakeUserApi extends UserAPIApi {
  _FakeUserApi({this.onLoginByNickname, this.onLoginByPhone});

  final Future<ApiResponseDtoUserRespDto?> Function(String)? onLoginByNickname;
  final Future<ApiResponseDtoUserRespDto?> Function(String)? onLoginByPhone;

  @override
  Future<ApiResponseDtoUserRespDto?> loginByNickname(String nickName) async {
    final handler = onLoginByNickname;
    if (handler == null) {
      throw UnimplementedError('onLoginByNickname is not configured');
    }
    return handler(nickName);
  }

  @override
  Future<ApiResponseDtoUserRespDto?> loginByPhone(String phoneNum) async {
    final handler = onLoginByPhone;
    if (handler == null) {
      throw UnimplementedError('onLoginByPhone is not configured');
    }
    return handler(phoneNum);
  }
}

void main() {
  group('UserService login error mapping', () {
    test(
      'maps socket transport ApiException(400) to NetworkException',
      () async {
        final service = UserService(
          userApi: _FakeUserApi(
            onLoginByNickname: (_) async => throw ApiException(
              400,
              'Socket operation failed: POST /user/login/by-nickname',
            ),
          ),
        );

        expect(
          service.loginWithNickname('minchan'),
          throwsA(isA<NetworkException>()),
        );
      },
    );

    test('returns null for nickname login when API responds 404', () async {
      final service = UserService(
        userApi: _FakeUserApi(
          onLoginByNickname: (_) async => throw ApiException(404, 'not found'),
        ),
      );

      final result = await service.loginWithNickname('unknown');
      expect(result, isNull);
    });

    test('returns null for phone login when API responds 404', () async {
      final service = UserService(
        userApi: _FakeUserApi(
          onLoginByPhone: (_) async => throw ApiException(404, 'not found'),
        ),
      );

      final result = await service.loginWithPhone('01000000000');
      expect(result, isNull);
    });
  });
}
