/// 国策的数字属性定义与累计值
class NumericAttribute {
  final String id;
  String name;       // 属性名称 (如: 耗时, 里程, 词汇量)
  String unit;       // 单位 (如: 分钟, km, 个)
  double totalValue; // 累计总数值
  int count;         // 录入频次

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
  int version; // 最初版为 1
  bool isPrompt;
  String? latestNote;

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
    List<NumericAttribute>? numericAttributes,
    this.x,
    this.y,
    DateTime? createdAt,
  })  : _numericAttributes = numericAttributes ?? [],
        createdAt = createdAt ?? DateTime.now();

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
  final Map<String, double>? attributeDeltas;
  final int? revision;
  final bool isEdit;
  final String? oldTitle;
  final String? newTitle;
  final String? oldContent;
  final String? newContent;
  final List<AttributeChange>? attributeChanges; // 记录属性的增删改差异
  final DateTime time;

  ProgressRecord({
    required this.id,
    required this.nodeId,
    required this.nodeTitle,
    required this.delta,
    required this.resultProgress,
    this.note,
    this.attributeDeltas,
    this.revision,
    this.isEdit = false,
    this.oldTitle,
    this.newTitle,
    this.oldContent,
    this.newContent,
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
        'attributeDeltas': attributeDeltas,
        'revision': revision,
        'isEdit': isEdit,
        'oldTitle': oldTitle,
        'newTitle': newTitle,
        'oldContent': oldContent,
        'newContent': newContent,
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
        attributeChanges: (json['attributeChanges'] as List<dynamic>?)
            ?.map((e) => AttributeChange.fromJson(e as Map<String, dynamic>))
            .toList(),
        time: json['time'] != null
            ? DateTime.tryParse(json['time'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}