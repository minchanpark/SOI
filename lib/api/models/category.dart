import 'package:soi_api_client/api.dart';

/// 카테고리 필터 타입
///
/// 카테고리 조회 시 필터링 옵션입니다.
enum CategoryFilter {
  /// 전체 카테고리
  all('ALL'),

  /// 공개 카테고리 (그룹)
  public_('PUBLIC'),

  /// 비공개 카테고리 (개인)
  private_('PRIVATE');

  final String value;
  const CategoryFilter(this.value);
}

/// 카테고리(앨범) 모델
///
/// API의 CategoryRespDto를 앱 내부에서 사용하기 위한 모델입니다.
class Category {
  final int id;
  final String name;
  final String? photoUrl;
  final bool isNew;
  final int totalUserCount;
  final bool isPinned;
  final List<String> usersProfile;
  final DateTime? pinnedAt;

  const Category({
    required this.id,
    required this.name,
    this.photoUrl,
    this.isNew = false,
    this.totalUserCount = 0,
    this.isPinned = false,
    this.usersProfile = const [],
    this.pinnedAt,
  });

  /// CategoryRespDto에서 Category 모델 생성
  factory Category.fromDto(CategoryRespDto dto) {
    return Category(
      id: dto.id ?? 0,
      name: dto.name ?? '',
      photoUrl: dto.categoryPhotoUrl,
      isNew: dto.isNew ?? false,
      totalUserCount: dto.totalUserNum ?? 0,
      isPinned: dto.isPinned ?? false,
      usersProfile: dto.usersProfile,
      pinnedAt: dto.pinnedAt,
    );
  }

  /// JSON에서 Category 모델 생성
  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      photoUrl: json['categoryPhotoUrl'] as String?,
      isNew: json['isNew'] as bool? ?? false,
      totalUserCount: json['totalUserNum'] as int? ?? 0,
      isPinned: json['isPinned'] as bool? ?? false,
      usersProfile:
          (json['usersProfile'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      pinnedAt: json['pinnedAt'] != null
          ? DateTime.tryParse(json['pinnedAt'] as String)
          : null,
    );
  }

  /// Category 모델을 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'categoryPhotoUrl': photoUrl,
      'isNew': isNew,
      'totalUserNum': totalUserCount,
      'isPinned': isPinned,
      'usersProfile': usersProfile,
      'pinnedAt': pinnedAt?.toIso8601String(),
    };
  }

  /// 카테고리 사진 유무 확인
  bool get hasPhoto => photoUrl != null && photoUrl!.isNotEmpty;

  /// copyWith 메서드
  Category copyWith({
    int? id,
    String? name,
    String? photoUrl,
    bool? isNew,
    int? totalUserCount,
    bool? isPinned,
    List<String>? usersProfile,
    DateTime? pinnedAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      isNew: isNew ?? this.isNew,
      totalUserCount: totalUserCount ?? this.totalUserCount,
      isPinned: isPinned ?? this.isPinned,
      usersProfile: usersProfile ?? this.usersProfile,
      pinnedAt: pinnedAt ?? this.pinnedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Category{id: $id, name: $name, totalUserCount: $totalUserCount}';
  }
}
