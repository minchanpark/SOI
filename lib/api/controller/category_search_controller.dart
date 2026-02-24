import 'package:flutter/material.dart';

import '../models/category.dart';

/// REST API용 카테고리 검색 컨트롤러
///
/// CategoryController가 내려주는 카테고리 리스트를 클라이언트에서
/// 필터링하여 UI에 제공한다. Firebase 버전의 검색 로직을 참고해
/// 한글 초성/영문 약어 검색도 지원한다.
class CategorySearchController extends ChangeNotifier {
  // 현재 검색어, 필터링된 카테고리 리스트, 활성화된 필터 상태
  String _searchQuery = ''; // 현재 검색어
  List<Category> _filteredCategories = []; // 필터링된 카테고리 리스트
  CategoryFilter _activeFilter = CategoryFilter.all; // 활성화된 필터 상태

  String get searchQuery => _searchQuery; // 현재 검색어를 getter로 제공
  List<Category> get filteredCategories =>
      List.unmodifiable(_filteredCategories); // 필터링된 카테고리 리스트를 읽기 전용으로 제공
  CategoryFilter get activeFilter => _activeFilter; // 활성화된 필터 상태를 getter로 제공

  /// 주어진 [categories] 리스트를 기준으로 검색어를 적용한다.
  ///
  /// Parameters:
  ///   - [categories]: 검색 대상이 되는 카테고리 리스트
  ///   - [query]: 검색어
  ///   - [filter]: 적용할 카테고리 필터 (기본값: CategoryFilter.all)
  void searchCategories(
    List<Category> categories,
    String query, {
    CategoryFilter filter = CategoryFilter.all,
  }) {
    _searchQuery = query.trim();
    _activeFilter = filter;

    if (_searchQuery.isEmpty) {
      _filteredCategories = [];
      notifyListeners();
      return;
    }

    _filteredCategories = categories.where((category) {
      if (_matchesSearch(category.name, _searchQuery)) return true;
      if (category.nickNames.any(
        (nick) => _matchesSearch(nick, _searchQuery),
      )) {
        return true;
      }
      return false;
    }).toList();
    notifyListeners();
  }

  /// 검색 상태를 초기화한다.
  void clearSearch({bool notify = true}) {
    _searchQuery = '';
    _filteredCategories = [];
    if (notify) {
      notifyListeners();
    }
  }

  /// 카테고리 이름이나 닉네임이 검색어와 일치하는지 확인한다.
  ///
  /// Parameters:
  ///   - [text]: 카테고리 이름 또는 닉네임
  ///   - [query]: 검색어
  ///
  /// Returns:
  ///   - true: 일치하는 경우
  ///   - false: 일치하지 않는 경우
  bool _matchesSearch(String text, String query) {
    if (text.isEmpty || query.isEmpty) return false;
    if (text.toLowerCase().contains(query.toLowerCase())) return true;
    if (_matchesChosung(text, query)) return true;
    return _matchesAcronym(text, query);
  }

  /// 한글 초성 매칭 확인
  ///
  /// Parameters:
  ///   - [text]: 카테고리 이름 또는 닉네임
  ///   - [query]: 검색어
  ///
  /// Returns:
  ///   - true: 초성이 일치하는 경우
  ///   - false: 일치하지 않는 경우
  bool _matchesChosung(String text, String query) {
    try {
      final textChosung = _extractChosung(text);
      final queryChosung = _extractChosung(query);
      return textChosung.contains(queryChosung);
    } catch (_) {
      return false;
    }
  }

  /// 영문 약어 매칭 확인
  ///
  /// Parameters:
  ///   - [text]: 카테고리 이름 또는 닉네임
  ///   - [query]: 검색어
  ////
  /// Returns:
  ///   - true: 약어가 일치하는 경우
  ///   - false: 일치하지 않는 경우
  bool _matchesAcronym(String text, String query) {
    final words = text.split(' ');
    final initials = words.map((word) => word.isNotEmpty ? word[0] : '').join();
    return initials.toLowerCase().contains(query.toLowerCase());
  }

  /// 한글 초성 추출
  ///
  /// Parameters:
  ///   - [text]: 카테고리 이름 또는 닉네임
  ///
  /// Returns:
  ///   - 초성 문자열
  String _extractChosung(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      if (rune >= 0xAC00 && rune <= 0xD7A3) {
        final index = rune - 0xAC00;
        final chosungIndex = index ~/ (21 * 28);
        buffer.write(_chosungMap[chosungIndex]);
      } else {
        buffer.write(String.fromCharCode(rune));
      }
    }
    return buffer.toString();
  }

  static const List<String> _chosungMap = [
    'ㄱ',
    'ㄲ',
    'ㄴ',
    'ㄷ',
    'ㄸ',
    'ㄹ',
    'ㅁ',
    'ㅂ',
    'ㅃ',
    'ㅅ',
    'ㅆ',
    'ㅇ',
    'ㅈ',
    'ㅉ',
    'ㅊ',
    'ㅋ',
    'ㅌ',
    'ㅍ',
    'ㅎ',
  ];
}
