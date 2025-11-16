import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../api_firebase/controllers/auth_controller.dart';

class ProfileCacheManager {
  // 프로필 정보 캐싱
  final Map<String, String> _userProfileImages = {};
  final Map<String, String> _userNames = {};
  final Map<String, bool> _loadingStates = {};

  // Getters
  Map<String, String> get userProfileImages => _userProfileImages;
  Map<String, String> get userNames => _userNames;
  Map<String, bool> get loadingStates => _loadingStates;

  // 콜백 함수들
  VoidCallback? _onStateChanged;

  void setOnStateChanged(VoidCallback? callback) {
    _onStateChanged = callback;
  }

  void _notifyStateChanged() {
    _onStateChanged?.call();
  }

  /// 현재 사용자 프로필 로드
  Future<void> loadCurrentUserProfile(
    AuthController authController,
    String currentUserId,
  ) async {
    if (!_userProfileImages.containsKey(currentUserId)) {
      try {
        final currentUserProfileImage = await authController
            .getUserProfileImageUrlWithCache(currentUserId);
        _userProfileImages[currentUserId] = currentUserProfileImage;
        _notifyStateChanged();
      } catch (e) {
        debugPrint('[ERROR] 현재 사용자 프로필 이미지 로드 실패: $e');
      }
    }
  }

  /// 특정 사용자의 프로필 정보를 로드하는 메서드
  Future<void> loadUserProfileForPhoto(
    String userId,
    BuildContext context,
  ) async {
    if (_loadingStates[userId] == true || _userNames.containsKey(userId)) {
      return;
    }

    _loadingStates[userId] = true;
    _notifyStateChanged();

    try {
      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );
      final profileImageUrl = await authController
          .getUserProfileImageUrlWithCache(userId);
      final userInfo = await authController.getUserInfo(userId);

      _userProfileImages[userId] = profileImageUrl;
      _userNames[userId] = userInfo?.id ?? userId;
      _loadingStates[userId] = false;
      _notifyStateChanged();
    } catch (e) {
      _userNames[userId] = userId;
      _loadingStates[userId] = false;
      _notifyStateChanged();
    }
  }

  /// 특정 사용자의 프로필 이미지 캐시 강제 리프레시
  Future<void> refreshUserProfileImage(
    String userId,
    BuildContext context,
  ) async {
    final authController = Provider.of<AuthController>(context, listen: false);
    try {
      _loadingStates[userId] = true;
      _notifyStateChanged();

      final profileImageUrl = await authController
          .getUserProfileImageUrlWithCache(userId);

      _userProfileImages[userId] = profileImageUrl;
      _loadingStates[userId] = false;
      _notifyStateChanged();
    } catch (e) {
      _loadingStates[userId] = false;
      _notifyStateChanged();
    }
  }

  /// AuthController 변경 감지 시 프로필 이미지 캐시 업데이트
  Future<void> onAuthControllerChanged(AuthController authController) async {
    final currentUser = authController.currentUser;
    if (currentUser != null) {
      final newProfileImageUrl = await authController
          .getUserProfileImageUrlWithCache(currentUser.uid);
      if (_userProfileImages[currentUser.uid] != newProfileImageUrl) {
        _userProfileImages[currentUser.uid] = newProfileImageUrl;
        _notifyStateChanged();
      }
    }
  }

  /// 리소스 정리
  void dispose() {
    _userProfileImages.clear();
    _userNames.clear();
    _loadingStates.clear();
  }
}
