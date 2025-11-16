import 'package:flutter/material.dart';
import 'package:soi/api_firebase/controllers/auth_controller.dart';
import 'package:provider/provider.dart';
import 'package:soi/api_firebase/controllers/category_member_controller.dart';
import '../../../api_firebase/controllers/category_controller.dart';
import '../../../api_firebase/models/category_data_model.dart';

/// ⚡ 아카이브 카테고리 액션 처리 클래스
/// 카테고리 관련 비즈니스 로직을 담당합니다.
class ArchiveCategoryActions {
  // 카테고리 고정/해제 토글
  static Future<void> handleTogglePinCategory(
    BuildContext context,
    CategoryDataModel category,
  ) async {
    try {
      final categoryController = Provider.of<CategoryController>(
        context,
        listen: false,
      );

      // AuthService에서 현재 사용자 UID 가져오기
      final authController = AuthController();
      final currentUserId = authController.getUserId;

      if (currentUserId == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('사용자 정보를 찾을 수 없습니다.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // 현재 사용자의 고정 상태 확인
      final currentPinStatus = category.isPinnedForUser(currentUserId);

      await categoryController.togglePinCategory(
        category.id,
        currentUserId,
        currentPinStatus,
      );

      if (context.mounted) {
        final message = currentPinStatus
            ? '카테고리 고정이 해제되었습니다.'
            : '카테고리가 상단에 고정되었습니다.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: const Color(0xFF323232),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // 카테고리 고정 변경 실패

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('카테고리 고정 변경에 실패했습니다.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // 카테고리 이름 업데이트 (관리자용 - 모든 사용자에게 적용)
  static Future<void> updateCategoryName(
    BuildContext context,
    CategoryDataModel category,
    String newName,
  ) async {
    try {
      final categoryController = Provider.of<CategoryController>(
        context,
        listen: false,
      );

      // 카테고리 이름 업데이트
      await categoryController.updateCategory(
        categoryId: category.id,
        name: newName,
      );

      // 성공 피드백
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('카테고리 이름이 "$newName"으로 변경되었습니다.'),
            backgroundColor: const Color(0xFF323232),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // 카테고리 이름 변경 실패

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('카테고리 이름 변경에 실패했습니다.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 🔄 사용자별 카테고리 커스텀 이름 업데이트
  static Future<void> updateCustomCategoryName(
    BuildContext context,
    CategoryDataModel category,
    String customName,
  ) async {
    try {
      final categoryController = Provider.of<CategoryController>(
        context,
        listen: false,
      );

      // AuthService에서 현재 사용자 UID 가져오기
      final authController = AuthController();
      final currentUserId = authController.getUserId;

      if (currentUserId == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('사용자 정보를 찾을 수 없습니다.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // 사용자별 커스텀 이름 업데이트
      await categoryController.updateCustomCategoryName(
        categoryId: category.id,
        userId: currentUserId,
        customName: customName,
      );

      // 성공 피드백
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('내 카테고리 이름이 "$customName"으로 변경되었습니다.'),
            backgroundColor: const Color(0xFF323232),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // 커스텀 이름 변경 실패

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('카테고리 이름 변경에 실패했습니다.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 카테고리 나가기 실행
  static Future<void> leaveCategoryConfirmed(
    BuildContext context,
    CategoryDataModel category,
  ) async {
    // 위젯이 여전히 활성 상태인지 확인
    if (!context.mounted) {
      // 위젯이 이미 dispose되어 카테고리 나가기 중단
      return;
    }

    try {
      final categoryController = Provider.of<CategoryMemberController>(
        context,
        listen: false,
      );

      // AuthService에서 현재 사용자 UID 가져오기
      final authController = AuthController();
      final currentUserId = authController.getUserId;

      if (currentUserId == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('사용자 정보를 찾을 수 없습니다.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // 비동기 작업 전에 mounted 체크
      if (!context.mounted) return;

      await categoryController.leaveCategoryByUid(category.id, currentUserId);

      // 비동기 작업 후에도 mounted 체크
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${category.name}" 카테고리에서 나갔습니다.'),
            backgroundColor: const Color(0xFF323232),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // 카테고리 나가기 실패

      // 에러 처리 시에도 mounted 체크
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('카테고리 나가기에 실패했습니다.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
