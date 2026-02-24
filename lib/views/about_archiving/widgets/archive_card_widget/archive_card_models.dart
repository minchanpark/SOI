/// 모델: 카테고리 프로필 행 데이터
/// 카테고리 프로필 행에 표시할 사용자 프로필 URL 키 목록과 총 사용자 수를 포함합니다.
/// ApiArchiveCardWidget 및 ApiArchiveProfileRowWidget에서 사용됩니다.
class CategoryProfileRowData {
  final List<String> profileUrlKeys;
  final int totalUserCount;

  const CategoryProfileRowData({
    required this.profileUrlKeys,
    required this.totalUserCount,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryProfileRowData &&
          runtimeType == other.runtimeType &&
          totalUserCount == other.totalUserCount &&
          _listEquals(profileUrlKeys, other.profileUrlKeys);

  @override
  int get hashCode =>
      Object.hash(totalUserCount, Object.hashAll(profileUrlKeys));

  // 리스트가 동일한지 비교하는 헬퍼 메서드
  static bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
