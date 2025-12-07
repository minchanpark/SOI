import 'package:flutter/material.dart';

import '../models/category.dart';

/// REST API용 카테고리 검색 컨트롤러
///
/// CategoryController가 내려주는 카테고리 리스트를 클라이언트에서
/// 필터링하여 UI에 제공한다. Firebase 버전의 검색 로직을 참고해
/// 한글 초성/영문 약어 검색도 지원한다.
class CategorySearchController extends ChangeNotifier {
  String _searchQuery = '';
  List<Category> _filteredCategories = [];
  CategoryFilter _activeFilter = CategoryFilter.all;

  String get searchQuery => _searchQuery;
  List<Category> get filteredCategories => List.unmodifiable(_filteredCategories);
  CategoryFilter get activeFilter => _activeFilter;

  /// 주어진 [categories] 리스트를 기준으로 검색어를 적용한다.
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
      if (category.nickNames.any((nick) => _matchesSearch(nick, _searchQuery))) {
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

  bool _matchesSearch(String text, String query) {
    if (text.isEmpty || query.isEmpty) return false;
    if (text.toLowerCase().contains(query.toLowerCase())) return true;
    if (_matchesChosung(text, query)) return true;
    return _matchesAcronym(text, query);
  }

  bool _matchesChosung(String text, String query) {
    try {
      final textChosung = _extractChosung(text);
      final queryChosung = _extractChosung(query);
      return textChosung.contains(queryChosung);
    } catch (_) {
      return false;
    }
  }

  bool _matchesAcronym(String text, String query) {
    final words = text.split(' ');
    final initials = words.map((word) => word.isNotEmpty ? word[0] : '').join();
    return initials.toLowerCase().contains(query.toLowerCase());
  }

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
    'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ',
    'ㅅ', 'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ',
  ];
}
