import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'dart:async';
import '../models/user_search_model.dart';
import '../repositories/user_search_repository.dart';
import '../services/user_matching_service.dart';
import '../services/friend_request_service.dart';

/// 사용자 매칭 및 추천 관련 UI 상태 관리를 담당하는 Controller
class UserMatchingController extends ChangeNotifier {
  final UserMatchingService _userMatchingService;
  final FriendRequestService _friendRequestService;
  final UserSearchRepository _userSearchRepository;

  // 상태 변수들
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  // 연락처 관련
  List<Contact> _contacts = [];
  bool _hasContactPermission = false;
  bool _isLoadingContacts = false;

  // 추천 친구 (매칭 결과)
  List<ContactMatchResult> _contactMatches = [];
  List<UserSearchModel> _recommendedFriends = [];
  final Map<String, bool> _processingRecommendations = {};
  bool _isLoadingRecommendations = false;

  // 사용자 검색
  List<UserSearchModel> _searchResults = [];
  String _currentSearchQuery = '';
  bool _isSearching = false;
  final Map<String, bool> _processingSearchResults = {};

  // 매칭 통계
  MatchingStats? _matchingStats;

  // 백그라운드 작업 상태
  bool _isBackgroundProcessing = false;

  UserMatchingController({
    required UserMatchingService userMatchingService,
    required FriendRequestService friendRequestService,
    required UserSearchRepository userSearchRepository,
  }) : _userMatchingService = userMatchingService,
       _friendRequestService = friendRequestService,
       _userSearchRepository = userSearchRepository;

  // Getters
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  List<Contact> get contacts => _contacts;
  bool get hasContactPermission => _hasContactPermission;
  bool get isLoadingContacts => _isLoadingContacts;
  List<ContactMatchResult> get contactMatches => _contactMatches;
  List<UserSearchModel> get recommendedFriends => _recommendedFriends;
  bool get isLoadingRecommendations => _isLoadingRecommendations;
  List<UserSearchModel> get searchResults => _searchResults;
  String get currentSearchQuery => _currentSearchQuery;
  bool get isSearching => _isSearching;
  MatchingStats? get matchingStats => _matchingStats;
  bool get isBackgroundProcessing => _isBackgroundProcessing;

  /// 특정 추천이 처리 중인지 확인
  bool isProcessingRecommendation(String userId) {
    return _processingRecommendations[userId] ?? false;
  }

  /// 특정 검색 결과가 처리 중인지 확인
  bool isProcessingSearchResult(String userId) {
    return _processingSearchResults[userId] ?? false;
  }

  /// 초기화 (앱 시작 시 호출)
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _setLoading(true);
      _clearError();

      // 연락처 권한 확인
      await _checkContactPermission();

      // 연락처가 있다면 백그라운드에서 추천 시작
      if (_hasContactPermission) {
        _startBackgroundMatching();
      }

