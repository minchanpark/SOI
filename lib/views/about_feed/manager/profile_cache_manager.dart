import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../api/controller/user_controller.dart';
import '../../../api/models/user.dart' as api_user;

class ProfileCacheManager {
  final Map<String, String> _userProfileImages = {};
  final Map<String, String> _userNames = {};
  final Map<String, bool> _loadingStates = {};

  VoidCallback? _onStateChanged;

  Map<String, String> get userProfileImages => _userProfileImages;
  Map<String, String> get userNames => _userNames;
  Map<String, bool> get loadingStates => _loadingStates;

  void setOnStateChanged(VoidCallback? callback) {
    _onStateChanged = callback;
  }

  void _notifyStateChanged() {
    _onStateChanged?.call();
  }

  Future<void> loadCurrentUserProfile(UserController userController) async {
    final currentUser = userController.currentUser;
    if (currentUser == null) return;
    final key = currentUser.userId;
    if (_userProfileImages.containsKey(key)) return;

    _userProfileImages[key] = currentUser.profileImageUrlKey ?? '';
    _userNames[key] = currentUser.userId;
    _loadingStates[key] = false;
    _notifyStateChanged();
  }

  Future<void> loadUserProfileForPost(
    String userNickname,
    BuildContext context,
  ) async {
    if (_loadingStates[userNickname] == true || _userNames.containsKey(userNickname)) {
      return;
    }

    _loadingStates[userNickname] = true;
    _notifyStateChanged();

    try {
      final userController = Provider.of<UserController>(
        context,
        listen: false,
      );
      api_user.User? user;
      final numericId = int.tryParse(userNickname);
      if (numericId != null) {
        user = await userController.getUser(numericId);
      } else {
        user = await userController.getUserByNickname(userNickname);
      }

      _userProfileImages[userNickname] = user?.profileImageUrlKey ?? '';
      _userNames[userNickname] = user?.userId ?? userNickname;
      _loadingStates[userNickname] = false;
      _notifyStateChanged();
    } catch (e) {
      debugPrint('[ProfileCacheManager] 사용자 정보 로드 실패: $e');
      _userNames[userNickname] = userNickname;
      _loadingStates[userNickname] = false;
      _notifyStateChanged();
    }
  }

  Future<void> refreshUserProfileImage(
    String userNickname,
    BuildContext context,
  ) async {
    final userController = Provider.of<UserController>(context, listen: false);
    try {
      _loadingStates[userNickname] = true;
      _notifyStateChanged();

      api_user.User? user;
      final numericId = int.tryParse(userNickname);
      if (numericId != null) {
        user = await userController.getUser(numericId);
      } else {
        user = await userController.getUserByNickname(userNickname);
      }
      _userProfileImages[userNickname] = user?.profileImageUrlKey ?? '';
      _userNames[userNickname] = user?.userId ?? userNickname;
      _loadingStates[userNickname] = false;
      _notifyStateChanged();
    } catch (e) {
      _loadingStates[userNickname] = false;
      _notifyStateChanged();
    }
  }

  void dispose() {
    _userProfileImages.clear();
    _userNames.clear();
    _loadingStates.clear();
  }
}
