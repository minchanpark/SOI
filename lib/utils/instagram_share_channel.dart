import 'package:flutter/services.dart';

/// Instagram Direct 공유를 위한 네이티브 채널
class InstagramShareChannel {
  static const MethodChannel _channel = MethodChannel(
    'com.soi.instagram_share',
  );

  /// Instagram Direct로 텍스트 공유
  /// Instagram 앱이 열리면서 바로 DM 친구 선택 화면이 표시됨
  static Future<bool> shareToInstagramDirect(String text) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'shareToInstagramDirect',
        {'text': text},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('Instagram 공유 실패: ${e.message}');
      return false;
    }
  }

  /// Instagram 설치 여부 확인
  static Future<bool> isInstagramInstalled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isInstagramInstalled');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
}
