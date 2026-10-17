/// 国策的数字属性定义与累计值
class NumericAttribute {
  final String id;
  String name;
  String unit;
  double totalValue;
  int count;

  NumericAttribute({
    String? id,
    required this.name,
    required this.unit,
    this.totalValue = 0.0,
    this.count = 0,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  double get average => count > 0 ? totalValue / count : 0.0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'unit': unit,
        'totalValue': totalValue,
        'count': count,
      };

  factory NumericAttribute.fromJson(Map<String, dynamic> json) =>
      NumericAttribute(
        id: json['id'] as String?,
        name: json['name'] as String? ?? '数值',
        unit: json['unit'] as String? ?? '项',
        totalValue: (json['totalValue'] as num?)?.toDouble() ?? 0.0,
        count: json['count'] as int? ?? 0,
      );
}

/// 属性变更明细 (用于版本修订对比)
class AttributeChange {
  final String? oldName;
  final String? oldUnit;
  final String? newName;
  final String? newUnit;
  final int type; // -1: 删除, 0: 修改, 1: 新增

  AttributeChange({
    this.oldName,
    this.oldUnit,
    this.newName,
    this.newUnit,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
        'oldName': oldName,
        'oldUnit': oldUnit,
        'newName': newName,
        'newUnit': newUnit,
        'type': type,
      };

  factory AttributeChange.fromJson(Map<String, dynamic> json) =>
      AttributeChange(
        oldName: json['oldName'] as String?,
        oldUnit: json['oldUnit'] as String?,
        newName: json['newName'] as String?,
        newUnit: json['newUnit'] as String?,
        type: json['type'] as int? ?? 0,
      );
}

class FocusNodeModel {
  final String id;
  String title;
  String content;
  int progress;
  int increaseCount;
  int decreaseCount;
  int version;
  bool isPrompt;
  String? latestNote;

  // 节点自定义备注弹窗开关
  bool promptNoteOnIncrease;
  bool promptNoteOnDecrease;

  // 重复规则配置
  // repeatMode: 0 = 周一至周日自选 (全选即为每天), 1 = 周期/频次 (每x天/每周x次/每月x次)
  int repeatMode;
  List<int> repeatWeekdays; // 1(周一) ~ 7(周日)
  int repeatFreqType; // 0 = 每x天, 1 = 每周x次, 2 = 每月x次
  int repeatFreqValue; // x 的值

  List<NumericAttribute>? _numericAttributes;
  List<NumericAttribute> get numericAttributes => _numericAttributes ??= [];
  set numericAttributes(List<NumericAttribute> val) => _numericAttributes = val;

  double? x;
  double? y;
  final DateTime createdAt;

  FocusNodeModel({
    required this.id,
    required this.title,
    required this.content,
    this.progress = 0,
    this.increaseCount = 0,
    this.decreaseCount = 0,
    this.version = 1,
    this.isPrompt = false,
    this.latestNote,
    this.promptNoteOnIncrease = true,
    this.promptNoteOnDecrease = true,
    this.repeatMode = 0,
    List<int>? repeatWeekdays,
    this.repeatFreqType = 0,
    this.repeatFreqValue = 1,
    List<NumericAttribute>? numericAttributes,
    this.x,
    this.y,
    DateTime? createdAt,
  })  : repeatWeekdays = repeatWeekdays != null && repeatWeekdays.isNotEmpty
            ? List.from(repeatWeekdays)
            : [1, 2, 3, 4, 5, 6, 7],
        _numericAttributes = numericAttributes ?? [],
        createdAt = createdAt ?? DateTime.now();

  /// 生成可读的重复规则描述文本
  static String formatRepeatRule({
    required int mode,
    required List<int> weekdays,
    required int freqType,
    required int freqValue,
  }) {
    if (mode == 0) {
      if (weekdays.length >= 7) return '每天';
      final sorted = List<int>.from(weekdays)..sort();
      const names = ['', '一', '二', '三', '四', '五', '六', '日'];
      return '周${sorted.map((d) => names[d.clamp(1, 7)]).join("、")}';
    } else {
      if (freqType == 0) {
        return freqValue <= 1 ? '每天' : '每 $freqValue 天';
      } else if (freqType == 1) {
        return '每周 $freqValue 次';
      } else {
        return '每月 $freqValue 次';
      }
    }
  }

  /// 生成可读的重复规则描述文本
  String get repeatDescription => formatRepeatRule(
        mode: repeatMode,
        weekdays: repeatWeekdays,
        freqType: repeatFreqType,
        freqValue: repeatFreqValue,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'progress': progress,
        'increaseCount': increaseCount,
        'decreaseCount': decreaseCount,
        'version': version,
        'isPrompt': isPrompt,
        'latestNote': latestNote,
        'promptNoteOnIncrease': promptNoteOnIncrease,
        'promptNoteOnDecrease': promptNoteOnDecrease,
        'repeatMode': repeatMode,
        'repeatWeekdays': repeatWeekdays,
        'repeatFreqType': repeatFreqType,
        'repeatFreqValue': repeatFreqValue,
        'numericAttributes':
            numericAttributes.map((attr) => attr.toJson()).toList(),
        'x': x,
        'y': y,
        'createdAt': createdAt.toIso8601String(),
      };

