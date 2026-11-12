import 'dart:async';

import 'package:cc_dau_thau/features/ads/domain/ad_banner_service.dart';
import 'package:cc_dau_thau/features/ads/domain/ad_config.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Google Mobile Ads implementation restricted to Android and iOS.
class GoogleMobileAdsBannerService implements AdBannerService {
  GoogleMobileAdsBannerService({
    this.maxTopBannerHeightDp = 64.0,
    this.loadTimeout = const Duration(seconds: 15),
  });

  /// Upper bound preventing taller banner variants from crowding `HomeShell`.
  final double maxTopBannerHeightDp;
  final Duration loadTimeout;

  Future<void>? _initializeFuture;

  @override
  bool get isSupportedOnCurrentPlatform => AdConfig.isMobileSupportedPlatform();

  @override
  Future<void> initialize() {
    if (!isSupportedOnCurrentPlatform) return Future<void>.value();
    return _initializeFuture ??= _initializeInternal();
  }

  Future<void> _initializeInternal() async {
    try {
      await MobileAds.instance.initialize();
    } catch (error) {
      // Allow graceful retry if transient initialization error occurs.
      _initializeFuture = null;
      debugPrint('AdMob initialize skipped: $error');
    }
  }

  @override
  Future<LoadedAdBannerHandle?> loadTopAnchoredBanner({
    required int widthDp,
    required Orientation orientation,
  }) async {
    if (!isSupportedOnCurrentPlatform || widthDp <= 0) return null;

    await initialize();
    final adUnitId = await AdConfig.resolveBannerUnitId();
    if (adUnitId == null || adUnitId.isEmpty) return null;

    final adSize = await _resolveCompactAnchoredSize(widthDp, orientation);
    final completer = Completer<LoadedAdBannerHandle?>();
    late final BannerAd bannerAd;

    final timer = Timer(loadTimeout, () {
      if (!completer.isCompleted) {
        unawaited(bannerAd.dispose());
        completer.complete(null);
      }
    });

    bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: adSize,
      request: const AdRequest(nonPersonalizedAds: true),
      listener: BannerAdListener(
        onAdLoaded: (ad) async {
          timer.cancel();
          final loaded = ad as BannerAd;
          if (completer.isCompleted) {
            await loaded.dispose();
            return;
          }
          final platformSize = await loaded.getPlatformAdSize();
          final resolved = platformSize ?? loaded.size;
          completer.complete(
            LoadedAdBannerHandle(
              width: resolved.width.toDouble(),
              height: resolved.height.toDouble(),
              builder: (_) => AdWidget(
                key: ObjectKey(loaded),
                ad: loaded,
              ),
              onDispose: () => unawaited(loaded.dispose()),
            ),
          );
        },
        onAdFailedToLoad: (ad, error) {
          timer.cancel();
          unawaited(ad.dispose());
          if (!completer.isCompleted) {
            debugPrint('AdMob banner failed to load: ${error.message}');
            completer.complete(null);
          }
        },
      ),
    );

    try {
      await bannerAd.load();
    } catch (error) {
      timer.cancel();
      await bannerAd.dispose();
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }

    return completer.future;
  }

  Future<AdSize> _resolveCompactAnchoredSize(
    int widthDp,
    Orientation orientation,
  ) async {
    try {
      final adaptive =
          await AdSize.getLargeAnchoredAdaptiveBannerAdSizeWithOrientation(
        orientation,
        widthDp,
      );
      if (adaptive != null && adaptive.height <= maxTopBannerHeightDp) {
        return adaptive;
      }
    } catch (_) {
      // Fallback safely to fixed compact banner size when SDK query fails.
    }
    if (widthDp >= AdSize.fullBanner.width) {
      return AdSize.fullBanner;
    }
    return AdSize.banner;
  }
}

