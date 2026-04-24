import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:soi/views/about_camera/widgets/about_camera/gallery_thumbnail.dart';

class _MutableValue<T> {
  _MutableValue(this.value);

  T value;
}

class _FakeThumbnailAssetEntity extends Fake implements AssetEntity {
  _FakeThumbnailAssetEntity(this.assetId);

  final String assetId;
  final _thumbnailCallCount = _MutableValue<int>(0);
  final _lastRequestedSize = _MutableValue<ThumbnailSize?>(null);

  int get thumbnailCallCount => _thumbnailCallCount.value;

  ThumbnailSize? get lastRequestedSize => _lastRequestedSize.value;

  @override
  String get id => assetId;

  @override
  Future<Uint8List?> thumbnailDataWithSize(
    ThumbnailSize size, {
    ThumbnailFormat format = ThumbnailFormat.jpeg,
    int quality = 100,
    PMProgressHandler? progressHandler,
    PMCancelToken? cancelToken,
    int frame = 0,
  }) async {
    _thumbnailCallCount.value++;
    _lastRequestedSize.value = size;
    return null;
  }
}

Future<void> _pumpThumbnail(
  WidgetTester tester, {
  required AssetEntity? asset,
  double size = 46,
}) async {
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      child: MaterialApp(
        home: Scaffold(
          body: GalleryThumbnail(
            isLoading: false,
            asset: asset,
            errorMessage: null,
            size: size,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GalleryThumbnail', () {
    testWidgets(
      'reuses thumbnail future for rebuilds with the same asset and size',
      (tester) async {
        final asset = _FakeThumbnailAssetEntity('asset-1');

        await _pumpThumbnail(tester, asset: asset);
        await _pumpThumbnail(tester, asset: asset);

        expect(asset.thumbnailCallCount, 1);
        expect(asset.lastRequestedSize, const ThumbnailSize.square(92));
      },
    );

    testWidgets('refreshes thumbnail future when the asset changes', (
      tester,
    ) async {
      final firstAsset = _FakeThumbnailAssetEntity('asset-1');
      final secondAsset = _FakeThumbnailAssetEntity('asset-2');

      await _pumpThumbnail(tester, asset: firstAsset);
      await _pumpThumbnail(tester, asset: secondAsset);

      expect(firstAsset.thumbnailCallCount, 1);
      expect(secondAsset.thumbnailCallCount, 1);
    });
  });
}
