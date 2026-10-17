import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/focus_node_model.dart';

class RsipEngine extends ChangeNotifier {
  final List<FocusNodeModel> _nodes = [];
  final Set<FocusConnection> _connections = {};
  final List<FocusGroupModel> _groups = [];
  final List<ProgressRecord> _history = [];

  String? _selectedNodeId;
  FocusConnection? _selectedConnection;

  bool _isGroupSelectMode = false;
  final Set<String> _groupSelectedNodeIds = {};

  int _dayStartHourOffset = 0;

  int get dayStartHourOffset => _dayStartHourOffset;
  List<FocusNodeModel> get nodes => List.unmodifiable(_nodes);
  Set<FocusConnection> get connections => Set.unmodifiable(_connections);
  List<FocusGroupModel> get groups => List.unmodifiable(_groups);
  List<ProgressRecord> get history => List.unmodifiable(_history.reversed);

  String? get selectedNodeId => _selectedNodeId;
  FocusNodeModel? get selectedNode {
    if (_selectedNodeId == null) return null;
    try {
      return _nodes.firstWhere((n) => n.id == _selectedNodeId);
    } catch (_) {
      return null;
    }
  }

  FocusConnection? get selectedConnection => _selectedConnection;
  bool get isGroupSelectMode => _isGroupSelectMode;
  Set<String> get groupSelectedNodeIds => Set.unmodifiable(_groupSelectedNodeIds);

  RsipEngine() {
    _loadFromStorage();
  }

  static const String _keyNodes = 'rsip_nodes_data';
  static const String _keyConnections = 'rsip_connections_data';
  static const String _keyGroups = 'rsip_groups_data';
  static const String _keyHistory = 'rsip_history_data';
  static const String _keyDayOffset = 'rsip_day_start_hour_offset';

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _dayStartHourOffset = prefs.getInt(_keyDayOffset) ?? 0;

      final nodesJson = prefs.getString(_keyNodes);
      if (nodesJson != null) {
        final List list = jsonDecode(nodesJson);
        _nodes.clear();
        _nodes.addAll(list.map((e) => FocusNodeModel.fromJson(e)));
      }

      final connJson = prefs.getString(_keyConnections);
      if (connJson != null) {
        final List list = jsonDecode(connJson);
        _connections.clear();
        _connections.addAll(list.map((e) => FocusConnection.fromJson(e)));
      }

      final groupsJson = prefs.getString(_keyGroups);
      if (groupsJson != null) {
        final List list = jsonDecode(groupsJson);
        _groups.clear();
        _groups.addAll(list.map((e) => FocusGroupModel.fromJson(e)));
      }

      final historyJson = prefs.getString(_keyHistory);
      if (historyJson != null) {
        final List list = jsonDecode(historyJson);
        _history.clear();
        _history.addAll(list.map((e) => ProgressRecord.fromJson(e)));
      }

