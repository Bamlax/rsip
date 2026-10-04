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

  // 节点拖拽
  String? _draggingNodeId;
  Offset? _nodeDragStartFingerPos;
  Offset? _nodeDragStartPos;

  // 大节点组拖拽
  String? _draggingGroupId;
  Offset? _groupDragStartFingerPos;
  Map<String, Offset>? _groupDragStartPositions;

  // 框选
  bool _isMarqueeSelecting = false;
  Offset? _marqueeStart;
  Offset? _marqueeEnd;
  final Set<String> _marqueeSelectedNodeIds = {};
  Map<String, Offset>? _multiDragStartPositions;

  static const double _canvasWidth = 6000.0;
  static const double _canvasHeight = 6000.0;

  static const double _normalWidth = 175.0;
  static const double _normalHeight = 88.0;
  static const double _promptWidth = 145.0;
  static const double _promptHeight = 54.0;

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
            content: Text('已选「${node.title}」，请点击另一个节点完成连接'),
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

  /// 连线碰撞检测：检测手指点击是否命中了贝塞尔曲线
  FocusConnection? _hitTestConnection(Offset tapPos, Map<String, Offset> positions) {
    const double hitRadiusSquared = 22.0 * 22.0;

    for (final conn in widget.engine.connections) {
      final p1 = positions[conn.fromId];
      final p2 = positions[conn.toId];
      if (p1 == null || p2 == null) continue;

      final p1Ctrl = Offset(p1.dx, (p1.dy + p2.dy) / 2);
      final p2Ctrl = Offset(p2.dx, (p1.dy + p2.dy) / 2);

      // 采样 25 个点计算与点击位置的距离
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

  @override
  Widget build(BuildContext context) {
    final nodes = widget.engine.nodes;
    final positions = _calculateAllPositions();
    final inGroupMode = widget.engine.isGroupSelectMode;

    return Container(
      color: AppTheme.bgCanvas,
      child: Stack(
        children: [
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

                  // 1. 如果点击了某条连接线：选中该连线
                  if (!widget.isConnectMode && !inGroupMode) {
                    final hitConn = _hitTestConnection(local, positions);
                    if (hitConn != null) {
                      HapticFeedback.selectionClick();
                      widget.engine.selectConnection(hitConn);
                      return;
                    }
                  }

                  // 2. 点击空白处清除所有选中
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
                    // 1. 连线层（支持高亮选中连线）
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _TreeConnectionPainter(
                          connections: widget.engine.connections,
                          positions: positions,
                          selectedConnection: widget.engine.selectedConnection,
                        ),
                      ),
                    ),

                    // 2. 大节点框层
                    ...widget.engine.groups.map((group) {
                      return _buildGroupBoundingBox(group, positions);
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
                    showDialog(
                      context: context,
                      builder: (ctx) => AddNodeDialog(engine: widget.engine),
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

  Widget _buildGroupBoundingBox(FocusGroupModel group, Map<String, Offset> positions) {
    final groupNodes = widget.engine.nodes
        .where((n) => group.nodeIds.contains(n.id))
        .toList();

    if (groupNodes.isEmpty) return const SizedBox.shrink();

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

    final boxLeft = minX - padH;
    final boxTop = minY - padTop;
    final boxWidth = (maxX - minX) + (padH * 2);
    final boxHeight = (maxY - minY) + padTop + padBottom;

    final totalProgress = groupNodes.fold<int>(0, (sum, n) => sum + n.progress);
    final progColor = ProgressColorHelper.getColor(totalProgress);
    final isGroupDragging = _draggingGroupId == group.id;

    return Positioned(
      left: boxLeft,
      top: boxTop,
      width: boxWidth,
      height: boxHeight,
      child: GestureDetector(
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
              color: isGroupDragging
                  ? AppTheme.primaryBlue
                  : AppTheme.skyBlue.withValues(alpha: 0.55),
              width: isGroupDragging ? 2.5 : 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 12, right: 10, top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.drag_indicator_rounded, size: 14, color: AppTheme.primaryBlue),
                    const SizedBox(width: 4),
                    Text(
                      group.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.deepNavy,
                      ),
                    ),
                  ],
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
                        '总进度: ${totalProgress >= 0 ? "+$totalProgress" : totalProgress}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: progColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => widget.engine.deleteGroup(group.id),
                      child: Container(
                        padding: const EdgeInsets.all(2),
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

  /// 提示块优化：无图标、字体放大至 13 且垂直水平完全居中
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
      // 去掉图标，内容整体居中对齐
      child: Center(
        child: Text(
          node.content.isEmpty ? node.title : node.content,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.deepNavy,
            height: 1.3,
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
  final FocusConnection? selectedConnection; // 选中高亮

  _TreeConnectionPainter({
    required this.connections,
    required this.positions,
    this.selectedConnection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final conn in connections) {
      final p1 = positions[conn.fromId];
      final p2 = positions[conn.toId];
      if (p1 != null && p2 != null) {
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

        // 选中连线时光晕高亮效果
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
  }

  @override
  bool shouldRepaint(covariant _TreeConnectionPainter oldDelegate) => true;
}