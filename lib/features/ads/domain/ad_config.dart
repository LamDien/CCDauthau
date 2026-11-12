import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Resolves Google AdMob Ad Unit configuration cleanly across platforms.
///
/// Android production IDs are read from Gradle `local.properties` via
/// `AndroidManifest.xml` metadata (or `--dart-define=ADMOB_ANDROID_BANNER_ID`).
/// Debug builds default to Google's official test banner IDs to prevent
/// accidental invalid-traffic policy violations during development.
abstract final class AdConfig {
  static const String androidTestBannerUnitId =
      'ca-app-pub-3940256099942544/9214589741';
  static const String iosTestBannerUnitId =
      'ca-app-pub-3940256099942544/2435281174';

  static const String _dartDefineAndroidBannerId =
      String.fromEnvironment('ADMOB_ANDROID_BANNER_ID');
  static const String _dartDefineIosBannerId =
      String.fromEnvironment('ADMOB_IOS_BANNER_ID');
  static const bool _useProdInDebug =
      bool.fromEnvironment('ADMOB_USE_PROD_IN_DEBUG');
  static const bool _useTestAds =
      bool.fromEnvironment('ADMOB_USE_TEST_ADS');

  static const MethodChannel _channel =
      MethodChannel('vn.ccdauthau/ad_config');

  /// Whether Google Mobile Ads should run on the given target platform.
  static bool isMobileSupportedPlatform({
    bool? isWebOverride,
    TargetPlatform? platformOverride,
  }) {
    final isWeb = isWebOverride ?? kIsWeb;
    if (isWeb) return false;
    final platform = platformOverride ?? defaultTargetPlatform;
    return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
  }

  /// Resolves the banner Ad Unit ID for the current platform and build mode.
  static Future<String?> resolveBannerUnitId({
    bool? isWebOverride,
    TargetPlatform? platformOverride,
    bool? isDebugModeOverride,
    bool? useProdInDebugOverride,
    bool? useTestAdsOverride,
    String? androidDefineOverride,
    String? iosDefineOverride,
    Future<String?> Function()? androidNativeBannerIdLoader,
  }) async {
    final isWeb = isWebOverride ?? kIsWeb;
    final platform = platformOverride ?? defaultTargetPlatform;
    if (!isMobileSupportedPlatform(
      isWebOverride: isWeb,
      platformOverride: platform,
    )) {
      return null;
    }

    final forceTestAds = useTestAdsOverride ?? _useTestAds;
    if (forceTestAds) {
      return platform == TargetPlatform.android
          ? androidTestBannerUnitId
          : iosTestBannerUnitId;
    }

    final isDebug = isDebugModeOverride ?? kDebugMode;
    final allowProdInDebug = useProdInDebugOverride ?? _useProdInDebug;
    if (isDebug && !allowProdInDebug) {
      return platform == TargetPlatform.android
          ? androidTestBannerUnitId
          : iosTestBannerUnitId;
    }

    if (platform == TargetPlatform.android) {
      final defineId =
          (androidDefineOverride ?? _dartDefineAndroidBannerId).trim();
      if (defineId.isNotEmpty) return defineId;

      final nativeLoader =
          androidNativeBannerIdLoader ?? _readAndroidManifestBannerId;
      final nativeId = (await nativeLoader())?.trim();
      if (nativeId != null && nativeId.isNotEmpty) return nativeId;

      return androidTestBannerUnitId;
    }

    final iosDefineId = (iosDefineOverride ?? _dartDefineIosBannerId).trim();
    if (iosDefineId.isNotEmpty) return iosDefineId;
    return iosTestBannerUnitId;
  }

  static Future<String?> _readAndroidManifestBannerId() async {
    try {
      final config =
          await _channel.invokeMapMethod<String, dynamic>('getAdConfig');
      final value = config?['bannerUnitId'];
      return value is String ? value : null;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

