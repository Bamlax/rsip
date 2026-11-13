/// 习惯连续性打分算法参数配置[cite: 1]
class HabitScoreConfig {
  int windowSize; // W: 滑动窗口天数 (默认 90)[cite: 1]
  double tau; // τ: 连续饱和尺度 (默认 14.0)[cite: 1]
  double gammaBase; // γ_base: 基础能量保留率 (默认 0.85)[cite: 1]
  double kDrop; // k_drop: 连击衰减斜率 (默认 0.005)[cite: 1]
  double gammaMin; // γ_min: 保留率下限保底 (默认 0.35)[cite: 1]
  double powerP; // p: 分段幂次 (默认 1.5)[cite: 1]
  int coldStartK; // K: 冷启动常数 (默认 7)[cite: 1]
  double weightR; // w_R: 短期势能权重 (默认 0.60, w_H = 1 - w_R = 0.40)[cite: 1]

  HabitScoreConfig({
    this.windowSize = 90,
    this.tau = 14.0,
    this.gammaBase = 0.85,
    this.kDrop = 0.005,
    this.gammaMin = 0.35,
    this.powerP = 1.5,
    this.coldStartK = 7,
    this.weightR = 0.60,
  });

  double get weightH => (1.0 - weightR).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
        'windowSize': windowSize,
        'tau': tau,
        'gammaBase': gammaBase,
        'kDrop': kDrop,
        'gammaMin': gammaMin,
        'powerP': powerP,
        'coldStartK': coldStartK,
        'weightR': weightR,
      };

  factory HabitScoreConfig.fromJson(Map<String, dynamic> json) =>
      HabitScoreConfig(
        windowSize: (json['windowSize'] as num?)?.toInt() ?? 90,
        tau: (json['tau'] as num?)?.toDouble() ?? 14.0,
        gammaBase: (json['gammaBase'] as num?)?.toDouble() ?? 0.85,
        kDrop: (json['kDrop'] as num?)?.toDouble() ?? 0.005,
        gammaMin: (json['gammaMin'] as num?)?.toDouble() ?? 0.35,
        powerP: (json['powerP'] as num?)?.toDouble() ?? 1.5,
        coldStartK: (json['coldStartK'] as num?)?.toInt() ?? 7,
        weightR: (json['weightR'] as num?)?.toDouble() ?? 0.60,
      );

  HabitScoreConfig copy() => HabitScoreConfig(
        windowSize: windowSize,
        tau: tau,
        gammaBase: gammaBase,
        kDrop: kDrop,
        gammaMin: gammaMin,
        powerP: powerP,
        coldStartK: coldStartK,
        weightR: weightR,
      );
}

/// 单个节点的打分评估结果[cite: 1]
class NodeScoreResult {
  final double score; // 总分 S ∈ [0, 100][cite: 1]
  final double energy; // 当前连续能量 E_t[cite: 1]
  final int streak; // 当前连续天数 c[cite: 1]
  final int lastBrokenStreak; // 最近一次断签前的连击天数 c_prev[cite: 1]
  final double rValue; // 当前连续势能指标 R ∈ [0, 1][cite: 1]
  final double hValue; // 历史结构质量指标 H ∈ [0, 1][cite: 1]
  final bool justBrokeStreak; // 最近一次结算是否为长连击断签

  const NodeScoreResult({
    this.score = 0.0,
    this.energy = 0.0,
    this.streak = 0,
    this.lastBrokenStreak = 0,
    this.rValue = 0.0,
    this.hValue = 0.0,
    this.justBrokeStreak = false,
  });
}

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
  bool isArchived;
  String? latestNote;

  // 节点自定义备注弹窗开关
  bool promptNoteOnIncrease;
  bool promptNoteOnDecrease;

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
    this.isArchived = false,
    this.latestNote,
    this.promptNoteOnIncrease = true,
    this.promptNoteOnDecrease = true,
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
        'isArchived': isArchived,
        'latestNote': latestNote,
        'promptNoteOnIncrease': promptNoteOnIncrease,
        'promptNoteOnDecrease': promptNoteOnDecrease,
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
        isArchived: json['isArchived'] as bool? ?? false,
        latestNote: json['latestNote'] as String?,
        promptNoteOnIncrease: json['promptNoteOnIncrease'] as bool? ?? true,
        promptNoteOnDecrease: json['promptNoteOnDecrease'] as bool? ?? true,
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
        attributeChanges: (json['attributeChanges'] as List<dynamic>?)
            ?.map((e) => AttributeChange.fromJson(e as Map<String, dynamic>))
            .toList(),
        time: json['time'] != null
            ? DateTime.tryParse(json['time'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}