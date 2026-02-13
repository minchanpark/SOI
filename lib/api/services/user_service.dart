import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:soi_api_client/api.dart';

import '../api_client.dart';
import '../api_exception.dart';
import '../models/models.dart';

/// 사용자 및 인증 관련 API 래퍼 서비스
///
/// SMS 인증, 로그인, 사용자 생성/조회/수정/삭제 등 사용자 관련 기능을 제공합니다.
/// Provider를 통해 주입받아 사용합니다.
///
/// 사용 예시:
/// ```dart
/// final userService = Provider.of<UserService>(context, listen: false);
///
/// // SMS 인증 발송
/// final success = await userService.sendSmsVerification('01012345678');
///
/// // 인증 코드 확인
/// final verified = await userService.verifySmsCode('01012345678', '123456');
///
/// // 로그인
/// final user = await userService.loginWithPhone('01012345678');
///
/// // 사용자 생성
/// final user = await userService.createUser(
///   name: '홍길동',
///   nickName: 'hong123',
///   phoneNum: '01012345678',
///   birthDate: '1990-01-01',
/// );
///
/// // 사용자 조회
/// final user = await userService.getUser(1);
///
/// // 사용자 ID 중복 확인
/// final isAvailable = await userService.checknickNameAvailable('hong123');
/// ```
class UserService {
  final UserAPIApi _userApi;

  UserService({UserAPIApi? userApi})
    : _userApi = userApi ?? SoiApiClient.instance.userApi;

  // ============================================
  // SMS 인증
  // ============================================

  /// SMS 인증 코드 발송
  ///
  /// [phoneNum]으로 SMS 인증 코드를 발송합니다.
  /// 성공 시 true 반환, 실패 시 예외를 throw합니다.
  ///
  /// Throws:
  /// - [NetworkException]: 네트워크 연결 실패
  /// - [BadRequestException]: 잘못된 전화번호 형식
  /// - [SoiApiException]: 기타 API 에러
  Future<bool> sendSmsVerification(String phoneNum) async {
    try {
      final result = await _userApi.authSMS(phoneNum);
      return result ?? false;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      throw SoiApiException(message: 'SMS 인증 발송 실패: $e', originalException: e);
    }
  }

  /// SMS 인증 코드 확인
  ///
  /// [phoneNum]과 [code]로 SMS 인증을 확인합니다.
  /// 성공 시 true 반환, 실패 시 예외를 throw합니다.
  ///
  /// Throws:
  /// - [NetworkException]: 네트워크 연결 실패
  /// - [BadRequestException]: 잘못된 인증 코드
  /// - [SoiApiException]: 기타 API 에러
  Future<bool> verifySmsCode(String phoneNum, String code) async {
    try {
      final dto = AuthCheckReqDto(phoneNum: phoneNum, code: code);
      final result = await _userApi.checkAuthSMS(dto);
      return result ?? false;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      throw SoiApiException(message: '인증 코드 확인 실패: $e', originalException: e);
    }
  }

  // ============================================
  // 로그인
  // ============================================

  /// 닉네임(ID)으로 로그인
  ///
  /// [nickName]으로 로그인합니다.
  /// 성공 시 사용자 정보(User) 반환, 실패 시 예외를 throw합니다.
  ///
  /// 반환값:
  /// - 기존 회원: User (사용자 정보)
  /// - 신규 회원: null (회원가입 필요)
  ///
  /// Throws:
  /// - [NetworkException]: 네트워크 연결 실패
  /// - [NotFoundException]: 등록되지 않은 닉네임
  /// - [SoiApiException]: 기타 API 에러
  Future<User?> loginWithNickname(String nickName) async {
    try {
      final response = await _userApi.loginByNickname(nickName);

      if (response == null) {
        return null;
      }

      // ApiResponseDto 언래핑
      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '로그인 실패');
      }

      if (response.data == null) {
        return null;
      }

