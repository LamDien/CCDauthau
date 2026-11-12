import 'package:flutter/widgets.dart';

/// UI-facing handle for a loaded banner advertisement.
class LoadedAdBannerHandle {
  const LoadedAdBannerHandle({
    required this.width,
    required this.height,
    required this.builder,
    required this.onDispose,
  });

  final double width;
  final double height;
  final WidgetBuilder builder;
  final VoidCallback onDispose;

  /// Releases native resources associated with this banner instance.
  void dispose() => onDispose();
}

/// Platform-agnostic contract for initializing and loading banner ads.
abstract class AdBannerService {
  /// Returns true only on mobile platforms supported by Google Mobile Ads.
  bool get isSupportedOnCurrentPlatform;

  /// Initializes the ad SDK once per process when supported.
  Future<void> initialize();

  /// Loads a compact top-anchored banner sized for [widthDp] and [orientation].
  ///
  /// Returns `null` when unsupported, offline, or when loading fails.
  Future<LoadedAdBannerHandle?> loadTopAnchoredBanner({
    required int widthDp,
    required Orientation orientation,
  });
}

/// No-op implementation used on unsupported platforms (macOS/web) and tests.
class NoopAdBannerService implements AdBannerService {
  const NoopAdBannerService();

  @override
  bool get isSupportedOnCurrentPlatform => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<LoadedAdBannerHandle?> loadTopAnchoredBanner({
    required int widthDp,
    required Orientation orientation,
  }) async =>
      null;
}

