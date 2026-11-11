import 'package:cc_dau_thau/app/theme/app_theme.dart';
import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Multi-select searchable picker allowing users to hand-pick questions for practice.
class ManualPickerScreen extends StatefulWidget {
  const ManualPickerScreen({
    super.key,
    required this.bank,
    required this.onStartSelectedStudy,
  });

  final QuestionBank bank;
  final void Function(List<Question> selectedQuestions) onStartSelectedStudy;

  @override
  State<ManualPickerScreen> createState() => _ManualPickerScreenState();
}

class _ManualPickerScreenState extends State<ManualPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _selectedTopicId;
  final Set<String> _selectedCodes = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Question> get _filteredQuestions {
    final lowerQuery = _query.trim().toLowerCase();
    return widget.bank.questions.where((q) {
      if (_selectedTopicId != null && q.topicId != _selectedTopicId) {
        return false;
      }
      if (lowerQuery.isEmpty) return true;
      return q.stem.toLowerCase().contains(lowerQuery) ||
          q.code.toLowerCase().contains(lowerQuery) ||
          q.topicName.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredQuestions;
    final selectedList = widget.bank.questions
        .where((q) => _selectedCodes.contains(q.code))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn câu hỏi thủ công'),
        actions: [
          if (_selectedCodes.isNotEmpty)
            TextButton(
              onPressed: () => setState(_selectedCodes.clear),
              child: const Text('Bỏ chọn'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: AppColors.surfaceCard,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'Tìm theo nội dung hoặc mã câu hỏi...',
                      prefixIcon: const Icon(LucideIcons.search, size: 18),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(LucideIcons.x, size: 18),
                            ),
                      filled: true,
                      fillColor: AppColors.scaffoldBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.borderSky),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.borderSky),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: _selectedTopicId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            filled: true,
                            fillColor: AppColors.scaffoldBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: AppColors.borderSky),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: AppColors.borderSky),
                            ),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Tất cả 13 chuyên đề'),
                            ),
                            for (final topic in widget.bank.topics)
                              DropdownMenuItem<String?>(
                                value: topic.id,
                                child: Text(
                                  topic.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedTopicId = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: filtered.isEmpty
                            ? null
                            : () {
                                setState(() {
                                  for (final q in filtered) {
                                    _selectedCodes.add(q.code);
                                  }
                                });
                              },
                        child: const Text('Chọn lọc'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('Không tìm thấy câu hỏi phù hợp.'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final q = filtered[index];
                        final checked = _selectedCodes.contains(q.code);
                        return Card(
                          child: CheckboxListTile(
                            value: checked,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedCodes.add(q.code);
                                } else {
                                  _selectedCodes.remove(q.code);
                                }
                              });
                            },
                            activeColor: AppColors.primary,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              q.stem,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            subtitle: Text(
                              '${q.code} • ${q.topicName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Container(
              color: AppColors.surfaceCard,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: selectedList.isEmpty
                    ? null
                    : () => widget.onStartSelectedStudy(selectedList),
                icon: const Icon(LucideIcons.listChecks, size: 19),
                label: Text(
                  'Ôn ngay (${selectedList.length} câu đã chọn)',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