      return User.fromDto(response.data!);
    } on ApiException catch (e) {
      // 404는 신규 회원을 의미할 수 있음
      if (e.code == 404) {
        return null;
      }
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '로그인 실패: $e', originalException: e);
    }
  }

  /// 전화번호로 로그인
  ///
  /// SMS 인증이 완료된 [phoneNum]으로 로그인합니다.
  /// 성공 시 사용자 정보(User) 반환, 실패 시 예외를 throw합니다.
  ///
  /// 반환값:
  /// - 기존 회원: User (사용자 정보)
  /// - 신규 회원: null (회원가입 필요)
  ///
  /// Throws:
  /// - [NetworkException]: 네트워크 연결 실패
  /// - [NotFoundException]: 등록되지 않은 전화번호
  /// - [SoiApiException]: 기타 API 에러
  Future<User?> loginWithPhone(String phoneNum) async {
    try {
      final response = await _userApi.loginByPhone(phoneNum);

      if (response == null) {
        return null;
      }

      // ApiResponseDto 언래핑
      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '로그인 실패');
      }

      if (response.data == null) {
        return null;
      }

      return User.fromDto(response.data!);
    } on ApiException catch (e) {
      // 404는 신규 회원을 의미할 수 있음
      if (e.code == 404) {
        return null;
      }
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '로그인 실패: $e', originalException: e);
    }
  }

  // ============================================
  // 사용자 생성
  // ============================================

  /// 새 사용자 생성 (회원가입)
  ///
  /// 필수 정보를 입력받아 새 사용자를 생성합니다.
  ///
  /// Parameters:
  /// - [name]: 사용자 이름
  /// - [nickName]: 사용자 아이디 (고유)
  /// - [phoneNum]: 전화번호
  /// - [birthDate]: 생년월일 (yyyy-MM-dd 형식)
  /// - [profileImage]: 프로필 이미지 URL (선택)
  /// - [serviceAgreed]: 서비스 약관 동의 여부
  /// - [privacyPolicyAgreed]: 개인정보 처리방침 동의 여부
  /// - [marketingAgreed]: 마케팅 수신 동의 여부 (선택)
  ///
  /// Returns: 생성된 사용자 정보 (User)
  ///
  /// Throws:
  /// - [BadRequestException]: 필수 정보 누락 또는 잘못된 형식
  /// - [SoiApiException]: 이미 존재하는 아이디/전화번호
  Future<User> createUser({
    required String name,
    required String nickName,
    required String phoneNum,
    required String birthDate,
    String? profileImageKey,
    bool serviceAgreed = true,
    bool privacyPolicyAgreed = true,
    bool marketingAgreed = false,
  }) async {
    try {
      final dto = UserCreateReqDto(
        name: name,
        nickname: nickName,
        phoneNum: phoneNum,
        birthDate: birthDate,
        profileImageKey: profileImageKey ?? '', // null 대신 빈 문자열 전송
        serviceAgreed: serviceAgreed,
        privacyPolicyAgreed: privacyPolicyAgreed,
        marketingAgreed: marketingAgreed,
      );

      final response = await _userApi.createUser(dto);

      if (response == null) {
        throw const DataValidationException(message: '사용자 생성 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '사용자 생성 실패');
      }

      if (response.data == null) {
        throw const DataValidationException(message: '생성된 사용자 정보가 없습니다.');
      }

      return User.fromDto(response.data!);
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '사용자 생성 실패: $e', originalException: e);
    }
  }

  // ============================================
  // 사용자 조회
  // ============================================

  /// ID로 사용자 조회
  ///
  /// [id]에 해당하는 사용자 정보를 조회합니다.
  ///
  /// Returns: 사용자 정보 (User)
  ///
  /// Throws:
  /// - [NotFoundException]: 해당 ID의 사용자가 없음
  Future<User> getUser(int id) async {
    try {
      final response = await _userApi.getUser(id);

      if (response == null) {
        throw const NotFoundException(message: '사용자를 찾을 수 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '사용자 조회 실패');
      }

      if (response.data == null) {
        throw const NotFoundException(message: '사용자 정보가 없습니다.');
      }

      return User.fromDto(response.data!);
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '사용자 조회 실패: $e', originalException: e);
    }
  }

  /// 모든 사용자 조회
  ///
  /// 등록된 모든 사용자 목록을 조회합니다.
  /// (주의: 대량 데이터 조회 시 성능 이슈 가능)
  ///
  /// Returns: 사용자 목록 (List<User>)
  Future<List<User>> getAllUsers() async {
    try {
      final response = await _userApi.getAllUsers();

      if (response == null) {
        return [];
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '사용자 목록 조회 실패');
      }

      return response.data.map((dto) => User.fromFindDto(dto)).toList();
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '사용자 목록 조회 실패: $e', originalException: e);
    }
  }

  /// 키워드로 사용자 검색
  ///
  /// [keyword]가 포함된 nickName를 가진 사용자를 검색합니다.
  ///
  /// Returns: 검색된 사용자 목록 (List<User>)
  Future<List<User>> findUsersByKeyword(String keyword) async {
    try {
      final response = await _userApi.findUser(keyword);

      if (response == null) {
        return [];
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '사용자 검색 실패');
      }

      return response.data.map((dto) => User.fromDto(dto)).toList();
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '사용자 검색 실패: $e', originalException: e);
    }
  }

  // ============================================
  // 사용자 ID 중복 확인
  // ============================================

  /// 사용자 ID 중복 확인
  ///
  /// [nickName]가 사용 가능한지 확인합니다.
  ///
  /// Returns:
  /// - true: 사용 가능
  /// - false: 이미 사용 중 (중복)
  Future<bool> checknickNameAvailable(String nickName) async {
    try {
      final response = await _userApi.idCheck(nickName);

      if (response == null) {
        return false;
      }

      if (response.success != true) {
        return false;
      }

      return response.data ?? false;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: 'ID 중복 확인 실패: $e', originalException: e);
    }
  }

  // ============================================
  // 사용자 정보 수정
  // ============================================

  /// 사용자 정보 수정
  ///
  /// 사용자의 기본 정보를 수정합니다.
  ///
  /// Parameters:
  /// - [id]: 사용자 고유 ID
  /// - [name]: 변경할 이름 (선택)
  /// - [nickName]: 변경할 아이디 (선택)
  /// - [phoneNum]: 변경할 전화번호 (선택)
  /// - [birthDate]: 변경할 생년월일 (선택)
  /// - [profileImageKey]: 변경할 프로필 이미지 키 (선택)
  ///
  /// Returns: 수정된 사용자 정보 (User)
  Future<User> updateUser({
    required int id,
    String? name,
    String? nickName,
    String? phoneNum,
    String? birthDate,
    String? profileImageKey,
  }) async {
    try {
      final dto = UserUpdateReqDto(
        id: id,
        name: name,
        nickname: nickName,
        phoneNum: phoneNum,
        birthDate: birthDate,
        profileImageKey: profileImageKey,
      );

      final response = await _userApi.update1(dto);

      if (response == null) {
        throw const DataValidationException(message: '사용자 수정 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '사용자 정보 수정 실패');
      }

      if (response.data == null) {
        throw const DataValidationException(message: '수정된 사용자 정보가 없습니다.');
      }

      return User.fromDto(response.data!);
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '사용자 정보 수정 실패: $e', originalException: e);
    }
  }

  /// 프로필 이미지 수정
  ///
  /// [userId]의 프로필 이미지를 [profileImageKey] URL로 수정합니다.
  ///
  /// Returns: 수정된 사용자 정보 (User)
  Future<User> updateProfileImage({
    required int userId,
    required String profileImageKey,
  }) async {
    try {
      final response = await _userApi.updateProfile(
        userId,
        profileImageKey: profileImageKey,
      );

      if (response == null) {
        throw const DataValidationException(message: '프로필 수정 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '프로필 이미지 수정 실패');
      }

      if (response.data == null) {
        throw const DataValidationException(message: '수정된 사용자 정보가 없습니다.');
      }

      return User.fromDto(response.data!);
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '프로필 이미지 수정 실패: $e', originalException: e);
    }
  }

  // ============================================
  // 사용자 삭제
  // ============================================

  /// 사용자 삭제 (회원탈퇴)
  ///
  /// [id]에 해당하는 사용자를 삭제합니다.
  ///
  /// Returns: 삭제된 사용자 정보 (User)
  ///
  /// Throws:
  /// - [NotFoundException]: 해당 ID의 사용자가 없음
  Future<User> deleteUser(int id) async {
    try {
      final response = await _userApi.deleteUser(id);

      if (response == null) {
        throw const DataValidationException(message: '사용자 삭제 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '사용자 삭제 실패');
      }

      if (response.data == null) {
        throw const DataValidationException(message: '삭제된 사용자 정보가 없습니다.');
      }

      return User.fromDto(response.data!);
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '사용자 삭제 실패: $e', originalException: e);
    }
  }

  // ============================================
  // 에러 핸들링 헬퍼
  // ============================================

  SoiApiException _handleApiException(ApiException e) {
    debugPrint('API Error [${e.code}]: ${e.message}');

    if (_isTransportFailure(e.message)) {
      return NetworkException(
        message: '네트워크 연결을 확인해주세요.',
        originalException: e,
      );
    }

    switch (e.code) {
      case 400:
        return BadRequestException(
          message: e.message ?? '잘못된 요청입니다.',
          originalException: e,
        );
      case 401:
        return AuthException(
          message: e.message ?? '인증이 필요합니다.',
          originalException: e,
        );
      case 403:
        return ForbiddenException(
          message: e.message ?? '접근 권한이 없습니다.',
          originalException: e,
        );
      case 404:
        return NotFoundException(
          message: e.message ?? '사용자를 찾을 수 없습니다.',
          originalException: e,
        );
      case >= 500:
        return ServerException(
          statusCode: e.code,
          message: e.message ?? '서버 오류가 발생했습니다.',
          originalException: e,
        );
      default:
        return SoiApiException(
          statusCode: e.code,
          message: e.message ?? '알 수 없는 오류가 발생했습니다.',
          originalException: e,
        );
    }
  }

  bool _isTransportFailure(String? message) {
    if (message == null) return false;
    final normalized = message.toLowerCase();
    return normalized.contains('socket operation failed') ||
        normalized.contains('tls/ssl communication failed') ||
        normalized.contains('http connection failed') ||
        normalized.contains('i/o operation failed');
  }
}