      notifyListeners();
    } catch (e) {
      debugPrint('加载本地存储失败: $e');
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        _keyNodes,
        jsonEncode(_nodes.map((n) => n.toJson()).toList()),
      );
      await prefs.setString(
        _keyConnections,
        jsonEncode(_connections.map((c) => c.toJson()).toList()),
      );
      await prefs.setString(
        _keyGroups,
        jsonEncode(_groups.map((g) => g.toJson()).toList()),
      );
      await prefs.setString(
        _keyHistory,
        jsonEncode(_history.map((h) => h.toJson()).toList()),
      );
      await prefs.setInt(_keyDayOffset, _dayStartHourOffset);
    } catch (e) {
      debugPrint('保存到本地存储失败: $e');
    }
  }

  // ==========================================
  // 日期归属、排期与今日完成状态判定
  // ==========================================

  void setDayStartHourOffset(int hours) {
    _dayStartHourOffset = hours.clamp(0, 12);
    notifyListeners();
    _saveToStorage();
  }

  /// 计算归属日期（若已是日历选择器生成的零点纯日期则直接返回，否则扣除延后小时）
  DateTime getEffectiveDate(DateTime dt) {
    if (dt.hour == 0 && dt.minute == 0 && dt.second == 0 && dt.millisecond == 0) {
      return DateTime(dt.year, dt.month, dt.day);
    }
    final adjusted = dt.subtract(Duration(hours: _dayStartHourOffset));
    return DateTime(adjusted.year, adjusted.month, adjusted.day);
  }

  String formatRecordDate(DateTime dt) {
    final d = getEffectiveDate(dt);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 判断节点在今天是否已经打卡完成（存在今日的正向记录）
  bool isNodeCompletedToday(FocusNodeModel node) {
    if (node.isPrompt) return false;
    final today = getEffectiveDate(DateTime.now());
    return _history.any((r) =>
        !r.isEdit &&
        r.nodeId == node.id &&
        r.delta > 0 &&
        _isSameDay(getEffectiveDate(r.time), today));
  }

  /// 判断节点根据重复规则是否排期在今天执行
  bool isNodeScheduledToday(FocusNodeModel node) {
    if (node.isPrompt) return true;
    final today = getEffectiveDate(DateTime.now());

    if (node.repeatMode == 0) {
      // 模式 0：周一到周日自选
      return node.repeatWeekdays.contains(today.weekday);
    } else {
      final freqVal = node.repeatFreqValue.clamp(1, 365);
      if (node.repeatFreqType == 0) {
        // 每 X 天
        if (freqVal <= 1) return true;
        DateTime? lastDate;
        for (final r in _history) {
          if (!r.isEdit && r.nodeId == node.id && r.delta > 0) {
            final d = getEffectiveDate(r.time);
            if (d.isBefore(today)) {
              if (lastDate == null || d.isAfter(lastDate)) {
                lastDate = d;
              }
            }
          }
        }
        if (lastDate == null) return true;
        return today.difference(lastDate).inDays >= freqVal;
      } else if (node.repeatFreqType == 1) {
        // 每周 X 次（统计本周一至今日之前的完成次数）
        final weekStart = today.subtract(Duration(days: today.weekday - 1));
        int countBeforeToday = 0;
        for (final r in _history) {
          if (!r.isEdit && r.nodeId == node.id && r.delta > 0) {
            final d = getEffectiveDate(r.time);
            if (!d.isBefore(weekStart) && d.isBefore(today)) {
              countBeforeToday++;
            }
          }
        }
        return countBeforeToday < freqVal;
      } else {
        // 每月 X 次（统计本月1号至今日之前的完成次数）
        final monthStart = DateTime(today.year, today.month, 1);
        int countBeforeToday = 0;
        for (final r in _history) {
          if (!r.isEdit && r.nodeId == node.id && r.delta > 0) {
            final d = getEffectiveDate(r.time);
            if (!d.isBefore(monthStart) && d.isBefore(today)) {
              countBeforeToday++;
            }
          }
        }
        return countBeforeToday < freqVal;
      }
    }
  }

  /// 节点今日是否处于“待办活跃”状态（是今日排期且今日未完成）
  bool isNodeActiveToday(FocusNodeModel node) {
    if (node.isPrompt) return true;
    return isNodeScheduledToday(node) && !isNodeCompletedToday(node);
  }

  // ==========================================
  // 标签管理 (增加与减少隔离)
  // ==========================================

  List<String> getHistoricalTags({required bool isIncrease}) {
    final Set<String> tagSet = {};
    for (final record in _history) {
      if (record.isEdit) continue;
      final match = isIncrease ? record.delta > 0 : record.delta < 0;
      if (match && record.tags != null) {
        tagSet.addAll(record.tags!);
      }
    }
    return tagSet.toList();
  }

  // ==========================================
  // 节点拖拽排序（适配列表过滤后的可见项）
  // ==========================================

  void reorderNodes(int oldIndex, int newIndex) {
    final visible = _nodes.where((n) => !n.isPrompt && isNodeActiveToday(n)).toList();
    if (oldIndex < 0 || oldIndex >= visible.length) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final movedItem = visible.removeAt(oldIndex);
    visible.insert(newIndex, movedItem);

    final visibleIds = visible.map((n) => n.id).toSet();
    int vIdx = 0;
    for (int i = 0; i < _nodes.length; i++) {
      if (visibleIds.contains(_nodes[i].id)) {
        _nodes[i] = visible[vIdx++];
      }
    }

    notifyListeners();
    _saveToStorage();
  }

  // ==========================================
  // 大节点管理
  // ==========================================

  void startGroupSelectMode() {
    _isGroupSelectMode = true;
    _groupSelectedNodeIds.clear();
    _selectedNodeId = null;
    _selectedConnection = null;
    notifyListeners();
  }

  void cancelGroupSelectMode() {
    _isGroupSelectMode = false;
    _groupSelectedNodeIds.clear();
    notifyListeners();
  }

  void toggleNodeInGroupSelect(String id) {
    if (_groupSelectedNodeIds.contains(id)) {
      _groupSelectedNodeIds.remove(id);
    } else {
      _groupSelectedNodeIds.add(id);
    }
    notifyListeners();
  }

  void addGroup({required String title, required Set<String> nodeIds}) {
    if (nodeIds.isEmpty) return;
    final group = FocusGroupModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      nodeIds: nodeIds,
    );
    _groups.add(group);
    notifyListeners();
    _saveToStorage();
  }

  void deleteGroup(String groupId) {
    _groups.removeWhere((g) => g.id == groupId);
    _connections.removeWhere((conn) => conn.fromId == groupId || conn.toId == groupId);
    if (_selectedConnection != null &&
        (_selectedConnection!.fromId == groupId || _selectedConnection!.toId == groupId)) {
      _selectedConnection = null;
    }
    notifyListeners();
    _saveToStorage();
  }

  // ==========================================
  // 连线管理
  // ==========================================

  void selectConnection(FocusConnection? conn) {
    _selectedConnection = conn;
    if (conn != null) {
      _selectedNodeId = null;
    }
    notifyListeners();
  }

  bool addConnection(String nodeAId, String nodeBId) {
    if (nodeAId == nodeBId) return false;
    final conn = FocusConnection(fromId: nodeAId, toId: nodeBId);
    final isNew = _connections.add(conn);
    if (isNew) {
      notifyListeners();
      _saveToStorage();
    }
    return isNew;
  }

  void deleteConnection(FocusConnection conn) {
    _connections.remove(conn);
    if (_selectedConnection == conn) {
      _selectedConnection = null;
    }
    notifyListeners();
    _saveToStorage();
  }

  // ==========================================
  // 国策节点增删改查
  // ==========================================

  void selectNode(String? id) {
    if (_selectedNodeId == id) {
      _selectedNodeId = null;
    } else {
      _selectedNodeId = id;
      _selectedConnection = null;
    }
    notifyListeners();
  }

  void updateNodePosition(String id, double x, double y) {
    final index = _nodes.indexWhere((n) => n.id == id);
    if (index != -1) {
      _nodes[index].x = x;
      _nodes[index].y = y;
      notifyListeners();
      _saveToStorage();
    }
  }

  void addNode({
    required String title,
    required String content,
    bool isPrompt = false,
    bool promptNoteOnIncrease = true,
    bool promptNoteOnDecrease = true,
    int repeatMode = 0,
    List<int>? repeatWeekdays,
    int repeatFreqType = 0,
    int repeatFreqValue = 1,
    List<NumericAttribute>? numericAttributes,
    double? x,
    double? y,
  }) {
    double targetX = x ?? 3000.0;
    double targetY = y ?? 3000.0;

    if (x == null && y == null && _nodes.isNotEmpty) {
      double sumX = 0;
      double sumY = 0;
      for (final n in _nodes) {
        sumX += (n.x ?? 3000.0);
        sumY += (n.y ?? 3000.0);
      }
      targetX = sumX / _nodes.length;
      targetY = sumY / _nodes.length;
    }

    final newNode = FocusNodeModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      content: content,
      isPrompt: isPrompt,
      promptNoteOnIncrease: promptNoteOnIncrease,
      promptNoteOnDecrease: promptNoteOnDecrease,
      repeatMode: repeatMode,
      repeatWeekdays: repeatWeekdays,
      repeatFreqType: repeatFreqType,
      repeatFreqValue: repeatFreqValue,
      numericAttributes: numericAttributes,
      x: targetX,
      y: targetY,
    );
    _nodes.add(newNode);
    notifyListeners();
    _saveToStorage();
  }

  void deleteNode(String id) {
    if (_selectedNodeId == id) _selectedNodeId = null;
    _nodes.removeWhere((node) => node.id == id);
    _connections.removeWhere((conn) => conn.fromId == id || conn.toId == id);
    if (_selectedConnection != null &&
        (_selectedConnection!.fromId == id || _selectedConnection!.toId == id)) {
      _selectedConnection = null;
    }
    _history.removeWhere((record) => record.nodeId == id);

    for (final group in _groups) {
      group.nodeIds.remove(id);
    }
    _groups.removeWhere((group) => group.nodeIds.isEmpty);

    notifyListeners();
    _saveToStorage();
  }

  void updateNode(
    String id,
    String newTitle,
    String newContent, {
    bool? promptNoteOnIncrease,
    bool? promptNoteOnDecrease,
    int? repeatMode,
    List<int>? repeatWeekdays,
    int? repeatFreqType,
    int? repeatFreqValue,
    List<NumericAttribute>? numericAttributes,
    List<AttributeChange>? attributeChanges,
    bool recordToHistory = false,
  }) {
    final target = _nodes.firstWhere((n) => n.id == id);
    final prevTitle = target.title;
    final prevContent = target.content;
    final prevRepeatDesc = target.repeatDescription; // 记录修改前的重复规则

    if (promptNoteOnIncrease != null) {
      target.promptNoteOnIncrease = promptNoteOnIncrease;
    }
    if (promptNoteOnDecrease != null) {
      target.promptNoteOnDecrease = promptNoteOnDecrease;
    }
    if (repeatMode != null) {
      target.repeatMode = repeatMode;
    }
    if (repeatWeekdays != null && repeatWeekdays.isNotEmpty) {
      target.repeatWeekdays = List.from(repeatWeekdays);
    }
    if (repeatFreqType != null) {
      target.repeatFreqType = repeatFreqType;
    }
    if (repeatFreqValue != null) {
      target.repeatFreqValue = repeatFreqValue;
    }

    final currentRepeatDesc = target.repeatDescription; // 获取修改后的重复规则

    if (attributeChanges != null) {
      for (final change in attributeChanges) {
        if (change.type == 0 &&
            change.oldName != null &&
            change.newName != null &&
            change.oldName != change.newName) {
          for (final record in _history) {
            if (record.nodeId == id && record.attributeDeltas != null) {
              if (record.attributeDeltas!.containsKey(change.oldName)) {
                final val = record.attributeDeltas!.remove(change.oldName)!;
                record.attributeDeltas![change.newName!] = val;
              }
            }
          }
        } else if (change.type == -1 && change.oldName != null) {
          for (final record in _history) {
            if (record.nodeId == id && record.attributeDeltas != null) {
              record.attributeDeltas!.remove(change.oldName);
            }
          }
        }
      }
    }

    target.title = newTitle;
    target.content = newContent;
    if (numericAttributes != null) {
      target.numericAttributes = List.from(numericAttributes);
    }

    if (recordToHistory) {
      target.version += 1;
      _history.add(
        ProgressRecord(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          nodeId: target.id,
          nodeTitle: target.title,
          delta: 0,
          resultProgress: target.progress,
          revision: target.version,
          isEdit: true,
          oldTitle: prevTitle,
          newTitle: newTitle,
          oldContent: prevContent,
          newContent: newContent,
          oldRepeatDesc: prevRepeatDesc != currentRepeatDesc ? prevRepeatDesc : null,
          newRepeatDesc: prevRepeatDesc != currentRepeatDesc ? currentRepeatDesc : null,
          attributeChanges: attributeChanges,
          time: DateTime.now(),
        ),
      );
    }

    notifyListeners();
    _saveToStorage();
  }

  // ==========================================
  // 打卡流水与修改
  // ==========================================

  void changeProgress(
    String id,
    int delta, {
    String? note,
    List<String>? tags,
    Map<String, double>? attributeDeltas,
    DateTime? recordDate,
  }) {
    final target = _nodes.firstWhere((n) => n.id == id);
    if (target.isPrompt) return;

    target.progress += delta;
    if (delta > 0) {
      target.increaseCount += 1;
    } else if (delta < 0) {
      target.decreaseCount += 1;
    }

    if (note != null && note.trim().isNotEmpty) {
      target.latestNote = note.trim();
    }

    if (attributeDeltas != null && attributeDeltas.isNotEmpty) {
      for (final attr in target.numericAttributes) {
        if (attributeDeltas.containsKey(attr.name)) {
          final addVal = attributeDeltas[attr.name]!;
          attr.totalValue += addVal;
          attr.count += 1;
        }
      }
    }

    _history.add(
      ProgressRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        nodeId: target.id,
        nodeTitle: target.title,
        delta: delta,
        resultProgress: target.progress,
        note: (note != null && note.trim().isNotEmpty) ? note.trim() : null,
        tags: (tags != null && tags.isNotEmpty) ? tags : null,
        attributeDeltas: attributeDeltas,
        time: recordDate ?? DateTime.now(),
      ),
    );
    notifyListeners();
    _saveToStorage();
  }

  void updateRecord({
    required String recordId,
    required DateTime newDate,
    String? newNote,
    List<String>? newTags,
    Map<String, double>? newAttributeDeltas,
  }) {
    final index = _history.indexWhere((r) => r.id == recordId);
    if (index == -1) return;
    final oldRecord = _history[index];
    if (oldRecord.isEdit) return;

    final nodeIndex = _nodes.indexWhere((n) => n.id == oldRecord.nodeId);
    if (nodeIndex != -1) {
      final node = _nodes[nodeIndex];
      if (newAttributeDeltas != null) {
        for (final attr in node.numericAttributes) {
          final oldVal = oldRecord.attributeDeltas?[attr.name] ?? 0.0;
          final newVal = newAttributeDeltas[attr.name] ?? 0.0;
          attr.totalValue += (newVal - oldVal);
        }
      }
      if (oldRecord.note == node.latestNote && newNote != null) {
        node.latestNote = newNote.trim().isEmpty ? null : newNote.trim();
      }
    }

    final updatedRecord = ProgressRecord(
      id: oldRecord.id,
      nodeId: oldRecord.nodeId,
      nodeTitle: oldRecord.nodeTitle,
      delta: oldRecord.delta,
      resultProgress: oldRecord.resultProgress,
      note: newNote?.trim().isEmpty == true ? null : newNote?.trim(),
      tags: (newTags != null && newTags.isNotEmpty) ? newTags : null,
      attributeDeltas: newAttributeDeltas,
      revision: oldRecord.revision,
      isEdit: oldRecord.isEdit,
      oldTitle: oldRecord.oldTitle,
      newTitle: oldRecord.newTitle,
      oldContent: oldRecord.oldContent,
      newContent: oldRecord.newContent,
      attributeChanges: oldRecord.attributeChanges,
      time: newDate,
    );

    _history[index] = updatedRecord;
    notifyListeners();
    _saveToStorage();
  }

  void deleteRecord(String recordId) {
    final index = _history.indexWhere((r) => r.id == recordId);
    if (index == -1) return;
    final record = _history[index];
    if (record.isEdit) return;

    final nodeIndex = _nodes.indexWhere((n) => n.id == record.nodeId);
    if (nodeIndex != -1) {
      final node = _nodes[nodeIndex];
      node.progress -= record.delta;
      if (record.delta > 0) {
        node.increaseCount = (node.increaseCount - 1).clamp(0, 999999);
      } else if (record.delta < 0) {
        node.decreaseCount = (node.decreaseCount - 1).clamp(0, 999999);
      }

      if (record.attributeDeltas != null) {
        for (final entry in record.attributeDeltas!.entries) {
          final attrIndex =
              node.numericAttributes.indexWhere((a) => a.name == entry.key);
          if (attrIndex != -1) {
            final attr = node.numericAttributes[attrIndex];
            attr.totalValue -= entry.value;
            attr.count = (attr.count - 1).clamp(0, 999999);
          }
        }
      }

      if (node.latestNote == record.note) {
        final remainingNotes = _history
            .where((r) =>
                r.id != recordId &&
                r.nodeId == node.id &&
                r.note != null &&
                r.note!.isNotEmpty)
            .toList();
        node.latestNote =
            remainingNotes.isNotEmpty ? remainingNotes.first.note : null;
      }
    }

    _history.removeAt(index);
    notifyListeners();
    _saveToStorage();
  }
}