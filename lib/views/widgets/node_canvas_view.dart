import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../core/progress_color_helper.dart';
import '../../engine/rsip_engine.dart';
import '../../models/focus_node_model.dart';
import 'add_node_dialog.dart';

class NodeCanvasView extends StatefulWidget {
  final RsipEngine engine;
  final bool isConnectMode;

  const NodeCanvasView({
    super.key,
    required this.engine,
    this.isConnectMode = false,
  });

  @override
  State<NodeCanvasView> createState() => _NodeCanvasViewState();
}

class _NodeCanvasViewState extends State<NodeCanvasView> {
  final TransformationController _transController = TransformationController();
  final GlobalKey _canvasKey = GlobalKey();

  static const double _canvasWidth = 6000.0;
  static const double _canvasHeight = 6000.0;
  static const double _normalWidth = 150.0;
  static const double _normalHeight = 70.0;
  static const double _promptWidth = 130.0;
  static const double _promptHeight = 55.0;

  String? _connectStartId;

  // 大节点长按协同拖拽状态
  String? _draggingGroupId;
  Offset? _groupDragStartFingerPos;
  Map<String, Offset>? _groupDragStartPositions;

  // 单个节点拖拽状态
  String? _draggingNodeId;
  Offset? _nodeDragStartPos;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerCanvas());
  }

  @override
  void didUpdateWidget(covariant NodeCanvasView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isConnectMode && _connectStartId != null) {
      setState(() => _connectStartId = null);
    }
  }

  void _centerCanvas() {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    final nodes = widget.engine.nodes;

    double targetX = _canvasWidth / 2;
    double targetY = _canvasHeight / 2;

    if (nodes.isNotEmpty) {
      double sumX = 0;
      double sumY = 0;
      for (final n in nodes) {
        sumX += (n.x ?? _canvasWidth / 2);
        sumY += (n.y ?? _canvasHeight / 2);
      }
      targetX = sumX / nodes.length;
      targetY = sumY / nodes.length;
    }

    final matrix = Matrix4.identity()
      ..translate(
        size.width / 2 - targetX,
        size.height / 2 - targetY,
      );
    _transController.value = matrix;
  }

  void _onCanvasTap() {
    if (widget.engine.isGroupSelectMode) return;
    if (_connectStartId != null) {
      setState(() => _connectStartId = null);
    }
    widget.engine.selectNode(null);
    widget.engine.selectConnection(null);
  }

  void _onCanvasDoubleTap(TapDownDetails details) {
    if (widget.engine.isGroupSelectMode) return;
    final scenePos = _transController.toScene(details.localPosition);
    showDialog(
      context: context,
      builder: (ctx) => AddNodeDialog(
        engine: widget.engine,
        spawnPosition: scenePos,
      ),
    );
  }

  void _onNodeTap(FocusNodeModel node) {
    if (widget.engine.isGroupSelectMode) {
      widget.engine.toggleNodeInGroupSelect(node.id);
      return;
    }

    if (widget.isConnectMode) {
      _handleConnectTap(node.id);
      return;
    }

    widget.engine.selectNode(node.id);
  }

  void _onGroupTap(FocusGroupModel group) {
    if (widget.isConnectMode) {
      _handleConnectTap(group.id);
    }
  }

  void _handleConnectTap(String tappedId) {
    if (_connectStartId == null) {
      setState(() => _connectStartId = tappedId);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已选起点，请点击另一个目标国策或分类大框'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      if (_connectStartId == tappedId) {
        setState(() => _connectStartId = null);
        return;
      }

      final isNew = widget.engine.addConnection(_connectStartId!, tappedId);
      setState(() => _connectStartId = null);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isNew ? '已成功建立连线' : '此连线已存在'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _confirmDeleteGroup(FocusGroupModel group) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          '解散分类大框？',
          style: TextStyle(color: AppTheme.deepNavy, fontWeight: FontWeight.bold),
        ),
        content: Text('将解散大框「${group.title}」，框内国策节点及其连线将完好保留。'),
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
            child: const Text('解散'),
            onPressed: () {
              widget.engine.deleteGroup(group.id);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nodes = widget.engine.nodes;
    final groups = widget.engine.groups;

    final Map<String, Offset> nodePositions = {};
    for (final node in nodes) {
      nodePositions[node.id] = Offset(
        (node.x ?? _canvasWidth / 2).clamp(50.0, _canvasWidth - 50.0),
        (node.y ?? _canvasHeight / 2).clamp(50.0, _canvasHeight - 50.0),
      );
    }

    final Map<String, Rect> groupRects = {};
    for (final group in groups) {
      double minX = double.infinity;
      double minY = double.infinity;
      double maxX = -double.infinity;
      double maxY = -double.infinity;
      bool hasAny = false;

      for (final nId in group.nodeIds) {
        final pos = nodePositions[nId];
        final node = nodes.where((n) => n.id == nId).firstOrNull;
        if (pos != null && node != null) {
          hasAny = true;
          final w = node.isPrompt ? _promptWidth : _normalWidth;
          final h = node.isPrompt ? _promptHeight : _normalHeight;
          minX = math.min(minX, pos.dx);
          minY = math.min(minY, pos.dy);
          maxX = math.max(maxX, pos.dx + w);
          maxY = math.max(maxY, pos.dy + h);
        }
      }

      if (hasAny) {
        const padding = 20.0;
        groupRects[group.id] = Rect.fromLTRB(
          minX - padding,
          minY - padding - 22.0,
          maxX + padding,
          maxY + padding,
        );
      }
    }

    return GestureDetector(
      onTap: _onCanvasTap,
      onDoubleTapDown: _onCanvasDoubleTap,
      child: InteractiveViewer(
        transformationController: _transController,
        boundaryMargin: const EdgeInsets.all(3000),
        minScale: 0.1,
        maxScale: 3.5,
        constrained: false,
        child: Container(
          key: _canvasKey,
          width: _canvasWidth,
          height: _canvasHeight,
          decoration: const BoxDecoration(
            color: AppTheme.bgCanvas,
          ),
          child: CustomPaint(
            painter: DotGridPainter(),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. 连线层
                ..._buildConnections(nodePositions, groupRects),

                // 2. 分类大框层
                for (final group in groups)
                  if (groupRects.containsKey(group.id))
                    _buildGroupBoundingBox(group, groupRects[group.id]!, nodePositions),

                // 3. 国策卡片层
                for (final node in nodes)
                  if (nodePositions.containsKey(node.id))
                    _buildNodeCardWrapper(node, nodePositions[node.id]!),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupBoundingBox(
    FocusGroupModel group,
    Rect rect,
    Map<String, Offset> positions,
  ) {
    final groupNodes = widget.engine.nodes
        .where((n) => group.nodeIds.contains(n.id) && !n.isPrompt)
        .toList();

    double avgScore = 0.0;
    if (groupNodes.isNotEmpty) {
      final sumScore = groupNodes.fold<double>(
        0.0,
        (sum, n) => sum + widget.engine.getNodeScore(n.id).score,
      );
      avgScore = sumScore / groupNodes.length;
    }

    final scoreColor = ProgressColorHelper.getScoreColor(avgScore);
    final scoreBg = ProgressColorHelper.getScoreBgColor(avgScore);
    final isGroupDragging = _draggingGroupId == group.id;
    final isConnectSelected = group.id == _connectStartId;

    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onGroupTap(group),
        onLongPressStart: (details) {
          HapticFeedback.mediumImpact();
          final renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
          if (renderBox != null) {
            _groupDragStartFingerPos = renderBox.globalToLocal(details.globalPosition);
            _groupDragStartPositions = {
              for (final n in widget.engine.nodes.where((n) => group.nodeIds.contains(n.id)))
                n.id: positions[n.id]!
            };
            setState(() => _draggingGroupId = group.id);
          }
        },
        onLongPressMoveUpdate: (details) {
          if (_groupDragStartFingerPos != null && _groupDragStartPositions != null) {
            final renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
            if (renderBox != null) {
              final currentFinger = renderBox.globalToLocal(details.globalPosition);
              final delta = currentFinger - _groupDragStartFingerPos!;
              for (final entry in _groupDragStartPositions!.entries) {
                final initPos = entry.value;
                widget.engine.updateNodePosition(
                  entry.key,
                  (initPos.dx + delta.dx).clamp(50.0, _canvasWidth - 50.0),
                  (initPos.dy + delta.dy).clamp(50.0, _canvasHeight - 50.0),
                );
              }
            }
          }
        },
        onLongPressEnd: (details) {
          setState(() {
            _draggingGroupId = null;
            _groupDragStartFingerPos = null;
            _groupDragStartPositions = null;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: isGroupDragging
                ? AppTheme.primaryBlue.withValues(alpha: 0.08)
                : AppTheme.primaryBlue.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (isGroupDragging || isConnectSelected)
                  ? AppTheme.primaryBlue
                  : AppTheme.skyBlue.withValues(alpha: 0.55),
              width: (isGroupDragging || isConnectSelected) ? 2.5 : 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 12, right: 10, top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  group.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.deepNavy,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: scoreBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: scoreColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        '均 ${avgScore.toStringAsFixed(1)}分',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: scoreColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _confirmDeleteGroup(group),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 12, color: Colors.black45),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNodeCardWrapper(FocusNodeModel node, Offset pos) {
    final isSelectedSingle = node.id == widget.engine.selectedNodeId;
    final isHighlightedGroup = widget.engine.groupSelectedNodeIds.contains(node.id);
    final isDragging = _draggingNodeId == node.id;
    final isConnectSelected = node.id == _connectStartId;

    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: GestureDetector(
        onTap: () => _onNodeTap(node),
        onPanStart: (details) {
          _nodeDragStartPos = pos;
          setState(() => _draggingNodeId = node.id);
        },
        onPanUpdate: (details) {
          if (_draggingNodeId == node.id) {
            final sceneDelta = details.delta / _transController.value.getMaxScaleOnAxis();
            final curX = node.x ?? _canvasWidth / 2;
            final curY = node.y ?? _canvasHeight / 2;
            widget.engine.updateNodePosition(
              node.id,
              (curX + sceneDelta.dx).clamp(50.0, _canvasWidth - 50.0),
              (curY + sceneDelta.dy).clamp(50.0, _canvasHeight - 50.0),
            );
          }
        },
        onPanEnd: (_) => setState(() => _draggingNodeId = null),
        child: node.isPrompt
            ? _buildPromptNodeCard(node, isSelectedSingle, isHighlightedGroup, isDragging)
            : _buildNormalNodeCard(
                node,
                isSelectedSingle || isConnectSelected,
                isHighlightedGroup,
                isDragging,
              ),
      ),
    );
  }

  Widget _buildNormalNodeCard(
    FocusNodeModel node,
    bool isSelectedSingle,
    bool isHighlightedGroup,
    bool isDragging,
  ) {
    final scoreRes = widget.engine.getNodeScore(node.id);
    final scoreColor = ProgressColorHelper.getScoreColor(scoreRes.score);
    final scoreBg = ProgressColorHelper.getScoreBgColor(scoreRes.score);
    final solidBgColor = Color.alphaBlend(
      scoreBg.withValues(alpha: 0.55),
      AppTheme.surfaceWhite,
    );
    final isHighlighted = isSelectedSingle || isHighlightedGroup;
    final isActiveToday = widget.engine.isNodeActiveToday(node);

    // 已归档节点在树画布中半透明显示 (0.35)，而非删除
    final double targetOpacity = node.isArchived
        ? (isHighlighted || isDragging ? 0.65 : 0.35)
        : ((isActiveToday || isHighlighted || isDragging) ? 1.0 : 0.45);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: targetOpacity,
      child: Container(
        width: _normalWidth,
        height: _normalHeight,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isHighlighted ? AppTheme.subtleFill : solidBgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDragging
                ? AppTheme.skyBlue
                : isHighlighted
                    ? AppTheme.primaryBlue
                    : scoreColor.withValues(alpha: 0.55),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDragging
                  ? AppTheme.primaryBlue.withValues(alpha: 0.35)
                  : isHighlighted
                      ? AppTheme.primaryBlue.withValues(alpha: 0.2)
                      : scoreColor.withValues(alpha: 0.08),
              blurRadius: (isDragging || isHighlighted) ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        node.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.deepNavy,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: scoreBg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: scoreColor.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '${scoreRes.score.toStringAsFixed(1)}分',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: scoreColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  node.content.isEmpty ? '（无详细内容）' : node.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.black54, height: 1.25),
                ),
              ],
            ),
            if (isHighlightedGroup)
              const Positioned(
                right: 0,
                bottom: 0,
                child: Icon(Icons.check_circle, size: 16, color: AppTheme.primaryBlue),
              ),
          ],
        ),
      ),
    );
  }

  /// 提示块保持清晰、不透明的中性白底卡片样式
  Widget _buildPromptNodeCard(
    FocusNodeModel node,
    bool isSelectedSingle,
    bool isHighlightedGroup,
    bool isDragging,
  ) {
    final isHighlighted = isSelectedSingle || isHighlightedGroup;

    return Container(
      width: _promptWidth,
      height: _promptHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isHighlighted ? AppTheme.subtleFill : AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDragging
              ? AppTheme.skyBlue
              : isHighlighted
                  ? AppTheme.primaryBlue
                  : const Color(0xFFCBD5E1),
          width: isHighlighted ? 1.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDragging
                ? AppTheme.primaryBlue.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: isDragging ? 6 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              node.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                height: 1.25,
              ),
            ),
          ),
          if (isHighlightedGroup)
            const Positioned(
              right: 0,
              bottom: 0,
              child: Icon(Icons.check_circle, size: 14, color: AppTheme.primaryBlue),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildConnections(
    Map<String, Offset> nodePositions,
    Map<String, Rect> groupRects,
  ) {
    final widgets = <Widget>[];

    for (final conn in widget.engine.connections) {
      final fromNode = widget.engine.nodes.where((n) => n.id == conn.fromId).firstOrNull;
      final toNode = widget.engine.nodes.where((n) => n.id == conn.toId).firstOrNull;

      final isFaded = (fromNode != null && fromNode.isArchived) ||
          (toNode != null && toNode.isArchived);

      Offset? fromCenter;
      Offset? toCenter;

      if (groupRects.containsKey(conn.fromId)) {
        fromCenter = groupRects[conn.fromId]!.center;
      } else if (nodePositions.containsKey(conn.fromId)) {
        final pos = nodePositions[conn.fromId]!;
        final w = fromNode?.isPrompt == true ? _promptWidth : _normalWidth;
        final h = fromNode?.isPrompt == true ? _promptHeight : _normalHeight;
        fromCenter = Offset(pos.dx + w / 2, pos.dy + h / 2);
      }

      if (groupRects.containsKey(conn.toId)) {
        toCenter = groupRects[conn.toId]!.center;
      } else if (nodePositions.containsKey(conn.toId)) {
        final pos = nodePositions[conn.toId]!;
        final w = toNode?.isPrompt == true ? _promptWidth : _normalWidth;
        final h = toNode?.isPrompt == true ? _promptHeight : _normalHeight;
        toCenter = Offset(pos.dx + w / 2, pos.dy + h / 2);
      }

      if (fromCenter != null && toCenter != null) {
        final isSelected = conn == widget.engine.selectedConnection;
        widgets.add(
          CustomPaint(
            size: const Size(_canvasWidth, _canvasHeight),
            painter: BezierConnectionPainter(
              start: fromCenter,
              end: toCenter,
              isSelected: isSelected,
              isFaded: isFaded,
            ),
          ),
        );

        final mid = Offset((fromCenter.dx + toCenter.dx) / 2, (fromCenter.dy + toCenter.dy) / 2);
        widgets.add(
          Positioned(
            left: mid.dx - 18,
            top: mid.dy - 18,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.engine.selectConnection(conn),
              child: Container(
                width: 36,
                height: 36,
                color: Colors.transparent,
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }
}

/// 贝塞尔平滑连线绘制器
class BezierConnectionPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final bool isSelected;
  final bool isFaded;

  BezierConnectionPainter({
    required this.start,
    required this.end,
    required this.isSelected,
    this.isFaded = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isSelected
          ? AppTheme.primaryBlue
          : AppTheme.primaryBlue.withValues(alpha: isFaded ? 0.15 : 0.35)
      ..strokeWidth = isSelected ? 3.0 : 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(start.dx, start.dy);

    final dx = (end.dx - start.dx).abs();
    final dy = (end.dy - start.dy).abs();
    final controlOffset = math.max(dx * 0.45, dy * 0.3);

    path.cubicTo(
      start.dx + (end.dx > start.dx ? controlOffset : -controlOffset),
      start.dy,
      end.dx + (end.dx > start.dx ? -controlOffset : controlOffset),
      end.dy,
      end.dx,
      end.dy,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant BezierConnectionPainter oldDelegate) {
    return oldDelegate.start != start ||
        oldDelegate.end != end ||
        oldDelegate.isSelected != isSelected ||
        oldDelegate.isFaded != isFaded;
  }
}

/// 点阵画布背景绘制器
class DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 32.0;
    final dotPaint = Paint()
      ..color = AppTheme.borderLight.withValues(alpha: 0.85)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.8, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}