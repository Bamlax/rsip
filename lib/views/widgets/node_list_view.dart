import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  void _confirmDeletePreset(BuildContext context, ArchivePresetModel preset) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          '删除归档分类？',
          style: TextStyle(
            color: AppTheme.deepNavy,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text('将删除快速归档分类「${preset.name}」，不会影响现有国策节点。'),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('确认删除'),
            onPressed: () {
              engine.deleteArchivePreset(preset.id);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allNormalNodes = engine.nodes.where((n) => !n.isPrompt).toList();

    // 1. 归档管理模式
    if (engine.isArchiveMode) {
      if (allNormalNodes.isEmpty) {
        return const Center(
          child: Text(
            '暂无可归档的国策节点',
            style: TextStyle(fontSize: 14, color: Colors.black38),
          ),
        );
      }

      final presets = engine.archivePresets;

      return Column(
        children: [
          // 顶部栏下方的快速归档小 Tag 区
          if (presets.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceWhite,
                border: Border(
                  bottom: BorderSide(color: AppTheme.borderLight, width: 0.8),
                ),
              ),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: presets.map((preset) {
                  final isSelected =
                      engine.selectedArchivePresetId == preset.id;

                  return GestureDetector(
                    onTap: () => engine.selectArchivePreset(preset.id),
                    onLongPress: () => _confirmDeletePreset(context, preset),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryBlue
                            : AppTheme.bgCanvas,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryBlue
                              : AppTheme.borderLight,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        preset.name,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? Colors.white : AppTheme.deepNavy,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // 国策列表：与常规模式共用同一行布局，点击切换归档状态零尺寸变化与位移
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 0, bottom: 24),
              itemCount: allNormalNodes.length,
              itemBuilder: (context, index) {
                final node = allNormalNodes[index];
                final isArchived = engine.archiveSelectedIds.contains(node.id);

                return Container(
                  key: ValueKey('archive_${node.id}'),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: AppTheme.borderLight,
                        width: 0.8,
                      ),
                    ),
                  ),
                  child: _buildSeamlessNodeRow(
                    node,
                    isArchiveMode: true,
                    isArchivedInMode: isArchived,
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    // 2. 常规列表：支持下拉同步 WebDAV
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

  /// 常规模式与归档模式共享的国策行组件：保证点击前后零尺寸变化、零元素位移
  Widget _buildSeamlessNodeRow(
    FocusNodeModel node, {
    bool isArchiveMode = false,
    bool isArchivedInMode = false,
  }) {
    final isSelected = !isArchiveMode && node.id == engine.selectedNodeId;
    final isCountMode = engine.displayMode == 1;

    final scoreRes = engine.getNodeScore(node.id);
    final scoreColor = ProgressColorHelper.getScoreColor(scoreRes.score);
    final scoreBgColor = ProgressColorHelper.getScoreBgColor(scoreRes.score);

    final incTextColor =
        ProgressColorHelper.getIncreaseColor(node.increaseCount);
    final incBgColor =
        ProgressColorHelper.getIncreaseBgColor(node.increaseCount);

    final Color bgColor = isArchiveMode
        ? (isArchivedInMode ? const Color(0xFFD8E0E8) : AppTheme.surfaceWhite)
        : (isSelected ? AppTheme.subtleFill : AppTheme.surfaceWhite);

    final Color titleColor =
        isArchivedInMode ? const Color(0xFF475569) : AppTheme.deepNavy;
    final Color contentColor =
        isArchivedInMode ? const Color(0xFF64748B) : Colors.black87;
    final double mutedOpacity = isArchivedInMode ? 0.55 : 1.0;

    return InkWell(
      onTap: isArchiveMode
          ? () => engine.toggleArchiveSelection(node.id)
          : () => engine.selectNode(node.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: bgColor,
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
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Opacity(
                  opacity: mutedOpacity,
                  child: isCountMode
                      ? Row(
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
                      : Container(
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
                ),
              ],
            ),
            if (node.content.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                node.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: contentColor,
                  height: 1.4,
                ),
              ),
            ],
            if (node.numericAttributes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Opacity(
                opacity: isArchivedInMode ? 0.65 : 1.0,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: node.numericAttributes.map((attr) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: isArchivedInMode
                            ? Colors.white.withValues(alpha: 0.45)
                            : AppTheme.bgCanvas,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isArchivedInMode
                              ? const Color(0xFFB8C4D0)
                              : AppTheme.borderLight,
                        ),
                      ),
                      child: Text(
                        '${attr.name}: 累计 ${_formatNum(attr.totalValue)}${attr.unit} (均 ${_formatNum(attr.average)})',
                        style: TextStyle(
                          fontSize: 11,
                          color: titleColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}