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
    required this.isConnectMode,
  });

  @override
  State<NodeCanvasView> createState() => NodeCanvasViewState();
}

class NodeCanvasViewState extends State<NodeCanvasView> {
  final TransformationController _controller = TransformationController();
  final GlobalKey _canvasKey = GlobalKey();

  String? _connectStartId;

  // 节点相对增量拖动状态
  String? _draggingNodeId;
  Offset? _nodeDragStartFingerPos;
  Offset? _nodeDragStartPos;

  // 大节点组拖拽状态
  String? _draggingGroupId;
  Offset? _groupDragStartFingerPos;
  Map<String, Offset>? _groupDragStartPositions;

  // 空白区域框选多选状态
  bool _isMarqueeSelecting = false;
  Offset? _marqueeStart;
  Offset? _marqueeEnd;
  final Set<String> _marqueeSelectedNodeIds = {};
  Map<String, Offset>? _multiDragStartPositions;

  static const double _canvasWidth = 6000.0;
  static const double _canvasHeight = 6000.0;

  static const double _normalWidth = 175.0;
  static const double _normalHeight = 88.0;
  static const double _promptWidth = 150.0;
  static const double _promptHeight = 56.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => centerView());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 居中视角并聚焦现有所有国策的中心质心
  void centerView() {
    if (!mounted) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final positions = _calculateAllPositions();

    double targetCenterX = _canvasWidth / 2;
    double targetCenterY = _canvasHeight / 2;

    if (positions.isNotEmpty) {
      double minX = double.infinity, maxX = -double.infinity;
      double minY = double.infinity, maxY = -double.infinity;
      for (final pos in positions.values) {
        if (pos.dx < minX) minX = pos.dx;
        if (pos.dx > maxX) maxX = pos.dx;
        if (pos.dy < minY) minY = pos.dy;
        if (pos.dy > maxY) maxY = pos.dy;
      }
      targetCenterX = (minX + maxX) / 2;
      targetCenterY = (minY + maxY) / 2;
    }

    const scale = 0.85;
    final tx = (screenWidth / 2) - (targetCenterX * scale);
    final ty = (screenHeight / 2) - (targetCenterY * scale) - 30.0;

    _controller.value = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(0, 3, tx)
      ..setEntry(1, 3, ty);
  }

  /// 实时计算当前屏幕视口在 6000x6000 画布上的真实正中心坐标
  Offset _getViewportCenterInCanvas() {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    final double scale = _controller.value.getMaxScaleOnAxis();
    final double tx = _controller.value.entry(0, 3);
    final double ty = _controller.value.entry(1, 3);

    final double screenCenterX = screenWidth / 2;
    final double screenCenterY = screenHeight / 2;

    final double canvasCenterX = (screenCenterX - tx) / scale;
    final double canvasCenterY = (screenCenterY - ty) / scale;

    return Offset(
      canvasCenterX.clamp(120.0, _canvasWidth - 120.0),
      canvasCenterY.clamp(120.0, _canvasHeight - 120.0),
    );
  }

  Offset _getNodeOffset(FocusNodeModel node, int index) {
    if (node.x != null && node.y != null) {
      return Offset(node.x!, node.y!);
    }
    const colCount = 2;
    const colSpacing = 320.0;
    const rowSpacing = 160.0;
    const startX = (_canvasWidth - colSpacing) / 2;
    const startY = (_canvasHeight / 2) - 100.0;

    final col = index % colCount;
    final row = index ~/ colCount;
    return Offset(startX + (col * colSpacing), startY + (row * rowSpacing));
  }

  Map<String, Offset> _calculateAllPositions() {
    final Map<String, Offset> positions = {};
    for (int i = 0; i < widget.engine.nodes.length; i++) {
      final node = widget.engine.nodes[i];
      positions[node.id] = _getNodeOffset(node, i);
    }
    return positions;
  }

  /// 计算所有大节点外框在画布上的真实外接矩形
  Map<String, Rect> _calculateAllGroupRects(Map<String, Offset> positions) {
    final Map<String, Rect> rects = {};
    for (final group in widget.engine.groups) {
      final groupNodes = widget.engine.nodes
          .where((n) => group.nodeIds.contains(n.id))
          .toList();
      if (groupNodes.isEmpty) continue;

      double minX = double.infinity, maxX = -double.infinity;
      double minY = double.infinity, maxY = -double.infinity;

      for (final node in groupNodes) {
        final pos = positions[node.id];
        if (pos == null) continue;
        final w = node.isPrompt ? _promptWidth : _normalWidth;
        final h = node.isPrompt ? _promptHeight : _normalHeight;

        final left = pos.dx - (w / 2);
        final right = pos.dx + (w / 2);
        final top = pos.dy - (h / 2);
        final bottom = pos.dy + (h / 2);

        if (left < minX) minX = left;
        if (right > maxX) maxX = right;
        if (top < minY) minY = top;
        if (bottom > maxY) maxY = bottom;
      }

      const padH = 20.0;
      const padTop = 38.0;
      const padBottom = 16.0;

      rects[group.id] = Rect.fromLTWH(
        minX - padH,
        minY - padTop,
        (maxX - minX) + (padH * 2),
        (maxY - minY) + padTop + padBottom,
      );
    }
    return rects;
  }

  /// 计算射线从中心指向 target 时与矩形边框的精确交点
  static Offset getRectPerimeterPoint(Rect rect, Offset target) {
    final center = rect.center;
    final dx = target.dx - center.dx;
    final dy = target.dy - center.dy;
    if (dx == 0 && dy == 0) return center;

    final halfW = rect.width / 2;
    final halfH = rect.height / 2;
    final scaleX = dx == 0 ? double.infinity : (halfW / dx.abs());
    final scaleY = dy == 0 ? double.infinity : (halfH / dy.abs());
    final scale = math.min(scaleX, scaleY);
    return center + Offset(dx * scale, dy * scale);
  }

  void _onNodeTap(FocusNodeModel node) {
    if (widget.engine.isGroupSelectMode) {
      widget.engine.toggleNodeInGroupSelect(node.id);
      return;
    }

    if (widget.isConnectMode) {
      if (_connectStartId == null) {
        setState(() => _connectStartId = node.id);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已选「${node.title}」，请点击另一个节点或大节点完成连接'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (_connectStartId == node.id) {
        setState(() => _connectStartId = null);
      } else {
        widget.engine.addConnection(_connectStartId!, node.id);
        setState(() => _connectStartId = null);
      }
      return;
    }

    widget.engine.selectNode(node.id);
  }

  void _onGroupTap(FocusGroupModel group) {
    if (widget.isConnectMode) {
      if (_connectStartId == null) {
        setState(() => _connectStartId = group.id);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已选大节点「${group.title}」，请点击另一个节点或大节点完成连接'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (_connectStartId == group.id) {
        setState(() => _connectStartId = null);
      } else {
        widget.engine.addConnection(_connectStartId!, group.id);
        setState(() => _connectStartId = null);
      }
    }
  }

  /// 连线碰撞检测（兼顾节点与大节点外框交点）
  FocusConnection? _hitTestConnection(
    Offset tapPos,
    Map<String, Offset> positions,
    Map<String, Rect> groupRects,
  ) {
    const double hitRadiusSquared = 22.0 * 22.0;

    for (final conn in widget.engine.connections) {
      final centerA = groupRects[conn.fromId]?.center ?? positions[conn.fromId];
      final centerB = groupRects[conn.toId]?.center ?? positions[conn.toId];
      if (centerA == null || centerB == null) continue;

      final p1 = groupRects.containsKey(conn.fromId)
          ? getRectPerimeterPoint(groupRects[conn.fromId]!, centerB)
          : centerA;
      final p2 = groupRects.containsKey(conn.toId)
          ? getRectPerimeterPoint(groupRects[conn.toId]!, centerA)
          : centerB;

      final p1Ctrl = Offset(p1.dx, (p1.dy + p2.dy) / 2);
      final p2Ctrl = Offset(p2.dx, (p1.dy + p2.dy) / 2);

      for (int i = 0; i <= 24; i++) {
        final t = i / 24.0;
        final u = 1.0 - t;
        final tt = t * t;
        final uu = u * u;
        final uuu = uu * u;
        final ttt = tt * t;

        final curveX = uuu * p1.dx + 3 * uu * t * p1Ctrl.dx + 3 * u * tt * p2Ctrl.dx + ttt * p2.dx;
        final curveY = uuu * p1.dy + 3 * uu * t * p1Ctrl.dy + 3 * u * tt * p2Ctrl.dy + ttt * p2.dy;

        final dx = curveX - tapPos.dx;
        final dy = curveY - tapPos.dy;
        if (dx * dx + dy * dy <= hitRadiusSquared) {
          return conn;
        }
      }
    }
    return null;
  }

  void _updateMarqueeIntersection(Rect marqueeRect, Map<String, Offset> positions) {
    final Set<String> inside = {};
    for (final node in widget.engine.nodes) {
      final pos = positions[node.id];
      if (pos == null) continue;
      final w = node.isPrompt ? _promptWidth : _normalWidth;
      final h = node.isPrompt ? _promptHeight : _normalHeight;
      final nodeRect = Rect.fromCenter(center: pos, width: w, height: h);

      if (marqueeRect.overlaps(nodeRect)) {
        inside.add(node.id);
      }
    }
    setState(() {
      _marqueeSelectedNodeIds.clear();
      _marqueeSelectedNodeIds.addAll(inside);
    });
  }

  void _confirmDeleteGroup(FocusGroupModel group) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          '确认解散大节点？',
          style: TextStyle(
            color: AppTheme.deepNavy,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text('将解散大节点「${group.title}」，框内包含的国策节点将保留。'),
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
            child: const Text('确认解散'),
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
    final positions = _calculateAllPositions();
    final groupRects = _calculateAllGroupRects(positions);
    final inGroupMode = widget.engine.isGroupSelectMode;

    return Container(
      color: AppTheme.bgCanvas,
      child: Stack(
        children: [
          // 视口级动态无限点阵背景
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _InfiniteViewportGridPainter(matrix: _controller.value),
                );
              },
            ),
          ),

          // 画布交互层
          InteractiveViewer(
            transformationController: _controller,
            boundaryMargin: const EdgeInsets.all(4000),
            minScale: 0.25,
            maxScale: 2.5,
            panEnabled: true,
            constrained: false,
            child: GestureDetector(
              onTapUp: (details) {
                final renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                if (renderBox != null) {
                  final local = renderBox.globalToLocal(details.globalPosition);

                  if (!widget.isConnectMode && !inGroupMode) {
                    final hitConn = _hitTestConnection(local, positions, groupRects);
                    if (hitConn != null) {
                      HapticFeedback.selectionClick();
                      widget.engine.selectConnection(hitConn);
                      return;
                    }
                  }

                  if (widget.engine.selectedNodeId != null) {
                    widget.engine.selectNode(null);
                  }
                  if (widget.engine.selectedConnection != null) {
                    widget.engine.selectConnection(null);
                  }
                  if (_marqueeSelectedNodeIds.isNotEmpty) {
                    setState(() => _marqueeSelectedNodeIds.clear());
                  }
                }
              },
              onLongPressStart: (details) {
                final renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                if (renderBox != null) {
                  HapticFeedback.selectionClick();
                  final local = renderBox.globalToLocal(details.globalPosition);
                  setState(() {
                    _isMarqueeSelecting = true;
                    _marqueeStart = local;
                    _marqueeEnd = local;
                    _marqueeSelectedNodeIds.clear();
                  });
                }
              },
              onLongPressMoveUpdate: (details) {
                if (_isMarqueeSelecting && _marqueeStart != null) {
                  final renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                  if (renderBox != null) {
                    final current = renderBox.globalToLocal(details.globalPosition);
                    _marqueeEnd = current;
                    final marqueeRect = Rect.fromPoints(_marqueeStart!, _marqueeEnd!);
                    _updateMarqueeIntersection(marqueeRect, positions);
                  }
                }
              },
              onLongPressEnd: (details) {
                if (_isMarqueeSelecting) {
                  setState(() {
                    _isMarqueeSelecting = false;
                    _marqueeStart = null;
                    _marqueeEnd = null;
                  });
                  if (_marqueeSelectedNodeIds.isNotEmpty) {
                    HapticFeedback.mediumImpact();
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('已框选 ${_marqueeSelectedNodeIds.length} 个节点，长按任意已选国策可整体移动'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              child: SizedBox(
                key: _canvasKey,
                width: _canvasWidth,
                height: _canvasHeight,
                child: Stack(
                  children: [
                    // 1. 连线层
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _TreeConnectionPainter(
                          connections: widget.engine.connections,
                          positions: positions,
                          groupRects: groupRects,
                          selectedConnection: widget.engine.selectedConnection,
                        ),
                      ),
                    ),

                    // 2. 大节点框层
                    ...widget.engine.groups.map((group) {
                      final rect = groupRects[group.id];
                      if (rect == null) return const SizedBox.shrink();
                      return _buildGroupBoundingBox(group, rect, positions);
                    }),

                    // 3. 拉框半透明视觉层
                    if (_isMarqueeSelecting && _marqueeStart != null && _marqueeEnd != null)
                      _buildMarqueeVisualBox(),

                    // 4. 国策卡片层
                    ...nodes.asMap().entries.map((entry) {
                      final node = entry.value;
                      final pos = positions[node.id]!;

                      final isSelectedSingle = node.id == widget.engine.selectedNodeId ||
                          node.id == _connectStartId;
                      final isGroupSelected = widget.engine.groupSelectedNodeIds.contains(node.id);
                      final isMarqueeSelected = _marqueeSelectedNodeIds.contains(node.id);
                      final isDragging = node.id == _draggingNodeId;

                      final w = node.isPrompt ? _promptWidth : _normalWidth;
                      final h = node.isPrompt ? _promptHeight : _normalHeight;

                      return Positioned(
                        left: pos.dx - (w / 2),
                        top: pos.dy - (h / 2),
                        child: GestureDetector(
                          onTap: () => _onNodeTap(node),
                          onLongPressStart: inGroupMode
                              ? null
                              : (details) {
                                  HapticFeedback.mediumImpact();
                                  final renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                                  if (renderBox != null) {
                                    _nodeDragStartFingerPos = renderBox.globalToLocal(details.globalPosition);

                                    if (_marqueeSelectedNodeIds.contains(node.id)) {
                                      _multiDragStartPositions = {
                                        for (final id in _marqueeSelectedNodeIds) id: positions[id]!
                                      };
                                    } else {
                                      _marqueeSelectedNodeIds.clear();
                                      _nodeDragStartPos = positions[node.id]!;
                                    }
                                    setState(() => _draggingNodeId = node.id);
                                  }
                                },
                          onLongPressMoveUpdate: inGroupMode
                              ? null
                              : (details) {
                                  if (_nodeDragStartFingerPos != null) {
                                    final renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                                    if (renderBox != null) {
                                      final currentFinger = renderBox.globalToLocal(details.globalPosition);
                                      final delta = currentFinger - _nodeDragStartFingerPos!;

                                      if (_multiDragStartPositions != null) {
                                        for (final entry in _multiDragStartPositions!.entries) {
                                          final initPos = entry.value;
                                          widget.engine.updateNodePosition(
                                            entry.key,
                                            (initPos.dx + delta.dx).clamp(50.0, _canvasWidth - 50.0),
                                            (initPos.dy + delta.dy).clamp(50.0, _canvasHeight - 50.0),
                                          );
                                        }
                                      } else if (_nodeDragStartPos != null) {
                                        final newX = (_nodeDragStartPos!.dx + delta.dx).clamp(w / 2, _canvasWidth - w / 2);
                                        final newY = (_nodeDragStartPos!.dy + delta.dy).clamp(h / 2, _canvasHeight - h / 2);
                                        widget.engine.updateNodePosition(node.id, newX, newY);
                                      }
                                    }
                                  }
                                },
                          onLongPressEnd: inGroupMode
                              ? null
                              : (details) {
                                  setState(() {
                                    _draggingNodeId = null;
                                    _nodeDragStartFingerPos = null;
                                    _nodeDragStartPos = null;
                                    _multiDragStartPositions = null;
                                  });
                                },
                          child: node.isPrompt
                              ? _buildPromptNodeCard(node, isSelectedSingle, isGroupSelected || isMarqueeSelected, isDragging)
                              : _buildNormalNodeCard(node, isSelectedSingle, isGroupSelected || isMarqueeSelected, isDragging),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),

          if (inGroupMode)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceWhite,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.4)),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.touch_app_outlined, size: 16, color: AppTheme.primaryBlue),
                      const SizedBox(width: 6),
                      Text(
                        '直接在画布上点击国策进行多选 (已选 ${widget.engine.groupSelectedNodeIds.length} 个)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.deepNavy,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          Positioned(
            right: 16,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'tree_center_btn',
                  backgroundColor: AppTheme.surfaceWhite,
                  foregroundColor: AppTheme.deepNavy,
                  elevation: 2,
                  tooltip: '对齐居中所有国策',
                  onPressed: centerView,
                  child: const Icon(Icons.center_focus_strong_outlined, size: 20),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'tree_add_node_btn',
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 3,
                  tooltip: '添加国策节点',
                  onPressed: () {
                    final center = _getViewportCenterInCanvas();
                    showDialog(
                      context: context,
                      builder: (ctx) => AddNodeDialog(
                        engine: widget.engine,
                        spawnPosition: center,
                      ),
                    );
                  },
                  child: const Icon(Icons.add, size: 26),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarqueeVisualBox() {
    final rect = Rect.fromPoints(_marqueeStart!, _marqueeEnd!);
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AppTheme.primaryBlue.withValues(alpha: 0.6),
              width: 1.5,
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
        .where((n) => group.nodeIds.contains(n.id))
        .toList();

    final totalProgress = groupNodes.fold<int>(0, (sum, n) => sum + n.progress);
    final progColor = ProgressColorHelper.getColor(totalProgress);
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
              for (final n in groupNodes) n.id: positions[n.id]!
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
                        color: ProgressColorHelper.getBgColor(totalProgress),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: progColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        totalProgress >= 0 ? '+$totalProgress' : '$totalProgress',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: progColor,
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

  Widget _buildNormalNodeCard(
    FocusNodeModel node,
    bool isSelectedSingle,
    bool isHighlightedGroup,
    bool isDragging,
  ) {
    final progColor = ProgressColorHelper.getColor(node.progress);
    final progBg = ProgressColorHelper.getBgColor(node.progress);
    final solidBgColor = Color.alphaBlend(progBg, AppTheme.surfaceWhite);

    final isHighlighted = isSelectedSingle || isHighlightedGroup;

    return Container(
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
                  : progColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDragging
                ? AppTheme.primaryBlue.withValues(alpha: 0.35)
                : isHighlighted
                    ? AppTheme.primaryBlue.withValues(alpha: 0.2)
                    : progColor.withValues(alpha: 0.08),
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
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.deepNavy),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '+${node.increaseCount}',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.green.shade700),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '-${node.decreaseCount}',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.red.shade700),
                        ),
                      ),
                    ],
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
    );
  }

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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isHighlighted ? AppTheme.subtleFill : AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDragging
              ? AppTheme.skyBlue
              : isHighlighted
                  ? AppTheme.primaryBlue
                  : AppTheme.skyBlue.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.skyBlue.withValues(alpha: 0.12),
            blurRadius: (isDragging || isHighlighted) ? 6 : 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          node.content.isEmpty ? node.title : node.content,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppTheme.deepNavy,
            height: 1.25,
          ),
        ),
      ),
    );
  }
}

