import 'dart:async';

import 'package:cc_dau_thau/features/ads/domain/ad_banner_service.dart';
import 'package:flutter/widgets.dart';

/// Coordinates loading and **Safe Reveal Gate** promotion for the single
/// top-anchored banner in `HomeShell`.
///
/// If an ad finishes loading after home content has settled on screen, it stays
/// queued rather than shifting buttons down mid-tap, and only reveals at the
/// next navigation boundary (tab switch or returning from exam/study screens).
class HomeBannerController extends ChangeNotifier {
  HomeBannerController({
    required this.service,
    DateTime Function()? nowProvider,
    this.retryCooldown = const Duration(seconds: 60),
  }) : _now = nowProvider ?? DateTime.now;

  final AdBannerService service;
  final DateTime Function() _now;
  final Duration retryCooldown;

  LoadedAdBannerHandle? _activeBanner;
  LoadedAdBannerHandle? _queuedBanner;
  bool _contentSettled = false;
  bool _isLoading = false;
  DateTime? _lastFailureAt;
  int? _lastWidthDp;
  Orientation? _lastOrientation;
  int _requestGeneration = 0;
  bool _disposed = false;

  LoadedAdBannerHandle? get activeBanner => _activeBanner;
  bool get hasActiveBanner => _activeBanner != null;
  bool get hasQueuedBanner => _queuedBanner != null;
  bool get isLoading => _isLoading;

  /// Marks that the primary `HomeTab` actions have rendered to the user.
  void markContentSettled() {
    _contentSettled = true;
  }

  /// Ensures a banner matching the current viewport width/orientation is loaded.
  Future<void> syncViewportAndLoad({
    required int widthDp,
    required Orientation orientation,
  }) async {
    if (_disposed || !service.isSupportedOnCurrentPlatform || widthDp <= 0) {
      return;
    }

    final sameViewport =
        _lastWidthDp == widthDp && _lastOrientation == orientation;
    if (sameViewport &&
        (_isLoading || _activeBanner != null || _queuedBanner != null)) {
      return;
    }
    if (sameViewport && !_canRetryFailure()) {
      return;
    }

    _lastWidthDp = widthDp;
    _lastOrientation = orientation;
    await _startLoad(widthDp: widthDp, orientation: orientation);
  }

  /// Promotes any queued banner on tab switch or return from full-screen routes,
  /// and retries failed loads once the retry cooldown has elapsed.
  void onSafeNavigationBoundary() {
    if (_disposed || !service.isSupportedOnCurrentPlatform) return;

    if (_queuedBanner != null) {
      final promoted = _queuedBanner!;
      _queuedBanner = null;
      _setActiveBanner(promoted);
      notifyListeners();
      return;
    }

    final widthDp = _lastWidthDp;
    final orientation = _lastOrientation;
    if (_activeBanner == null &&
        !_isLoading &&
        widthDp != null &&
        orientation != null &&
        _canRetryFailure()) {
      unawaited(_startLoad(widthDp: widthDp, orientation: orientation));
    }
  }

  bool _canRetryFailure() {
    final failedAt = _lastFailureAt;
    if (failedAt == null) return true;
    return _now().difference(failedAt) >= retryCooldown;
  }

  Future<void> _startLoad({
    required int widthDp,
    required Orientation orientation,
  }) async {
    final generation = ++_requestGeneration;
    _isLoading = true;

    LoadedAdBannerHandle? loaded;
    try {
      loaded = await service.loadTopAnchoredBanner(
        widthDp: widthDp,
        orientation: orientation,
      );
    } catch (_) {
      loaded = null;
    } finally {
      if (generation == _requestGeneration) {
        _isLoading = false;
      }
    }

    if (_disposed || generation != _requestGeneration) {
      loaded?.dispose();
      return;
    }

    if (loaded == null) {
      _lastFailureAt = _now();
      return;
    }

    _lastFailureAt = null;
    if (_activeBanner != null || !_contentSettled) {
      // Slot is already open (e.g., orientation refresh) or content is not yet
      // settled, so showing immediately will not jump under the user's thumb.
      _replaceQueuedBanner(null);
      _setActiveBanner(loaded);
      notifyListeners();
      return;
    }

    // Hold in queue to prevent shifting HomeTab CTA buttons downward mid-tap.
    _replaceQueuedBanner(loaded);
  }

  void _setActiveBanner(LoadedAdBannerHandle? next) {
    final previous = _activeBanner;
    _activeBanner = next;
    if (!identical(previous, next)) {
      previous?.dispose();
    }
  }

  void _replaceQueuedBanner(LoadedAdBannerHandle? next) {
    final previous = _queuedBanner;
    _queuedBanner = next;
    if (!identical(previous, next)) {
      previous?.dispose();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _requestGeneration++;
    _activeBanner?.dispose();
    _activeBanner = null;
    _queuedBanner?.dispose();
    _queuedBanner = null;
    super.dispose();
  }
}
