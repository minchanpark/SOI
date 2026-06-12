import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soi/main.dart' as app;

// run_perf.sh 가 --dart-define 으로 주입한 JWT 세션 (컴파일타임 상수)
const _accessToken = String.fromEnvironment('PERF_ACCESS_TOKEN');
const _refreshToken = String.fromEnvironment('PERF_REFRESH_TOKEN');
const _userId = int.fromEnvironment('PERF_USER_ID');
const _phone = String.fromEnvironment('PERF_PHONE');
const _expiresAccess = int.fromEnvironment('PERF_EXPIRES_ACCESS');
const _expiresRefresh = int.fromEnvironment('PERF_EXPIRES_REFRESH');
const _issuedAt = int.fromEnvironment('PERF_ISSUED_AT');

/// SharedPreferences에 세션을 주입하여 auto-login이 동작하게 합니다.
Future<void> _injectSession() async {
  if (_accessToken.isEmpty) return;

  final prefs = await SharedPreferences.getInstance();
  await Future.wait([
    prefs.setBool('api_is_logged_in', true),
    prefs.setString('api_access_token', _accessToken),
    prefs.setString('api_refresh_token', _refreshToken),
    prefs.setInt('api_user_id', _userId),
    prefs.setString('api_phone_number', _phone),
    if (_expiresAccess > 0) prefs.setInt('api_access_token_expires_in_ms', _expiresAccess),
    if (_expiresRefresh > 0) prefs.setInt('api_refresh_token_expires_in_ms', _expiresRefresh),
    if (_issuedAt > 0) prefs.setInt('api_auth_issued_at_ms', _issuedAt),
  ]);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('feed_scroll', (tester) async {
    await _injectSession();
    app.main();

    // 부트 시퀀스 완료 대기 (Firebase, auto-login, 라우팅)
    await tester.pumpAndSettle(const Duration(seconds: 10));

    final scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isEmpty) {
      debugPrint('[perf] Scrollable not found — 로그인 화면? export_session.sh 재실행 필요.');
      return;
    }

    await binding.traceAction(() async {
      for (int i = 0; i < 6; i++) {
        await tester.fling(scrollables.first, const Offset(0, -500), 1500);
        await tester.pumpAndSettle(const Duration(milliseconds: 800));
      }
    }, reportKey: 'feed_scroll');
  });

  testWidgets('tab_navigation', (tester) async {
    await _injectSession();
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 10));

    final bottomNav = find.byType(BottomNavigationBar);
    if (bottomNav.evaluate().isEmpty) {
      debugPrint('[perf] BottomNavigationBar not found — skipping.');
      return;
    }

    await binding.traceAction(() async {
      final tabs = find.descendant(
        of: bottomNav,
        matching: find.byType(InkResponse),
      );
      for (int i = 0; i < tabs.evaluate().length; i++) {
        await tester.tap(tabs.at(i));
        await tester.pumpAndSettle(const Duration(milliseconds: 500));
      }
    }, reportKey: 'tab_navigation');
  });
}
