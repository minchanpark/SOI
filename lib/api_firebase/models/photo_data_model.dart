import 'package:cloud_firestore/cloud_firestore.dart';

/// 사진 데이터 모델 (순수 데이터 클래스)
class MediaDataModel {
  final String id; // 사진 문서 ID
  final String imageUrl; // 사진 URL
  final String audioUrl; // 사진을 올릴 때, 함께 올린 음성 URL
  final String userID; // 사진을 올린 사용자 UID
  final List<String> userIds; // 사진에 태그된 사용자 UIDs
  final String categoryId; // 사진이 속한 카테고리 ID
  final DateTime createdAt; // 사진 업로드 시간
  final PhotoStatus status; // 사진 상태
  final List<double>? waveformData; // 실제 오디오 파형 데이터 추가
  final Duration duration; // 음성 길이 (초 단위) 추가
  final bool unactive; // 사용자 비활성화 상태
  final DateTime? deletedAt; // 삭제된 시간 (30일 후 영구 삭제를 위해)
  final String? caption; // 게시글 텍스트
  final bool isVideo; // 비디오 여부
  final String? videoUrl; // 비디오 URL
  final String? thumbnailUrl; // 썸네일 URL
  final bool isFromCamera; // 카메라 촬영 여부

  MediaDataModel({
    required this.id,
    required this.imageUrl,
    required this.audioUrl,
    required this.userID,
    required this.userIds,
    required this.categoryId,
    required this.createdAt,
    this.status = PhotoStatus.active,
    this.waveformData, // 파형 데이터 추가
    this.duration = const Duration(seconds: 0), // 기본값 0초
    this.unactive = false, // 기본값 false
    this.deletedAt, // 삭제 시간
    this.caption, // 게시글
    this.isVideo = false, // 기본값 false
    this.videoUrl, // 비디오 URL
    this.thumbnailUrl, // 썸네일 URL
    this.isFromCamera = false, // 카메라 촬영 여부 (기본값: 갤러리)
  });

  // Firestore에서 데이터를 가져올 때 사용
  factory MediaDataModel.fromFirestore(Map<String, dynamic> data, String id) {
    // waveformData 타입 캐스팅 처리
    List<double>? waveformData;
    if (data['waveformData'] != null) {
      final dynamic waveformRaw = data['waveformData'];

      if (waveformRaw is List) {
        try {
          waveformData = waveformRaw.map((e) => (e as num).toDouble()).toList();
        } catch (e) {
          waveformData = null;
        }
      }
    }

    return MediaDataModel(
      id: id,
      imageUrl: data['imageUrl'] ?? '',
      audioUrl: data['audioUrl'] ?? '',
      userID: data['userID'] ?? '',
      userIds: (data['userIds'] as List?)?.cast<String>() ?? [],
      categoryId: data['categoryId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: PhotoStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => PhotoStatus.active,
      ),
      waveformData: waveformData, // 파형 데이터 추가
      duration: Duration(seconds: (data['duration'] ?? 0) as int), // 음성 길이 추가
      unactive: data['unactive'] ?? false, // 사용자 비활성화 상태 추가
      deletedAt: (data['deletedAt'] as Timestamp?)?.toDate(), // 삭제 시간 추가
      caption: data['caption'] as String?, // 게시글 추가
      isVideo: data['isVideo'] ?? false, // 비디오 여부
      videoUrl: data['videoUrl'] as String?, // 비디오 URL
      thumbnailUrl: data['thumbnailUrl'] as String?, // 썸네일 URL
      isFromCamera: data['isFromCamera'] ?? false, // 카메라 촬영 여부
    );
  }

  // Firestore에 저장할 때 사용
  Map<String, dynamic> toFirestore() {
    final Map<String, dynamic> data = {
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'userID': userID,
      'userIds': userIds,
      'categoryId': categoryId,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status.name,
      'duration': duration.inSeconds, // 음성 길이 추가 (초 단위로 저장)
      'unactive': unactive, // 사용자 비활성화 상태 추가
      'isVideo': isVideo, // 비디오 여부 추가
      'isFromCamera': isFromCamera, // 카메라 촬영 여부 추가
    };

    // caption이 있을 때만 추가
    if (caption != null && caption!.isNotEmpty) {
      data['caption'] = caption;
    }

    // waveformData가 있을 때만 추가
    if (waveformData != null) {
      data['waveformData'] = waveformData;
    }

    // deletedAt이 있을 때만 추가
    if (deletedAt != null) {
      data['deletedAt'] = Timestamp.fromDate(deletedAt!);
    }

    // videoUrl이 있을 때만 추가
    if (videoUrl != null && videoUrl!.isNotEmpty) {
      data['videoUrl'] = videoUrl;
    }

    // thumbnailUrl이 있을 때만 추가
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      data['thumbnailUrl'] = thumbnailUrl;
    }

    return data;
  }

  // 기존 PhotoModel 호환성을 위한 getter
  String get getPhotoId => id;

  /// 음성이 있는지 확인
  bool get hasAudio => audioUrl.isNotEmpty && duration > Duration.zero;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaDataModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// 사진 상태 열거형
enum PhotoStatus {
  active, // 활성 상태
  archived, // 아카이브됨
  deleted, // 삭제됨
  reported, // 신고됨
  processing, // 처리 중
}

/// 사진 업로드 결과
class PhotoUploadResult {
  final bool isSuccess;
  final String? photoId;
  final String? imageUrl;
  final String? audioUrl;
  final String? error;

  PhotoUploadResult({
    required this.isSuccess,
    this.photoId,
    this.imageUrl,
    this.audioUrl,
    this.error,
  });

  factory PhotoUploadResult.success({
    required String photoId,
    required String imageUrl,
    String? audioUrl,
  }) {
    return PhotoUploadResult(
      isSuccess: true,
      photoId: photoId,
      imageUrl: imageUrl,
      audioUrl: audioUrl,
    );
  }

  factory PhotoUploadResult.failure(String error) {
    return PhotoUploadResult(isSuccess: false, error: error);
  }
}
