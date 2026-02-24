/// SOI API 래퍼 레이어 - 커스텀 예외 클래스
///
/// 이 파일은 API 호출 중 발생하는 다양한 에러 상황을 처리하기 위한
/// 커스텀 예외 클래스들을 정의합니다.
///
/// 사용 예시:
/// ```dart
/// try {
///   final user = await userService.getUser(1);
/// } on SoiApiException catch (e) {
///   print('API 에러: ${e.message}');
/// } on NetworkException catch (e) {
///   print('네트워크 에러: ${e.message}');
/// }
/// ```

/// SOI API 기본 예외 클래스
///
/// 모든 API 관련 예외의 기본 클래스입니다.
/// [statusCode]는 HTTP 상태 코드, [message]는 에러 메시지입니다.
class SoiApiException implements Exception {
  /// HTTP 상태 코드 (예: 400, 401, 500)
  final int? statusCode;

  /// 에러 메시지
  final String message;

  /// 원본 예외 (디버깅용)
  final dynamic originalException;

  const SoiApiException({
    this.statusCode,
    required this.message,
    this.originalException,
  });

  @override
  String toString() {
    if (statusCode != null) {
      return 'SoiApiException [$statusCode]: $message';
    }
    return 'SoiApiException: $message';
  }
}

/// 네트워크 연결 관련 예외
///
/// 인터넷 연결 실패, 타임아웃 등 네트워크 관련 에러에 사용됩니다.
class NetworkException extends SoiApiException {
  const NetworkException({
    String message = '네트워크 연결을 확인해주세요.',
    dynamic originalException,
  }) : super(message: message, originalException: originalException);

  @override
  String toString() => 'NetworkException: $message';
}

/// 인증 관련 예외 (401 Unauthorized)
///
/// 로그인이 필요하거나 토큰이 만료된 경우 발생합니다.
class AuthException extends SoiApiException {
  const AuthException({
    String message = '인증이 필요합니다. 다시 로그인해주세요.',
    dynamic originalException,
  }) : super(
         statusCode: 401,
         message: message,
         originalException: originalException,
       );

  @override
  String toString() => 'AuthException: $message';
}

/// 권한 부족 예외 (403 Forbidden)
///
/// 해당 리소스에 접근 권한이 없는 경우 발생합니다.
class ForbiddenException extends SoiApiException {
  const ForbiddenException({
    String message = '접근 권한이 없습니다.',
    dynamic originalException,
  }) : super(
         statusCode: 403,
         message: message,
         originalException: originalException,
       );

  @override
  String toString() => 'ForbiddenException: $message';
}

/// 리소스 없음 예외 (404 Not Found)
///
/// 요청한 리소스가 존재하지 않는 경우 발생합니다.
class NotFoundException extends SoiApiException {
  const NotFoundException({
    String message = '요청한 정보를 찾을 수 없습니다.',
    dynamic originalException,
  }) : super(
         statusCode: 404,
         message: message,
         originalException: originalException,
       );

  @override
  String toString() => 'NotFoundException: $message';
}

/// 서버 에러 예외 (5xx)
///
/// 서버 내부 에러가 발생한 경우 사용됩니다.
class ServerException extends SoiApiException {
  const ServerException({
    int statusCode = 500,
    String message = '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.',
    dynamic originalException,
  }) : super(
         statusCode: statusCode,
         message: message,
         originalException: originalException,
       );

  @override
  String toString() => 'ServerException [$statusCode]: $message';
}

/// 잘못된 요청 예외 (400 Bad Request)
///
/// 클라이언트의 요청이 잘못된 경우 발생합니다.
class BadRequestException extends SoiApiException {
  const BadRequestException({
    String message = '잘못된 요청입니다.',
    dynamic originalException,
  }) : super(
         statusCode: 400,
         message: message,
         originalException: originalException,
       );

  @override
  String toString() => 'BadRequestException: $message';
}

/// 데이터 검증 예외
///
/// 응답 데이터가 예상과 다르거나 null인 경우 발생합니다.
class DataValidationException extends SoiApiException {
  const DataValidationException({
    String message = '데이터 처리 중 오류가 발생했습니다.',
    dynamic originalException,
  }) : super(message: message, originalException: originalException);

  @override
  String toString() => 'DataValidationException: $message';
}
