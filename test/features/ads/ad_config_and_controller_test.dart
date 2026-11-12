import 'dart:async';

import 'package:cc_dau_thau/features/ads/controllers/home_banner_controller.dart';
import 'package:cc_dau_thau/features/ads/domain/ad_banner_service.dart';
import 'package:cc_dau_thau/features/ads/domain/ad_config.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAdBannerService implements AdBannerService {
  final List<({int widthDp, Orientation orientation})> loadCalls = [];
  Completer<LoadedAdBannerHandle?>? pendingCompleter;
  LoadedAdBannerHandle? nextResult;
  int disposeCount = 0;

  LoadedAdBannerHandle createHandle({
    double width = 390,
    double height = 56,
  }) {
    return LoadedAdBannerHandle(
      width: width,
      height: height,
      builder: (_) => SizedBox(width: width, height: height),
      onDispose: () => disposeCount++,
    );
  }

  @override
  bool get isSupportedOnCurrentPlatform => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<LoadedAdBannerHandle?> loadTopAnchoredBanner({
    required int widthDp,
    required Orientation orientation,
  }) {
    loadCalls.add((widthDp: widthDp, orientation: orientation));
    if (pendingCompleter != null) {
      return pendingCompleter!.future;
    }
    return Future<LoadedAdBannerHandle?>.value(nextResult);
  }
}