      _isInitialized = true;
      // debugPrint('UserMatchingController 초기화 완료');
    } catch (e) {
      _setError('사용자 매칭 초기화 실패: $e');
      // debugPrint('UserMatchingController 초기화 실패: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// 연락처 권한 요청 및 로드
  Future<bool> requestContactPermission() async {
    try {
      _isLoadingContacts = true;
      _clearError();
      notifyListeners();

      // Flutter Contacts 직접 사용
      if (await FlutterContacts.requestPermission()) {
        _hasContactPermission = true;
        _contacts = await FlutterContacts.getContacts(withProperties: true);
        // debugPrint('연락처 로드 완료: ${_contacts.length}개');

        // 연락처 로드 후 매칭 시작
        await performContactMatching();
      } else {
        _hasContactPermission = false;
        // debugPrint('연락처 권한 거부됨');
      }

      return _hasContactPermission;
    } catch (e) {
      _setError('연락처 권한 요청 실패: $e');
      // debugPrint('연락처 권한 요청 실패: $e');
      return false;
    } finally {
      _isLoadingContacts = false;
      notifyListeners();
    }
  }

  /// 연락처 매칭 수행
  Future<void> performContactMatching() async {
    if (!_hasContactPermission || _contacts.isEmpty) return;

    try {
      _isLoadingRecommendations = true;
      _clearError();
      notifyListeners();

      // UserMatchingService로 매칭 수행
      _contactMatches = await _userMatchingService.matchContactsWithUsers(
        _contacts,
      );

      // 매칭 결과에서 추천 친구 추출
      _recommendedFriends = _contactMatches.map((match) => match.user).toList();

      // 매칭 통계 계산
      await _updateMatchingStats();
    } catch (e) {
      _setError('연락처 매칭 실패: $e');
      // debugPrint('연락처 매칭 실패: $e');
    } finally {
      _isLoadingRecommendations = false;
      notifyListeners();
    }
  }

  /// 사용자 검색
  ///
  /// [query] 검색 쿼리 (이름, 전화번호, 이메일 등)
  Future<void> searchUsers(String query) async {
    try {
      _isSearching = true;
      _currentSearchQuery = query;
      _clearError();
      notifyListeners();

      if (query.trim().isEmpty) {
        _searchResults = [];
      } else {
        // UserSearchRepository로 검색
        _searchResults = await _userSearchRepository.searchUsersById(query);
        // debugPrint('사용자 검색 완료: ${_searchResults.length}명 발견');
      }
    } catch (e) {
      _setError('사용자 검색 실패: $e');
      // debugPrint('사용자 검색 실패: $e');
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  /// ID로 사용자 검색
  ///
  /// [userId] 검색할 사용자 ID
  /// Returns: UserSearchModel 또는 null
  Future<List<UserSearchModel>?> searchUserById(String userId) async {
    try {
      // debugPrint('ID로 사용자 검색 시작: $userId');
      final result = await _userMatchingService.searchUserById(userId);
      // debugPrint('ID 검색 결과: ${result}');
      return result;
    } catch (e) {
      // debugPrint('ID로 사용자 검색 실패: $e');
      _setError('사용자 검색 실패: $e');
      return null;
    }
  }

  /// 검색 결과 클리어
  void clearSearch() {
    _searchResults = [];
    _currentSearchQuery = '';
    _isSearching = false;
    _processingSearchResults.clear();
    notifyListeners();
  }

  /// 추천 친구에게 친구 요청 보내기
  ///
  /// [userId] 친구 요청을 보낼 사용자 ID
  Future<bool> sendFriendRequestToRecommendation(String userId) async {
    try {
      _processingRecommendations[userId] = true;
      _clearError();
      notifyListeners();

      await _friendRequestService.sendFriendRequest(receiverUid: userId);

      // 추천 목록에서 제거
      _recommendedFriends.removeWhere((user) => user.uid == userId);
      _contactMatches.removeWhere((match) => match.user.uid == userId);

      // debugPrint('추천 친구에게 친구 요청 전송 성공: $userId');
      return true;
    } catch (e) {
      _setError('친구 요청 전송 실패: $e');
      // debugPrint('친구 요청 전송 실패: $e');
      return false;
    } finally {
      _processingRecommendations[userId] = false;
      notifyListeners();
    }
  }

  /// 검색 결과에서 친구 요청 보내기
  ///
  /// [userId] 친구 요청을 보낼 사용자 ID
  Future<bool> sendFriendRequestToSearchResult(String userId) async {
    try {
      _processingSearchResults[userId] = true;
      _clearError();
      notifyListeners();

      await _friendRequestService.sendFriendRequest(
        message: userId,
        receiverUid: '',
      );

      // debugPrint('검색 결과에서 친구 요청 전송 성공: $userId');
      return true;
    } catch (e) {
      _setError('친구 요청 전송 실패: $e');
      // debugPrint('친구 요청 전송 실패: $e');
      return false;
    } finally {
      _processingSearchResults[userId] = false;
      notifyListeners();
    }
  }

  /// 추천 숨기기
  ///
  /// [userId] 숨길 사용자 ID
  Future<bool> hideRecommendation(String userId) async {
    try {
      _processingRecommendations[userId] = true;
      notifyListeners();

      // 추천 목록에서 제거 (로컬 상태만)
      _recommendedFriends.removeWhere((user) => user.uid == userId);
      _contactMatches.removeWhere((match) => match.user.uid == userId);

      // debugPrint('추천 숨기기 성공: $userId');
      return true;
    } catch (e) {
      _setError('추천 숨기기 실패: $e');
      // debugPrint('추천 숨기기 실패: $e');
      return false;
    } finally {
      _processingRecommendations[userId] = false;
      notifyListeners();
    }
  }

  /// 연락처 동기화
  Future<bool> syncContacts() async {
    if (!_hasContactPermission) return false;

    try {
      _isLoadingContacts = true;
      _clearError();
      notifyListeners();

      _contacts = await FlutterContacts.getContacts(withProperties: true);
      // debugPrint('연락처 동기화 완료: ${_contacts.length}개');

      // 연락처 동기화 후 매칭 업데이트
      await performContactMatching();

      return true;
    } catch (e) {
      _setError('연락처 동기화 실패: $e');
      // debugPrint('연락처 동기화 실패: $e');
      return false;
    } finally {
      _isLoadingContacts = false;
      notifyListeners();
    }
  }

  /// 특정 연락처의 검색 상태 확인
  ///
  /// [contact] 확인할 연락처
  Future<ContactSearchStatus> getContactSearchStatus(Contact contact) async {
    try {
      return await _userMatchingService.getContactSearchStatus(contact);
    } catch (e) {
      // debugPrint('연락처 검색 상태 확인 실패: $e');
      return ContactSearchStatus.error;
    }
  }

  /// 특정 연락처와 매칭되는 사용자 찾기
  ///
  /// [contact] 검색할 연락처
  Future<UserSearchModel?> findUserForContact(Contact contact) async {
    try {
      return await _userMatchingService.findUserForContact(contact);
    } catch (e) {
      // debugPrint('연락처 사용자 찾기 실패: $e');
      return null;
    }
  }

  /// 연락처 권한 확인
  Future<void> _checkContactPermission() async {
    try {
      _hasContactPermission = await FlutterContacts.requestPermission(
        readonly: true,
      );

      if (_hasContactPermission) {
        _contacts = await FlutterContacts.getContacts(withProperties: true);
        // debugPrint('기존 연락처 로드 완료: ${_contacts.length}개');
      }
    } catch (e) {
      // debugPrint('연락처 권한 확인 실패: $e');
      _hasContactPermission = false;
    }
  }

  /// 백그라운드에서 매칭 시작
  void _startBackgroundMatching() {
    if (_isBackgroundProcessing) return;

    _isBackgroundProcessing = true;
    notifyListeners();

    // 백그라운드에서 매칭 수행 (UI 블로킹 없이)
    performContactMatching().then((_) {
      _isBackgroundProcessing = false;
      notifyListeners();
    });
  }

  /// 매칭 통계 업데이트
  Future<void> _updateMatchingStats() async {
    try {
      if (_contacts.isNotEmpty) {
        _matchingStats = await _userMatchingService.getMatchingStats(_contacts);
        notifyListeners();
      }
    } catch (e) {
      // debugPrint('매칭 통계 업데이트 실패: $e');
    }
  }

  /// 새로고침
  Future<void> refresh() async {
    try {
      _setLoading(true);
      _clearError();

      if (_hasContactPermission) {
        await syncContacts();
      }

      // debugPrint('사용자 매칭 정보 새로고침 완료');
    } catch (e) {
      _setError('새로고침 실패: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// 로딩 상태 설정
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// 에러 설정
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  /// 에러 클리어
  void _clearError() {
    _error = null;
    notifyListeners();
  }
}
