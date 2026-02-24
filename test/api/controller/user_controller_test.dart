import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/api_exception.dart';
import 'package:soi/api/controller/user_controller.dart';
import 'package:soi/api/models/user.dart';
import 'package:soi/api/services/user_service.dart';
import 'package:soi_api_client/api.dart';

class _NoopUserApi extends UserAPIApi {}

class _FakeUserService extends UserService {
  _FakeUserService({this.onLoginWithNickname, this.onLoginWithPhone})
    : super(userApi: _NoopUserApi());

  final Future<User?> Function(String)? onLoginWithNickname;
  final Future<User?> Function(String)? onLoginWithPhone;

  @override
  Future<User?> loginWithNickname(String nickName) async {
    final handler = onLoginWithNickname;
    if (handler == null) {
      throw UnimplementedError('onLoginWithNickname is not configured');
    }
    return handler(nickName);
  }

  @override
  Future<User?> loginWithPhone(String phoneNum) async {
    final handler = onLoginWithPhone;
    if (handler == null) {
      throw UnimplementedError('onLoginWithPhone is not configured');
    }
    return handler(phoneNum);
  }
}

void main() {
  group('UserController login error handling', () {
    test('returns null when nickname login throws NotFoundException', () async {
      final controller = UserController(
        userService: _FakeUserService(
          onLoginWithNickname: (_) async =>
              throw const NotFoundException(message: 'not found'),
        ),
      );

      final result = await controller.loginWithNickname('unknown');
      expect(result, isNull);
      expect(controller.currentUser, isNull);
    });

    test(
      'rethrows NetworkException when phone login fails by network',
      () async {
        final controller = UserController(
          userService: _FakeUserService(
            onLoginWithPhone: (_) async =>
                throw const NetworkException(message: 'network down'),
          ),
        );

        try {
          await controller.login('01011112222');
          fail('Expected NetworkException to be thrown');
        } on NetworkException {
          expect(controller.errorMessage, contains('로그인 실패'));
        }
      },
    );
  });
}