  factory FocusNodeModel.fromJson(Map<String, dynamic> json) => FocusNodeModel(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        progress: json['progress'] as int? ?? 0,
        increaseCount: json['increaseCount'] as int? ?? 0,
        decreaseCount: json['decreaseCount'] as int? ?? 0,
        version: json['version'] as int? ?? 1,
        isPrompt: json['isPrompt'] as bool? ?? false,
        latestNote: json['latestNote'] as String?,
        promptNoteOnIncrease: json['promptNoteOnIncrease'] as bool? ?? true,
        promptNoteOnDecrease: json['promptNoteOnDecrease'] as bool? ?? true,
        repeatMode: json['repeatMode'] as int? ?? 0,
        repeatWeekdays: (json['repeatWeekdays'] as List<dynamic>?)
                ?.map((e) => (e as num).toInt())
                .toList() ??
            [1, 2, 3, 4, 5, 6, 7],
        repeatFreqType: json['repeatFreqType'] as int? ?? 0,
        repeatFreqValue: json['repeatFreqValue'] as int? ?? 1,
        numericAttributes: (json['numericAttributes'] as List<dynamic>?)
            ?.map((e) => NumericAttribute.fromJson(e as Map<String, dynamic>))
            .toList(),
        x: (json['x'] as num?)?.toDouble(),
        y: (json['y'] as num?)?.toDouble(),
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );
}

/// 大节点框
class FocusGroupModel {
  final String id;
  String title;
  final Set<String> nodeIds;
  final DateTime createdAt;

  FocusGroupModel({
    required this.id,
    required this.title,
    required Set<String> nodeIds,
    DateTime? createdAt,
  })  : nodeIds = Set.from(nodeIds),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'nodeIds': nodeIds.toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory FocusGroupModel.fromJson(Map<String, dynamic> json) =>
      FocusGroupModel(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        nodeIds: (json['nodeIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toSet() ??
            {},
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );
}

/// 节点连线
class FocusConnection {
  final String fromId;
  final String toId;

  FocusConnection({required this.fromId, required this.toId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FocusConnection &&
          ((fromId == other.fromId && toId == other.toId) ||
              (fromId == other.toId && toId == other.fromId));

  @override
  int get hashCode => fromId.hashCode ^ toId.hashCode;

  Map<String, dynamic> toJson() => {
        'fromId': fromId,
        'toId': toId,
      };

  factory FocusConnection.fromJson(Map<String, dynamic> json) =>
      FocusConnection(
        fromId: json['fromId'] as String,
        toId: json['toId'] as String,
      );
}

/// 打卡历史与修订流水
class ProgressRecord {
  final String id;
  final String nodeId;
  final String nodeTitle;
  final int delta;
  final int resultProgress;
  final String? note;
  final List<String>? tags;
  final Map<String, double>? attributeDeltas;
  final int? revision;
  final bool isEdit;
  final String? oldTitle;
  final String? newTitle;
  final String? oldContent;
  final String? newContent;
  final String? oldRepeatDesc; // 新增：修改前的重复规则描述
  final String? newRepeatDesc; // 新增：修改后的重复规则描述
  final List<AttributeChange>? attributeChanges;
  final DateTime time;

  ProgressRecord({
    required this.id,
    required this.nodeId,
    required this.nodeTitle,
    required this.delta,
    required this.resultProgress,
    this.note,
    this.tags,
    this.attributeDeltas,
    this.revision,
    this.isEdit = false,
    this.oldTitle,
    this.newTitle,
    this.oldContent,
    this.newContent,
    this.oldRepeatDesc,
    this.newRepeatDesc,
    this.attributeChanges,
    required this.time,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nodeId': nodeId,
        'nodeTitle': nodeTitle,
        'delta': delta,
        'resultProgress': resultProgress,
        'note': note,
        'tags': tags,
        'attributeDeltas': attributeDeltas,
        'revision': revision,
        'isEdit': isEdit,
        'oldTitle': oldTitle,
        'newTitle': newTitle,
        'oldContent': oldContent,
        'newContent': newContent,
        'oldRepeatDesc': oldRepeatDesc,
        'newRepeatDesc': newRepeatDesc,
        'attributeChanges':
            attributeChanges?.map((e) => e.toJson()).toList(),
        'time': time.toIso8601String(),
      };

  factory ProgressRecord.fromJson(Map<String, dynamic> json) => ProgressRecord(
        id: json['id'] as String,
        nodeId: json['nodeId'] as String? ?? '',
        nodeTitle: json['nodeTitle'] as String? ?? '',
        delta: json['delta'] as int? ?? 0,
        resultProgress: json['resultProgress'] as int? ?? 0,
        note: json['note'] as String?,
        tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
        attributeDeltas: json['attributeDeltas'] != null
            ? (json['attributeDeltas'] as Map<String, dynamic>).map(
                (k, v) => MapEntry(k, (v as num).toDouble()),
              )
            : null,
        revision: json['revision'] as int?,
        isEdit: json['isEdit'] as bool? ?? false,
        oldTitle: json['oldTitle'] as String?,
        newTitle: json['newTitle'] as String?,
        oldContent: json['oldContent'] as String?,
        newContent: json['newContent'] as String?,
        oldRepeatDesc: json['oldRepeatDesc'] as String?,
        newRepeatDesc: json['newRepeatDesc'] as String?,
        attributeChanges: (json['attributeChanges'] as List<dynamic>?)
            ?.map((e) => AttributeChange.fromJson(e as Map<String, dynamic>))
            .toList(),
        time: json['time'] != null
            ? DateTime.tryParse(json['time'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}