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

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

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
    } catch (e) {
      debugPrint('保存到本地存储失败: $e');
    }
  }

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

 // 在 lib/engine/rsip_engine.dart 中更新 addNode 方法：

  void addNode({
    required String title,
    required String content,
    bool isPrompt = false,
    bool promptNoteOnIncrease = true,
    bool promptNoteOnDecrease = true,
    List<NumericAttribute>? numericAttributes,
    double? x,
    double? y,
  }) {
    // 优先使用传入的屏幕中心坐标；若未传入则以现有节点的几何质心为准，避免不断下移
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
    List<NumericAttribute>? numericAttributes,
    List<AttributeChange>? attributeChanges,
    bool recordToHistory = false,
  }) {
    final target = _nodes.firstWhere((n) => n.id == id);
    final prevTitle = target.title;
    final prevContent = target.content;

    // 独立更新备注开关（绝不写入版本历史）
    if (promptNoteOnIncrease != null) {
      target.promptNoteOnIncrease = promptNoteOnIncrease;
    }
    if (promptNoteOnDecrease != null) {
      target.promptNoteOnDecrease = promptNoteOnDecrease;
    }

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

    // 仅在有内容修改且用户确认时记录修订
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
          attributeChanges: attributeChanges,
          time: DateTime.now(),
        ),
      );
    }

    notifyListeners();
    _saveToStorage();
  }

  void changeProgress(
    String id,
    int delta, {
    String? note,
    Map<String, double>? attributeDeltas,
    DateTime? recordDate, // 支持传入用户选择的记录日期
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
        attributeDeltas: attributeDeltas,
        time: recordDate ?? DateTime.now(), // 存储选择的日期
      ),
    );
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

  void reorderNodes(int oldIndex, int newIndex) {
    final visible = _nodes.where((n) => !n.isPrompt).toList();
    if (oldIndex < 0 || oldIndex >= visible.length) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final movedItem = visible.removeAt(oldIndex);
    visible.insert(newIndex, movedItem);

    // 依序填回 _nodes 中（保持提示节点位置不受影响）
    int vIdx = 0;
    for (int i = 0; i < _nodes.length; i++) {
      if (!_nodes[i].isPrompt) {
        _nodes[i] = visible[vIdx++];
      }
    }

    notifyListeners();
    _saveToStorage();
  }
}