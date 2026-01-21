import 'dart:io';

import 'package:flutter/foundation.dart' hide Category;
import 'package:soi_api_client/api.dart';

import '../api_client.dart';
import '../api_exception.dart';
import '../models/models.dart';

/// 카테고리 초대 상태
///
/// 카테고리 초대에 대한 응답 상태입니다.
enum CategoryInviteStatus {
  /// 대기 중
  pending('PENDING'),

  /// 수락됨
  accepted('ACCEPTED'),

  /// 거절됨
  declined('DECLINED'),

  /// 만료됨
  expired('EXPIRED');

  final String value;
  const CategoryInviteStatus(this.value);
}

/// 카테고리 관련 API 래퍼 서비스
///
/// 카테고리 생성, 조회, 초대 관리 등 카테고리 관련 기능을 제공합니다.
/// Provider를 통해 주입받아 사용합니다.
///
/// 사용 예시:
/// ```dart
/// final categoryService = Provider.of<CategoryService>(context, listen: false);
///
/// // 카테고리 생성
/// final categoryId = await categoryService.createCategory(
///   requesterId: 1,
///   name: '우리 그룹',
///   receiverIds: [2, 3, 4],
///   isPublic: true,
/// );
///
/// // 카테고리 목록 조회
/// final categories = await categoryService.getCategories(
///   userId: 1,
///   filter: CategoryFilter.all,
/// );
/// ```
class CategoryService {
  final CategoryAPIApi _categoryApi;

  CategoryService({CategoryAPIApi? categoryApi})
    : _categoryApi = categoryApi ?? SoiApiClient.instance.categoryApi;

  // ============================================
  // 카테고리 생성
  // ============================================

  /// 카테고리 생성
  ///
  /// 새로운 카테고리(앨범)를 생성합니다.
  ///
  /// Parameters:
  /// - [requesterId]: 생성 요청자 ID
  /// - [name]: 카테고리 이름
  /// - [receiverIds]: 초대할 사용자 ID 목록
  /// - [isPublic]: 공개 여부 (true: 그룹, false: 개인)
  ///
  /// Returns: 생성된 카테고리 ID (int)
  ///
  /// Throws:
  /// - [BadRequestException]: 필수 정보 누락
  /// - [SoiApiException]: 카테고리 생성 실패
  Future<int> createCategory({
    required int requesterId,
    required String name,
    List<int> receiverIds = const [],
    bool isPublic = true,
  }) async {
    try {
      final dto = CategoryCreateReqDto(
        requesterId: requesterId,
        name: name,
        receiverIds: receiverIds,
        isPublic: isPublic,
      );

      final response = await _categoryApi.create3(dto);

      if (response == null) {
        throw const DataValidationException(message: '카테고리 생성 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '카테고리 생성 실패');
      }

      if (response.data == null) {
        throw const DataValidationException(message: '생성된 카테고리 ID가 없습니다.');
      }

      return response.data!;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '카테고리 생성 실패: $e', originalException: e);
    }
  }

  // ============================================
  // 카테고리 조회
  // ============================================

