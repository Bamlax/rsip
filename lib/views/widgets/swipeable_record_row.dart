import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

class SwipeableRecordRow extends StatefulWidget {
  final String recordId;
  final bool enabled;
  final Widget child;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueNotifier<String?> openedRowNotifier;

  const SwipeableRecordRow({
    super.key,
    required this.recordId,
    required this.enabled,
    required this.child,
    required this.onEdit,
    required this.onDelete,
    required this.openedRowNotifier,
  });

  @override
  State<SwipeableRecordRow> createState() => _SwipeableRecordRowState();
}

class _SwipeableRecordRowState extends State<SwipeableRecordRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  // 两个按钮的总宽度
  static const double _btnWidth = 64.0;
  static const double _totalActionWidth = _btnWidth * 2;
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
        _dragOffset = _controller.value * _totalActionWidth;
      });
    });
    widget.openedRowNotifier.addListener(_onOpenedRowChanged);
  }

  void _onOpenedRowChanged() {
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
          _dragOffset = (_dragOffset - details.primaryDelta!).clamp(0.0, _totalActionWidth);
          _controller.value = _dragOffset / _totalActionWidth;
        });
      },
      onHorizontalDragEnd: (_) {
        if (_dragOffset > _totalActionWidth / 2) {
          _open();
        } else {
          _close();
        }
      },
      child: Stack(
        children: [
          // 底层：[编辑 (蓝色)] [删除 (红色)]
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 编辑按钮 (在删除左边)
                SizedBox(
                  width: _btnWidth,
                  child: Material(
                    color: AppTheme.primaryBlue,
                    child: InkWell(
                      onTap: () {
                        _close();
                        widget.onEdit();
                      },
                      child: const Center(
                        child: Icon(
                          Icons.edit_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                // 删除按钮
                SizedBox(
                  width: _btnWidth,
                  child: Material(
                    color: Colors.redAccent,
                    child: InkWell(
                      onTap: () {
                        _close();
                        widget.onDelete();
                      },
                      child: const Center(
                        child: Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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