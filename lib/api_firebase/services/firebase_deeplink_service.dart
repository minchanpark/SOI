import 'package:flutter/material.dart';

/// Firebase 기반 딥링크 서비스
/// Firebase Hosting을 사용한 간단한 딥링크 시스템
class FirebaseDeeplinkService {
  static const String _baseUrl = 'https://soi-sns.web.app';

  /// 친구 초대 링크 생성
  static String createFriendInviteLink({
    required String inviterName,
    required String inviterId,

    String? inviterProfileImage,
  }) {
    try {
      debugPrint('Creating friend invite link with Firebase Hosting...');
      debugPrint('- Inviter: $inviterName ($inviterId)');

      // Firebase Hosting을 사용한 간단한 URL 생성
      final params =
          Uri(
            queryParameters: {
              'inviter': inviterName,
              'inviterId': inviterId,
              'auto': '1', // 자동으로 앱 열기 시도
            },
          ).query;

      final shareUrl = '$_baseUrl/invite.html?$params';

      debugPrint('Friend invite link created: $shareUrl');
      return shareUrl;
    } catch (e) {
      debugPrint('Friend invite link error: $e');
      rethrow;
    }
  }

  /// 사진 공유 링크 생성 (향후 확장용)
  static String createPhotoShareLink({
    required String photoId,
    required String categoryName,
    String? userDisplayName,
  }) {
    final params =
        Uri(
          queryParameters: {
            'type': 'photo',
            'photoId': photoId,
            'category': categoryName,
            'user': userDisplayName ?? 'user',
          },
        ).query;

    return '$_baseUrl/share.html?$params';
  }

  /// 카테고리 공유 링크 생성 (향후 확장용)
  static String createCategoryShareLink({
    required String categoryId,
    required String categoryName,
    required int photoCount,
  }) {
    final params =
        Uri(
          queryParameters: {
            'type': 'category',
            'categoryId': categoryId,
            'name': categoryName,
            'count': photoCount.toString(),
          },
        ).query;

    return '$_baseUrl/album.html?$params';
  }

  /// 프로필 공유 링크 생성 (향후 확장용)
  static String createProfileShareLink({
    required String userId,
    required String userName,
    String? profileImageUrl,
  }) {
    final params =
        Uri(
          queryParameters: {
            'type': 'profile',
            'userId': userId,
            'name': userName,
            if (profileImageUrl != null) 'image': profileImageUrl,
          },
        ).query;

    return '$_baseUrl/profile.html?$params';
  }
}
