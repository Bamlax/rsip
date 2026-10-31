import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/diff_helper.dart';
import '../../core/progress_color_helper.dart';
import '../../engine/rsip_engine.dart';
import '../../models/focus_node_model.dart';
import 'edit_node_dialog.dart';
import 'edit_record_dialog.dart';
import 'swipeable_record_row.dart';

class NodeDetailScreen extends StatefulWidget {
  final String nodeId;
  final RsipEngine engine;

  const NodeDetailScreen({
    super.key,
    required this.nodeId,
    required this.engine,
  });

  @override
  State<NodeDetailScreen> createState() => _NodeDetailScreenState();
}

class _NodeDetailScreenState extends State<NodeDetailScreen> {
  final ValueNotifier<String?> _openedRowNotifier = ValueNotifier(null);

  @override
  void dispose() {
    _openedRowNotifier.dispose();
    super.dispose();
  }

  String _formatNum(double val) {
    return val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(1);
  }

  void _openEditDialog(BuildContext context, FocusNodeModel node) {
    showDialog(
      context: context,
      builder: (ctx) => EditNodeDialog(node: node, engine: widget.engine),
    );
  }

  void _confirmDeleteNode(BuildContext context, FocusNodeModel node) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          '确认删除国策？',
          style: TextStyle(color: AppTheme.deepNavy, fontWeight: FontWeight.bold),
        ),
        content: Text('将彻底删除「${node.title}」及其全部历史打卡记录和关联连线。'),
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
              widget.engine.deleteNode(node.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
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
          '确认删除此打卡记录？',
          style: TextStyle(color: AppTheme.deepNavy, fontWeight: FontWeight.bold),
        ),
        content: const Text('删除后将撤回该次打卡记录，并重新计算习惯连续性得分与属性统计。'),
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
    return ListenableBuilder(
      listenable: widget.engine,
      builder: (context, _) {
        FocusNodeModel? node;
        try {
          node = widget.engine.nodes.firstWhere((n) => n.id == widget.nodeId);
        } catch (_) {
          node = null;
        }

        if (node == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('国策详情')),
            body: const Center(child: Text('该国策已被删除')),
          );
        }

        final nodeHistory = widget.engine.history.where((r) => r.nodeId == node!.id).toList();
        nodeHistory.sort((a, b) => b.time.compareTo(a.time));

        final scoreRes = widget.engine.getNodeScore(node.id);
        final scoreColor = ProgressColorHelper.getScoreColor(scoreRes.score);
        final scoreBg = ProgressColorHelper.getScoreBgColor(scoreRes.score);

        return Scaffold(
          backgroundColor: AppTheme.bgCanvas,
          appBar: AppBar(
            backgroundColor: AppTheme.surfaceWhite,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(
              node.title,
              style: const TextStyle(
                color: AppTheme.deepNavy,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryBlue),
                tooltip: '编辑国策',
                onPressed: () => _openEditDialog(context, node!),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                tooltip: '删除此国策',
                onPressed: () => _confirmDeleteNode(context, node!),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.only(top: 0, bottom: 24),
            children: [
              // 1. 顶部核心看板：习惯连续性打分与势能指标
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceWhite,
                  border: Border(
                    bottom: BorderSide(color: AppTheme.borderLight),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (node.content.isNotEmpty) ...[
                      Text(
                        node.content,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppTheme.borderLight),
                      const SizedBox(height: 12),
                    ],

                    Row(
                      children: [
                        _buildMetricTile(
                          label: '习惯得分', // 移除时期后缀
                          value: '${scoreRes.score.toStringAsFixed(1)} 分',
                          valColor: scoreColor,
                        ),
                        const SizedBox(width: 8),
                        _buildMetricTile(
                          label: '当前连续天数',
                          value: '${scoreRes.streak} 天',
                          valColor: AppTheme.primaryBlue,
                        ),
                        const SizedBox(width: 8),
                        _buildMetricTile(
                          label: '连续势能 E',
                          value: scoreRes.energy.toStringAsFixed(1),
                          valColor: Colors.teal.shade700,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // 仅保留干净的 R / H 与排期规则信息，移除“正在生根”等提示文案
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: scoreBg.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: scoreColor.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '短期冲劲 R: ${(scoreRes.rValue * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.deepNavy,
                            ),
                          ),
                          Text(
                            '长期质量 H: ${(scoreRes.hValue * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.deepNavy,
                            ),
                          ),
                          Text(
                            '规则: ${node.repeatDescription}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (node.numericAttributes.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text(
                        '属性数据累计与单次均值',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.deepNavy),
                      ),
                      const SizedBox(height: 8),
                      ...node.numericAttributes.map((attr) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${attr.name} (${attr.count}次记录)',
                                style: const TextStyle(fontSize: 12, color: Colors.black87),
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.bgCanvas,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '总量: ${_formatNum(attr.totalValue)} ${attr.unit}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.bgCanvas,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '均值: ${_formatNum(attr.average)} ${attr.unit}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  '详情',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black45,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // 2. 流水明细列表
              if (nodeHistory.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  alignment: Alignment.center,
                  child: const Text('暂无详情变动明细', style: TextStyle(color: Colors.black38, fontSize: 13)),
                )
              else
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppTheme.borderLight),
                    ),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < nodeHistory.length; i++) ...[
                        if (i > 0) const Divider(height: 1, thickness: 0.8, color: AppTheme.borderLight),
                        SwipeableRecordRow(
                          recordId: nodeHistory[i].id,
                          enabled: !nodeHistory[i].isEdit,
                          openedRowNotifier: _openedRowNotifier,
                          onEdit: () => _openEditRecord(context, nodeHistory[i]),
                          onDelete: () => _confirmDeleteRecord(context, nodeHistory[i]),
                          child: _buildSeamlessHistoryRow(nodeHistory[i], node),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color valColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.bgCanvas,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: valColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeamlessHistoryRow(ProgressRecord record, FocusNodeModel node) {
    final isGain = record.delta > 0;
    final Color rowBgColor = record.isEdit
        ? const Color(0xFFF0F7FF)
        : (isGain ? const Color(0xFFF2FBF4) : const Color(0xFFFDF3F3));

    final timeStr = widget.engine.formatRecordDate(record.time);

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
                child: record.isEdit && record.oldTitle != null && record.oldTitle != record.newTitle
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
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.deepNavy),
                      ),
              ),
              Text(
                timeStr,
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
              const SizedBox(width: 10),
              Text(
                record.isEdit
                    ? '版本修订'
                    : (isGain ? '打卡完成' : '断签反思'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: record.isEdit
                      ? AppTheme.primaryBlue
                      : (isGain ? Colors.green.shade700 : Colors.red.shade700),
                ),
              ),
            ],
          ),

          if (record.isEdit && (record.oldContent != null || record.newContent != null)) ...[
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

          if (record.isEdit &&
              record.oldRepeatDesc != null &&
              record.newRepeatDesc != null &&
              record.oldRepeatDesc != record.newRepeatDesc) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: RichText(
                text: TextSpan(
                  children: [
                    const TextSpan(
                      text: '重复规则: ',
                      style: TextStyle(fontSize: 11, color: Colors.black45),
                    ),
                    TextSpan(
                      text: record.oldRepeatDesc!,
                      style: TextStyle(
                        fontSize: 12,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: Colors.red.shade400,
                        decorationThickness: 2.0,
                        color: Colors.red.shade400,
                      ),
                    ),
                    const TextSpan(
                      text: ' ➔ ',
                      style: TextStyle(fontSize: 12, color: Colors.black38),
                    ),
                    TextSpan(
                      text: record.newRepeatDesc!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (record.isEdit &&
              record.attributeChanges != null &&
              record.attributeChanges!.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...record.attributeChanges!.map((change) {
              if (change.type == -1) {
                return Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: '删除属性: ',
                          style: TextStyle(fontSize: 11, color: Colors.black45),
                        ),
                        TextSpan(
                          text: '${change.oldName} (${change.oldUnit})',
                          style: TextStyle(
                            fontSize: 12,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: Colors.red.shade400,
                            decorationThickness: 2.0,
                            color: Colors.red.shade400,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              } else if (change.type == 0) {
                return Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: '修改属性: ',
                          style: TextStyle(fontSize: 11, color: Colors.black45),
                        ),
                        TextSpan(
                          text: '${change.oldName} (${change.oldUnit})',
                          style: TextStyle(
                            fontSize: 12,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: Colors.red.shade400,
                            decorationThickness: 2.0,
                            color: Colors.red.shade400,
                          ),
                        ),
                        const TextSpan(
                          text: ' ➔ ',
                          style: TextStyle(fontSize: 12, color: Colors.black38),
                        ),
                        TextSpan(
                          text: '${change.newName} (${change.newUnit})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                return Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: '新增属性: ',
                          style: TextStyle(fontSize: 11, color: Colors.black45),
                        ),
                        TextSpan(
                          text: '${change.newName} (${change.newUnit})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            }),
          ],

          if (!record.isEdit && record.note != null && record.note!.isNotEmpty) ...[
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
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isGain ? Colors.green.shade200 : Colors.red.shade200,
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    '#$tag',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isGain ? Colors.green.shade800 : Colors.red.shade800,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          if (record.attributeDeltas != null && record.attributeDeltas!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: record.attributeDeltas!.entries.map((entry) {
                String unit = '';
                try {
                  unit = node.numericAttributes.firstWhere((a) => a.name == entry.key).unit;
                } catch (_) {}

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