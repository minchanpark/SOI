/// 인증 결과를 담는 클래스
class AuthResult {
  final bool isSuccess;
  final String? error;
  final dynamic data;

  AuthResult._({required this.isSuccess, this.error, this.data});

  /// 성공 결과
  factory AuthResult.success([dynamic data]) {
    return AuthResult._(isSuccess: true, data: data);
  }

  /// 실패 결과
  factory AuthResult.failure(String error) {
    return AuthResult._(isSuccess: false, error: error);
  }
}
