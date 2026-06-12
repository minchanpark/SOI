import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:soi/api/controller/category_controller.dart';
import 'package:soi/api/controller/friend_controller.dart';
import 'package:soi/api/controller/post_controller.dart';
import 'package:soi/api/controller/user_controller.dart';
import 'package:soi/api/models/category.dart';
import 'package:soi/api/models/friend.dart';
import 'package:soi/api/models/post.dart';
import 'package:soi/api/models/user.dart';
import 'package:soi/api/services/category_service.dart';
import 'package:soi/api/services/friend_service.dart';
import 'package:soi/api/services/post_service.dart';
import 'package:soi/api/services/user_service.dart';
import 'package:soi/views/about_feed/manager/feed_data_manager.dart';
import 'package:soi_api_client/api.dart';

void main() {
  group('FeedDataManager loadUserCategoriesAndPhotos', () {
    testWidgets(
      'keeps category post requests cacheable when forceRefresh is false',
      (tester) async {
        final manager = FeedDataManager();
        final userController =
            UserController(userService: UserService(userApi: _NoopUserApi()))
              ..setCurrentUser(
                const User(
                  id: 7,
                  userId: 'viewer',
                  name: 'Viewer',
                  phoneNumber: '01000000000',
                ),
              );
        final categoryController = _RecordingCategoryController(
          categories: _categories,
        );
        final postController = _RecordingPostController();
        final friendController = _NoopFriendController();

        final context = await _pumpProviderTree(
          tester: tester,
          manager: manager,
          userController: userController,
          categoryController: categoryController,
          postController: postController,
          friendController: friendController,
        );

        await manager.loadUserCategoriesAndPhotos(context);

        expect(categoryController.forceReloads, [false]);
        expect(postController.calls, hasLength(_categories.length));
        expect(
          postController.calls.every((call) => call.forceRefresh == false),
          isTrue,
        );
        expect(
          postController.calls.every((call) => call.notifyLoading == false),
          isTrue,
        );
      },
    );

    testWidgets(
      'bypasses category post cache for every category on forceRefresh',
      (tester) async {
        final manager = FeedDataManager();
        final userController =
            UserController(userService: UserService(userApi: _NoopUserApi()))
              ..setCurrentUser(
                const User(
                  id: 7,
                  userId: 'viewer',
                  name: 'Viewer',
                  phoneNumber: '01000000000',
                ),
              );
        final categoryController = _RecordingCategoryController(
          categories: _categories,
        );
        final postController = _RecordingPostController();
        final friendController = _NoopFriendController();

        final context = await _pumpProviderTree(
          tester: tester,
          manager: manager,
          userController: userController,
          categoryController: categoryController,
          postController: postController,
          friendController: friendController,
        );

        await manager.loadUserCategoriesAndPhotos(context, forceRefresh: true);

        expect(categoryController.forceReloads, [true]);
        expect(postController.calls, hasLength(_categories.length));
        expect(postController.calls.every((call) => call.forceRefresh), isTrue);
        expect(
          postController.calls.every((call) => call.notifyLoading == false),
          isTrue,
        );
      },
    );

    testWidgets(
      'emits provisional feed candidates before every category request completes',
      (tester) async {
        final manager = FeedDataManager();
        final userController =
            UserController(userService: UserService(userApi: _NoopUserApi()))
              ..setCurrentUser(
                const User(
                  id: 7,
                  userId: 'viewer',
                  name: 'Viewer',
                  phoneNumber: '01000000000',
                ),
              );
        final categoryController = _RecordingCategoryController(
          categories: _categories,
        );
        final postController = _RecordingPostController();
        final friendController = _NoopFriendController();
        final alphaCompleter = Completer<List<Post>>();
        final betaCompleter = Completer<List<Post>>();
        final emittedSnapshots = <List<int>>[];

        postController.onGetPostsByCategory =
            ({
              required int categoryId,
              required int userId,
              int? notificationId,
              int page = 0,
              bool notifyLoading = true,
              bool forceRefresh = false,
            }) {
              if (categoryId == 1) {
                return alphaCompleter.future;
              }
              return betaCompleter.future;
            };

        manager.setOnPostsLoaded((items) {
          emittedSnapshots.add(
            items.map((item) => item.post.id).toList(growable: false),
          );
        });

        final context = await _pumpProviderTree(
          tester: tester,
          manager: manager,
          userController: userController,
          categoryController: categoryController,
          postController: postController,
          friendController: friendController,
        );

        final loadFuture = manager.loadUserCategoriesAndPhotos(context);

        alphaCompleter.complete([
          Post(
            id: 101,
            nickName: 'alpha-author',
            createdAt: DateTime.utc(2026, 3, 11, 8),
          ),
        ]);
        await tester.pump();

        expect(emittedSnapshots, isNotEmpty);
        expect(emittedSnapshots.first, [101]);

        betaCompleter.complete([
          Post(
            id: 202,
            nickName: 'beta-author',
            createdAt: DateTime.utc(2026, 3, 11, 9),
          ),
        ]);
        await loadFuture;
        await tester.pumpAndSettle();

        expect(emittedSnapshots.length, greaterThanOrEqualTo(2));
        expect(emittedSnapshots.last, [202, 101]);
        expect(
          manager.allPosts.map((item) => item.post.id).toList(growable: false),
          [202, 101],
        );
      },
    );

    testWidgets('re-emits loaded candidates when warm feed cache is reused', (
      tester,
    ) async {
      final manager = FeedDataManager();
      final userController =
          UserController(userService: UserService(userApi: _NoopUserApi()))
            ..setCurrentUser(
              const User(
                id: 7,
                userId: 'viewer',
                name: 'Viewer',
                phoneNumber: '01000000000',
              ),
            );
      final categoryController = _RecordingCategoryController(
        categories: _categories,
      );
      final postController = _RecordingPostController();
      final friendController = _NoopFriendController();
      final emittedSnapshots = <List<int>>[];

      final context = await _pumpProviderTree(
        tester: tester,
        manager: manager,
        userController: userController,
        categoryController: categoryController,
        postController: postController,
        friendController: friendController,
      );

      await manager.loadUserCategoriesAndPhotos(context);
      final firstLoadCallCount = postController.calls.length;

      manager.setOnPostsLoaded((items) {
        emittedSnapshots.add(
          items.map((item) => item.post.id).toList(growable: false),
        );
      });

      await manager.loadUserCategoriesAndPhotos(context);

      expect(postController.calls.length, firstLoadCallCount);
      expect(emittedSnapshots, isNotEmpty);
      expect(
        emittedSnapshots.single,
        manager.allPosts.map((item) => item.post.id).toList(growable: false),
      );
    });

    testWidgets('keeps visible feed while warm cache refresh is in flight', (
      tester,
    ) async {
      final manager = FeedDataManager();
      final userController =
          UserController(userService: UserService(userApi: _NoopUserApi()))
            ..setCurrentUser(
              const User(
                id: 7,
                userId: 'viewer',
                name: 'Viewer',
                phoneNumber: '01000000000',
              ),
            );
      final categoryController = _RecordingCategoryController(
        categories: _categories,
      );
      final postController = _RecordingPostController();
      final friendController = _NoopFriendController();

      final context = await _pumpProviderTree(
        tester: tester,
        manager: manager,
        userController: userController,
        categoryController: categoryController,
        postController: postController,
        friendController: friendController,
      );

      await manager.loadUserCategoriesAndPhotos(context);
      expect(manager.visiblePosts, isNotEmpty);
      expect(manager.isLoading, isFalse);

      final refreshCompleter = Completer<List<Post>>();
      postController.onGetPostsByCategory =
          ({
            required int categoryId,
            required int userId,
            int? notificationId,
            int page = 0,
            bool notifyLoading = true,
            bool forceRefresh = false,
          }) => refreshCompleter.future;

      unawaited(
        manager.loadUserCategoriesAndPhotos(context, forceRefresh: true),
      );
      await tester.pump();

      expect(manager.isLoading, isFalse);
      expect(manager.visiblePosts, isNotEmpty);

      refreshCompleter.complete([
        Post(
          id: 999,
          nickName: 'refreshed',
          createdAt: DateTime.utc(2026, 3, 12),
        ),
      ]);
      await tester.pumpAndSettle();
    });

    testWidgets('preserves stale posts when refresh fails after cache warmup', (
      tester,
    ) async {
      final manager = FeedDataManager();
      final userController =
          UserController(userService: UserService(userApi: _NoopUserApi()))
            ..setCurrentUser(
              const User(
                id: 7,
                userId: 'viewer',
                name: 'Viewer',
                phoneNumber: '01000000000',
              ),
            );
      final categoryController = _RecordingCategoryController(
        categories: _categories,
      );
      final postController = _RecordingPostController();
      final friendController = _NoopFriendController();

      final context = await _pumpProviderTree(
        tester: tester,
        manager: manager,
        userController: userController,
        categoryController: categoryController,
        postController: postController,
        friendController: friendController,
      );

      await manager.loadUserCategoriesAndPhotos(context);
      final initialVisiblePosts = manager.visiblePosts;

      postController.onGetPostsByCategory =
          ({
            required int categoryId,
            required int userId,
            int? notificationId,
            int page = 0,
            bool notifyLoading = true,
            bool forceRefresh = false,
          }) async => throw Exception('network error');

      await manager.loadUserCategoriesAndPhotos(context, forceRefresh: true);

      expect(manager.isLoading, isFalse);
      expect(manager.visiblePosts, same(initialVisiblePosts));
      expect(manager.allPosts, isNotEmpty);
    });

    testWidgets('defers posts-changed refresh until feed tab is visible', (
      tester,
    ) async {
      final manager = FeedDataManager();
      final userController =
          UserController(userService: UserService(userApi: _NoopUserApi()))
            ..setCurrentUser(
              const User(
                id: 7,
                userId: 'viewer',
                name: 'Viewer',
                phoneNumber: '01000000000',
              ),
            );
      final categoryController = _RecordingCategoryController(
        categories: _categories,
      );
      final postController = _RecordingPostController();
      final friendController = _NoopFriendController();

      var tickerEnabled = false;
      late StateSetter setTickerMode;
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FeedDataManager>.value(value: manager),
            ChangeNotifierProvider<UserController>.value(value: userController),
            ChangeNotifierProvider<CategoryController>.value(
              value: categoryController,
            ),
            ChangeNotifierProvider<PostController>.value(value: postController),
            ChangeNotifierProvider<FriendController>.value(
              value: friendController,
            ),
          ],
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: StatefulBuilder(
              builder: (context, setState) {
                setTickerMode = setState;
                return TickerMode(
                  enabled: tickerEnabled,
                  child: Builder(
                    builder: (context) {
                      capturedContext = context;
                      return const SizedBox.shrink();
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      manager.listenToPostController(postController, capturedContext);
      postController.notifyPostsChanged();
      await tester.pump();

      expect(postController.calls, isEmpty);

      setTickerMode(() {
        tickerEnabled = true;
      });
      await tester.pump();

      manager.refreshIfPendingVisible();
      await tester.pumpAndSettle();

      expect(postController.calls, hasLength(_categories.length));
      expect(postController.calls.every((call) => call.forceRefresh), isTrue);
    });
  });
}

const List<Category> _categories = [
  Category(id: 1, name: 'alpha'),
  Category(id: 2, name: 'beta'),
];

Future<BuildContext> _pumpProviderTree({
  required WidgetTester tester,
  required FeedDataManager manager,
  required UserController userController,
  required CategoryController categoryController,
  required PostController postController,
  required FriendController friendController,
}) async {
  late BuildContext capturedContext;

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<FeedDataManager>.value(value: manager),
        ChangeNotifierProvider<UserController>.value(value: userController),
        ChangeNotifierProvider<CategoryController>.value(
          value: categoryController,
        ),
        ChangeNotifierProvider<PostController>.value(value: postController),
        ChangeNotifierProvider<FriendController>.value(value: friendController),
      ],
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );

  return capturedContext;
}

class _RecordingCategoryController extends CategoryController {
  _RecordingCategoryController({required List<Category> categories})
    : _categories = categories,
      super(categoryService: CategoryService(categoryApi: _NoopCategoryApi()));

  final List<Category> _categories;
  final List<bool> forceReloads = <bool>[];

  @override
  Future<List<Category>> loadCategories(
    int userId, {
    CategoryFilter filter = CategoryFilter.all,
    bool forceReload = true,
    int page = 0,
    bool fetchAllPages = true,
    int maxPages = 50,
  }) async {
    forceReloads.add(forceReload);
    return _categories;
  }
}

class _RecordingPostController extends PostController {
  _RecordingPostController()
    : super(postService: PostService(postApi: _NoopPostApi()));

  Future<List<Post>> Function({
    required int categoryId,
    required int userId,
    int? notificationId,
    int page,
    bool notifyLoading,
    bool forceRefresh,
  })?
  onGetPostsByCategory;
  final List<_PostRequest> calls = <_PostRequest>[];

  @override
  Future<List<Post>> getPostsByCategory({
    required int categoryId,
    required int userId,
    int? notificationId,
    int page = 0,
    bool notifyLoading = true,
    bool forceRefresh = false,
  }) async {
    calls.add(
      _PostRequest(
        categoryId: categoryId,
        userId: userId,
        page: page,
        notifyLoading: notifyLoading,
        forceRefresh: forceRefresh,
      ),
    );

    final handler = onGetPostsByCategory;
    if (handler != null) {
      return handler(
        categoryId: categoryId,
        userId: userId,
        notificationId: notificationId,
        page: page,
        notifyLoading: notifyLoading,
        forceRefresh: forceRefresh,
      );
    }

    return [
      Post(
        id: categoryId,
        nickName: 'author-$categoryId',
        createdAt: DateTime.utc(2026, 3, 11, 0, categoryId),
      ),
    ];
  }
}

class _NoopFriendController extends FriendController {
  _NoopFriendController()
    : super(friendService: FriendService(friendApi: _NoopFriendApi()));

  @override
  Future<List<User>> getAllFriends({
    required int userId,
    FriendStatus status = FriendStatus.accepted,
    bool forceRefresh = false,
  }) async {
    return const <User>[];
  }
}

class _PostRequest {
  const _PostRequest({
    required this.categoryId,
    required this.userId,
    required this.page,
    required this.notifyLoading,
    required this.forceRefresh,
  });

  final int categoryId;
  final int userId;
  final int page;
  final bool notifyLoading;
  final bool forceRefresh;
}

class _NoopUserApi extends UserAPIApi {}

class _NoopCategoryApi extends CategoryAPIApi {}

class _NoopPostApi extends PostAPIApi {}

class _NoopFriendApi extends FriendAPIApi {}