class _InfiniteViewportGridPainter extends CustomPainter {
  final Matrix4 matrix;

  _InfiniteViewportGridPainter({required this.matrix});

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = matrix.getMaxScaleOnAxis();
    final double tx = matrix.entry(0, 3);
    final double ty = matrix.entry(1, 3);

    const double baseStep = 32.0;
    double stepOnScreen = baseStep * scale;

    while (stepOnScreen < 18.0) {
      stepOnScreen *= 2;
    }

    double startX = tx % stepOnScreen;
    if (startX > 0) startX -= stepOnScreen;

    double startY = ty % stepOnScreen;
    if (startY > 0) startY -= stepOnScreen;

    final dotPaint = Paint()
      ..color = AppTheme.primaryBlue.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final double dotRadius = (1.2 * scale).clamp(0.8, 1.8);

    for (double x = startX; x <= size.width + stepOnScreen; x += stepOnScreen) {
      for (double y = startY; y <= size.height + stepOnScreen; y += stepOnScreen) {
        canvas.drawCircle(Offset(x, y), dotRadius, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _InfiniteViewportGridPainter oldDelegate) =>
      oldDelegate.matrix != matrix;
}

class _TreeConnectionPainter extends CustomPainter {
  final Set<FocusConnection> connections;
  final Map<String, Offset> positions;
  final Map<String, Rect> groupRects;
  final FocusConnection? selectedConnection;

  _TreeConnectionPainter({
    required this.connections,
    required this.positions,
    required this.groupRects,
    this.selectedConnection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final conn in connections) {
      final centerA = groupRects[conn.fromId]?.center ?? positions[conn.fromId];
      final centerB = groupRects[conn.toId]?.center ?? positions[conn.toId];
      if (centerA == null || centerB == null) continue;

      final p1 = groupRects.containsKey(conn.fromId)
          ? NodeCanvasViewState.getRectPerimeterPoint(groupRects[conn.fromId]!, centerB)
          : centerA;
      final p2 = groupRects.containsKey(conn.toId)
          ? NodeCanvasViewState.getRectPerimeterPoint(groupRects[conn.toId]!, centerA)
          : centerB;

      final path = Path();
      path.moveTo(p1.dx, p1.dy);
      path.cubicTo(
        p1.dx,
        (p1.dy + p2.dy) / 2,
        p2.dx,
        (p1.dy + p2.dy) / 2,
        p2.dx,
        p2.dy,
      );

      final isSelected = conn == selectedConnection;

      if (isSelected) {
        final glowPaint = Paint()
          ..color = AppTheme.primaryBlue.withValues(alpha: 0.28)
          ..strokeWidth = 9.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(path, glowPaint);
      }

      final linePaint = Paint()
        ..color = isSelected ? AppTheme.primaryBlue : AppTheme.primaryBlue.withValues(alpha: 0.45)
        ..strokeWidth = isSelected ? 3.0 : 2.0
        ..style = PaintingStyle.stroke;

      canvas.drawPath(path, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TreeConnectionPainter oldDelegate) => true;
}