import 'package:flutter/material.dart';

class SwipeableRecordRow extends StatefulWidget {
  final String recordId;
  final bool enabled; // 为 false 时（如版本修订）彻底禁用左滑
  final Widget child;
  final VoidCallback onDelete;
  final ValueNotifier<String?> openedRowNotifier;

  const SwipeableRecordRow({
    super.key,
    required this.recordId,
    required this.enabled,
    required this.child,
    required this.onDelete,
    required this.openedRowNotifier,
  });

  @override
  State<SwipeableRecordRow> createState() => _SwipeableRecordRowState();
}

class _SwipeableRecordRowState extends State<SwipeableRecordRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  static const double _actionWidth = 74.0;
  double _dragOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _controller.addListener(() {
      setState(() {
        _dragOffset = _controller.value * _actionWidth;
      });
    });
    widget.openedRowNotifier.addListener(_onOpenedRowChanged);
  }

  void _onOpenedRowChanged() {
    // 监听互斥事件：一旦其它条目被滑动，自身自动平滑关闭
    if (widget.openedRowNotifier.value != widget.recordId && _dragOffset > 0) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    widget.openedRowNotifier.removeListener(_onOpenedRowChanged);
    _controller.dispose();
    super.dispose();
  }

  void _open() {
    _controller.forward();
    widget.openedRowNotifier.value = widget.recordId;
  }

  void _close() {
    _controller.reverse();
    if (widget.openedRowNotifier.value == widget.recordId) {
      widget.openedRowNotifier.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return GestureDetector(
      onHorizontalDragStart: (_) {
        if (widget.openedRowNotifier.value != widget.recordId) {
          widget.openedRowNotifier.value = widget.recordId;
        }
      },
      onHorizontalDragUpdate: (details) {
        setState(() {
          _dragOffset = (_dragOffset - details.primaryDelta!).clamp(0.0, _actionWidth);
          _controller.value = _dragOffset / _actionWidth;
        });
      },
      onHorizontalDragEnd: (_) {
        if (_dragOffset > _actionWidth / 2) {
          _open();
        } else {
          _close();
        }
      },
      child: Stack(
        children: [
          // 底层红色删除区域
          Positioned.fill(
            child: Container(
              alignment: Alignment.centerRight,
              color: Colors.redAccent,
              child: SizedBox(
                width: _actionWidth,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      _close();
                      widget.onDelete();
                    },
                    child: const Center(
                      child: Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 表层内容平移
          Transform.translate(
            offset: Offset(-_dragOffset, 0),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dragOffset > 0 ? _close : null,
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}