import 'dart:async';

import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:soi/api/services/camera_service.dart';

class _CallCounter {
  int value = 0;

  void increment() => value++;
}

class _FakeAssetEntity extends Fake implements AssetEntity {
  _FakeAssetEntity(this.assetId);

  final String assetId;

  @override
  String get id => assetId;
}

class _FakeAssetPathEntity extends Fake implements AssetPathEntity {
  _FakeAssetPathEntity(this.assets);

  final List<AssetEntity> assets;
  final _getAssetListCounter = _CallCounter();

  int get getAssetListCallCount => _getAssetListCounter.value;

  @override
  Future<List<AssetEntity>> getAssetListPaged({
    required int page,
    required int size,
  }) async {
    _getAssetListCounter.increment();
    return assets.take(size).toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CameraService', () {
    test(
      'returns cached first gallery image within ttl and refetches after expiry',
      () async {
        var now = DateTime(2026, 3, 21, 9, 0, 0);
        var permissionCallCount = 0;
        var pathListCallCount = 0;
        final pathEntities = <_FakeAssetPathEntity>[
          _FakeAssetPathEntity([_FakeAssetEntity('asset-1')]),
          _FakeAssetPathEntity([_FakeAssetEntity('asset-2')]),
        ];

        final service = CameraService.testable(
          requestGalleryPermission: () async {
            permissionCallCount++;
            return PermissionState.authorized;
          },
          getAssetPathList:
              ({
                bool onlyAll = false,
                RequestType type = RequestType.common,
                PMFilter? filterOption,
              }) async {
                pathListCallCount++;
                return [pathEntities[pathListCallCount - 1]];
              },
          now: () => now,
        );

        final first = await service.getFirstGalleryImage();
        final second = await service.getFirstGalleryImage();

        expect(first?.id, 'asset-1');
        expect(second?.id, 'asset-1');
        expect(permissionCallCount, 1);
        expect(pathListCallCount, 1);
        expect(pathEntities.first.getAssetListCallCount, 1);

        now = now.add(const Duration(seconds: 6));

        final third = await service.getFirstGalleryImage();

        expect(third?.id, 'asset-2');
        expect(permissionCallCount, 1);
        expect(pathListCallCount, 2);
        expect(pathEntities.last.getAssetListCallCount, 1);
      },
    );

    test('caches denied gallery permission state for ten seconds', () async {
      var now = DateTime(2026, 3, 21, 9, 0, 0);
      var permissionCallCount = 0;
      var pathListCallCount = 0;

      final service = CameraService.testable(
        requestGalleryPermission: () async {
          permissionCallCount++;
          return PermissionState.denied;
        },
        getAssetPathList:
            ({
              bool onlyAll = false,
              RequestType type = RequestType.common,
              PMFilter? filterOption,
            }) async {
              pathListCallCount++;
              return const [];
            },
        now: () => now,
      );

      expect(await service.getFirstGalleryImage(), isNull);
      expect(await service.getFirstGalleryImage(), isNull);
      expect(permissionCallCount, 1);
      expect(pathListCallCount, 0);

      now = now.add(const Duration(seconds: 11));

      expect(await service.getFirstGalleryImage(), isNull);
      expect(permissionCallCount, 2);
      expect(pathListCallCount, 0);
    });

    test('dedupes in-flight first gallery image requests', () async {
      var permissionCallCount = 0;
      var pathListCallCount = 0;
      final pathCompleter = Completer<List<AssetPathEntity>>();
      final service = CameraService.testable(
        requestGalleryPermission: () async {
          permissionCallCount++;
          return PermissionState.authorized;
        },
        getAssetPathList:
            ({
              bool onlyAll = false,
              RequestType type = RequestType.common,
              PMFilter? filterOption,
            }) {
              pathListCallCount++;
              return pathCompleter.future;
            },
        now: () => DateTime(2026, 3, 21, 9, 0, 0),
      );

      final firstFuture = service.getFirstGalleryImage();
      final secondFuture = service.getFirstGalleryImage();

      await Future<void>.delayed(Duration.zero);

      expect(permissionCallCount, 1);
      expect(pathListCallCount, 1);

      final asset = _FakeAssetEntity('asset-1');
      pathCompleter.complete([
        _FakeAssetPathEntity([asset]),
      ]);

      final results = await Future.wait([firstFuture, secondFuture]);

      expect(results[0]?.id, 'asset-1');
      expect(results[1]?.id, 'asset-1');
      expect(identical(results[0], results[1]), isTrue);
    });

    test(
      'invalidates first gallery image cache so next call fetches fresh asset',
      () async {
        var now = DateTime(2026, 3, 21, 9, 0, 0);
        var pathListCallCount = 0;
        final pathEntities = <_FakeAssetPathEntity>[
          _FakeAssetPathEntity([_FakeAssetEntity('asset-1')]),
          _FakeAssetPathEntity([_FakeAssetEntity('asset-2')]),
        ];

        final service = CameraService.testable(
          requestGalleryPermission: () async => PermissionState.authorized,
          getAssetPathList:
              ({
                bool onlyAll = false,
                RequestType type = RequestType.common,
                PMFilter? filterOption,
              }) async {
                pathListCallCount++;
                return [pathEntities[pathListCallCount - 1]];
              },
          now: () => now,
        );

        final first = await service.getFirstGalleryImage();
        expect(first?.id, 'asset-1');
        expect(pathListCallCount, 1);

        service.invalidateGalleryCache();

        final second = await service.getFirstGalleryImage();
        expect(second?.id, 'asset-2');
        expect(pathListCallCount, 2);
      },
    );

    test(
      'prepareSessionIfPermitted warms camera first and upgrades recording warmup when microphone becomes granted',
      () async {
        var microphoneGranted = false;
        final preparedRecordingFlags = <bool>[];

        final service = CameraService.testable(
          requestGalleryPermission: () async => PermissionState.authorized,
          getAssetPathList:
              ({
                bool onlyAll = false,
                RequestType type = RequestType.common,
                PMFilter? filterOption,
              }) async => const [],
          now: () => DateTime(2026, 3, 21, 9, 0, 0),
          loadCameraPermissionStatus: () async => PermissionStatus.granted,
          loadMicrophonePermissionStatus: () async {
            return microphoneGranted
                ? PermissionStatus.granted
                : PermissionStatus.denied;
          },
          prepareCaptureResources: ({required bool prepareRecording}) async {
            preparedRecordingFlags.add(prepareRecording);
          },
        );

        await service.prepareSessionIfPermitted();
        await service.prepareSessionIfPermitted();

        microphoneGranted = true;

        await service.prepareSessionIfPermitted();
        await service.prepareSessionIfPermitted();

        expect(preparedRecordingFlags, [false, true]);
      },
    );

    test('prepareSessionIfPermitted dedupes in-flight warmup calls', () async {
      final warmupCompleter = Completer<void>();
      var warmupCallCount = 0;

      final service = CameraService.testable(
        requestGalleryPermission: () async => PermissionState.authorized,
        getAssetPathList:
            ({
              bool onlyAll = false,
              RequestType type = RequestType.common,
              PMFilter? filterOption,
            }) async => const [],
        now: () => DateTime(2026, 3, 21, 9, 0, 0),
        loadCameraPermissionStatus: () async => PermissionStatus.granted,
        loadMicrophonePermissionStatus: () async => PermissionStatus.granted,
        prepareCaptureResources: ({required bool prepareRecording}) {
          warmupCallCount++;
          return warmupCompleter.future;
        },
      );

      final first = service.prepareSessionIfPermitted();
      final second = service.prepareSessionIfPermitted();

      await Future<void>.delayed(Duration.zero);

      expect(warmupCallCount, 1);

      warmupCompleter.complete();

      await Future.wait([first, second]);
    });
  });
}
