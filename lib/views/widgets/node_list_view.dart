import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/progress_color_helper.dart';
import '../../engine/rsip_engine.dart';
import '../../models/focus_node_model.dart';

class NodeListView extends StatelessWidget {
  final RsipEngine engine;

  const NodeListView({super.key, required this.engine});

  String _formatNum(double val) {
    return val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(1);
  }

  Future<void> _handlePullRefresh(BuildContext context) async {
    final res = await engine.syncWithWebDav();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.message),
        backgroundColor: res.success ? Colors.green.shade700 : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allNormalNodes = engine.nodes.where((n) => !n.isPrompt).toList();

    // 1. 归档管理模式（颜色深浅标定归档状态）
    if (engine.isArchiveMode) {
      if (allNormalNodes.isEmpty) {
        return const Center(
          child: Text(
            '暂无可归档的国策节点',
            style: TextStyle(fontSize: 14, color: Colors.black38),
          ),
        );
      }

      final archivedCount = engine.archiveSelectedIds.length;
      final activeCount = allNormalNodes.length - archivedCount;

      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: AppTheme.bgCanvas,
              border: Border(bottom: BorderSide(color: AppTheme.borderLight)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '点击卡片切换状态',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceWhite,
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(color: Colors.black26),
                      ),
                    ),
                    Text(
                      ' 正常($activeCount)   ',
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Text(
                      ' 已归档($archivedCount)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(top: 0, bottom: 24),
              itemCount: allNormalNodes.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                thickness: 0.8,
                color: AppTheme.borderLight,
              ),
              itemBuilder: (context, index) {
                final node = allNormalNodes[index];
                final isArchived = engine.archiveSelectedIds.contains(node.id);
                final scoreRes = engine.getNodeScore(node.id);

                return InkWell(
                  onTap: () => engine.toggleArchiveSelection(node.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    color: isArchived
                        ? const Color(0xFFD8E0E8)
                        : AppTheme.surfaceWhite,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                node.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isArchived
                                      ? const Color(0xFF475569)
                                      : AppTheme.deepNavy,
                                ),
                              ),
                              if (node.content.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  node.content,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isArchived
                                        ? const Color(0xFF64748B)
                                        : Colors.black54,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isArchived
                                ? const Color(0xFF64748B)
                                : AppTheme.bgCanvas,
                            borderRadius: BorderRadius.circular(6),
                            border: isArchived
                                ? null
                                : Border.all(color: AppTheme.borderLight),
                          ),
                          child: Text(
                            isArchived
                                ? '已归档'
                                : '${scoreRes.score.toStringAsFixed(1)}分',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isArchived
                                  ? Colors.white
                                  : AppTheme.deepNavy,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    // 2. 常规列表：支持下拉出现刷新图标执行 WebDAV 同步
    final visibleNodes = allNormalNodes
        .where((n) => !n.isArchived && engine.isNodeActiveToday(n))
        .toList();

    return RefreshIndicator(
      color: AppTheme.primaryBlue,
      backgroundColor: AppTheme.surfaceWhite,
      onRefresh: () => _handlePullRefresh(context),
      child: visibleNodes.isEmpty
          ? LayoutBuilder(
              builder: (context, constraints) {
                final hasActiveNodes =
                    allNormalNodes.any((n) => !n.isArchived);
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasActiveNodes
                                ? Icons.task_alt_rounded
                                : Icons.notes_rounded,
                            size: 56,
                            color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            hasActiveNodes
                                ? '今日待办国策已全部处理'
                                : '暂无国策节点',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.deepNavy,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasActiveNodes
                                ? '下拉刷新同步云端 · 已处理节点可在「树」界面查看'
                                : '点击右下角按钮添加国策，或下拉同步云端数据',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            )
          : ReorderableListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 0, bottom: 24),
              itemCount: visibleNodes.length,
              onReorder: (oldIndex, newIndex) =>
                  engine.reorderNodes(oldIndex, newIndex),
              proxyDecorator: (child, index, animation) {
                return Material(
                  elevation: 6,
                  color: AppTheme.surfaceWhite,
                  shadowColor: AppTheme.primaryBlue.withValues(alpha: 0.35),
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final node = visibleNodes[index];
                return Container(
                  key: ValueKey(node.id),
                  decoration: const BoxDecoration(
                    color: AppTheme.surfaceWhite,
                    border: Border(
                      bottom: BorderSide(
                        color: AppTheme.borderLight,
                        width: 0.8,
                      ),
                    ),
                  ),
                  child: _buildSeamlessNodeRow(node),
                );
              },
            ),
    );
  }

  Widget _buildSeamlessNodeRow(FocusNodeModel node) {
    final isSelected = node.id == engine.selectedNodeId;
    final isCountMode = engine.displayMode == 1;

    final scoreRes = engine.getNodeScore(node.id);
    final scoreColor = ProgressColorHelper.getScoreColor(scoreRes.score);
    final scoreBgColor = ProgressColorHelper.getScoreBgColor(scoreRes.score);

    final incTextColor =
        ProgressColorHelper.getIncreaseColor(node.increaseCount);
    final incBgColor =
        ProgressColorHelper.getIncreaseBgColor(node.increaseCount);

    return InkWell(
      onTap: () => engine.selectNode(node.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: isSelected ? AppTheme.subtleFill : AppTheme.surfaceWhite,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    node.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.deepNavy,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (isCountMode)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: incBgColor,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '+${node.increaseCount}',
                          style: TextStyle(
                            color: incTextColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '-${node.decreaseCount}',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: scoreBgColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: scoreColor.withValues(alpha: 0.35),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '${scoreRes.score.toStringAsFixed(1)}分',
                      style: TextStyle(
                        color: scoreColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
            if (node.content.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                node.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
            ],
            if (node.numericAttributes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: node.numericAttributes.map((attr) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCanvas,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: Text(
                      '${attr.name}: 累计 ${_formatNum(attr.totalValue)}${attr.unit} (均 ${_formatNum(attr.average)})',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.deepNavy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}