void main() {
  group('AdConfig', () {
    test('returns unsupported and null banner ID on macOS and Web', () async {
      expect(
        AdConfig.isMobileSupportedPlatform(
          isWebOverride: false,
          platformOverride: TargetPlatform.macOS,
        ),
        isFalse,
      );
      expect(
        await AdConfig.resolveBannerUnitId(
          isWebOverride: true,
          platformOverride: TargetPlatform.android,
        ),
        isNull,
      );
      expect(
        await AdConfig.resolveBannerUnitId(
          isWebOverride: false,
          platformOverride: TargetPlatform.macOS,
        ),
        isNull,
      );
    });

    test('uses test banner IDs in debug unless explicitly overridden', () async {
      const fakeNativeUnitId = 'ca-app-pub-0000000000000000/1111111111';

      final androidDebugId = await AdConfig.resolveBannerUnitId(
        isWebOverride: false,
        platformOverride: TargetPlatform.android,
        isDebugModeOverride: true,
        useProdInDebugOverride: false,
        androidNativeBannerIdLoader: () async => fakeNativeUnitId,
      );
      expect(androidDebugId, AdConfig.androidTestBannerUnitId);

      final androidForcedProdInDebug = await AdConfig.resolveBannerUnitId(
        isWebOverride: false,
        platformOverride: TargetPlatform.android,
        isDebugModeOverride: true,
        useProdInDebugOverride: true,
        androidDefineOverride: '',
        androidNativeBannerIdLoader: () async => fakeNativeUnitId,
      );
      expect(androidForcedProdInDebug, fakeNativeUnitId);
    });

    test('prefers dart-define over native manifest metadata in release mode',
        () async {
      const fakeNativeUnitId = 'ca-app-pub-0000000000000000/1111111111';

      final fromDefine = await AdConfig.resolveBannerUnitId(
        isWebOverride: false,
        platformOverride: TargetPlatform.android,
        isDebugModeOverride: false,
        androidDefineOverride: 'ca-app-pub-custom/define-unit',
        androidNativeBannerIdLoader: () async => fakeNativeUnitId,
      );
      expect(fromDefine, 'ca-app-pub-custom/define-unit');

      final fromNativeLocalProps = await AdConfig.resolveBannerUnitId(
        isWebOverride: false,
        platformOverride: TargetPlatform.android,
        isDebugModeOverride: false,
        androidDefineOverride: '',
        androidNativeBannerIdLoader: () async => fakeNativeUnitId,
      );
      expect(fromNativeLocalProps, fakeNativeUnitId);

      final iosReleaseDefault = await AdConfig.resolveBannerUnitId(
        isWebOverride: false,
        platformOverride: TargetPlatform.iOS,
        isDebugModeOverride: false,
        iosDefineOverride: '',
        iosNativeBannerIdLoader: () async => null,
      );
      expect(iosReleaseDefault, AdConfig.iosTestBannerUnitId);

      final iosNativeInRelease = await AdConfig.resolveBannerUnitId(
        isWebOverride: false,
        platformOverride: TargetPlatform.iOS,
        isDebugModeOverride: false,
        iosDefineOverride: '',
        iosNativeBannerIdLoader: () async => fakeNativeUnitId,
      );
      expect(iosNativeInRelease, fakeNativeUnitId);

      final iosDefineOverridesNative = await AdConfig.resolveBannerUnitId(
        isWebOverride: false,
        platformOverride: TargetPlatform.iOS,
        isDebugModeOverride: false,
        iosDefineOverride: 'ca-app-pub-custom/ios-define-unit',
        iosNativeBannerIdLoader: () async => fakeNativeUnitId,
      );
      expect(iosDefineOverridesNative, 'ca-app-pub-custom/ios-define-unit');

      final forcedTestAdsInRelease = await AdConfig.resolveBannerUnitId(
        isWebOverride: false,
        platformOverride: TargetPlatform.android,
        isDebugModeOverride: false,
        useTestAdsOverride: true,
        androidDefineOverride: 'ca-app-pub-custom/define-unit',
        androidNativeBannerIdLoader: () async => fakeNativeUnitId,
      );
      expect(forcedTestAdsInRelease, AdConfig.androidTestBannerUnitId);
    });
  });

  group('HomeBannerController Safe Reveal Gate', () {
    test('does nothing on unsupported platforms (Noop)', () async {
      final controller = HomeBannerController(
        service: const NoopAdBannerService(),
      );
      addTearDown(controller.dispose);

      await controller.syncViewportAndLoad(
        widthDp: 390,
        orientation: Orientation.portrait,
      );
      controller.onSafeNavigationBoundary();

      expect(controller.hasActiveBanner, isFalse);
      expect(controller.hasQueuedBanner, isFalse);
    });

    test('queues late banner after content settles until navigation boundary',
        () async {
      final service = _FakeAdBannerService();
      final completer = Completer<LoadedAdBannerHandle?>();
      service.pendingCompleter = completer;

      final controller = HomeBannerController(service: service);
      addTearDown(controller.dispose);

      final loadFuture = controller.syncViewportAndLoad(
        widthDp: 390,
        orientation: Orientation.portrait,
      );
      controller.markContentSettled();

      completer.complete(service.createHandle(height: 58));
      await loadFuture;

      expect(controller.hasActiveBanner, isFalse);
      expect(controller.hasQueuedBanner, isTrue);

      controller.onSafeNavigationBoundary();

      expect(controller.hasQueuedBanner, isFalse);
      expect(controller.hasActiveBanner, isTrue);
      expect(controller.activeBanner!.height, 58);
    });

    test('reveals immediately if loaded before content settles', () async {
      final service = _FakeAdBannerService();
      service.nextResult = service.createHandle(height: 54);

      final controller = HomeBannerController(service: service);
      addTearDown(controller.dispose);

      await controller.syncViewportAndLoad(
        widthDp: 360,
        orientation: Orientation.portrait,
      );

      expect(controller.hasActiveBanner, isTrue);
      expect(controller.hasQueuedBanner, isFalse);
      expect(controller.activeBanner!.height, 54);
    });

    test('throttles offline retries and disposes handles on replacement/dispose',
        () async {
      var now = DateTime(2026, 11, 12, 12, 0);
      final service = _FakeAdBannerService()..nextResult = null;
      final controller = HomeBannerController(
        service: service,
        nowProvider: () => now,
        retryCooldown: const Duration(seconds: 60),
      );

      await controller.syncViewportAndLoad(
        widthDp: 390,
        orientation: Orientation.portrait,
      );
      expect(service.loadCalls, hasLength(1));
      expect(controller.hasActiveBanner, isFalse);

      // Within cooldown: navigation boundary should NOT spam ad requests.
      now = now.add(const Duration(seconds: 30));
      controller.onSafeNavigationBoundary();
      expect(service.loadCalls, hasLength(1));

      // Past cooldown: retries and succeeds cleanly.
      service.nextResult = service.createHandle(width: 390, height: 52);
      now = now.add(const Duration(seconds: 31));
      controller.onSafeNavigationBoundary();
      await Future<void>.delayed(Duration.zero);

      expect(service.loadCalls, hasLength(2));
      expect(controller.hasActiveBanner, isTrue);

      // Orientation change refreshes banner and disposes old handle.
      service.nextResult = service.createHandle(width: 780, height: 60);
      await controller.syncViewportAndLoad(
        widthDp: 780,
        orientation: Orientation.landscape,
      );
      expect(service.disposeCount, 1);
      expect(controller.activeBanner!.width, 780);

      controller.dispose();
      expect(service.disposeCount, 2);
    });
  });
}
