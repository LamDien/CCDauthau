import 'dart:typed_data';

import 'package:cc_dau_thau/app/theme/app_theme.dart';
import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:cc_dau_thau/features/data_vault/domain/models/vault_result.dart';
import 'package:cc_dau_thau/features/mobile_ui/controllers/app_state_controller.dart';
import 'package:cc_dau_thau/features/study_progress/domain/models/progress_models.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// File name + raw bytes returned by the system file picker or test double.
class PickedBankFile {
  const PickedBankFile({
    required this.fileName,
    required this.bytes,
  });

  final String fileName;
  final Uint8List bytes;
}

/// Settings and offline vault management tab.
class SettingsTab extends StatefulWidget {
  const SettingsTab({
    super.key,
    required this.controller,
    this.filePickerOverride,
  });

  final AppStateController controller;
  final Future<PickedBankFile?> Function()? filePickerOverride;

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _isImporting = false;
  String? _importStatusMessage;
  bool _importSucceeded = false;
  List<ExcelRowError> _rowErrors = const [];

  Future<PickedBankFile?> _pickDefaultFile() async {
    final picked = await FilePicker.pickFile(
      dialogTitle: 'Chọn file ngân hàng câu hỏi (.bex hoặc .xlsx)',
      type: FileType.any,
    );
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    return PickedBankFile(fileName: picked.name, bytes: bytes);
  }

  Future<void> _updateSettings(UserSettings next) async {
    try {
      await widget.controller.updateSettings(next);
    } on ArgumentError catch (e) {
      if (!mounted) return;
      _showSnackBar('${e.message}');
    }
  }

