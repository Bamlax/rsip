import 'dart:convert';
import 'dart:math' as math;
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

  // 归档选择模式状态
  bool _isArchiveMode = false;
  final Set<String> _archiveSelectedIds = {};

  int _dayStartHourOffset = 0;
  bool _autoPenalizeMissedYesterday = false;
  String? _lastAutoPenaltyDate;
  HabitScoreConfig _scoreConfig = HabitScoreConfig();

  int get dayStartHourOffset => _dayStartHourOffset;
  bool get autoPenalizeMissedYesterday => _autoPenalizeMissedYesterday;
  HabitScoreConfig get scoreConfig => _scoreConfig;
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

  bool get isArchiveMode => _isArchiveMode;
  Set<String> get archiveSelectedIds => Set.unmodifiable(_archiveSelectedIds);

  RsipEngine() {
    _loadFromStorage();
  }

  // ==========================================
  // 本地持久化 (Storage)
  // ==========================================

  static const String _keyNodes = 'rsip_nodes_data';
  static const String _keyConnections = 'rsip_connections_data';
  static const String _keyGroups = 'rsip_groups_data';
  static const String _keyHistory = 'rsip_history_data';
  static const String _keyDayOffset = 'rsip_day_start_hour_offset';
  static const String _keyAutoPenalize = 'rsip_auto_penalize_missed_yesterday';
  static const String _keyLastPenaltyDate = 'rsip_last_auto_penalty_date';
  static const String _keyScoreConfig = 'rsip_habit_score_config';

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _dayStartHourOffset = prefs.getInt(_keyDayOffset) ?? 0;
      _autoPenalizeMissedYesterday = prefs.getBool(_keyAutoPenalize) ?? false;
      _lastAutoPenaltyDate = prefs.getString(_keyLastPenaltyDate);

      final scoreCfgJson = prefs.getString(_keyScoreConfig);
      if (scoreCfgJson != null) {
        _scoreConfig = HabitScoreConfig.fromJson(jsonDecode(scoreCfgJson));
      }

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

      // 若开启了前一天未完成自动标记为减，加载后执行检查
      await _applyMissedYesterdayPenaltyIfNeeded(saveAfter: true);

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
      await prefs.setBool(_keyAutoPenalize, _autoPenalizeMissedYesterday);
      if (_lastAutoPenaltyDate != null) {
        await prefs.setString(_keyLastPenaltyDate, _lastAutoPenaltyDate!);
      }
      await prefs.setString(_keyScoreConfig, jsonEncode(_scoreConfig.toJson()));
    } catch (e) {
      debugPrint('保存到本地存储失败: $e');
    }
  }

  // ==========================================
  // 前一天未完成自动标记为减
  // ==========================================

  Future<void> setAutoPenalizeMissedYesterday(bool enabled) async {
    _autoPenalizeMissedYesterday = enabled;
    if (enabled) {
      await _applyMissedYesterdayPenaltyIfNeeded(saveAfter: false);
    }
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> _applyMissedYesterdayPenaltyIfNeeded({bool saveAfter = true}) async {
    if (!_autoPenalizeMissedYesterday) return;

    final today = getEffectiveDate(DateTime.now());
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final yesterdayStr = formatRecordDate(yesterday);

    if (_lastAutoPenaltyDate == yesterdayStr) return;

    bool hasAddedRecord = false;
    final yesterdayTimestamp =
        DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59);

    for (final node in _nodes) {
      if (node.isPrompt || node.isArchived) continue;

      final createdDate = getEffectiveDate(node.createdAt);
      // 仅检查在昨天或昨天之前创建的国策
      if (createdDate.isAfter(yesterday)) continue;

      final hasAnyActionYesterday = _history.any((r) =>
          !r.isEdit &&
          r.nodeId == node.id &&
          (r.delta != 0 || r.isSkip) &&
          _isSameDay(getEffectiveDate(r.time), yesterday));

      if (!hasAnyActionYesterday) {
        node.progress -= 1;
        node.decreaseCount += 1;
        _history.add(
          ProgressRecord(
            id: '${DateTime.now().microsecondsSinceEpoch}_${node.id}',
            nodeId: node.id,
            nodeTitle: node.title,
            delta: -1,
            resultProgress: node.progress,
            note: '前一天未完成自动标记',
            time: yesterdayTimestamp,
          ),
        );
        hasAddedRecord = true;
      }
    }

    _lastAutoPenaltyDate = yesterdayStr;
    if (saveAfter && hasAddedRecord) {
      await _saveToStorage();
    }
  }

  // ==========================================
  // 习惯连续性打分算法 (0 ~ 100 分)
  // ==========================================

  void updateScoreConfig(HabitScoreConfig newConfig) {
    _scoreConfig = newConfig;
    notifyListeners();
    _saveToStorage();
  }

  void resetScoreConfigToDefault() {
    _scoreConfig = HabitScoreConfig();
    notifyListeners();
    _saveToStorage();
  }

  /// 计算单个节点的 0~100 习惯连续性健康度得分（跳过日冻结连续状态，不惩罚）
  NodeScoreResult getNodeScore(String nodeId) {
    final nodeIndex = _nodes.indexWhere((n) => n.id == nodeId);
    if (nodeIndex == -1) return const NodeScoreResult();
    final node = _nodes[nodeIndex];
    if (node.isPrompt) return const NodeScoreResult();

    final today = getEffectiveDate(DateTime.now());
    final nodeRecords = _history
        .where((r) => !r.isEdit && r.nodeId == nodeId && (r.delta != 0 || r.isSkip))
        .toList();

    final Map<DateTime, int> dailyNetDelta = {};
    final Set<DateTime> dailySkipDates = {};
    DateTime? earliestRecordDate;

    for (final r in nodeRecords) {
      final d = getEffectiveDate(r.time);
      if (r.isSkip) {
        dailySkipDates.add(d);
      } else {
        dailyNetDelta[d] = (dailyNetDelta[d] ?? 0) + r.delta;
      }
      if (earliestRecordDate == null || d.isBefore(earliestRecordDate)) {
        earliestRecordDate = d;
      }
    }

    final createdDate = getEffectiveDate(node.createdAt);
    DateTime startDate = createdDate;
    if (earliestRecordDate != null && earliestRecordDate.isBefore(startDate)) {
      startDate = earliestRecordDate;
    }

    if (nodeRecords.isEmpty && !startDate.isBefore(today)) {
      return const NodeScoreResult();
    }

    double energy = 0.0;
    int streak = 0;
    int lastBrokenStreak = 0;
    bool justBroke = false;
    final List<int> windowEvents = [];

    for (DateTime d = startDate;
        !d.isAfter(today);
        d = DateTime(d.year, d.month, d.day + 1)) {
      final hasDeltaOnDay = dailyNetDelta.containsKey(d);
      final hasSkipOnDay = dailySkipDates.contains(d);
      final isToday = _isSameDay(d, today);

      // 当日尚未填写任何记录：处于等待状态，暂不扣减势能
      if (isToday && !hasDeltaOnDay && !hasSkipOnDay) {
        break;
      }

      if (hasDeltaOnDay) {
        final net = dailyNetDelta[d]!;
        if (net > 0) {
          streak += 1;
          energy += 1.0;
          justBroke = false;
          windowEvents.add(1);
        } else {
          lastBrokenStreak = streak;
          streak = 0;
          final gamma = math.max(
            _scoreConfig.gammaMin,
            _scoreConfig.gammaBase - (_scoreConfig.kDrop * lastBrokenStreak),
          );
          energy = energy * gamma;
          justBroke = true;
          windowEvents.add(0);
        }
      } else if (hasSkipOnDay) {
        // 显式跳过：冻结当天势能与连击数，既不增加也不触发断签惩罚
        continue;
      } else {
        // 历史未打卡日 (d < today)：计为断签 x_t == 0
        lastBrokenStreak = streak;
        streak = 0;
        final gamma = math.max(
          _scoreConfig.gammaMin,
          _scoreConfig.gammaBase - (_scoreConfig.kDrop * lastBrokenStreak),
        );
        energy = energy * gamma;
        justBroke = true;
        windowEvents.add(0);
      }
    }

    if (windowEvents.isEmpty) {
      return const NodeScoreResult();
    }

    final int wLimit = _scoreConfig.windowSize.clamp(1, 1000);
    final List<int> recentWindow = windowEvents.length > wLimit
        ? windowEvents.sublist(windowEvents.length - wLimit)
        : windowEvents;

    final int nW = recentWindow.length;

    final double tau = _scoreConfig.tau <= 0.1 ? 14.0 : _scoreConfig.tau;
    final double rVal = (1.0 - math.exp(-energy / tau)).clamp(0.0, 1.0);

    double sumPow = 0.0;
    int currentRun = 0;
    final double p = _scoreConfig.powerP;
    for (final x in recentWindow) {
      if (x == 1) {
        currentRun += 1;
      } else {
        if (currentRun > 0) {
          sumPow += math.pow(currentRun, p).toDouble();
          currentRun = 0;
        }
      }
    }
    if (currentRun > 0) {
      sumPow += math.pow(currentRun, p).toDouble();
    }

    final double denom = math.pow(nW + _scoreConfig.coldStartK, p).toDouble();
    final double hVal = denom > 0 ? (sumPow / denom).clamp(0.0, 1.0) : 0.0;

    final double totalScore = (100.0 *
            (_scoreConfig.weightR * rVal + _scoreConfig.weightH * hVal))
        .clamp(0.0, 100.0);

    return NodeScoreResult(
      score: totalScore,
      energy: energy,
      streak: streak,
      lastBrokenStreak: lastBrokenStreak,
      rValue: rVal,
      hValue: hVal,
      justBrokeStreak: justBroke,
    );
  }

  // ==========================================
  // 清空历史填充数据（保留应用与节点版本号）
  // ==========================================

  Future<void> clearAllHistoryData() async {
    _history.clear();
    _lastAutoPenaltyDate = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLastPenaltyDate);

    for (final node in _nodes) {
      node.progress = 0;
      node.increaseCount = 0;
      node.decreaseCount = 0;
      node.latestNote = null;
      for (final attr in node.numericAttributes) {
        attr.totalValue = 0.0;
        attr.count = 0;
      }
    }
    notifyListeners();
    await _saveToStorage();
  }

  // ==========================================
  // 归档管理模式
  // ==========================================

  void startArchiveMode() {
    _isArchiveMode = true;
    _archiveSelectedIds.clear();
    for (final n in _nodes) {
      if (n.isArchived) {
        _archiveSelectedIds.add(n.id);
      }
    }
    _selectedNodeId = null;
    _selectedConnection = null;
    notifyListeners();
  }

  void toggleArchiveSelection(String id) {
    if (_archiveSelectedIds.contains(id)) {
      _archiveSelectedIds.remove(id);
    } else {
      _archiveSelectedIds.add(id);
    }
    notifyListeners();
  }

  void saveArchiveSelections() {
    for (final n in _nodes) {
      n.isArchived = _archiveSelectedIds.contains(n.id);
    }
    _isArchiveMode = false;
    _archiveSelectedIds.clear();
    notifyListeners();
    _saveToStorage();
  }

  void cancelArchiveMode() {
    _isArchiveMode = false;
    _archiveSelectedIds.clear();
    notifyListeners();
  }

  // ==========================================
  // 日期归属与当日完成状态判定
  // ==========================================

  void setDayStartHourOffset(int hours) {
    _dayStartHourOffset = hours.clamp(0, 12);
    notifyListeners();
    _saveToStorage();
  }

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

  /// 无论是正向打卡、负面打卡还是跳过，当天只要填写过，列表自动隐藏
  bool isNodeCompletedToday(FocusNodeModel node) {
    if (node.isPrompt) return false;
    final today = getEffectiveDate(DateTime.now());
    return _history.any((r) =>
        !r.isEdit &&
        r.nodeId == node.id &&
        (r.delta != 0 || r.isSkip) &&
        _isSameDay(getEffectiveDate(r.time), today));
  }

  /// 节点今日是否处于“待办活跃”状态
  bool isNodeActiveToday(FocusNodeModel node) {
    if (node.isPrompt) return true;
    return !isNodeCompletedToday(node);
  }

  // ==========================================
  // 标签管理 (增加、减少与跳过隔离)
  // ==========================================

  List<String> getHistoricalTags({required bool isIncrease, bool isSkip = false}) {
    final Set<String> tagSet = {};
    for (final record in _history) {
      if (record.isEdit) continue;
      final bool match;
      if (isSkip) {
        match = record.isSkip;
      } else {
        match = !record.isSkip && (isIncrease ? record.delta > 0 : record.delta < 0);
      }
      if (match && record.tags != null) {
        tagSet.addAll(record.tags!);
      }
    }
    return tagSet.toList();
  }

  // ==========================================
  // 节点拖拽排序 (排除已归档节点)
  // ==========================================

  void reorderNodes(int oldIndex, int newIndex) {
    final visible = _nodes
        .where((n) => !n.isPrompt && !n.isArchived && isNodeActiveToday(n))
        .toList();
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

  // ==========================================
  // 打卡流水（增加、减少、跳过）与修改
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

  /// 跳过国策（必须附带原因，不计入增减与断签，当天在列表隐藏）
  void skipNode(
    String id, {
    required String reason,
    List<String>? tags,
    DateTime? recordDate,
  }) {
    final target = _nodes.firstWhere((n) => n.id == id);
    if (target.isPrompt) return;

    final trimmedReason = reason.trim();
    if (trimmedReason.isNotEmpty) {
      target.latestNote = trimmedReason;
    }

    _history.add(
      ProgressRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        nodeId: target.id,
        nodeTitle: target.title,
        delta: 0,
        resultProgress: target.progress,
        isSkip: true,
        note: trimmedReason,
        tags: (tags != null && tags.isNotEmpty) ? tags : null,
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
      if (newAttributeDeltas != null && !oldRecord.isSkip) {
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
      isSkip: oldRecord.isSkip,
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
      if (!record.isSkip) {
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