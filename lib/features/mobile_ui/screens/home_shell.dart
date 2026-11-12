import 'dart:async';

import 'package:cc_dau_thau/app/theme/app_theme.dart';
import 'package:cc_dau_thau/features/ads/controllers/home_banner_controller.dart';
import 'package:cc_dau_thau/features/ads/domain/ad_banner_service.dart';
import 'package:cc_dau_thau/features/ads/widgets/top_anchored_ad_slot.dart';
import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_models.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_result.dart';
import 'package:cc_dau_thau/features/mobile_ui/controllers/app_state_controller.dart';
import 'package:cc_dau_thau/features/mobile_ui/screens/home_tab.dart';
import 'package:cc_dau_thau/features/study_progress/domain/models/progress_models.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Root 4-tab navigation shell opening directly to [HomeTab] without login.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.controller,
    this.adBannerService = const NoopAdBannerService(),
    this.routeObserver,
    this.studyTabBuilder,
    this.historyTabBuilder,
    this.settingsTabBuilder,
    this.onStartExamRequested,
    this.onStartStudyQuestionsRequested,
  });

  final AppStateController controller;
  final AdBannerService adBannerService;
  final RouteObserver<ModalRoute<void>>? routeObserver;
  final WidgetBuilder? studyTabBuilder;
  final WidgetBuilder? historyTabBuilder;
  final WidgetBuilder? settingsTabBuilder;
  final void Function(BuildContext context, GeneratedExam exam)?
      onStartExamRequested;
  final void Function(
    BuildContext context,
    String title,
    List<Question> questions, {
    bool isRevengeMode,
  })? onStartStudyQuestionsRequested;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with RouteAware {
  int _selectedIndex = 0;
  late final HomeBannerController _bannerController;
  ModalRoute<void>? _subscribedRoute;
  bool _didScheduleSettled = false;

  @override
  void initState() {
    super.initState();
    _bannerController = HomeBannerController(service: widget.adBannerService);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _subscribedRoute) {
      if (_subscribedRoute != null) {
        widget.routeObserver?.unsubscribe(this);
      }
      _subscribedRoute = route;
      if (route != null) {
        widget.routeObserver?.subscribe(this, route);
      }
    }

    final media = MediaQuery.of(context);
    unawaited(
      _bannerController.syncViewportAndLoad(
        widthDp: media.size.width.truncate(),
        orientation: media.orientation,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routeObserver != widget.routeObserver) {
      oldWidget.routeObserver?.unsubscribe(this);
      final route = _subscribedRoute;
      if (route != null) {
        widget.routeObserver?.subscribe(this, route);
      }
    }
  }

  @override
  void didPopNext() {
    _bannerController.onSafeNavigationBoundary();
  }

  @override
  void dispose() {
    widget.routeObserver?.unsubscribe(this);
    _bannerController.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    _bannerController.onSafeNavigationBoundary();
    setState(() => _selectedIndex = index);
  }

  void _scheduleContentSettledIfReady(AppStateController ctrl) {
    if (_didScheduleSettled || ctrl.isLoading || ctrl.startupError != null) {
      return;
    }
    _didScheduleSettled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _bannerController.markContentSettled();
      }
    });
  }

  Widget _buildAppBarTitle() {
    final tabTitle = switch (_selectedIndex) {
      1 => 'Ôn thi chuyên đề',
      2 => 'Lịch sử thi thử',
      3 => 'Cài đặt & Dữ liệu',
      _ => null,
    };

    if (tabTitle == null) {
      return Tooltip(
        message: 'Ôn luyện Chứng chỉ Đấu thầu',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/home_goal_emblem.png',
              height: 36,
              fit: BoxFit.contain,
              semanticLabel: 'Búa đấu thầu',
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'ÔN LUYỆN CCĐT',
                  maxLines: 1,
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Text(tabTitle);
  }

  void _handleStartExamResult(ExamResult<GeneratedExam> result) {
    switch (result) {
      case ExamError<GeneratedExam>(:final failure):
        _showMessage(failure.message);
      case ExamSuccess<GeneratedExam>(:final data):
        widget.onStartExamRequested?.call(context, data);
    }
  }

  Future<void> _startRevengeStudy() async {
    final weakQuestions = await widget.controller.loadWeakQueue();
    if (!mounted) return;
    if (weakQuestions.isEmpty) {
      _showMessage('Hiện không còn câu nào trong hàng đợi Phục thù.');
      return;
    }
    widget.onStartStudyQuestionsRequested?.call(
      context,
      'Phục thù câu sai (${weakQuestions.length} câu)',
      weakQuestions,
      isRevengeMode: true,
    );
  }

  void _startTopicStudy(TopicMasteryStatus status) {
    final bank = widget.controller.bank;
    if (bank == null) return;
    final questions = bank.questionsByTopicId[status.topicId] ?? const [];
    if (questions.isEmpty) {
      _showMessage('Chuyên đề này chưa có câu hỏi.');
      return;
    }
    widget.onStartStudyQuestionsRequested?.call(
      context,
      status.topicName,
      questions,
      isRevengeMode: false,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;

        Widget body;
        if (ctrl.isLoading) {
          body = const Center(child: CircularProgressIndicator());
        } else if (ctrl.startupError != null) {
          body = _StartupErrorView(
            message: ctrl.startupError!,
            onRetry: ctrl.initialize,
          );
        } else {
          _scheduleContentSettledIfReady(ctrl);
          final tabs = <Widget>[
            HomeTab(
              controller: ctrl,
              onStartMockExam: () =>
                  _handleStartExamResult(ctrl.createMockExam()),
              onOpenStudyTab: () => _selectTab(1),
              onStartRevengeStudy: _startRevengeStudy,
              onStartDiagnosticMiniTest: () =>
                  _handleStartExamResult(ctrl.createDiagnosticMiniTest()),
              onStartTopicStudy: _startTopicStudy,
            ),
            widget.studyTabBuilder?.call(context) ??
                const Center(child: Text('Ôn thi')),
            widget.historyTabBuilder?.call(context) ??
                const Center(child: Text('Lịch sử')),
            widget.settingsTabBuilder?.call(context) ??
                const Center(child: Text('Cài đặt')),
          ];
          body = IndexedStack(
            index: _selectedIndex,
            children: tabs,
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: _buildAppBarTitle(),
            actions: [
              if (ctrl.bank != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Chip(
                    backgroundColor: AppColors.surfaceTint,
                    side: const BorderSide(color: AppColors.borderSky),
                    label: Text(
                      '${ctrl.bank!.questions.length} câu',
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                TopAnchoredAdSlot(controller: _bannerController),
                Expanded(child: body),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _selectTab,
            destinations: const [
              NavigationDestination(
                icon: Icon(LucideIcons.house),
                label: 'Trang chủ',
              ),
              NavigationDestination(
                icon: Icon(LucideIcons.bookOpen),
                label: 'Ôn thi',
              ),
              NavigationDestination(
                icon: Icon(LucideIcons.history),
                label: 'Lịch sử',
              ),
              NavigationDestination(
                icon: Icon(LucideIcons.settings),
                label: 'Cài đặt',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StartupErrorView extends StatelessWidget {
  const _StartupErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.triangleAlert,
                  size: 36,
                  color: AppColors.weakFg,
                ),
                const SizedBox(height: 12),
                Text(
                  'Không thể nạp dữ liệu ngân hàng câu hỏi',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(LucideIcons.rotateCcw, size: 18),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
