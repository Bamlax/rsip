import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
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

/// 时间轴某一帧上的虚拟节点快照
class _TimelineNodeSnapshot {
  final String id;
  String title;
  String content;
  final bool isPrompt;
  final bool isArchived;
  final double x;
  final double y;
  final DateTime createdAt;

  int progress = 0;
  int increaseCount = 0;
  int decreaseCount = 0;
  int consecutiveCount = 0;
  double score = 0.0;

  String? activeEffect;

  _TimelineNodeSnapshot({
    required this.id,
    required this.title,
    required this.content,
    required this.isPrompt,
    required this.isArchived,
    required this.x,
    required this.y,
    required this.createdAt,
  });
}

class _TimelineConnectionSnapshot {
  final String fromId;
  final String toId;
  String? activeEffect;

  _TimelineConnectionSnapshot({
    required this.fromId,
    required this.toId,
  });
}

class _TimelineGroupSnapshot {
  final String id;
  final String title;
  final Set<String> nodeIds;
  String? activeEffect;

  _TimelineGroupSnapshot({
    required this.id,
    required this.title,
    required Set<String> nodeIds,
  }) : nodeIds = Set.from(nodeIds);
}

class _TimelineFrameState {
  final List<_TimelineNodeSnapshot> nodes;
  final List<_TimelineConnectionSnapshot> connections;
  final List<_TimelineGroupSnapshot> groups;
  final TimelineEventModel? currentEvent;

  const _TimelineFrameState({
    required this.nodes,
    required this.connections,
    required this.groups,
    this.currentEvent,
  });
}

class _NodeCanvasViewState extends State<NodeCanvasView> {
  final TransformationController _transController = TransformationController();
  final GlobalKey _canvasKey = GlobalKey();

  static const double _canvasWidth = 6000.0;
  static const double _canvasHeight = 6000.0;
  static const double _normalWidth = 150.0;
  static const double _normalHeight = 70.0;
  static const double _promptWidth = 104.0;
  static const double _promptHeight = 50.0;

  String? _connectStartId;

  // 大节点长按协同拖拽状态
  String? _draggingGroupId;
  Offset? _groupDragStartFingerPos;
  Map<String, Offset>? _groupDragStartPositions;

  // 单个或多选节点拖拽状态
  String? _draggingNodeId;
  Offset? _nodeDragStartPos;
  Offset? _nodeDragStartFingerPos;
  Map<String, Offset>? _multiDragStartPositions;

  // 长按空白界面 1 秒拉出多选框状态（无进度环提示）
  int _activePointers = 0;
  Timer? _marqueeHoldTimer;
  Offset? _marqueeHoldScenePos;
  bool _isMarqueeSelecting = false;
  Offset? _marqueeStartScene;
  Offset? _marqueeCurrentScene;

