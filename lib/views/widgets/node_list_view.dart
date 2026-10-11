import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../engine/rsip_engine.dart';
import '../../models/focus_node_model.dart';

class NodeListView extends StatelessWidget {
  final RsipEngine engine;

  const NodeListView({super.key, required this.engine});

  String _formatNum(double val) {
    return val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final visibleNodes = engine.nodes.where((n) => !n.isPrompt).toList();

    if (visibleNodes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notes_rounded, size: 56, color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            const Text(
              '暂无国策节点',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.deepNavy),
            ),
            const SizedBox(height: 4),
            const Text('点击右下角按钮添加国策，长按可上下拖拽排序', style: TextStyle(fontSize: 12, color: Colors.black38)),
          ],
        ),
      );
    }

    // 支持长按拖拽排序的无缝列表
    return ReorderableListView.builder(
      padding: const EdgeInsets.only(top: 0, bottom: 24),
      itemCount: visibleNodes.length,
      onReorder: (oldIndex, newIndex) => engine.reorderNodes(oldIndex, newIndex),
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
              bottom: BorderSide(color: AppTheme.borderLight, width: 0.8),
            ),
          ),
          child: _buildSeamlessNodeRow(node),
        );
      },
    );
  }

  Widget _buildSeamlessNodeRow(FocusNodeModel node) {
    final isSelected = node.id == engine.selectedNodeId;

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
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.deepNavy,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '+${node.increaseCount}',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
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
                    const SizedBox(width: 8),
                    const Icon(Icons.drag_indicator_rounded, size: 18, color: Colors.black26),
                  ],
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
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
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
            if (node.latestNote != null && node.latestNote!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.bgCanvas,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  node.latestNote!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}