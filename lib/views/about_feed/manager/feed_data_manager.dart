import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../api/controller/category_controller.dart' as api_category;
import '../../../api/controller/post_controller.dart';
import '../../../api/controller/user_controller.dart';
import '../../../api/models/category.dart' as api_model;
import '../../../api/models/post.dart';

class FeedPostItem {
  final Post post;
  final int categoryId;
  final String categoryName;

  const FeedPostItem({
    required this.post,
    required this.categoryId,
    required this.categoryName,
  });
}

class FeedDataManager {
  List<FeedPostItem> _allPosts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreData = false;

  VoidCallback? _onStateChanged;
  Function(List<FeedPostItem>)? _onPostsLoaded;

  List<FeedPostItem> get allPosts => _allPosts;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreData => _hasMoreData;

  void setOnStateChanged(VoidCallback? callback) {
    _onStateChanged = callback;
  }

  void setOnPostsLoaded(Function(List<FeedPostItem>)? callback) {
    _onPostsLoaded = callback;
  }

  void _notifyStateChanged() {
    _onStateChanged?.call();
  }

  Future<void> loadUserCategoriesAndPhotos(BuildContext context) async {
    await _loadFeed(context, forceRefresh: true);
  }

  Future<void> loadMorePhotos(BuildContext context) async {
    if (_isLoadingMore) return;
    _isLoadingMore = true;
    _notifyStateChanged();
    await _loadFeed(context);
    _isLoadingMore = false;
    _notifyStateChanged();
  }

  Future<void> _loadFeed(
    BuildContext context, {
    bool forceRefresh = false,
  }) async {
    final isInitialLoad = !_isLoadingMore;
    try {
      if (isInitialLoad) {
        _isLoading = true;
        _hasMoreData = false;
        _notifyStateChanged();
      }

      final userController = Provider.of<UserController>(
        context,
        listen: false,
      );
      final categoryController = Provider.of<api_category.CategoryController>(
        context,
        listen: false,
      );
      final postController = Provider.of<PostController>(
        context,
        listen: false,
      );

      if (userController.currentUser == null) {
        await userController.tryAutoLogin();
      }
      final currentUser = userController.currentUser;
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다.');
      }

      final categories = await categoryController.loadCategories(
        currentUser.id,
        filter: api_model.CategoryFilter.all,
        forceReload: forceRefresh,
      );

      if (categories.isEmpty) {
        _allPosts = [];
        _isLoading = false;
        _notifyStateChanged();
        return;
      }

      final List<FeedPostItem> combined = [];
      for (final category in categories) {
        try {
          final posts = await postController.getPostsByCategory(
            categoryId: category.id,
            userId: currentUser.id,
          );
          combined.addAll(
            posts.map(
              (post) => FeedPostItem(
                post: post,
                categoryId: category.id,
                categoryName: category.name,
              ),
            ),
          );
        } catch (e) {
          debugPrint('[FeedDataManager] 카테고리 ${category.id} 로드 실패: $e');
        }
      }

      combined.sort((a, b) {
        final aTime =
            a.post.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime =
            b.post.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      _allPosts = combined;
      if (isInitialLoad) {
        _isLoading = false;
      }
      _notifyStateChanged();
      _onPostsLoaded?.call(combined);
    } catch (e) {
      debugPrint('[FeedDataManager] 피드 로드 실패: $e');
      _allPosts = [];
      _hasMoreData = false;
      if (isInitialLoad) {
        _isLoading = false;
      }
      _notifyStateChanged();
    }
  }

  void removePhoto(int index) {
    if (index >= 0 && index < _allPosts.length) {
      _allPosts.removeAt(index);
      _notifyStateChanged();
    }
  }

  FeedPostItem? getPostData(int index) {
    if (index >= 0 && index < _allPosts.length) {
      return _allPosts[index];
    }
    return null;
  }

  void dispose() {
    _allPosts.clear();
  }
}
