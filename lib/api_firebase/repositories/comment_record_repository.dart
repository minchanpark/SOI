import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'; // debugPrint를 위한 import
import 'package:flutter/painting.dart'; // Offset를 위한 import
import '../models/comment_record_model.dart';

class CommentRecordRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const String _collectionName = 'comment_records';
  static const String _storagePath = 'comment_records';

  /// 음성 댓글을 Firebase Storage에 업로드하고 Firestore에 저장
  Future<CommentRecordModel> createCommentRecord({
    required String audioFilePath,
    required String photoId,
    required String recorderUser,
    required List<double> waveformData,
    required int duration,
    required String profileImageUrl, // 프로필 이미지 URL 추가
    Offset? relativePosition, // 프로필 이미지 상대 위치 (새로운 방식)
  }) async {
    try {
      // 1. Firebase Storage에 음성 파일 업로드
      final audioUrl = await _uploadAudioFile(
        audioFilePath,
        photoId,
        recorderUser,
      );

      // 2. CommentRecord 객체 생성
      final commentRecord = CommentRecordModel(
        id: '', // Firestore에서 자동 생성됨
        audioUrl: audioUrl,
        photoId: photoId,
        recorderUser: recorderUser,
        createdAt: DateTime.now(),
        waveformData: waveformData,
        duration: duration,
        isDeleted: false,
        profileImageUrl: profileImageUrl, // 전달받은 프로필 이미지 URL 사용
        relativePosition: relativePosition, // 상대 위치 추가 (새로운 방식)
      );

      // 3. Firestore에 저장
      final docRef = await _firestore
          .collection(_collectionName)
          .add(commentRecord.toFirestore());

      // 4. ID가 포함된 객체 반환
      return commentRecord.copyWith(id: docRef.id);
    } catch (e) {
      throw Exception('음성 댓글 저장 실패: $e');
    }
  }

  /// 텍스트 댓글을 Firestore에 저장
  Future<CommentRecordModel> createTextComment({
    required String text,
    required String photoId,
    required String recorderUser,
    required String profileImageUrl,
    Offset? relativePosition,
  }) async {
    try {
      // CommentRecord 객체 생성 (텍스트 댓글)
      final commentRecord = CommentRecordModel(
        id: '', // Firestore에서 자동 생성됨
        audioUrl: '', // 텍스트 댓글은 오디오 없음
        photoId: photoId,
        recorderUser: recorderUser,
        createdAt: DateTime.now(),
        waveformData: [], // 텍스트 댓글은 파형 데이터 없음
        duration: 0, // 텍스트 댓글은 재생 시간 없음
        isDeleted: false,
        profileImageUrl: profileImageUrl,
        relativePosition: relativePosition,
        type: CommentType.text, // 텍스트 댓글 타입 지정
        text: text, // 텍스트 내용
      );

      // Firestore에 저장
      final docRef = await _firestore
          .collection(_collectionName)
          .add(commentRecord.toFirestore());

      // ID가 포함된 객체 반환
      return commentRecord.copyWith(id: docRef.id);
    } catch (e) {
      throw Exception('텍스트 댓글 저장 실패: $e');
    }
  }

  /// Firebase Storage에 오디오 파일 업로드
  Future<String> _uploadAudioFile(
    String filePath,
    String photoId,
    String recorderUser,
  ) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('음성 파일이 존재하지 않습니다: $filePath');
      }

      // 🔍 파일 업로드 전 로그
      debugPrint('📤 Firebase Storage 업로드 시작');
      debugPrint('  - 로컬 파일 경로: $filePath');
      debugPrint('  - 파일 크기: ${await file.length()} bytes');

      // 고유한 파일명 생성
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${photoId}_${recorderUser}_$timestamp.aac';
      final storageRef = _storage.ref().child('$_storagePath/$fileName');

      debugPrint('  - 생성된 파일명: $fileName');
      debugPrint('  - Storage 경로: $_storagePath/$fileName');

      // 메타데이터 설정
      final metadata = SettableMetadata(
        contentType: 'audio/aac',
        customMetadata: {
          'photoId': photoId,
          'recorderUser': recorderUser,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      // 파일 업로드
      final uploadTask = storageRef.putFile(file, metadata);
      final snapshot = await uploadTask;

      // 다운로드 URL 반환
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('✅ Firebase Storage 업로드 완료');
      debugPrint('  - 다운로드 URL: $downloadUrl');

      return downloadUrl;
    } catch (e) {
      throw Exception('음성 파일 업로드 실패: $e');
    }
  }

  /// 특정 사진의 음성 댓글들 조회
  Future<List<CommentRecordModel>> getCommentRecordsByPhotoId(
    String photoId,
  ) async {
    try {
      // debugPrint('🔍 Firestore 쿼리 시작 - photoId: $photoId');

      final querySnapshot =
          await _firestore
              .collection(_collectionName)
              .where('photoId', isEqualTo: photoId)
              .where('isDeleted', isEqualTo: false)
              .orderBy('createdAt', descending: false)
              .get();

      // debugPrint('✅ Firestore 쿼리 성공 - 문서 수: ${querySnapshot.docs.length}');

      final results =
          querySnapshot.docs.map((doc) {
            try {
              final comment = CommentRecordModel.fromFirestore(doc);
              debugPrint(
                '📄 댓글 조회됨 - ID: ${comment.id}, audioUrl: ${comment.audioUrl}',
              );
              return comment;
            } catch (e) {
              debugPrint('❌ 문서 파싱 실패 - ID: ${doc.id}, 오류: $e');
              rethrow;
            }
          }).toList();

      // debugPrint('✅ 모든 문서 파싱 완료 - 결과 수: ${results.length}');
      return results;
    } catch (e) {
      // debugPrint('❌ Firestore 쿼리 실패 - photoId: $photoId');
      // debugPrint('🔍 오류 타입: ${e.runtimeType}');
      // debugPrint('🔍 오류 메시지: ${e.toString()}');

      if (e.toString().contains('PERMISSION_DENIED')) {
        // debugPrint('🚫 권한 거부됨 - Firestore 보안 규칙을 확인하세요');
      } else if (e.toString().contains('FAILED_PRECONDITION')) {
        // debugPrint('📊 인덱스 없음 - Firestore 인덱스를 생성하세요');
      }

      throw Exception('음성 댓글 조회 실패: $e');
    }
  }

  /// 음성 댓글 삭제 (soft delete)
  Future<void> deleteCommentRecord(String commentId) async {
    try {
      await _firestore.collection(_collectionName).doc(commentId).update({
        'isDeleted': true,
      });
    } catch (e) {
      throw Exception('음성 댓글 삭제 실패: $e');
    }
  }

  /// 음성 댓글 하드 삭제 (Firestore 문서 + Storage 파일 실제 삭제)
  ///
  /// UI에서는 즉시 제거(optimistic) 후, 백그라운드에서 실행하도록 사용할 수 있음.
  Future<void> hardDeleteCommentRecord(String commentId) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc(commentId);
      final snapshot = await docRef.get();
      if (!snapshot.exists) return; // 이미 없음

      String audioUrl = '';
      try {
        final data = snapshot.data() as Map<String, dynamic>;
        audioUrl = data['audioUrl'] as String? ?? '';
      } catch (_) {}

      // 1) Storage 파일 삭제 (파일 없거나 권한 문제면 무시)
      if (audioUrl.isNotEmpty) {
        try {
          final ref = _storage.refFromURL(audioUrl);
          await ref.delete();
        } catch (e) {
          debugPrint('⚠️ Storage 파일 삭제 실패(무시): $e');
        }
      }

      // 2) Firestore 문서 삭제
      await docRef.delete();
    } catch (e) {
      throw Exception('음성 댓글 하드 삭제 실패: $e');
    }
  }

  /// 음성 댓글 수정
  Future<CommentRecordModel> updateCommentRecord(
    CommentRecordModel commentRecord,
  ) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(commentRecord.id)
          .update(commentRecord.toFirestore());

      return commentRecord;
    } catch (e) {
      throw Exception('음성 댓글 수정 실패: $e');
    }
  }

  /// 사용자별 음성 댓글들 조회
  Future<List<CommentRecordModel>> getCommentRecordsByUser(
    String userId,
  ) async {
    try {
      final querySnapshot =
          await _firestore
              .collection(_collectionName)
              .where('recorderUser', isEqualTo: userId)
              .where('isDeleted', isEqualTo: false)
              .orderBy('createdAt', descending: true)
              .get();

      return querySnapshot.docs
          .map((doc) => CommentRecordModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('사용자 음성 댓글 조회 실패: $e');
    }
  }

  /// 실시간 음성 댓글 스트림 (특정 사진)
  Stream<List<CommentRecordModel>> getCommentRecordsStream(String photoId) {
    return _firestore
        .collection(_collectionName)
        .where('photoId', isEqualTo: photoId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => CommentRecordModel.fromFirestore(doc))
                  .toList(),
        );
  }

  /// 프로필 이미지 위치 업데이트 (상대 좌표)
  Future<void> updateRelativeProfilePosition({
    required String commentId,
    required Offset relativePosition,
  }) async {
    try {
      await _firestore.collection(_collectionName).doc(commentId).update({
        'relativePosition': {
          'x': relativePosition.dx,
          'y': relativePosition.dy,
        },
      });
    } catch (e) {
      throw Exception('상대 프로필 위치 업데이트 실패: $e');
    }
  }

  /// 프로필 이미지 위치 업데이트 (기존 절대 좌표 - 하위호환성)
  Future<void> updateProfilePosition({
    required String commentId,
    required Offset profilePosition,
  }) async {
    try {
      await _firestore.collection(_collectionName).doc(commentId).update({
        'profilePosition': {'dx': profilePosition.dx, 'dy': profilePosition.dy},
      });
    } catch (e) {
      throw Exception('프로필 위치 업데이트 실패: $e');
    }
  }

  /// 특정 사용자의 모든 음성 댓글의 프로필 이미지 URL 업데이트
  Future<void> updateUserProfileImageUrl({
    required String userId,
    required String newProfileImageUrl,
  }) async {
    try {
      // debugPrint('🔄 사용자 음성 댓글 프로필 이미지 URL 업데이트 시작 - userId: $userId');

      // 해당 사용자의 모든 음성 댓글 조회
      final querySnapshot =
          await _firestore
              .collection(_collectionName)
              .where('recorderUser', isEqualTo: userId)
              .where('isDeleted', isEqualTo: false)
              .get();

      if (querySnapshot.docs.isEmpty) {
        // debugPrint('📝 업데이트할 음성 댓글이 없습니다 - userId: $userId');
        return;
      }

      // 배치 업데이트 사용 (성능 최적화)
      final batch = _firestore.batch();

      for (final doc in querySnapshot.docs) {
        batch.update(doc.reference, {'profileImageUrl': newProfileImageUrl});
      }

      // 배치 실행
      await batch.commit();
    } catch (e) {
      // debugPrint('❌ 사용자 음성 댓글 프로필 이미지 URL 업데이트 실패: $e');
      throw Exception('사용자 음성 댓글 프로필 이미지 URL 업데이트 실패: $e');
    }
  }
}
