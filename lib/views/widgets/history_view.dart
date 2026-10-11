import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/progress_color_helper.dart';
import '../../engine/rsip_engine.dart';
import '../../models/focus_node_model.dart';
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
      final attr = node.numericAttributes.firstWhere((a) => a.name == attrName);
      return attr.unit;
    } catch (_) {
      return '';
    }
  }

  void _confirmDeleteRecord(BuildContext context, ProgressRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          '确认删除此打卡记录？',
          style: TextStyle(color: AppTheme.deepNavy, fontWeight: FontWeight.bold),
        ),
        content: const Text('删除后将撤回该次进度的变更以及录入的数值统计。'),
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
    // 1. 过滤掉版本修订记录
    final list = widget.engine.history.where((r) => !r.isEdit).toList();

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_toggle_off_rounded, size: 54, color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            const Text(
              '暂无打卡记录',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.deepNavy),
            ),
            const SizedBox(height: 4),
            const Text('在列表或树中打卡即可沉淀记录，支持左滑删除', style: TextStyle(fontSize: 12, color: Colors.black38)),
          ],
        ),
      );
    }

    // 2. 严格按日期从新到老（降序）排序
    list.sort((a, b) => b.time.compareTo(a.time));

    // 3. 聚合按日期分栏
    final Map<String, List<ProgressRecord>> grouped = {};
    for (final r in list) {
      final dateKey = '${r.time.year}-${r.time.month.toString().padLeft(2, '0')}-${r.time.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(dateKey, () => []).add(r);
    }

    return ListView(
      // 与顶部 AppBar 零间距
      padding: const EdgeInsets.only(top: 0, bottom: 24),
      children: [
        for (final entry in grouped.entries) ...[
          // 日期分栏标签栏
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppTheme.bgCanvas,
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 13, color: AppTheme.primaryBlue),
                const SizedBox(width: 6),
                Text(
                  entry.key,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.deepNavy,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          // 当日无缝记录容器
          Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppTheme.borderLight),
              ),
            ),
            child: Column(
              children: [
                for (int i = 0; i < entry.value.length; i++) ...[
                  if (i > 0) const Divider(height: 1, thickness: 0.8, color: AppTheme.borderLight),
                  SwipeableRecordRow(
                    recordId: entry.value[i].id,
                    enabled: true,
                    openedRowNotifier: _openedRowNotifier,
                    onDelete: () => _confirmDeleteRecord(context, entry.value[i]),
                    child: _buildSeamlessHistoryRow(entry.value[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSeamlessHistoryRow(ProgressRecord record) {
    final isGain = record.delta > 0;
    final rowBgColor = isGain ? const Color(0xFFF2FBF4) : const Color(0xFFFDF3F3);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: rowBgColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
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
              // 右侧去掉了时间显示，直接展现当前净值
              Text(
                '净值 ${record.resultProgress >= 0 ? "+${record.resultProgress}" : record.resultProgress}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: ProgressColorHelper.getColor(record.resultProgress),
                ),
              ),
            ],
          ),
          if (record.note != null && record.note!.isNotEmpty) ...[
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
          if (record.attributeDeltas != null && record.attributeDeltas!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: record.attributeDeltas!.entries.map((entry) {
                final unit = _getUnit(record.nodeId, entry.key);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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