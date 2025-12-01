import 'package:flutter/material.dart';
import 'dart:async';
import '../services/friend_service.dart';
import '../models/friend_model.dart';

/// 친구 관리 관련 UI 상태 관리를 담당하는 Controller
class FriendController extends ChangeNotifier {
  final FriendService _friendService;

  // 상태 변수들
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  // 친구 목록
  List<FriendModel> _friends = [];
  List<FriendModel> _favoriteFriends = [];
  Map<String, List<FriendModel>> _categorizedFriends = {};

  // 검색 관련
  List<FriendModel> _searchResults = [];
  String _currentSearchQuery = '';
  bool _isSearching = false;

  // 작업 상태
  final Map<String, bool> _processingFriends = {}; // friendUid -> isProcessing

  // 통계 정보
  Map<String, dynamic> _friendStats = {};

  // Stream 구독
  StreamSubscription<List<FriendModel>>? _friendsSubscription;
  StreamSubscription<List<FriendModel>>? _favoriteFriendsSubscription;

  FriendController({required FriendService friendService})
    : _friendService = friendService;

  // Getters
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  List<FriendModel> get friends => _friends;
  List<FriendModel> get favoriteFriends => _favoriteFriends;
  Map<String, List<FriendModel>> get categorizedFriends => _categorizedFriends;
  List<FriendModel> get searchResults => _searchResults;
  String get currentSearchQuery => _currentSearchQuery;
  bool get isSearching => _isSearching;
  Map<String, dynamic> get friendStats => _friendStats;

  /// 특정 친구가 처리 중인지 확인
  bool isProcessingFriend(String friendUid) {
    return _processingFriends[friendUid] ?? false;
  }

  /// 초기화 (앱 시작 시 호출)
  Future<void> initialize() async {
    if (_isInitialized) {
      return; // 이미 초기화된 경우 넘어감
    }
    try {
      _setLoading(true);
      _clearError();

      // 이전 구독 해제 및 상태 초기화
      await _reset();

      // 실시간 친구 목록 구독
      await _subscribeToFriends();

      // 통계 정보 로드
      await _loadFriendStats();

      // 카테고리별 친구 분류 로드
      await _loadCategorizedFriends();

      // 이 변수를 true로 설정하여서 초기화가 완료되었음을 알림
      _isInitialized = true;
    } catch (e) {
      _setError('친구 관리 초기화 실패: $e');
      debugPrint('FriendController 초기화 실패: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// 상태 초기화 (사용자 변경 시 호출)
  Future<void> reset() async {
    await _reset();
    _isInitialized = false;
  }

  /// 내부 상태 초기화
  Future<void> _reset() async {
    // 기존 구독 해제
    await _friendsSubscription?.cancel();
    await _favoriteFriendsSubscription?.cancel();
    _friendsSubscription = null;
    _favoriteFriendsSubscription = null;

    // 데이터 초기화
    _friends.clear();
    _favoriteFriends.clear();
    _categorizedFriends.clear();
    _searchResults.clear();
    _processingFriends.clear();
    _friendStats.clear();

    // 상태 초기화
    _isLoading = false;
    _isSearching = false;
    _currentSearchQuery = '';
    _error = null;

    notifyListeners();
  }

  /// 친구 삭제
  ///
  /// [friendUid] 삭제할 친구의 UID
  Future<bool> removeFriend(String friendUid) async {
    try {
      _processingFriends[friendUid] = true;
      _clearError();
      notifyListeners();

      await _friendService.removeFriend(friendUid);

      // 통계 및 분류 업데이트
      await _loadFriendStats();
      await _loadCategorizedFriends();

      return true;
    } catch (e) {
      _setError('친구 삭제 실패: $e');
      debugPrint('친구 삭제 실패: $e');
      return false;
    } finally {
      _processingFriends[friendUid] = false;
      notifyListeners();
    }
  }

  /// 친구 차단
  ///
  /// [friendUid] 차단할 친구의 UID
  Future<bool> blockFriend(String friendUid) async {
    try {
      _processingFriends[friendUid] = true;
      _clearError();
      notifyListeners();

      await _friendService.blockFriend(friendUid);

      // 통계 업데이트
      await _loadFriendStats();

      return true;
    } catch (e) {
      _setError('친구 차단 실패: $e');
      return false;
    } finally {
      _processingFriends[friendUid] = false;
      notifyListeners();
    }
  }

  /// 친구 차단 해제
  ///
  /// [friendUid] 차단 해제할 친구의 UID
  Future<bool> unblockFriend(String friendUid) async {
    try {
      _processingFriends[friendUid] = true;
      _clearError();
      notifyListeners();

      await _friendService.unblockFriend(friendUid);

      // 통계 업데이트
      await _loadFriendStats();

      return true;
    } catch (e) {
      _setError('친구 차단 해제 실패: $e');
      debugPrint('친구 차단 해제 실패: $e');
      return false;
    } finally {
      _processingFriends[friendUid] = false;
      notifyListeners();
    }
  }

  /// 차단된 사용자 목록 조회
  ///
  /// Returns: 차단된 사용자의 UID 목록
  Future<List<String>> getBlockedUsers() async {
    try {
      return await _friendService.getBlockedUsers();
    } catch (e) {
      _setError('차단 목록 조회 실패: $e');
      return [];
    }
  }

  /// 검색 결과 클리어
  void clearSearch() {
    _searchResults = [];
    _currentSearchQuery = '';
    _isSearching = false;
    notifyListeners();
  }

  /// 실시간 친구 목록 구독
  Future<void> _subscribeToFriends() async {
    try {
      // 전체 친구 목록 구독
      _friendsSubscription = _friendService.getFriendsList().listen(
        (friends) {
          _friends = friends;
          notifyListeners();
        },
        onError: (error) {
          _setError('친구 목록 로드 실패: $error');
        },
      );

      // 즐겨찾기 친구 목록 구독
      _favoriteFriendsSubscription = _friendService
          .getFavoriteFriendsList()
          .listen(
            (favoriteFriends) {
              _favoriteFriends = favoriteFriends;
              notifyListeners();
            },
            onError: (error) {
              _setError('즐겨찾기 친구 목록 로드 실패: $error');
            },
          );
    } catch (e) {
      _setError('친구 목록 구독 실패: $e');
    }
  }

  /// 통계 정보 로드
  Future<void> _loadFriendStats() async {
    try {
      _friendStats = await _friendService.getFriendStats();
      notifyListeners();
    } catch (e) {
      debugPrint('친구 통계 로드 실패: $e');
    }
  }

  /// 카테고리별 친구 분류 로드
  Future<void> _loadCategorizedFriends() async {
    try {
      _categorizedFriends = await _friendService.getCategorizedFriends();
      notifyListeners();
    } catch (e) {
      debugPrint('친구 분류 로드 실패: $e');
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

  @override
  void dispose() {
    _friendsSubscription?.cancel();
    _favoriteFriendsSubscription?.cancel();
    super.dispose();
  }
}
