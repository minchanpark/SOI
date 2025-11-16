import 'package:flutter/material.dart';
import '../models/category_data_model.dart';
import '../services/category_service.dart';

/// 카테고리 검색 및 필터링을 담당하는 컨트롤러
class CategorySearchController extends ChangeNotifier {
  final CategoryService _categoryService = CategoryService();

  String _searchQuery = '';
  List<CategoryDataModel> _filteredCategories = [];
  List<CategoryDataModel> _userCategories = [];
  bool _isLoading = false;
  String? _error;

  String get searchQuery => _searchQuery;
  List<CategoryDataModel> get filteredCategories => _filteredCategories;
  List<CategoryDataModel> get userCategoryList => _userCategories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 검색어로 카테고리 필터링 (오버로드 버전 1: 외부에서 카테고리 리스트 전달)
  void searchCategories(
    dynamic categoriesOrQuery, [
    String? query,
    String? currentUserId,
  ]) {
    // 첫 번째 파라미터가 String이면 단순 검색 (내부 카테고리 사용)
    if (categoriesOrQuery is String) {
      _searchQuery = categoriesOrQuery.trim();

      if (_searchQuery.isEmpty) {
        _filteredCategories = [];
      } else {
        _filteredCategories =
            _userCategories.where((category) {
              final displayName =
                  currentUserId != null
                      ? category.getDisplayName(currentUserId)
                      : category.name;
              return _matchesSearch(displayName, _searchQuery);
            }).toList();
      }

      notifyListeners();
      return;
    }

    // 첫 번째 파라미터가 List이면 외부 카테고리로 검색
    if (categoriesOrQuery is List<CategoryDataModel>) {
      _userCategories = categoriesOrQuery;
      _searchQuery = (query ?? '').trim();

      if (_searchQuery.isEmpty) {
        _filteredCategories = [];
      } else {
        _filteredCategories =
            _userCategories.where((category) {
              final displayName =
                  currentUserId != null
                      ? category.getDisplayName(currentUserId)
                      : category.name;
              return _matchesSearch(displayName, _searchQuery);
            }).toList();
      }

      notifyListeners();
    }
  }

  /// 카테고리 목록 업데이트 (검색 없이)
  void updateCategories(List<CategoryDataModel> categories) {
    _userCategories = categories;
    notifyListeners();
  }

  /// 검색 초기화
  void clearSearch({bool notify = true}) {
    _searchQuery = '';
    _filteredCategories = [];
    if (notify) {
      notifyListeners();
    }
  }

  /// 카테고리가 검색어와 매치되는지 확인
  bool matchesSearchQuery(
    CategoryDataModel category,
    String query, {
    String? currentUserId,
  }) {
    if (query.isEmpty) return true;

    final displayName =
        currentUserId != null
            ? category.getDisplayName(currentUserId)
            : category.name;
    return _matchesSearch(displayName, query);
  }

  /// 카테고리 표시 이름 가져오기
  String getCategoryDisplayName(CategoryDataModel category, String userId) {
    return category.getDisplayName(userId);
  }

  /// 사용자별 커스텀 이름 업데이트
  Future<void> updateCustomCategoryName({
    required String categoryId,
    required String userId,
    required String customName,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await _categoryService.updateCustomCategoryName(
        categoryId: categoryId,
        userId: userId,
        customName: customName,
      );

      _isLoading = false;

      if (result.isSuccess) {
        // 로컬 카테고리 목록에서 해당 카테고리 업데이트
        final index = _userCategories.indexWhere((cat) => cat.id == categoryId);
        if (index != -1) {
          // 커스텀 이름 업데이트를 위해 카테고리 새로고침 필요
          // 실제로는 CategoryController에서 다시 로드하는 것이 좋음
        }
        notifyListeners();
      } else {
        _error = result.error;
        notifyListeners();
      }
    } catch (e) {
      _isLoading = false;
      _error = '커스텀 이름 설정 중 오류가 발생했습니다.';
      notifyListeners();
    }
  }

  /// 에러 초기화
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// 텍스트가 검색어와 매치되는지 확인 (한글 초성, 영어 약어 포함)
  bool _matchesSearch(String text, String query) {
    if (text.toLowerCase().contains(query.toLowerCase())) return true;
    if (_matchesChosung(text, query)) return true;
    return _matchesAcronym(text, query);
  }

  /// 한글 초성 검색
  bool _matchesChosung(String text, String query) {
    try {
      return _extractChosung(text).contains(_extractChosung(query));
    } catch (e) {
      return false;
    }
  }

  /// 한글에서 초성 추출
  String _extractChosung(String text) {
    const chosungList = [
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

    StringBuffer result = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      int charCode = text.codeUnitAt(i);
      if (charCode >= 0xAC00 && charCode <= 0xD7A3) {
        int chosungIndex = ((charCode - 0xAC00) / 588).floor();
        if (chosungIndex >= 0 && chosungIndex < chosungList.length) {
          result.write(chosungList[chosungIndex]);
        }
      } else if (_isChosung(text[i])) {
        result.write(text[i]);
      } else {
        result.write(text[i]);
      }
    }
    return result.toString();
  }

  /// 초성인지 확인
  bool _isChosung(String char) {
    const chosungList = [
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
    return chosungList.contains(char);
  }

  /// 영어 약어 검색
  bool _matchesAcronym(String text, String query) {
    try {
      if (query.length < 2) return false;
      return _extractAcronym(text).contains(query.toLowerCase());
    } catch (e) {
      return false;
    }
  }

  /// 영어 약어 추출
  String _extractAcronym(String text) {
    if (text.isEmpty) return '';
    List<String> words = _splitWordsFromText(text);
    StringBuffer acronym = StringBuffer();
    for (String word in words) {
      if (word.isNotEmpty) {
        acronym.write(word[0].toLowerCase());
      }
    }
    return acronym.toString();
  }

  /// 텍스트를 단어로 분리
  List<String> _splitWordsFromText(String text) {
    List<String> words = [];
    StringBuffer currentWord = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      String char = text[i];
      if (char == ' ' ||
          char == '-' ||
          char == '_' ||
          char == '.' ||
          char == ',') {
        if (currentWord.isNotEmpty) {
          words.add(currentWord.toString());
          currentWord.clear();
        }
      } else if (char == char.toUpperCase() && char != char.toLowerCase()) {
        if (currentWord.isNotEmpty) {
          words.add(currentWord.toString());
          currentWord.clear();
        }
        currentWord.write(char);
      } else {
        currentWord.write(char);
      }
    }

    if (currentWord.isNotEmpty) {
      words.add(currentWord.toString());
    }
    return words;
  }
}
