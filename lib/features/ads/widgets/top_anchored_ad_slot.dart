import 'package:cc_dau_thau/app/theme/app_theme.dart';
import 'package:cc_dau_thau/features/ads/controllers/home_banner_controller.dart';
import 'package:flutter/material.dart';

/// Top-anchored banner slot below `HomeShell`'s `AppBar`.
///
/// Collapses to zero height (`SizedBox.shrink`) when offline, unsupported, or
/// deferred by [HomeBannerController] to prevent layout shift.
class TopAnchoredAdSlot extends StatelessWidget {
  const TopAnchoredAdSlot({
    super.key,
    required this.controller,
  });

  final HomeBannerController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final banner = controller.activeBanner;
        if (banner == null) {
          return const SizedBox.shrink();
        }

        return Material(
          color: AppColors.surfaceCard,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              Center(
                child: Semantics(
                  container: true,
                  label: 'Quảng cáo tài trợ',
                  child: SizedBox(
                    width: banner.width,
                    height: banner.height,
                    child: banner.builder(context),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Divider(
                height: 1,
                thickness: 1,
                color: AppColors.borderSky.withValues(alpha: 0.45),
              ),
            ],
          ),
        );
      },
    );
  }
}