  Future<void> _handleImportFile() async {
    setState(() {
      _isImporting = true;
      _importStatusMessage = null;
      _rowErrors = const [];
    });

    try {
      final picker = widget.filePickerOverride ?? _pickDefaultFile;
      final file = await picker();
      if (file == null) {
        if (mounted) {
          setState(() => _isImporting = false);
        }
        return;
      }

      final lowerName = file.fileName.toLowerCase();
      final ImportFileType? fileType;
      if (lowerName.endsWith('.bex')) {
        fileType = ImportFileType.bex;
      } else if (lowerName.endsWith('.xlsx')) {
        fileType = ImportFileType.excel;
      } else {
        fileType = null;
      }

      if (fileType == null) {
        if (mounted) {
          setState(() {
            _isImporting = false;
            _importSucceeded = false;
            _importStatusMessage =
                'Định dạng không hỗ trợ (${file.fileName}). Vui lòng chọn file .xlsx hoặc .bex.';
          });
        }
        return;
      }

      final result = await widget.controller.importBankBytes(
        file.bytes,
        type: fileType,
      );
      if (!mounted) return;

      switch (result) {
        case VaultSuccess<ImportSummary>(:final data):
          setState(() {
            _isImporting = false;
            _importSucceeded = true;
            _rowErrors = const [];
            _importStatusMessage =
                'Cập nhật thành công ${data.totalQuestions} câu hỏi thuộc ${data.topicCount} chuyên đề (nhóm cùng điểm: ${data.pointGroupCount}).';
          });
        case VaultError<ImportSummary>(:final failure):
          setState(() {
            _isImporting = false;
            _importSucceeded = false;
            switch (failure) {
              case ExcelValidationFailure(:final rowErrors):
                _rowErrors = rowErrors;
                _importStatusMessage =
                    'File Excel chưa hợp lệ (${rowErrors.length} lỗi). Dữ liệu hiện tại vẫn được giữ nguyên.';
              case InsufficientBankFailure(:final message):
                _rowErrors = const [];
                _importStatusMessage = message;
              case CorruptedVaultFailure(:final message):
                _rowErrors = const [];
                _importStatusMessage = message;
              case StorageFailure(:final message):
                _rowErrors = const [];
                _importStatusMessage = message;
            }
          });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isImporting = false;
        _importSucceeded = false;
        _importStatusMessage = 'Không thể đọc file đã chọn: $error';
      });
    }
  }

  Future<void> _confirmRestoreBundledBank() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Khôi phục bộ câu hỏi mặc định?'),
        content: const Text(
          'Bộ câu hỏi mặc định kèm theo ứng dụng sẽ được nạp lại. Lịch sử thi và tiến độ cá nhân của bạn vẫn được giữ nguyên.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Khôi phục'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final res = await widget.controller.resetToBundledBank();
    if (!mounted) return;
    switch (res) {
      case VaultSuccess<QuestionBank>(:final data):
        setState(() {
          _importSucceeded = true;
          _rowErrors = const [];
          _importStatusMessage =
              'Đã khôi phục bộ câu hỏi gốc (${data.questions.length} câu hỏi).';
        });
      case VaultError<QuestionBank>(:final failure):
        _showSnackBar('Không thể khôi phục: $failure');
    }
  }

  Future<void> _confirmResetProgress() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xoá toàn bộ tiến độ & lịch sử?'),
        content: const Text(
          'Thao tác này sẽ xoá sạch lịch sử các bài thi thử, hàng đợi phục thù và danh sách đánh dấu sao trên thiết bị này.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.weakFg),
            child: const Text('Xoá toàn bộ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await widget.controller.resetAllProgress();
    if (!mounted) return;
    _showSnackBar('Đã đặt lại toàn bộ tiến độ cá nhân.');
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _sourceLabel(BankSourceType type) {
    return switch (type) {
      BankSourceType.bundled => 'Bộ mặc định kèm ứng dụng',
      BankSourceType.importedBex => 'Đã cập nhật từ file .bex',
      BankSourceType.importedExcel => 'Đã cập nhật từ file Excel',
    };
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.controller.settings;
    final bank = widget.controller.bank;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      LucideIcons.slidersHorizontal,
                      size: 19,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Ngưỡng đánh giá & Thi thử',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Ngưỡng điểm Đạt (thang 100)',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Giảm 5 điểm',
                      onPressed: settings.passScoreThreshold >
                              UserSettings.minPassScoreThreshold
                          ? () => _updateSettings(
                                settings.copyWith(
                                  passScoreThreshold:
                                      (settings.passScoreThreshold - 5).clamp(
                                    UserSettings.minPassScoreThreshold,
                                    UserSettings.maxPassScoreThreshold,
                                  ),
                                ),
                              )
                          : null,
                      icon: const Icon(LucideIcons.chevronLeft, size: 18),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${settings.passScoreThreshold.toStringAsFixed(0)} điểm',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tăng 5 điểm',
                      onPressed: settings.passScoreThreshold <
                              UserSettings.maxPassScoreThreshold
                          ? () => _updateSettings(
                                settings.copyWith(
                                  passScoreThreshold:
                                      (settings.passScoreThreshold + 5).clamp(
                                    UserSettings.minPassScoreThreshold,
                                    UserSettings.maxPassScoreThreshold,
                                  ),
                                ),
                              )
                          : null,
                      icon: const Icon(LucideIcons.chevronRight, size: 18),
                    ),
                  ],
                ),
                const Divider(height: 22),
                const Text(
                  'Số lần trả lời đúng liên tiếp để gỡ câu yếu',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _SingleRowOptionGroup<int>(
                  options: [
                    for (var s = UserSettings.minRevengeStreak;
                        s <= UserSettings.maxRevengeStreak;
                        s++)
                      _OptionChoice(value: s, label: '$s lần'),
                  ],
                  selectedValue: settings.revengeRequiredStreak,
                  onSelected: (s) => _updateSettings(
                    settings.copyWith(revengeRequiredStreak: s),
                  ),
                ),
                const Divider(height: 22),
                const Text(
                  'Thời gian làm bài Thi thử',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _SingleRowOptionGroup<int>(
                  options: [
                    for (final mins in UserSettings.allowedExamDurations)
                      _OptionChoice(value: mins, label: '$mins phút'),
                  ],
                  selectedValue: settings.examDurationMinutes,
                  onSelected: (mins) => _updateSettings(
                    settings.copyWith(examDurationMinutes: mins),
                  ),
                ),
                const Divider(height: 22),
                const Text(
                  'Mini-test chẩn đoán mỗi chuyên đề',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _SingleRowOptionGroup<int>(
                  options: [
                    for (final perTopic in UserSettings.allowedDiagnosticPerTopic)
                      _OptionChoice(
                        value: perTopic,
                        label: '$perTopic câu (${perTopic * 13} câu)',
                      ),
                  ],
                  selectedValue: settings.diagnosticPerTopic,
                  onSelected: (perTopic) => _updateSettings(
                    settings.copyWith(diagnosticPerTopic: perTopic),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      LucideIcons.fileSpreadsheet,
                      size: 19,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Ngân hàng câu hỏi (Offline)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                if (bank != null) ...[
                  const SizedBox(height: 10),
                  Text('Nguồn: ${_sourceLabel(bank.sourceType)}'),
                  Text(
                    'Quy mô: ${bank.questions.length} câu • ${bank.topics.length} chuyên đề • ${bank.questionsByPointGroup.length} nhóm cùng điểm',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isImporting ? null : _handleImportFile,
                    icon: const Icon(LucideIcons.upload, size: 18),
                    label: Text(
                      _isImporting
                          ? 'Đang kiểm tra & mã hoá...'
                          : 'Cập nhật từ file (.bex / .xlsx)',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isImporting ? null : _confirmRestoreBundledBank,
                    icon: const Icon(LucideIcons.rotateCcw, size: 18),
                    label: const Text('Khôi phục bộ câu hỏi mặc định'),
                  ),
                ),
                if (_importStatusMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _importSucceeded
                          ? AppColors.masteredBg
                          : AppColors.weakBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _importSucceeded
                            ? AppColors.masteredBorder
                            : AppColors.weakBorder,
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _importStatusMessage!,
                          style: TextStyle(
                            color: _importSucceeded
                                ? AppColors.masteredFg
                                : AppColors.weakFg,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                        if (_rowErrors.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          for (final err in _rowErrors.take(15))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Text(
                                '• Dòng ${err.rowNumber} (${err.columnName}): ${err.message}',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dữ liệu tiến độ cá nhân',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Dữ liệu ôn thi và lịch sử được lưu độc lập trên thiết bị, không gửi ra ngoài.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _confirmResetProgress,
                    icon: const Icon(
                      LucideIcons.trash2,
                      size: 18,
                      color: AppColors.weakFg,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.weakFg,
                      side: const BorderSide(
                        color: AppColors.weakBorder,
                        width: 1.4,
                      ),
                    ),
                    label: const Text('Xoá toàn bộ lịch sử & tiến độ học'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      LucideIcons.info,
                      size: 19,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Giới thiệu ứng dụng',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Ứng dụng hỗ trợ ôn thi Chứng chỉ Đấu thầu',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Phiên bản Ngân hàng 430 câu hỏi',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Lam Điền @ 2026',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OptionChoice<T> {
  const _OptionChoice({required this.value, required this.label});

  final T value;
  final String label;
}

class _SingleRowOptionGroup<T> extends StatelessWidget {
  const _SingleRowOptionGroup({
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  final List<_OptionChoice<T>> options;
  final T selectedValue;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _SettingOptionPill(
              label: options[i].label,
              selected: options[i].value == selectedValue,
              onTap: () => onSelected(options[i].value),
            ),
          ),
        ],
      ],
    );
  }
}

class _SettingOptionPill extends StatelessWidget {
  const _SettingOptionPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.primaryDark : AppColors.scaffoldBg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? AppColors.primaryDark : AppColors.borderSky,
                width: selected ? 1.5 : 1.2,
              ),
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 13.5,
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


