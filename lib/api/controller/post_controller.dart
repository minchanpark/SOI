import 'package:flutter/material.dart';

import '../models/models.dart';

/// 게시물 컨트롤러 추상 클래스
///
/// 게시물 관련 기능을 정의하는 인터페이스입니다.
/// 구현체를 교체하여 테스트나 다른 백엔드 사용이 가능합니다.
///
/// 사용 예시:
/// ```dart
/// final postController = Provider.of<PostController>(context, listen: false);
///
/// // 게시물 생성
/// final success = await postController.createPost(
///   userId: 'user123',
///   content: '오늘의 일상',
///   postFileKey: 'images/photo.jpg',
///   categoryIds: [1, 2],
/// );
///
/// // 메인 피드 조회
/// final posts = await postController.getMainFeedPosts(userId: 1);
/// ```
abstract class PostController extends ChangeNotifier {
  /// 로딩 상태
  bool get isLoading;

  /// 에러 메시지
  String? get errorMessage;

  // ============================================
  // 게시물 생성
  // ============================================

  /// 게시물 생성
  ///
  /// 새로운 게시물(사진 + 음성메모)을 생성합니다.
  ///
  /// Parameters:
  /// - [userId]: 작성자 사용자 ID (String)
  /// - [content]: 게시물 내용 (선택)
  /// - [postFileKey]: 이미지 파일 키
  /// - [audioFileKey]: 음성 파일 키 (선택)
  /// - [categoryIds]: 게시할 카테고리 ID 목록
  /// - [waveformData]: 음성 파형 데이터 (선택)
  /// - [duration]: 음성 길이 (선택)
  ///
  /// Returns: 생성 성공 여부
  Future<bool> createPost({
    required String userId,
    String? content,
    String? postFileKey,
    String? audioFileKey,
    List<int> categoryIds = const [],
    String? waveformData,
    int? duration,
  });

  // ============================================
  // 게시물 조회
  // ============================================

  /// 메인 피드 게시물 조회
  ///
  /// [userId]가 속한 모든 카테고리의 게시물을 조회합니다.
  /// 메인 페이지에 표시할 피드용입니다.
  ///
  /// Returns: 게시물 목록 (List<Post>)
  Future<List<Post>> getMainFeedPosts({required int userId});

  /// 카테고리별 게시물 조회
  ///
  /// 특정 카테고리에 속한 게시물만 조회합니다.
  ///
  /// Parameters:
  /// - [categoryId]: 카테고리 ID
  /// - [userId]: 요청 사용자 ID (권한 확인용)
  ///
  /// Returns: 게시물 목록 (List<Post>)
  Future<List<Post>> getPostsByCategory({
    required int categoryId,
    required int userId,
  });

  /// 게시물 상세 조회
  ///
  /// [postId]에 해당하는 게시물의 상세 정보를 조회합니다.
  ///
  /// Returns: 게시물 정보 (Post)
  Future<Post?> getPostDetail(int postId);

  // ============================================
  // 게시물 수정
  // ============================================

  /// 게시물 수정
  ///
  /// 기존 게시물의 내용을 수정합니다.
  ///
  /// Parameters:
  /// - [postId]: 수정할 게시물 ID
  /// - [content]: 변경할 내용 (선택)
  /// - [postFileKey]: 변경할 이미지 키 (선택)
  /// - [audioFileKey]: 변경할 음성 키 (선택)
  /// - [categoryIds]: 변경할 카테고리 목록 (선택)
  /// - [waveformData]: 변경할 파형 데이터 (선택)
  /// - [duration]: 변경할 음성 길이 (선택)
  ///
  /// Returns: 수정 성공 여부
  Future<bool> updatePost({
    required int postId,
    String? content,
    String? postFileKey,
    String? audioFileKey,
    List<int>? categoryIds,
    String? waveformData,
    int? duration,
  });

  // ============================================
  // 게시물 삭제
  // ============================================

  /// 게시물 삭제
  ///
  /// [postId]에 해당하는 게시물을 삭제합니다.
  /// 삭제된 게시물은 휴지통으로 이동됩니다.
  ///
  /// Returns: 삭제 성공 여부
  Future<bool> deletePost(int postId);

  // ============================================
  // 에러 처리
  // ============================================

  /// 에러 초기화
  void clearError();
}
