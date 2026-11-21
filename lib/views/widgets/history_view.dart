import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/diff_helper.dart';
import '../../engine/rsip_engine.dart';
import '../../models/focus_node_model.dart';
import 'edit_record_dialog.dart';
import 'swipeable_record_row.dart';

class HistoryView extends StatefulWidget {
  final RsipEngine engine;

  const HistoryView({super.key, required this.engine});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  final ValueNotifier<String?> _openedRowNotifier = ValueNotifier(null);

  @override
  void dispose() {
    _openedRowNotifier.dispose();
    super.dispose();
  }

  String _formatNum(double val) {
    return val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(1);
  }

  String _getUnit(String nodeId, String attrName) {
    try {
      final node = widget.engine.nodes.firstWhere((n) => n.id == nodeId);
      return node.numericAttributes.firstWhere((a) => a.name == attrName).unit;
    } catch (_) {
      return '';
    }
  }

  void _openEditRecord(BuildContext context, ProgressRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => EditRecordDialog(record: record, engine: widget.engine),
    );
  }

  void _confirmDeleteRecord(BuildContext context, ProgressRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          '确认删除此记录？',
          style: TextStyle(color: AppTheme.deepNavy, fontWeight: FontWeight.bold),
        ),
        content: const Text('删除后将撤回该次记录，并同步更新节点统计与得分。'),
        actions: [
          TextButton(
            child: const Text('取消', style: TextStyle(color: Colors.black45)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('确认删除'),
            onPressed: () {
              widget.engine.deleteRecord(record.id);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allHistory = List<ProgressRecord>.from(widget.engine.history)
      ..sort((a, b) => b.time.compareTo(a.time));

    if (allHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_rounded,
              size: 56,
              color: AppTheme.primaryBlue.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            const Text(
              '暂无历史记录',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.deepNavy,
              ),
            ),
          ],
        ),
      );
    }

    // 按归属日期分组
    final Map<String, List<ProgressRecord>> grouped = {};
    for (final r in allHistory) {
      final dateKey = widget.engine.formatRecordDate(r.time);
      grouped.putIfAbsent(dateKey, () => []).add(r);
    }

    final dateKeys = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.only(top: 0, bottom: 24),
      itemCount: dateKeys.length,
      itemBuilder: (context, groupIdx) {
        final dateStr = dateKeys[groupIdx];
        final dayRecords = grouped[dateStr]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: AppTheme.bgCanvas,
                border: Border(
                  bottom: BorderSide(color: AppTheme.borderLight, width: 0.8),
                ),
              ),
              child: Text(
                dateStr,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.black54,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            for (int i = 0; i < dayRecords.length; i++) ...[
              if (i > 0)
                const Divider(
                    height: 1, thickness: 0.8, color: AppTheme.borderLight),
              SwipeableRecordRow(
                recordId: dayRecords[i].id,
                enabled: !dayRecords[i].isEdit,
                openedRowNotifier: _openedRowNotifier,
                onEdit: () => _openEditRecord(context, dayRecords[i]),
                onDelete: () => _confirmDeleteRecord(context, dayRecords[i]),
                child: _buildSeamlessHistoryRow(dayRecords[i]),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSeamlessHistoryRow(ProgressRecord record) {
    final isGain = record.delta > 0;
    final isSkip = record.isSkip;
    final rowBgColor = record.isEdit
        ? const Color(0xFFF0F7FF)
        : isSkip
            ? const Color(0xFFF1F5F9)
            : (isGain ? const Color(0xFFF2FBF4) : const Color(0xFFFDF3F3));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: rowBgColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (record.isEdit) ...[
                Text(
                  '#${record.revision ?? 2}',
                  style: const TextStyle(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: record.isEdit &&
                        record.oldTitle != null &&
                        record.oldTitle != record.newTitle
                    ? RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          children: DiffHelper.buildDiffSpans(
                            record.oldTitle!,
                            record.newTitle ?? record.nodeTitle,
                          ),
                        ),
                      )
                    : Text(
                        record.nodeTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.deepNavy,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Text(
                record.isEdit
                    ? '版本修订'
                    : isSkip
                        ? '已跳过'
                        : (isGain ? '+1' : '-1'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: record.isEdit
                      ? AppTheme.primaryBlue
                      : isSkip
                          ? Colors.blueGrey.shade700
                          : (isGain
                              ? Colors.green.shade700
                              : Colors.red.shade700),
                ),
              ),
            ],
          ),
          if (record.isEdit &&
              (record.oldContent != null || record.newContent != null)) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: RichText(
                text: TextSpan(
                  children: DiffHelper.buildDiffSpans(
                    record.oldContent ?? '',
                    record.newContent ?? '',
                  ),
                ),
              ),
            ),
          ],
          if (!record.isEdit &&
              record.note != null &&
              record.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                record.note!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                  height: 1.35,
                ),
              ),
            ),
          ],
          if (record.tags != null && record.tags!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: record.tags!.map((tag) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isSkip
                          ? Colors.blueGrey.shade200
                          : (isGain
                              ? Colors.green.shade200
                              : Colors.red.shade200),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    '#$tag',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isSkip
                          ? Colors.blueGrey.shade800
                          : (isGain
                              ? Colors.green.shade800
                              : Colors.red.shade800),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (record.attributeDeltas != null &&
              record.attributeDeltas!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: record.attributeDeltas!.entries.map((entry) {
                final unit = _getUnit(record.nodeId, entry.key);
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${entry.key}: ${_formatNum(entry.value)} $unit',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.deepNavy,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}