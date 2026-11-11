import 'package:cc_dau_thau/app/theme/app_theme.dart';
import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:cc_dau_thau/features/mobile_ui/controllers/app_state_controller.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Hub for choosing study sources: weak queue, bookmarks, manual picker, or 1/multi topics.
class StudyTab extends StatefulWidget {
  const StudyTab({
    super.key,
    required this.controller,
    required this.onStartQuestions,
    required this.onOpenManualPicker,
  });

  final AppStateController controller;
  final void Function(
    String title,
    List<Question> questions, {
    bool isRevengeMode,
  }) onStartQuestions;
  final VoidCallback onOpenManualPicker;

  @override
  State<StudyTab> createState() => _StudyTabState();
}

class _StudyTabState extends State<StudyTab> {
  final Set<String> _selectedTopicIds = {};

  Future<void> _startWeakQueue() async {
    final questions = await widget.controller.loadWeakQueue();
    if (!mounted) return;
    if (questions.isEmpty) {
      _showNotice('Tuyệt vời! Bạn không còn câu nào trong hàng đợi câu sai.');
      return;
    }
    widget.onStartQuestions(
      'Phục thù câu sai (${questions.length} câu)',
      questions,
      isRevengeMode: true,
    );
  }

  Future<void> _startBookmarks() async {
    final questions = await widget.controller.loadBookmarkedQuestions();
    if (!mounted) return;
    if (questions.isEmpty) {
      _showNotice('Bạn chưa đánh dấu sao câu hỏi nào.');
      return;
    }
    widget.onStartQuestions(
      'Danh sách tự chọn (${questions.length} câu)',
      questions,
      isRevengeMode: false,
    );
  }

  void _startSelectedTopics(QuestionBank bank) {
    final chosen = bank.questions
        .where((q) => _selectedTopicIds.contains(q.topicId))
        .toList();
    if (chosen.isEmpty) return;
    widget.onStartQuestions(
      'Ôn ${_selectedTopicIds.length} chuyên đề (${chosen.length} câu)',
      chosen,
      isRevengeMode: false,
    );
  }

  void _showNotice(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bank = widget.controller.bank;
    final summary = widget.controller.summary;
    if (bank == null || summary == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final selectedCount = bank.questions
        .where((q) => _selectedTopicIds.contains(q.topicId))
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _SourceCard(
          icon: LucideIcons.triangleAlert,
          iconBg: AppColors.weakBg,
          iconColor: AppColors.weakFg,
          title: 'Phục thù câu sai',
          subtitle:
              '${summary.weakQueueCount} câu cần đúng ${widget.controller.settings.revengeRequiredStreak} lần liên tiếp để gỡ',
          onTap: _startWeakQueue,
        ),
        const SizedBox(height: 10),
        _SourceCard(
          icon: LucideIcons.bookmark,
          iconBg: AppColors.surfaceTint,
          iconColor: AppColors.primaryDark,
          title: 'Danh sách đánh dấu sao',
          subtitle: '${summary.bookmarkedCount} câu đã lưu để ôn riêng',
          onTap: _startBookmarks,
        ),
        const SizedBox(height: 10),
        _SourceCard(
          icon: LucideIcons.listChecks,
          iconBg: AppColors.surfaceTint,
          iconColor: AppColors.primaryDark,
          title: 'Chọn câu hỏi thủ công từ danh sách',
          subtitle: 'Tìm kiếm từ khóa, lọc chuyên đề và tích chọn tùy ý',
          onTap: widget.onOpenManualPicker,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                'Ôn theo chuyên đề (${bank.topics.length})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (_selectedTopicIds.isNotEmpty)
              TextButton(
                onPressed: () => setState(_selectedTopicIds.clear),
                child: const Text('Bỏ chọn'),
              ),
          ],
        ),
        Text(
          'Chạm trực tiếp vào tên chuyên đề để học ngay, hoặc tích chọn nhiều chuyên đề để gộp chung.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        if (_selectedTopicIds.isNotEmpty) ...[
          FilledButton.icon(
            onPressed: () => _startSelectedTopics(bank),
            icon: const Icon(LucideIcons.bookOpen, size: 18),
            label: Text(
              'Ôn ${_selectedTopicIds.length} chuyên đề đã chọn ($selectedCount câu)',
            ),
          ),
          const SizedBox(height: 12),
        ],
        for (var i = 0; i < bank.topics.length; i++) ...[
          _TopicPickerRow(
            topic: bank.topics[i],
            selected: _selectedTopicIds.contains(bank.topics[i].id),
            onToggleSelect: (val) {
              setState(() {
                if (val) {
                  _selectedTopicIds.add(bank.topics[i].id);
                } else {
                  _selectedTopicIds.remove(bank.topics[i].id);
                }
              });
            },
            onOpenSingleTopic: () {
              final qs = bank.questionsByTopicId[bank.topics[i].id] ?? const [];
              widget.onStartQuestions(
                bank.topics[i].name,
                qs,
                isRevengeMode: false,
              );
            },
          ),
          if (i < bank.topics.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                color: AppColors.textSecondary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopicPickerRow extends StatelessWidget {
  const _TopicPickerRow({
    required this.topic,
    required this.selected,
    required this.onToggleSelect,
    required this.onOpenSingleTopic,
  });

  final Topic topic;
  final bool selected;
  final ValueChanged<bool> onToggleSelect;
  final VoidCallback onOpenSingleTopic;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onOpenSingleTopic,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: (v) => onToggleSelect(v ?? false),
                activeColor: AppColors.primary,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.name,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(
                      '${topic.questionCount} câu hỏi',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 12.5,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                color: AppColors.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