  /// 사용자의 카테고리 목록 조회
  ///
  /// [userId]가 속한 카테고리 목록을 조회합니다.
  ///
  /// Parameters:
  /// - [userId]: 사용자 ID
  /// - [filter]: 카테고리 필터 (ALL, PUBLIC, PRIVATE)
  ///
  /// Returns: 카테고리 목록 (List<Category>)
  Future<List<Category>> getCategories({
    required int userId,
    CategoryFilter filter = CategoryFilter.all,
    int page = 0,
    bool fetchAllPages = true,
    int maxPages = 50,
  }) async {
    try {
      if (!fetchAllPages) {
        final response = await _categoryApi.getCategories(
          filter.value,
          userId,
          page: page,
        );

        if (response == null) {
          return [];
        }

        if (response.success != true) {
          throw SoiApiException(message: response.message ?? '카테고리 목록 조회 실패');
        }

        return response.data.map((dto) => Category.fromDto(dto)).toList();
      }

      final allCategories = <Category>[];
      final seenIds = <int>{};
      var currentPage = page;
      var pagesFetched = 0;

      while (pagesFetched < maxPages) {
        final response = await _categoryApi.getCategories(
          filter.value,
          userId,
          page: currentPage,
        );

        if (response == null) {
          break;
        }

        if (response.success != true) {
          throw SoiApiException(message: response.message ?? '카테고리 목록 조회 실패');
        }

        final pageItems = response.data
            .map((dto) => Category.fromDto(dto))
            .toList();
        if (pageItems.isEmpty) {
          break;
        }

        var addedCount = 0;
        for (final item in pageItems) {
          if (seenIds.add(item.id)) {
            allCategories.add(item);
            addedCount++;
          }
        }

        // 서버가 같은 페이지를 반복해서 반환할 경우 무한 루프 방지
        if (addedCount == 0) {
          break;
        }

        currentPage++;
        pagesFetched++;
      }

      return allCategories;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '카테고리 목록 조회 실패: $e', originalException: e);
    }
  }

  /// 전체 카테고리 조회 (편의 메서드)
  Future<List<Category>> getAllCategories(int userId) async {
    return getCategories(userId: userId, filter: CategoryFilter.all);
  }

  /// 공개(그룹) 카테고리만 조회 (편의 메서드)
  Future<List<Category>> getPublicCategories(int userId) async {
    return getCategories(userId: userId, filter: CategoryFilter.public_);
  }

  /// 비공개(개인) 카테고리만 조회 (편의 메서드)
  Future<List<Category>> getPrivateCategories(int userId) async {
    return getCategories(userId: userId, filter: CategoryFilter.private_);
  }

  // ============================================
  // 카테고리 고정
  // ============================================

  /// 카테고리 고정/고정해제 토글
  ///
  /// [categoryId]를 [userId]에 대해 고정하거나 고정 해제합니다.
  ///
  /// Returns:
  /// - true: 고정됨
  /// - false: 고정 해제됨
  Future<bool> toggleCategoryPin({
    required int categoryId,
    required int userId,
  }) async {
    try {
      final response = await _categoryApi.categoryPinned(categoryId, userId);

      if (response == null) {
        throw const DataValidationException(message: '카테고리 고정 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '카테고리 고정 변경 실패');
      }

      return response.data ?? false;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '카테고리 고정 변경 실패: $e', originalException: e);
    }
  }

  // ============================================
  // 카테고리 알림 설정
  // ============================================

  /// 카테고리 알림 설정
  ///
  /// [categoryId]에 대한 [userId]의 알림 상태를 설정합니다.
  ///
  /// Returns:
  /// - true: 알림 설정됨
  /// - false: 알림 해제됨
  Future<bool> setCategoryAlert({
    required int categoryId,
    required int userId,
  }) async {
    try {
      final response = await _categoryApi.categoryAlert(categoryId, userId);

      if (response == null) {
        throw const DataValidationException(message: '카테고리 알림 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '카테고리 알림 설정 실패');
      }

      return response.data ?? false;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '카테고리 알림 설정 실패: $e', originalException: e);
    }
  }

  // ============================================
  // 카테고리 초대
  // ============================================

  /// 카테고리에 사용자 초대
  ///
  /// 기존 카테고리에 새로운 사용자를 초대합니다.
  ///
  /// Parameters:
  /// - [categoryId]: 카테고리 ID
  /// - [requesterId]: 초대 요청자 ID
  /// - [receiverIds]: 초대받을 사용자 ID 목록
  ///
  /// Returns: 초대 성공 여부
  Future<bool> inviteUsersToCategory({
    required int categoryId,
    required int requesterId,
    required List<int> receiverIds,
  }) async {
    try {
      final dto = CategoryInviteReqDto(
        categoryId: categoryId,
        requesterId: requesterId,
        receiverId: receiverIds,
      );

      final response = await _categoryApi.inviteUser(dto);

      if (response == null) {
        throw const DataValidationException(message: '초대 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '사용자 초대 실패');
      }

      return response.data ?? false;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '사용자 초대 실패: $e', originalException: e);
    }
  }

  /// 카테고리 초대 응답
  ///
  /// 받은 초대에 대해 수락/거절 응답을 합니다.
  ///
  /// Parameters:
  /// - [categoryId]: 카테고리 ID
  /// - [userId]: 초대받은 사용자 ID
  /// - [status]: 응답 상태 (ACCEPTED, DECLINED 등)
  ///
  /// Returns: 응답 처리 성공 여부
  Future<bool> respondToInvite({
    required int categoryId,
    required int userId,
    required CategoryInviteStatus status,
  }) async {
    try {
      final dto = CategoryInviteResponseReqDto(
        categoryId: categoryId,
        responserId: userId,
        status: _toCategoryInviteStatusEnum(status),
      );

      final response = await _categoryApi.inviteResponse(dto);

      if (response == null) {
        throw const DataValidationException(message: '초대 응답 처리 결과가 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '초대 응답 처리 실패');
      }

      return response.data ?? false;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '초대 응답 처리 실패: $e', originalException: e);
    }
  }

  /// 카테고리 초대 수락 (편의 메서드)
  Future<bool> acceptInvite({
    required int categoryId,
    required int userId,
  }) async {
    return respondToInvite(
      categoryId: categoryId,
      userId: userId,
      status: CategoryInviteStatus.accepted,
    );
  }

  /// 카테고리 초대 거절 (편의 메서드)
  Future<bool> declineInvite({
    required int categoryId,
    required int userId,
  }) async {
    return respondToInvite(
      categoryId: categoryId,
      userId: userId,
      status: CategoryInviteStatus.declined,
    );
  }

  // ============================================
  // 카테고리 설정 (이름, 프로필)
  // ============================================

  /// 카테고리 커스텀 이름 수정
  ///
  /// 카테고리의 사용자별 커스텀 이름을 수정합니다.
  /// 빈 문자열("")을 전달하면 커스텀 이름이 삭제되고 원래 이름으로 돌아갑니다.
  ///
  /// Parameters:
  /// - [categoryId]: 카테고리 ID
  /// - [userId]: 사용자 ID
  /// - [name]: 새로운 커스텀 이름 (빈 문자열이면 커스텀 이름 삭제)
  ///
  /// Returns: 수정 성공 여부
  Future<bool> updateCustomName({
    required int categoryId,
    required int userId,
    String? name,
  }) async {
    try {
      final response = await _categoryApi.customName(
        categoryId,
        userId,
        name: name,
      );

      if (response == null) {
        throw const DataValidationException(message: '카테고리 이름 수정 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '카테고리 이름 수정 실패');
      }

      return response.data ?? false;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '카테고리 이름 수정 실패: $e', originalException: e);
    }
  }

  /// 카테고리 커스텀 프로필 이미지 수정
  ///
  /// 카테고리의 사용자별 커스텀 프로필 이미지를 수정합니다.
  /// 빈 문자열("")을 전달하면 기본 프로필로 변경됩니다.
  ///
  /// Parameters:
  /// - [categoryId]: 카테고리 ID
  /// - [userId]: 사용자 ID
  /// - [profileImageKey]: 새로운 프로필 이미지 키 (빈 문자열이면 기본 프로필)
  ///
  /// Returns: 수정 성공 여부
  Future<bool> updateCustomProfile({
    required int categoryId,
    required int userId,
    String? profileImageKey,
  }) async {
    try {
      final response = await _categoryApi.customProfile(
        categoryId,
        userId,
        profileImageKey: profileImageKey,
      );

      if (response == null) {
        throw const DataValidationException(message: '카테고리 프로필 수정 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '카테고리 프로필 수정 실패');
      }

      return response.data ?? false;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(
        message: '카테고리 프로필 수정 실패: $e',
        originalException: e,
      );
    }
  }

  // ============================================
  // 카테고리 삭제 (나가기)
  // ============================================

  /// 카테고리 나가기 (삭제)
  ///
  /// 카테고리에서 나갑니다.
  /// 만약 카테고리에 속한 유저가 본인밖에 없으면 관련 데이터가 모두 삭제됩니다.
  ///
  /// Parameters:
  /// - [userId]: 사용자 ID
  /// - [categoryId]: 카테고리 ID
  ///
  /// Returns: 삭제/나가기 성공 여부
  Future<bool> leaveCategory({
    required int userId,
    required int categoryId,
  }) async {
    try {
      // API 호출 - 카테고리 나가기
      final response = await _categoryApi.delete(userId, categoryId);

      if (response == null) {
        throw const DataValidationException(message: '카테고리 나가기 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '카테고리 나가기 실패');
      }

      return true;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '카테고리 나가기 실패: $e', originalException: e);
    }
  }

  /// 카테고리 삭제 (leaveCategory의 별칭)
  Future<bool> deleteCategory({
    required int userId,
    required int categoryId,
  }) async {
    return leaveCategory(userId: userId, categoryId: categoryId);
  }

  // ============================================
  // 에러 핸들링 헬퍼
  // ============================================

  SoiApiException _handleApiException(ApiException e) {
    debugPrint('🔴 API Error [${e.code}]: ${e.message}');

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
          message: e.message ?? '카테고리를 찾을 수 없습니다.',
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

  /// CategoryInviteStatus를 API enum으로 변환
  CategoryInviteResponseReqDtoStatusEnum? _toCategoryInviteStatusEnum(
    CategoryInviteStatus status,
  ) {
    switch (status) {
      case CategoryInviteStatus.pending:
        return CategoryInviteResponseReqDtoStatusEnum.PENDING;
      case CategoryInviteStatus.accepted:
        return CategoryInviteResponseReqDtoStatusEnum.ACCEPTED;
      case CategoryInviteStatus.declined:
        return CategoryInviteResponseReqDtoStatusEnum.DECLINED;
      case CategoryInviteStatus.expired:
        return CategoryInviteResponseReqDtoStatusEnum.EXPIRED;
    }
  }
}