  // 时间轴回放控制状态
  bool _wasTimelineMode = false;
  bool _isTimelinePlaying = false;
  int _timelineStepIndex = 0;
  double _playbackSpeed = 1.0;
  Timer? _playbackTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerCanvas());
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _cancelMarqueeHold();
    _transController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NodeCanvasView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isConnectMode && _connectStartId != null) {
      setState(() => _connectStartId = null);
    }
  }

  void _cancelMarqueeHold() {
    _marqueeHoldTimer?.cancel();
    _marqueeHoldTimer = null;
    _marqueeHoldScenePos = null;
  }

  bool _isPointOverAnyNode(Offset scenePos) {
    for (final node in widget.engine.nodes) {
      final nx = (node.x ?? _canvasWidth / 2).clamp(50.0, _canvasWidth - 50.0);
      final ny = (node.y ?? _canvasHeight / 2).clamp(50.0, _canvasHeight - 50.0);
      final w = node.isPrompt ? _promptWidth : _normalWidth;
      final h = node.isPrompt ? _promptHeight : _normalHeight;
      final rect = Rect.fromLTWH(nx, ny, w, h);
      if (rect.contains(scenePos)) {
        return true;
      }
    }
    return false;
  }

  void _updateMarqueeSelection() {
    if (_marqueeStartScene == null || _marqueeCurrentScene == null) return;
    final selectionRect =
        Rect.fromPoints(_marqueeStartScene!, _marqueeCurrentScene!);

    final Set<String> hitIds = {};
    for (final node in widget.engine.nodes) {
      if (node.isArchived) continue;
      final nx = (node.x ?? _canvasWidth / 2).clamp(50.0, _canvasWidth - 50.0);
      final ny = (node.y ?? _canvasHeight / 2).clamp(50.0, _canvasHeight - 50.0);
      final w = node.isPrompt ? _promptWidth : _normalWidth;
      final h = node.isPrompt ? _promptHeight : _normalHeight;
      final nodeRect = Rect.fromLTWH(nx, ny, w, h);
      if (selectionRect.overlaps(nodeRect)) {
        hitIds.add(node.id);
      }
    }
    widget.engine.setMultiSelectedNodes(hitIds);
  }

  void _syncTimelineLifecycle() {
    final isTimeline = widget.engine.isTimelineMode;
    if (isTimeline && !_wasTimelineMode) {
      _wasTimelineMode = true;
      _cancelMarqueeHold();
      final events = widget.engine.buildOrderedTimelineEvents(
        includeProgressChanges: widget.engine.timelineShowProgressChanges,
      );
      _timelineStepIndex = 0;
      if (events.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.engine.isTimelineMode) {
            _startTimelinePlayback();
          }
        });
      }
    } else if (!isTimeline && _wasTimelineMode) {
      _wasTimelineMode = false;
      _stopTimelinePlayback();
    }
  }

  void _startTimelinePlayback() {
    _playbackTimer?.cancel();
    final events = widget.engine.buildOrderedTimelineEvents(
      includeProgressChanges: widget.engine.timelineShowProgressChanges,
    );
    if (events.isEmpty) return;

    if (_timelineStepIndex >= events.length - 1) {
      setState(() => _timelineStepIndex = 0);
    }

    setState(() => _isTimelinePlaying = true);
    final intervalMs = (900 / _playbackSpeed).round().clamp(180, 1200);

    _playbackTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (!mounted || !widget.engine.isTimelineMode) {
        timer.cancel();
        return;
      }
      final currentEvents = widget.engine.buildOrderedTimelineEvents(
        includeProgressChanges: widget.engine.timelineShowProgressChanges,
      );
      if (_timelineStepIndex < currentEvents.length - 1) {
        setState(() {
          _timelineStepIndex++;
        });
      } else {
        _stopTimelinePlayback();
      }
    });
  }

  void _stopTimelinePlayback() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    if (mounted && _isTimelinePlaying) {
      setState(() => _isTimelinePlaying = false);
    }
  }

  void _stepTimelineBackward() {
    _stopTimelinePlayback();
    if (_timelineStepIndex > 0) {
      setState(() {
        _timelineStepIndex--;
      });
    }
  }

  void _stepTimelineForward(int totalEvents) {
    _stopTimelinePlayback();
    if (_timelineStepIndex < totalEvents - 1) {
      setState(() {
        _timelineStepIndex++;
      });
    }
  }

  void _cyclePlaybackSpeed() {
    setState(() {
      if (_playbackSpeed == 1.0) {
        _playbackSpeed = 2.0;
      } else if (_playbackSpeed == 2.0) {
        _playbackSpeed = 4.0;
      } else {
        _playbackSpeed = 1.0;
      }
    });
    if (_isTimelinePlaying) {
      _startTimelinePlayback();
    }
  }

  _TimelineFrameState _computeTimelineFrame(
    List<TimelineEventModel> events,
    int stepIndex,
    bool showProgressChanges,
  ) {
    if (events.isEmpty) {
      return const _TimelineFrameState(
        nodes: [],
        connections: [],
        groups: [],
      );
    }

    final clampedStep = stepIndex.clamp(0, events.length - 1);
    final Map<String, _TimelineNodeSnapshot> nodeMap = {};
    final List<_TimelineConnectionSnapshot> connList = [];
    final Map<String, _TimelineGroupSnapshot> groupMap = {};
    final List<ProgressRecord> recordsUpToStep = [];

    for (int i = 0; i <= clampedStep; i++) {
      final evt = events[i];
      final isCurrentFrame = i == clampedStep;

      for (final n in nodeMap.values) {
        n.activeEffect = null;
      }
      for (final c in connList) {
        c.activeEffect = null;
      }
      for (final g in groupMap.values) {
        g.activeEffect = null;
      }

      switch (evt.type) {
        case TimelineEventType.nodeCreated:
          final liveNode = widget.engine.nodes
              .where((n) => n.id == evt.targetId)
              .firstOrNull;
          final snap = _TimelineNodeSnapshot(
            id: evt.targetId,
            title: evt.title ?? liveNode?.title ?? '',
            content: evt.content ?? liveNode?.content ?? '',
            isPrompt: evt.isPrompt,
            isArchived: liveNode?.isArchived ?? evt.isArchived,
            x: (liveNode?.x ?? evt.x ?? _canvasWidth / 2)
                .clamp(50.0, _canvasWidth - 50.0),
            y: (liveNode?.y ?? evt.y ?? _canvasHeight / 2)
                .clamp(50.0, _canvasHeight - 50.0),
            createdAt: evt.time,
          );
          if (isCurrentFrame) snap.activeEffect = 'created';
          nodeMap[evt.targetId] = snap;
          break;

        case TimelineEventType.nodeUpdated:
          final snap = nodeMap[evt.targetId];
          if (snap != null) {
            if (evt.title != null) snap.title = evt.title!;
            if (evt.content != null) snap.content = evt.content!;
            if (isCurrentFrame) snap.activeEffect = 'updated';
          }
          break;

        case TimelineEventType.nodeDeleted:
          if (isCurrentFrame) {
            final snap = nodeMap[evt.targetId] ??
                _TimelineNodeSnapshot(
                  id: evt.targetId,
                  title: evt.title ?? '已删除国策',
                  content: evt.content ?? '',
                  isPrompt: evt.isPrompt,
                  isArchived: false,
                  x: (evt.x ?? _canvasWidth / 2)
                      .clamp(50.0, _canvasWidth - 50.0),
                  y: (evt.y ?? _canvasHeight / 2)
                      .clamp(50.0, _canvasHeight - 50.0),
                  createdAt: evt.time,
                );
            snap.activeEffect = 'deleted';
            nodeMap[evt.targetId] = snap;
          } else {
            nodeMap.remove(evt.targetId);
            connList.removeWhere(
              (c) => c.fromId == evt.targetId || c.toId == evt.targetId,
            );
            for (final g in groupMap.values) {
              g.nodeIds.remove(evt.targetId);
            }
          }
          break;

        case TimelineEventType.connectionAdded:
          final toId = evt.secondaryId;
          if (toId != null) {
            final exists = connList.any((c) =>
                (c.fromId == evt.targetId && c.toId == toId) ||
                (c.fromId == toId && c.toId == evt.targetId));
            if (!exists) {
              final connSnap = _TimelineConnectionSnapshot(
                fromId: evt.targetId,
                toId: toId,
              );
              if (isCurrentFrame) connSnap.activeEffect = 'added';
              connList.add(connSnap);
            }
          }
          break;

        case TimelineEventType.connectionRemoved:
          final toId = evt.secondaryId;
          if (toId != null) {
            if (isCurrentFrame) {
              for (final c in connList) {
                if ((c.fromId == evt.targetId && c.toId == toId) ||
                    (c.fromId == toId && c.toId == evt.targetId)) {
                  c.activeEffect = 'removed';
                }
              }
            } else {
              connList.removeWhere((c) =>
                  (c.fromId == evt.targetId && c.toId == toId) ||
                  (c.fromId == toId && c.toId == evt.targetId));
            }
          }
          break;

        case TimelineEventType.groupAdded:
          final gSnap = _TimelineGroupSnapshot(
            id: evt.targetId,
            title: evt.title ?? '分类组',
            nodeIds: (evt.nodeIds ?? []).toSet(),
          );
          if (isCurrentFrame) gSnap.activeEffect = 'added';
          groupMap[evt.targetId] = gSnap;
          break;

        case TimelineEventType.groupRemoved:
          if (isCurrentFrame) {
            final gSnap = groupMap[evt.targetId];
            if (gSnap != null) {
              gSnap.activeEffect = 'removed';
            }
          } else {
            groupMap.remove(evt.targetId);
            connList.removeWhere(
              (c) => c.fromId == evt.targetId || c.toId == evt.targetId,
            );
          }
          break;

        case TimelineEventType.progressChanged:
          final snap = nodeMap[evt.targetId];
          if (snap != null && !snap.isPrompt) {
            if (!evt.isSkip) {
              snap.progress += evt.delta;
              if (evt.delta > 0) {
                snap.increaseCount += 1;
                snap.consecutiveCount += 1;
              } else if (evt.delta < 0) {
                snap.decreaseCount += 1;
                snap.consecutiveCount = 0;
              }
            }
            if (isCurrentFrame) {
              snap.activeEffect =
                  evt.isSkip ? 'skip' : (evt.delta > 0 ? 'inc' : 'dec');
            }
          }
          recordsUpToStep.add(
            ProgressRecord(
              id: evt.id,
              nodeId: evt.targetId,
              nodeTitle: evt.title ?? '',
              delta: evt.delta,
              resultProgress: snap?.progress ?? 0,
              isSkip: evt.isSkip,
              time: evt.time,
            ),
          );
          break;
      }
    }

    final currentEvt = events[clampedStep];

    if (showProgressChanges) {
      for (final snap in nodeMap.values) {
        if (snap.isPrompt) continue;
        final res = widget.engine.computeNodeScoreFromRecords(
          nodeId: snap.id,
          createdAt: snap.createdAt,
          recordsUpToNow: recordsUpToStep,
          referenceTime: currentEvt.time,
        );
        snap.score = res.score;
      }
    }

    return _TimelineFrameState(
      nodes: nodeMap.values.toList(),
      connections: connList,
      groups: groupMap.values.toList(),
      currentEvent: currentEvt,
    );
  }

  String _formatEventTimestamp(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _describeTimelineEvent(TimelineEventModel evt) {
    final typePrefix = evt.isPrompt ? '提示' : '国策';
    final name = (evt.title != null && evt.title!.isNotEmpty)
        ? '「${evt.title}」'
        : '';
    switch (evt.type) {
      case TimelineEventType.nodeCreated:
        return '新增$typePrefix $name';
      case TimelineEventType.nodeUpdated:
        return '修订$typePrefix $name';
      case TimelineEventType.nodeDeleted:
        return '删除$typePrefix $name';
      case TimelineEventType.connectionAdded:
        return '建立节点连线';
      case TimelineEventType.connectionRemoved:
        return '移除节点连线';
      case TimelineEventType.groupAdded:
        return '创建大节点 $name';
      case TimelineEventType.groupRemoved:
        return '解散大节点 $name';
      case TimelineEventType.progressChanged:
        if (evt.isSkip) return '$name 跳过';
        return evt.delta > 0 ? '$name +1' : '$name -1';
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
    if (widget.engine.isTimelineMode) return;
    if (widget.engine.isGroupSelectMode) return;
    if (_connectStartId != null) {
      setState(() => _connectStartId = null);
    }
    if (widget.engine.isMultiSelectMode) {
      widget.engine.clearMultiSelection();
    }
    widget.engine.selectNode(null);
    widget.engine.selectConnection(null);
  }

  void _onCanvasDoubleTap(TapDownDetails details) {
    if (widget.engine.isTimelineMode) return;
    if (widget.engine.isGroupSelectMode) return;
    if (widget.engine.isMultiSelectMode) return;
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
    if (widget.engine.isTimelineMode) return;
    if (widget.engine.isGroupSelectMode) {
      widget.engine.toggleNodeInGroupSelect(node.id);
      return;
    }

    if (widget.engine.isMultiSelectMode) {
      widget.engine.toggleNodeInMultiSelect(node.id);
      return;
    }

    if (widget.isConnectMode) {
      _handleConnectTap(node.id);
      return;
    }

    widget.engine.selectNode(node.id);
  }

  void _onGroupTap(FocusGroupModel group) {
    if (widget.engine.isTimelineMode) return;
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
    _syncTimelineLifecycle();

    if (widget.engine.isTimelineMode) {
      return _buildTimelinePlaybackCanvas();
    }

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

    final Rect? activeMarqueeRect = (_isMarqueeSelecting &&
            _marqueeStartScene != null &&
            _marqueeCurrentScene != null)
        ? Rect.fromPoints(_marqueeStartScene!, _marqueeCurrentScene!)
        : null;

    return GestureDetector(
      onTap: _onCanvasTap,
      onDoubleTapDown: _onCanvasDoubleTap,
      child: InteractiveViewer(
        transformationController: _transController,
        panEnabled: !_isMarqueeSelecting,
        scaleEnabled: !_isMarqueeSelecting,
        boundaryMargin: const EdgeInsets.all(3000),
        minScale: 0.1,
        maxScale: 3.5,
        constrained: false,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            _activePointers++;
            if (_activePointers > 1) {
              _cancelMarqueeHold();
              return;
            }
            if (event.buttons != kPrimaryButton) return;
            if (widget.engine.isTimelineMode ||
                widget.engine.isGroupSelectMode ||
                widget.isConnectMode ||
                _draggingNodeId != null ||
                _draggingGroupId != null) {
              return;
            }

            final scenePos = event.localPosition;
            if (_isPointOverAnyNode(scenePos)) return;

            _cancelMarqueeHold();
            _marqueeHoldScenePos = scenePos;

            // 长按空白处 1 秒后直接开启框选（无视觉提示）
            _marqueeHoldTimer = Timer(const Duration(seconds: 1), () {
              if (!mounted || _activePointers != 1) return;
              HapticFeedback.mediumImpact();
              setState(() {
                _marqueeHoldScenePos = null;
                _isMarqueeSelecting = true;
                _marqueeStartScene = scenePos;
                _marqueeCurrentScene = scenePos;
              });
              _updateMarqueeSelection();
            });
          },
          onPointerMove: (event) {
            if (_isMarqueeSelecting) {
              setState(() {
                _marqueeCurrentScene = event.localPosition;
              });
              _updateMarqueeSelection();
              return;
            }

            if (_marqueeHoldTimer != null && _marqueeHoldScenePos != null) {
              final scale = _transController.value.getMaxScaleOnAxis();
              final screenDist =
                  (event.localPosition - _marqueeHoldScenePos!).distance *
                      scale;
              if (screenDist > 12.0) {
                _cancelMarqueeHold();
              }
            }
          },
          onPointerUp: (_) {
            _activePointers = math.max(0, _activePointers - 1);
            _cancelMarqueeHold();
            if (_isMarqueeSelecting) {
              setState(() {
                _isMarqueeSelecting = false;
                _marqueeStartScene = null;
                _marqueeCurrentScene = null;
              });
            }
          },
          onPointerCancel: (_) {
            _activePointers = math.max(0, _activePointers - 1);
            _cancelMarqueeHold();
            if (_isMarqueeSelecting) {
              setState(() {
                _isMarqueeSelecting = false;
                _marqueeStartScene = null;
                _marqueeCurrentScene = null;
              });
            }
          },
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
                  // 1. 连线视觉绘制层
                  ..._buildConnectionVisuals(nodePositions, groupRects),

                  // 2. 分类大框层
                  for (final group in groups)
                    if (groupRects.containsKey(group.id))
                      _buildGroupBoundingBox(
                          group, groupRects[group.id]!, nodePositions),

                  // 3. 连线精确点击检测层
                  if (!widget.isConnectMode &&
                      !widget.engine.isGroupSelectMode &&
                      !_isMarqueeSelecting)
                    ..._buildConnectionHitTargets(nodePositions, groupRects),

                  // 4. 国策卡片层
                  for (final node in nodes)
                    if (nodePositions.containsKey(node.id))
                      _buildNodeCardWrapper(
                          node, nodePositions[node.id]!, nodePositions),

                  // 5. 框选矩形遮罩层
                  if (activeMarqueeRect != null)
                    Positioned(
                      left: activeMarqueeRect.left,
                      top: activeMarqueeRect.top,
                      width: activeMarqueeRect.width,
                      height: activeMarqueeRect.height,
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppTheme.primaryBlue,
                              width: 1.8,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 时间轴回放画布与顶部控制栏
  // ==========================================

  Widget _buildTimelinePlaybackCanvas() {
    final showChanges = widget.engine.timelineShowProgressChanges;
    final events = widget.engine.buildOrderedTimelineEvents(
      includeProgressChanges: showChanges,
    );

    final safeStep =
        events.isEmpty ? 0 : _timelineStepIndex.clamp(0, events.length - 1);
    final frame = _computeTimelineFrame(events, safeStep, showChanges);

    final Map<String, Offset> nodePositions = {
      for (final n in frame.nodes) n.id: Offset(n.x, n.y),
    };

    final Map<String, Rect> groupRects = {};
    for (final group in frame.groups) {
      double minX = double.infinity;
      double minY = double.infinity;
      double maxX = -double.infinity;
      double maxY = -double.infinity;
      bool hasAny = false;

      for (final nId in group.nodeIds) {
        final snap = frame.nodes.where((n) => n.id == nId).firstOrNull;
        if (snap != null) {
          hasAny = true;
          final w = snap.isPrompt ? _promptWidth : _normalWidth;
          final h = snap.isPrompt ? _promptHeight : _normalHeight;
          minX = math.min(minX, snap.x);
          minY = math.min(minY, snap.y);
          maxX = math.max(maxX, snap.x + w);
          maxY = math.max(maxY, snap.y + h);
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

    return Stack(
      children: [
        InteractiveViewer(
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
                  ..._buildTimelineConnections(
                    frame.connections,
                    frame.nodes,
                    nodePositions,
                    groupRects,
                  ),
                  for (final group in frame.groups)
                    if (groupRects.containsKey(group.id))
                      _buildTimelineGroupBox(
                        group,
                        groupRects[group.id]!,
                        frame.nodes,
                        showChanges,
                      ),
                  for (final snap in frame.nodes)
                    _buildTimelineNodeCard(snap, showChanges),
                ],
              ),
            ),
          ),
        ),

        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceWhite,
              border: Border(
                bottom: BorderSide(color: AppTheme.borderLight, width: 0.9),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x0A0F172A),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: events.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: Text(
                        '暂无国策树演化记录',
                        style: TextStyle(fontSize: 12, color: Colors.black45),
                      ),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          _buildStepControlButton(
                            icon: Icons.skip_previous_rounded,
                            tooltip: '上一帧',
                            enabled: safeStep > 0,
                            onTap: _stepTimelineBackward,
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              if (_isTimelinePlaying) {
                                _stopTimelinePlayback();
                              } else {
                                _startTimelinePlayback();
                              }
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryBlue,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isTimelinePlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildStepControlButton(
                            icon: Icons.skip_next_rounded,
                            tooltip: '下一帧',
                            enabled: safeStep < events.length - 1,
                            onTap: () => _stepTimelineForward(events.length),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3.0,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6.5,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 12,
                                ),
                              ),
                              child: Slider(
                                value: safeStep.toDouble(),
                                min: 0,
                                max: math.max(1, events.length - 1).toDouble(),
                                divisions: events.length > 1
                                    ? events.length - 1
                                    : null,
                                activeColor: AppTheme.primaryBlue,
                                inactiveColor: AppTheme.borderLight,
                                onChanged: events.length <= 1
                                    ? null
                                    : (val) {
                                        _stopTimelinePlayback();
                                        setState(() {
                                          _timelineStepIndex = val.round();
                                        });
                                      },
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${safeStep + 1}/${events.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: _cyclePlaybackSpeed,
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.bgCanvas,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.borderLight),
                              ),
                              child: Text(
                                '${_playbackSpeed.toInt()}x',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.deepNavy,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (frame.currentEvent != null)
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.subtleFill,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _describeTimelineEvent(
                                          frame.currentEvent!),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      _formatEventTimestamp(
                                          frame.currentEvent!.time),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        color: Colors.black45,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            const Spacer(),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              final currentEvtId = frame.currentEvent?.id;
                              final nextShow = !showChanges;
                              widget.engine
                                  .setTimelineShowProgressChanges(nextShow);

                              final nextEvents =
                                  widget.engine.buildOrderedTimelineEvents(
                                includeProgressChanges: nextShow,
                              );
                              int targetIdx = 0;
                              if (currentEvtId != null &&
                                  nextEvents.isNotEmpty) {
                                final exactIdx = nextEvents
                                    .indexWhere((e) => e.id == currentEvtId);
                                if (exactIdx != -1) {
                                  targetIdx = exactIdx;
                                } else if (frame.currentEvent != null) {
                                  final t = frame.currentEvent!.time;
                                  final found = nextEvents
                                      .lastIndexWhere((e) => !e.time.isAfter(t));
                                  targetIdx = found == -1 ? 0 : found;
                                }
                              }
                              setState(() {
                                _timelineStepIndex = targetIdx;
                              });
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3.5,
                              ),
                              decoration: BoxDecoration(
                                color: showChanges
                                    ? AppTheme.primaryBlue
                                        .withValues(alpha: 0.12)
                                    : AppTheme.bgCanvas,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: showChanges
                                      ? AppTheme.primaryBlue
                                      : AppTheme.borderLight,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    showChanges
                                        ? Icons.check_box_rounded
                                        : Icons.check_box_outline_blank_rounded,
                                    size: 14,
                                    color: showChanges
                                        ? AppTheme.primaryBlue
                                        : Colors.black45,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '显示增减变化',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: showChanges
                                          ? AppTheme.primaryBlue
                                          : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepControlButton({
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.bgCanvas,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled ? AppTheme.deepNavy : Colors.black26,
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineGroupBox(
    _TimelineGroupSnapshot group,
    Rect rect,
    List<_TimelineNodeSnapshot> frameNodes,
    bool showChanges,
  ) {
    final isRemoved = group.activeEffect == 'removed';
    final isAdded = group.activeEffect == 'added';

    final groupNodes = frameNodes
        .where((n) => group.nodeIds.contains(n.id) && !n.isPrompt)
        .toList();

    final displayMode = widget.engine.displayMode;
    double avgScore = 0.0;
    int totalInc = 0;
    int totalDec = 0;
    double avgConsecutive = 0.0;

    if (groupNodes.isNotEmpty) {
      avgScore = groupNodes.fold<double>(0.0, (s, n) => s + n.score) /
          groupNodes.length;
      int sumCons = 0;
      for (final n in groupNodes) {
        totalInc += n.increaseCount;
        totalDec += n.decreaseCount;
        sumCons += n.consecutiveCount;
      }
      avgConsecutive = sumCons / groupNodes.length;
    }

    final scoreColor = ProgressColorHelper.getScoreColor(avgScore);
    final scoreBg = ProgressColorHelper.getScoreBgColor(avgScore);
    final incTextColor = ProgressColorHelper.getIncreaseColor(totalInc);
    final incBgColor = ProgressColorHelper.getIncreaseBgColor(totalInc);
    final consTextColor =
        ProgressColorHelper.getIncreaseColor(avgConsecutive.round());
    final consBgColor =
        ProgressColorHelper.getIncreaseBgColor(avgConsecutive.round());

    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 240),
        opacity: isRemoved ? 0.35 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          decoration: BoxDecoration(
            color: isRemoved
                ? Colors.red.withValues(alpha: 0.06)
                : isAdded
                    ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                    : AppTheme.primaryBlue.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRemoved
                  ? Colors.redAccent
                  : isAdded
                      ? AppTheme.primaryBlue
                      : AppTheme.skyBlue.withValues(alpha: 0.55),
              width: (isAdded || isRemoved) ? 2.2 : 1.5,
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
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isRemoved ? Colors.red.shade700 : AppTheme.deepNavy,
                  ),
                ),
                if (showChanges && !isRemoved) ...[
                  if (displayMode == 1)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: incBgColor,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            '+$totalInc',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: incTextColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            '-$totalDec',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    )
                  else if (displayMode == 2) ...[
                    if (avgConsecutive > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: consBgColor,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: consTextColor.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          '均连 ${avgConsecutive.toStringAsFixed(1)}次',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: consTextColor,
                          ),
                        ),
                      ),
                  ] else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
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
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineNodeCard(
    _TimelineNodeSnapshot snap,
    bool showChanges,
  ) {
    final effect = snap.activeEffect;
    final isCreated = effect == 'created';
    final isUpdated = effect == 'updated';
    final isDeleted = effect == 'deleted';
    final isInc = effect == 'inc';
    final isDec = effect == 'dec';
    final isSkip = effect == 'skip';

    final displayMode = widget.engine.displayMode;
    final scoreColor = ProgressColorHelper.getScoreColor(snap.score);
    final scoreBg = ProgressColorHelper.getScoreBgColor(snap.score);
    final incTextColor =
        ProgressColorHelper.getIncreaseColor(snap.increaseCount);
    final incBgColor =
        ProgressColorHelper.getIncreaseBgColor(snap.increaseCount);
    final progColor = ProgressColorHelper.getColor(snap.progress);
    final progBg = ProgressColorHelper.getBgColor(snap.progress);
    final consColor =
        ProgressColorHelper.getIncreaseColor(snap.consecutiveCount);
    final consBg =
        ProgressColorHelper.getIncreaseBgColor(snap.consecutiveCount);

    final Color baseBorderColor;
    final Color baseCardBg;

    if (isDeleted) {
      baseBorderColor = Colors.redAccent;
      baseCardBg = const Color(0xFFFEF2F2);
    } else if (isCreated || isUpdated) {
      baseBorderColor = AppTheme.primaryBlue;
      baseCardBg = AppTheme.subtleFill;
    } else if (isInc) {
      baseBorderColor = Colors.green.shade600;
      baseCardBg = const Color(0xFFF2FBF4);
    } else if (isDec) {
      baseBorderColor = Colors.red.shade600;
      baseCardBg = const Color(0xFFFDF3F3);
    } else if (isSkip) {
      baseBorderColor = Colors.blueGrey.shade500;
      baseCardBg = const Color(0xFFF1F5F9);
    } else if (snap.isPrompt) {
      baseBorderColor = Colors.black;
      baseCardBg = AppTheme.surfaceWhite;
    } else if (showChanges) {
      final activeBorder = switch (displayMode) {
        1 => progColor,
        2 => consColor,
        _ => scoreColor,
      };
      final activeTint = switch (displayMode) {
        1 => progBg,
        2 => consBg,
        _ => scoreBg,
      };
      baseBorderColor = activeBorder.withValues(alpha: 0.55);
      baseCardBg = Color.alphaBlend(
        activeTint.withValues(alpha: 0.55),
        AppTheme.surfaceWhite,
      );
    } else {
      baseBorderColor = AppTheme.skyBlue.withValues(alpha: 0.65);
      baseCardBg = AppTheme.surfaceWhite;
    }

    String? badgeLabel;
    Color? badgeColor;
    if (isCreated) {
      badgeLabel = '新增';
      badgeColor = AppTheme.primaryBlue;
    } else if (isUpdated) {
      badgeLabel = '修订';
      badgeColor = AppTheme.primaryBlue;
    } else if (isDeleted) {
      badgeLabel = '已删除';
      badgeColor = Colors.redAccent;
    } else if (isInc) {
      badgeLabel = '+1';
      badgeColor = Colors.green.shade700;
    } else if (isDec) {
      badgeLabel = '-1';
      badgeColor = Colors.red.shade700;
    } else if (isSkip) {
      badgeLabel = '跳过';
      badgeColor = Colors.blueGrey.shade700;
    }

    final double w = snap.isPrompt ? _promptWidth : _normalWidth;
    final double h = snap.isPrompt ? _promptHeight : _normalHeight;

    return Positioned(
      left: snap.x,
      top: snap.y,
      child: TweenAnimationBuilder<double>(
        key: ValueKey('tl_${snap.id}_${effect ?? "steady"}'),
        tween: Tween<double>(
          begin: isCreated ? 0.72 : (isDeleted ? 1.0 : 0.94),
          end: isDeleted ? 0.86 : 1.0,
        ),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 240),
              opacity: isDeleted ? 0.42 : 1.0,
              child: child,
            ),
          );
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            snap.isPrompt
                ? AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: w,
                    height: h,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: baseCardBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDeleted ? Colors.redAccent : Colors.black,
                        width: effect != null ? 2.0 : 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: effect != null ? 8 : 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        snap.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                          height: 1.25,
                        ),
                      ),
                    ),
                  )
                : AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: w,
                    height: h,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: baseCardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: baseBorderColor,
                        width: effect != null ? 2.0 : 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: effect != null
                              ? baseBorderColor.withValues(alpha: 0.25)
                              : Colors.black.withValues(alpha: 0.05),
                          blurRadius: effect != null ? 8 : 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                snap.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.deepNavy,
                                ),
                              ),
                            ),
                            if (showChanges) ...[
                              if (displayMode == 1)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: incBgColor,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '+${snap.increaseCount}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: incTextColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.red.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '-${snap.decreaseCount}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.red.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              else if (displayMode == 2) ...[
                                if (snap.consecutiveCount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: consBg,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color:
                                            consColor.withValues(alpha: 0.3),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      '连${snap.consecutiveCount}次',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: consColor,
                                      ),
                                    ),
                                  ),
                              ] else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: scoreBg,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: scoreColor.withValues(alpha: 0.3),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    '${snap.score.toStringAsFixed(1)}分',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: scoreColor,
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          snap.content.isEmpty ? '（无详细内容）' : snap.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),

            if (badgeLabel != null && badgeColor != null)
              Positioned(
                right: -4,
                top: -10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: badgeColor.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    badgeLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTimelineConnections(
    List<_TimelineConnectionSnapshot> conns,
    List<_TimelineNodeSnapshot> frameNodes,
    Map<String, Offset> nodePositions,
    Map<String, Rect> groupRects,
  ) {
    final widgets = <Widget>[];

    for (final conn in conns) {
      final fromNode =
          frameNodes.where((n) => n.id == conn.fromId).firstOrNull;
      final toNode = frameNodes.where((n) => n.id == conn.toId).firstOrNull;

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
        final isAdded = conn.activeEffect == 'added';
        final isRemoved = conn.activeEffect == 'removed';

        widgets.add(
          IgnorePointer(
            child: CustomPaint(
              size: const Size(_canvasWidth, _canvasHeight),
              painter: BezierConnectionPainter(
                start: fromCenter,
                end: toCenter,
                isSelected: isAdded,
                isRemoved: isRemoved,
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  // ==========================================
  // 常规树画布构建组件
  // ==========================================

  Widget _buildGroupBoundingBox(
    FocusGroupModel group,
    Rect rect,
    Map<String, Offset> positions,
  ) {
    final displayMode = widget.engine.displayMode;
    final groupNodes = widget.engine.nodes
        .where((n) => group.nodeIds.contains(n.id) && !n.isPrompt)
        .toList();

    double avgScore = 0.0;
    int totalInc = 0;
    int totalDec = 0;
    double avgConsecutive = 0.0;

    if (groupNodes.isNotEmpty) {
      final sumScore = groupNodes.fold<double>(
        0.0,
        (sum, n) => sum + widget.engine.getNodeScore(n.id).score,
      );
      avgScore = sumScore / groupNodes.length;

      int sumConsecutive = 0;
      for (final n in groupNodes) {
        totalInc += n.increaseCount;
        totalDec += n.decreaseCount;
        sumConsecutive += widget.engine.getNodeConsecutiveCount(n.id);
      }
      avgConsecutive = sumConsecutive / groupNodes.length;
    }

    final scoreColor = ProgressColorHelper.getScoreColor(avgScore);
    final scoreBg = ProgressColorHelper.getScoreBgColor(avgScore);
    final incTextColor = ProgressColorHelper.getIncreaseColor(totalInc);
    final incBgColor = ProgressColorHelper.getIncreaseBgColor(totalInc);
    final avgConsInt = avgConsecutive.round();
    final consTextColor = ProgressColorHelper.getIncreaseColor(avgConsInt);
    final consBgColor = ProgressColorHelper.getIncreaseBgColor(avgConsInt);

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
          _cancelMarqueeHold();
          HapticFeedback.mediumImpact();
          final renderBox =
              _canvasKey.currentContext?.findRenderObject() as RenderBox?;
          if (renderBox != null) {
            _groupDragStartFingerPos =
                renderBox.globalToLocal(details.globalPosition);
            _groupDragStartPositions = {
              for (final n in widget.engine.nodes
                  .where((n) => group.nodeIds.contains(n.id)))
                n.id: positions[n.id]!
            };
            setState(() => _draggingGroupId = group.id);
          }
        },
        onLongPressMoveUpdate: (details) {
          if (_groupDragStartFingerPos != null &&
              _groupDragStartPositions != null) {
            final renderBox =
                _canvasKey.currentContext?.findRenderObject() as RenderBox?;
            if (renderBox != null) {
              final currentFinger =
                  renderBox.globalToLocal(details.globalPosition);
              final delta = currentFinger - _groupDragStartFingerPos!;
              final Map<String, ({double x, double y})> updated = {};
              for (final entry in _groupDragStartPositions!.entries) {
                final initPos = entry.value;
                updated[entry.key] = (
                  x: (initPos.dx + delta.dx).clamp(50.0, _canvasWidth - 50.0),
                  y: (initPos.dy + delta.dy).clamp(50.0, _canvasHeight - 50.0),
                );
              }
              widget.engine.setNodesPositions(updated, save: false);
            }
          }
        },
        onLongPressEnd: (details) {
          if (_groupDragStartPositions != null) {
            final Map<String, ({double x, double y})> finalPositions = {};
            for (final id in _groupDragStartPositions!.keys) {
              final n =
                  widget.engine.nodes.where((item) => item.id == id).firstOrNull;
              if (n != null && n.x != null && n.y != null) {
                finalPositions[id] = (x: n.x!, y: n.y!);
              }
            }
            widget.engine.setNodesPositions(finalPositions, save: true);
          }
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
                    if (displayMode == 1) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: incBgColor,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '+$totalInc',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: incTextColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '-$totalDec',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ] else if (displayMode == 2) ...[
                      if (avgConsecutive > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: consBgColor,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: consTextColor.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            '均连 ${avgConsecutive.toStringAsFixed(1)}次',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: consTextColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
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
                    ],
                    GestureDetector(
                      onTap: () => _confirmDeleteGroup(group),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            size: 12, color: Colors.black45),
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

  Widget _buildNodeCardWrapper(
    FocusNodeModel node,
    Offset pos,
    Map<String, Offset> allPositions,
  ) {
    final isSelectedSingle = node.id == widget.engine.selectedNodeId;
    final isHighlightedGroup =
        widget.engine.groupSelectedNodeIds.contains(node.id) ||
            widget.engine.multiSelectedNodeIds.contains(node.id);
    final isDragging = _draggingNodeId == node.id ||
        (_draggingNodeId != null &&
            _multiDragStartPositions != null &&
            _multiDragStartPositions!.containsKey(node.id));
    final isConnectSelected = node.id == _connectStartId;

    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: GestureDetector(
        onTap: () => _onNodeTap(node),
        onPanStart: (details) {
          _cancelMarqueeHold();
          final renderBox =
              _canvasKey.currentContext?.findRenderObject() as RenderBox?;
          if (renderBox != null) {
            _nodeDragStartFingerPos =
                renderBox.globalToLocal(details.globalPosition);
            _nodeDragStartPos = pos;

            final multiIds = widget.engine.multiSelectedNodeIds;
            if (multiIds.isNotEmpty && multiIds.contains(node.id)) {
              _multiDragStartPositions = {
                for (final id in multiIds)
                  if (allPositions.containsKey(id)) id: allPositions[id]!,
              };
            } else {
              _multiDragStartPositions = null;
            }

            setState(() => _draggingNodeId = node.id);
          }
        },
        onPanUpdate: (details) {
          if (_draggingNodeId == node.id &&
              _nodeDragStartFingerPos != null &&
              _nodeDragStartPos != null) {
            final renderBox =
                _canvasKey.currentContext?.findRenderObject() as RenderBox?;
            if (renderBox != null) {
              final currentFingerPos =
                  renderBox.globalToLocal(details.globalPosition);
              final delta = currentFingerPos - _nodeDragStartFingerPos!;

              if (_multiDragStartPositions != null &&
                  _multiDragStartPositions!.isNotEmpty) {
                final Map<String, ({double x, double y})> updated = {};
                for (final entry in _multiDragStartPositions!.entries) {
                  updated[entry.key] = (
                    x: (entry.value.dx + delta.dx)
                        .clamp(50.0, _canvasWidth - 50.0),
                    y: (entry.value.dy + delta.dy)
                        .clamp(50.0, _canvasHeight - 50.0),
                  );
                }
                widget.engine.setNodesPositions(updated, save: false);
              } else {
                widget.engine.updateNodePosition(
                  node.id,
                  (_nodeDragStartPos!.dx + delta.dx)
                      .clamp(50.0, _canvasWidth - 50.0),
                  (_nodeDragStartPos!.dy + delta.dy)
                      .clamp(50.0, _canvasHeight - 50.0),
                  save: false,
                );
              }
            }
          }
        },
        onPanEnd: (_) => _finishNodeDrag(),
        onPanCancel: () => _finishNodeDrag(),
        child: node.isPrompt
            ? _buildPromptNodeCard(
                node, isSelectedSingle, isHighlightedGroup, isDragging)
            : _buildNormalNodeCard(
                node,
                isSelectedSingle || isConnectSelected,
                isHighlightedGroup,
                isDragging,
              ),
      ),
    );
  }

  void _finishNodeDrag() {
    if (_draggingNodeId != null) {
      if (_multiDragStartPositions != null &&
          _multiDragStartPositions!.isNotEmpty) {
        final Map<String, ({double x, double y})> finalPositions = {};
        for (final id in _multiDragStartPositions!.keys) {
          final n =
              widget.engine.nodes.where((item) => item.id == id).firstOrNull;
          if (n != null && n.x != null && n.y != null) {
            finalPositions[id] = (x: n.x!, y: n.y!);
          }
        }
        widget.engine.setNodesPositions(finalPositions, save: true);
      } else {
        final n = widget.engine.nodes
            .where((item) => item.id == _draggingNodeId)
            .firstOrNull;
        if (n != null && n.x != null && n.y != null) {
          widget.engine.updateNodePosition(n.id, n.x!, n.y!, save: true);
        }
      }
    }
    setState(() {
      _draggingNodeId = null;
      _nodeDragStartPos = null;
      _nodeDragStartFingerPos = null;
      _multiDragStartPositions = null;
    });
  }

  Widget _buildNormalNodeCard(
    FocusNodeModel node,
    bool isSelectedSingle,
    bool isHighlightedGroup,
    bool isDragging,
  ) {
    final displayMode = widget.engine.displayMode;
    final scoreRes = widget.engine.getNodeScore(node.id);
    final scoreColor = ProgressColorHelper.getScoreColor(scoreRes.score);
    final scoreBg = ProgressColorHelper.getScoreBgColor(scoreRes.score);

    final incTextColor =
        ProgressColorHelper.getIncreaseColor(node.increaseCount);
    final incBgColor =
        ProgressColorHelper.getIncreaseBgColor(node.increaseCount);
    final progColor = ProgressColorHelper.getColor(node.progress);
    final progBg = ProgressColorHelper.getBgColor(node.progress);

    final consecutiveCount = widget.engine.getNodeConsecutiveCount(node.id);
    final consColor = ProgressColorHelper.getIncreaseColor(consecutiveCount);
    final consBg = ProgressColorHelper.getIncreaseBgColor(consecutiveCount);

    final activeBorderColor = switch (displayMode) {
      1 => progColor,
      2 => consColor,
      _ => scoreColor,
    };
    final activeTintBg = switch (displayMode) {
      1 => progBg,
      2 => consBg,
      _ => scoreBg,
    };

    final solidBgColor = Color.alphaBlend(
      activeTintBg.withValues(alpha: 0.55),
      AppTheme.surfaceWhite,
    );
    final isHighlighted = isSelectedSingle || isHighlightedGroup;
    final isActiveToday = widget.engine.isNodeActiveToday(node);

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
                    : activeBorderColor.withValues(alpha: 0.55),
            width: isHighlighted ? 2.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDragging
                  ? AppTheme.primaryBlue.withValues(alpha: 0.35)
                  : isHighlighted
                      ? AppTheme.primaryBlue.withValues(alpha: 0.2)
                      : activeBorderColor.withValues(alpha: 0.08),
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
                    if (displayMode == 1)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: incBgColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '+${node.increaseCount}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: incTextColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '-${node.decreaseCount}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      )
                    else if (displayMode == 2) ...[
                      if (consecutiveCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: consBg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: consColor.withValues(alpha: 0.3),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            '连$consecutiveCount次',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: consColor,
                            ),
                          ),
                        ),
                    ] else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1.5),
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
                  style: const TextStyle(
                      fontSize: 11, color: Colors.black54, height: 1.25),
                ),
              ],
            ),
            if (isHighlightedGroup)
              const Positioned(
                right: 0,
                bottom: 0,
                child: Icon(Icons.check_circle,
                    size: 16, color: AppTheme.primaryBlue),
              ),
          ],
        ),
      ),
    );
  }

  /// 提示节点：更窄尺寸 + 全黑边框 + 文字居中
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isHighlighted ? AppTheme.subtleFill : AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.black,
          width: (isHighlighted || isDragging) ? 2.0 : 1.4,
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
                fontSize: 11,
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
              child: Icon(Icons.check_circle,
                  size: 14, color: AppTheme.primaryBlue),
            ),
        ],
      ),
    );
  }

  ({Offset start, Offset end, bool isFaded})? _resolveConnectionEndpoints(
    FocusConnection conn,
    Map<String, Offset> nodePositions,
    Map<String, Rect> groupRects,
  ) {
    final fromNode =
        widget.engine.nodes.where((n) => n.id == conn.fromId).firstOrNull;
    final toNode =
        widget.engine.nodes.where((n) => n.id == conn.toId).firstOrNull;

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

    if (fromCenter == null || toCenter == null) return null;
    return (start: fromCenter, end: toCenter, isFaded: isFaded);
  }

  List<Widget> _buildConnectionVisuals(
    Map<String, Offset> nodePositions,
    Map<String, Rect> groupRects,
  ) {
    final widgets = <Widget>[];

    for (final conn in widget.engine.connections) {
      final resolved =
          _resolveConnectionEndpoints(conn, nodePositions, groupRects);
      if (resolved == null) continue;

      final isSelected = conn == widget.engine.selectedConnection;
      widgets.add(
        IgnorePointer(
          child: CustomPaint(
            size: const Size(_canvasWidth, _canvasHeight),
            painter: BezierConnectionPainter(
              start: resolved.start,
              end: resolved.end,
              isSelected: isSelected,
              isFaded: resolved.isFaded,
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  List<Widget> _buildConnectionHitTargets(
    Map<String, Offset> nodePositions,
    Map<String, Rect> groupRects,
  ) {
    final widgets = <Widget>[];

    for (final conn in widget.engine.connections) {
      final resolved =
          _resolveConnectionEndpoints(conn, nodePositions, groupRects);
      if (resolved == null) continue;

      final isSelected = conn == widget.engine.selectedConnection;
      widgets.add(
        GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onTap: () {
            _cancelMarqueeHold();
            widget.engine.selectConnection(conn);
          },
          child: CustomPaint(
            size: const Size(_canvasWidth, _canvasHeight),
            painter: BezierConnectionPainter(
              start: resolved.start,
              end: resolved.end,
              isSelected: isSelected,
              isFaded: resolved.isFaded,
              hitTestOnly: true,
            ),
          ),
        ),
      );
    }

    return widgets;
  }
}

/// 贝塞尔平滑连线绘制器（内置整条曲线精确点击命中检测）
class BezierConnectionPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final bool isSelected;
  final bool isFaded;
  final bool isRemoved;
  final bool hitTestOnly;

  BezierConnectionPainter({
    required this.start,
    required this.end,
    required this.isSelected,
    this.isFaded = false,
    this.isRemoved = false,
    this.hitTestOnly = false,
  });

  Path _buildCurvePath() {
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
    return path;
  }

  Offset _evalCubic(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final u = 1.0 - t;
    final tt = t * t;
    final uu = u * u;
    final uuu = uu * u;
    final ttt = tt * t;
    return Offset(
      uuu * p0.dx + 3 * uu * t * p1.dx + 3 * u * tt * p2.dx + ttt * p3.dx,
      uuu * p0.dy + 3 * uu * t * p1.dy + 3 * u * tt * p2.dy + ttt * p3.dy,
    );
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lenSq == 0) return (p - a).distance;
    final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lenSq)
        .clamp(0.0, 1.0);
    final proj = Offset(a.dx + t * ab.dx, a.dy + t * ab.dy);
    return (p - proj).distance;
  }

  @override
  bool? hitTest(Offset position) {
    final dx = (end.dx - start.dx).abs();
    final dy = (end.dy - start.dy).abs();
    final controlOffset = math.max(dx * 0.45, dy * 0.3);

    final p0 = start;
    final p1 = Offset(
      start.dx + (end.dx > start.dx ? controlOffset : -controlOffset),
      start.dy,
    );
    final p2 = Offset(
      end.dx + (end.dx > start.dx ? -controlOffset : controlOffset),
      end.dy,
    );
    final p3 = end;

    final bounds = Rect.fromPoints(p0, p3)
        .expandToInclude(Rect.fromPoints(p1, p2))
        .inflate(22.0);
    if (!bounds.contains(position)) return false;

    const int steps = 20;
    Offset prev = p0;
    for (int i = 1; i <= steps; i++) {
      final curr = _evalCubic(p0, p1, p2, p3, i / steps);
      if (_distanceToSegment(position, prev, curr) <= 18.0) {
        return true;
      }
      prev = curr;
    }
    return false;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (hitTestOnly) return;

    final path = _buildCurvePath();

    if (isSelected) {
      final haloPaint = Paint()
        ..color = AppTheme.primaryBlue.withValues(alpha: 0.18)
        ..strokeWidth = 7.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, haloPaint);
    }

    final paint = Paint()
      ..color = isRemoved
          ? Colors.redAccent.withValues(alpha: 0.7)
          : isSelected
              ? AppTheme.primaryBlue
              : AppTheme.primaryBlue.withValues(alpha: isFaded ? 0.15 : 0.35)
      ..strokeWidth = (isSelected || isRemoved) ? 3.0 : 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant BezierConnectionPainter oldDelegate) {
    return oldDelegate.start != start ||
        oldDelegate.end != end ||
        oldDelegate.isSelected != isSelected ||
        oldDelegate.isFaded != isFaded ||
        oldDelegate.isRemoved != isRemoved ||
        oldDelegate.hitTestOnly != hitTestOnly;
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