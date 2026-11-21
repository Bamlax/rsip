import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

  // 显示方式：0 = 习惯连续性分数，1 = 直接显示加减次数
  int _displayMode = 0;

  // WebDAV 配置与同步状态
  String _webdavUrl = '';
  String _webdavUsername = '';
  String _webdavPassword = '';
  String? _webdavLastSyncTime;
  DateTime? _localLastModifiedAt;

  int get dayStartHourOffset => _dayStartHourOffset;
  bool get autoPenalizeMissedYesterday => _autoPenalizeMissedYesterday;
  HabitScoreConfig get scoreConfig => _scoreConfig;
  int get displayMode => _displayMode;

  String get webdavUrl => _webdavUrl;
  String get webdavUsername => _webdavUsername;
  String get webdavPassword => _webdavPassword;
  String? get webdavLastSyncTime => _webdavLastSyncTime;
  bool get isWebDavConfigured => _webdavUrl.trim().isNotEmpty;

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
  static const String _keyDisplayMode = 'rsip_display_mode';

  static const String _keyWebdavUrl = 'rsip_webdav_url';
  static const String _keyWebdavUser = 'rsip_webdav_username';
  static const String _keyWebdavPass = 'rsip_webdav_password';
  static const String _keyWebdavLastSync = 'rsip_webdav_last_sync';
  static const String _keyLocalLastModified = 'rsip_local_last_modified';

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _dayStartHourOffset = prefs.getInt(_keyDayOffset) ?? 0;
      _autoPenalizeMissedYesterday = prefs.getBool(_keyAutoPenalize) ?? false;
      _lastAutoPenaltyDate = prefs.getString(_keyLastPenaltyDate);
      _displayMode = prefs.getInt(_keyDisplayMode) ?? 0;

      _webdavUrl = prefs.getString(_keyWebdavUrl) ?? '';
      _webdavUsername = prefs.getString(_keyWebdavUser) ?? '';
      _webdavPassword = prefs.getString(_keyWebdavPass) ?? '';
      _webdavLastSyncTime = prefs.getString(_keyWebdavLastSync);

      final modifiedStr = prefs.getString(_keyLocalLastModified);
      if (modifiedStr != null) {
        _localLastModifiedAt = DateTime.tryParse(modifiedStr);
      }

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

      await _applyMissedYesterdayPenaltyIfNeeded(saveAfter: true);

      notifyListeners();
    } catch (e) {
      debugPrint('加载本地存储失败: $e');
    }
  }

  Future<void> _saveToStorage({bool markModified = true}) async {
    try {
      if (markModified) {
        _localLastModifiedAt = DateTime.now();
      }
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
      await prefs.setInt(_keyDisplayMode, _displayMode);
      if (_lastAutoPenaltyDate != null) {
        await prefs.setString(_keyLastPenaltyDate, _lastAutoPenaltyDate!);
      } else {
        await prefs.remove(_keyLastPenaltyDate);
      }
      await prefs.setString(_keyScoreConfig, jsonEncode(_scoreConfig.toJson()));

      await prefs.setString(_keyWebdavUrl, _webdavUrl);
      await prefs.setString(_keyWebdavUser, _webdavUsername);
      await prefs.setString(_keyWebdavPass, _webdavPassword);
      if (_webdavLastSyncTime != null) {
        await prefs.setString(_keyWebdavLastSync, _webdavLastSyncTime!);
      }
      if (_localLastModifiedAt != null) {
        await prefs.setString(
          _keyLocalLastModified,
          _localLastModifiedAt!.toIso8601String(),
        );
      }
    } catch (e) {
      debugPrint('保存到本地存储失败: $e');
    }
  }

  // ==========================================
  // WebDAV 配置、连通性测试与全量双向同步
  // ==========================================

  Future<void> saveWebDavConfig({
    required String url,
    required String username,
    required String password,
  }) async {
    _webdavUrl = url.trim();
    _webdavUsername = username.trim();
    _webdavPassword = password;
    notifyListeners();
    await _saveToStorage(markModified: false);
  }

  ({Uri dirUri, Uri fileUri})? _resolveWebDavUris(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null ||
        !parsed.hasScheme ||
        (parsed.scheme != 'http' && parsed.scheme != 'https')) {
      return null;
    }

    if (trimmed.toLowerCase().endsWith('.json')) {
      final lastSlash = trimmed.lastIndexOf('/');
      final dirStr = trimmed.substring(0, lastSlash + 1);
      return (dirUri: Uri.parse(dirStr), fileUri: parsed);
    } else {
      final dirStr = trimmed.endsWith('/') ? trimmed : '$trimmed/';
      return (
        dirUri: Uri.parse(dirStr),
        fileUri: Uri.parse('${dirStr}rsip_backup.json'),
      );
    }
  }

  String _buildBasicAuthHeader(String user, String pass) {
    final token = base64Encode(utf8.encode('$user:$pass'));
    return 'Basic $token';
  }

  String _formatSyncTimestamp(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<({bool success, String message})> testWebDavConnection({
    String? url,
    String? username,
    String? password,
  }) async {
    final targetUrl = (url ?? _webdavUrl).trim();
    final targetUser = (username ?? _webdavUsername).trim();
    final targetPass = password ?? _webdavPassword;

    final uris = _resolveWebDavUris(targetUrl);
    if (uris == null) {
      return (
        success: false,
        message: '请输入有效的 HTTP/HTTPS WebDAV 地址',
      );
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.openUrl('PROPFIND', uris.dirUri);
      if (targetUser.isNotEmpty || targetPass.isNotEmpty) {
        req.headers.set(
          HttpHeaders.authorizationHeader,
          _buildBasicAuthHeader(targetUser, targetPass),
        );
      }
      req.headers.set('Depth', '0');

      final res = await req.close().timeout(const Duration(seconds: 12));
      await res.drain<void>();

      if (res.statusCode == 200 || res.statusCode == 207) {
        return (success: true, message: '连接成功，WebDAV 目录可正常读写');
      } else if (res.statusCode == 401 || res.statusCode == 403) {
        return (
          success: false,
          message: '认证失败 (HTTP ${res.statusCode})，请检查账号或应用专用密码',
        );
      } else if (res.statusCode == 404) {
        final segments =
            uris.dirUri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (segments.length > 1) {
          final parentSegments = segments.sublist(0, segments.length - 1);
          final parentUri = uris.dirUri.replace(
            path: '/${parentSegments.join('/')}/',
          );
          final parentReq = await client.openUrl('PROPFIND', parentUri);
          if (targetUser.isNotEmpty || targetPass.isNotEmpty) {
            parentReq.headers.set(
              HttpHeaders.authorizationHeader,
              _buildBasicAuthHeader(targetUser, targetPass),
            );
          }
          parentReq.headers.set('Depth', '0');
          final parentRes =
              await parentReq.close().timeout(const Duration(seconds: 10));
          await parentRes.drain<void>();

          if (parentRes.statusCode == 200 || parentRes.statusCode == 207) {
            return (
              success: true,
              message: '认证成功，目标子目录尚不存在（上传时将自动创建）',
            );
          } else if (parentRes.statusCode == 401 ||
              parentRes.statusCode == 403) {
            return (
              success: false,
              message: '认证失败 (HTTP ${parentRes.statusCode})，请检查账号或密码',
            );
          }
        }
        return (
          success: false,
          message: '目标路径不存在 (HTTP 404)，请检查服务器路径是否正确',
        );
      } else if (res.statusCode == 405) {
        return (
          success: false,
          message: '当前地址不支持 WebDAV 协议 (HTTP 405)',
        );
      } else {
        return (
          success: false,
          message: '服务器返回异常状态码: HTTP ${res.statusCode}',
        );
      }
    } on SocketException {
      return (success: false, message: '无法连接到服务器，请检查网络或服务器地址');
    } on HandshakeException {
      return (success: false, message: 'SSL/TLS 安全证书握手失败');
    } on TimeoutException {
      return (success: false, message: '连接超时，请检查网络或服务器响应');
    } catch (e) {
      return (success: false, message: '连接异常: $e');
    } finally {
      client.close(force: true);
    }
  }

  String exportFullBackupJson({DateTime? exportedAt}) {
    final timestamp = exportedAt ?? DateTime.now();
    final payload = <String, dynamic>{
      'schemaVersion': 1,
      'exportedAt': timestamp.toIso8601String(),
      'settings': {
        'dayStartHourOffset': _dayStartHourOffset,
        'autoPenalizeMissedYesterday': _autoPenalizeMissedYesterday,
        'lastAutoPenaltyDate': _lastAutoPenaltyDate,
        'displayMode': _displayMode,
        'scoreConfig': _scoreConfig.toJson(),
      },
      'data': {
        'nodes': _nodes.map((n) => n.toJson()).toList(),
        'connections': _connections.map((c) => c.toJson()).toList(),
        'groups': _groups.map((g) => g.toJson()).toList(),
        'history': _history.map((h) => h.toJson()).toList(),
      },
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<({bool success, String message})> uploadToWebDav() async {
    final uris = _resolveWebDavUris(_webdavUrl);
    if (uris == null) {
      return (success: false, message: '请先在设置中配置有效的 WebDAV 地址');
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      try {
        final mkcolReq = await client.openUrl('MKCOL', uris.dirUri);
        if (_webdavUsername.isNotEmpty || _webdavPassword.isNotEmpty) {
          mkcolReq.headers.set(
            HttpHeaders.authorizationHeader,
            _buildBasicAuthHeader(_webdavUsername, _webdavPassword),
          );
        }
        final mkcolRes =
            await mkcolReq.close().timeout(const Duration(seconds: 10));
        await mkcolRes.drain<void>();
        if (mkcolRes.statusCode == 401 || mkcolRes.statusCode == 403) {
          return (
            success: false,
            message: '认证失败 (HTTP ${mkcolRes.statusCode})，请检查账号或密码',
          );
        }
      } catch (_) {}

      final now = DateTime.now();
      final jsonBytes = utf8.encode(exportFullBackupJson(exportedAt: now));
      final putReq = await client.putUrl(uris.fileUri);
      if (_webdavUsername.isNotEmpty || _webdavPassword.isNotEmpty) {
        putReq.headers.set(
          HttpHeaders.authorizationHeader,
          _buildBasicAuthHeader(_webdavUsername, _webdavPassword),
        );
      }
      putReq.headers.contentType =
          ContentType('application', 'json', charset: 'utf-8');
      putReq.headers.contentLength = jsonBytes.length;
      putReq.add(jsonBytes);

      final putRes = await putReq.close().timeout(const Duration(seconds: 15));
      await putRes.drain<void>();

      if (putRes.statusCode >= 200 && putRes.statusCode < 300) {
        _localLastModifiedAt = now;
        _webdavLastSyncTime = _formatSyncTimestamp(now);
        notifyListeners();
        await _saveToStorage(markModified: false);
        return (success: true, message: '上传成功，全部数据与设置已同步至云端');
      } else if (putRes.statusCode == 401 || putRes.statusCode == 403) {
        return (
          success: false,
          message: '上传被拒绝 (HTTP ${putRes.statusCode})，请检查写入权限与密码',
        );
      } else {
        return (
          success: false,
          message: '上传失败: HTTP ${putRes.statusCode}',
        );
      }
    } on SocketException {
      return (success: false, message: '网络连接失败，无法上传至服务器');
    } on TimeoutException {
      return (success: false, message: '上传超时，请稍后重试');
    } catch (e) {
      return (success: false, message: '上传异常: $e');
    } finally {
      client.close(force: true);
    }
  }

  Future<({bool success, String message})> downloadFromWebDav() async {
    final uris = _resolveWebDavUris(_webdavUrl);
    if (uris == null) {
      return (success: false, message: '请先在设置中配置有效的 WebDAV 地址');
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final getReq = await client.getUrl(uris.fileUri);
      if (_webdavUsername.isNotEmpty || _webdavPassword.isNotEmpty) {
        getReq.headers.set(
          HttpHeaders.authorizationHeader,
          _buildBasicAuthHeader(_webdavUsername, _webdavPassword),
        );
      }

      final getRes = await getReq.close().timeout(const Duration(seconds: 15));
      if (getRes.statusCode == 404) {
        await getRes.drain<void>();
        return (success: false, message: '云端尚无备份文件 (rsip_backup.json)');
      } else if (getRes.statusCode == 401 || getRes.statusCode == 403) {
        await getRes.drain<void>();
        return (
          success: false,
          message: '认证失败 (HTTP ${getRes.statusCode})，请检查账号或密码',
        );
      } else if (getRes.statusCode < 200 || getRes.statusCode >= 300) {
        await getRes.drain<void>();
        return (success: false, message: '下载失败: HTTP ${getRes.statusCode}');
      }

      final rawBody = await utf8.decoder.bind(getRes).join();
      final decoded = jsonDecode(rawBody);
      if (decoded is! Map<String, dynamic>) {
        return (success: false, message: '云端备份文件格式无效');
      }

      final applyError = _applyCloudBackupMap(decoded);
      if (applyError != null) {
        return (success: false, message: applyError);
      }

      notifyListeners();
      await _saveToStorage(markModified: false);

      return (success: true, message: '拉取成功，已同步恢复全部数据与设置参数');
    } on FormatException {
      return (success: false, message: '云端 JSON 文件解析失败，数据可能已损坏');
    } on SocketException {
      return (success: false, message: '网络连接失败，无法从服务器下载');
    } on TimeoutException {
      return (success: false, message: '下载超时，请稍后重试');
    } catch (e) {
      return (success: false, message: '拉取异常: $e');
    } finally {
      client.close(force: true);
    }
  }

  /// 首页下拉刷新专用：智能比对云端与本地时间戳，自动决定拉取、上传或提示已是最新
  Future<({bool success, String message})> syncWithWebDav() async {
    final uris = _resolveWebDavUris(_webdavUrl);
    if (uris == null) {
      return (
        success: false,
        message: '请先在「设置 - WebDAV 云同步」中配置服务器地址',
      );
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final getReq = await client.getUrl(uris.fileUri);
      if (_webdavUsername.isNotEmpty || _webdavPassword.isNotEmpty) {
        getReq.headers.set(
          HttpHeaders.authorizationHeader,
          _buildBasicAuthHeader(_webdavUsername, _webdavPassword),
        );
      }

      final getRes = await getReq.close().timeout(const Duration(seconds: 12));

      // 若云端尚无备份文件，自动将本地数据首次上传
      if (getRes.statusCode == 404) {
        await getRes.drain<void>();
        client.close(force: true);
        return await uploadToWebDav();
      } else if (getRes.statusCode == 401 || getRes.statusCode == 403) {
        await getRes.drain<void>();
        return (
          success: false,
          message: 'WebDAV 认证失败 (HTTP ${getRes.statusCode})，请检查配置',
        );
      } else if (getRes.statusCode < 200 || getRes.statusCode >= 300) {
        await getRes.drain<void>();
        return (success: false, message: '同步失败: HTTP ${getRes.statusCode}');
      }

      final rawBody = await utf8.decoder.bind(getRes).join();
      final decoded = jsonDecode(rawBody);
      if (decoded is! Map<String, dynamic>) {
        return (success: false, message: '云端备份文件格式无效');
      }

      final cloudExportedAt = decoded['exportedAt'] is String
          ? DateTime.tryParse(decoded['exportedAt'] as String)
          : null;

      final isLocalEmpty = _nodes.isEmpty && _history.isEmpty;

      // 情况 1：本地为空，或云端时间戳严格晚于本地最后修改时间 -> 从云端拉取
      if (isLocalEmpty ||
          (cloudExportedAt != null &&
              (_localLastModifiedAt == null ||
                  cloudExportedAt.isAfter(
                    _localLastModifiedAt!.add(const Duration(seconds: 1)),
                  )))) {
        final applyError = _applyCloudBackupMap(decoded);
        if (applyError != null) {
          return (success: false, message: applyError);
        }
        notifyListeners();
        await _saveToStorage(markModified: false);
        return (success: true, message: '同步完成：已从云端拉取最新数据');
      }

      // 情况 2：云端与本地时间戳一致（1秒误差内） -> 无需重复上传
      if (cloudExportedAt != null &&
          _localLastModifiedAt != null &&
          _localLastModifiedAt!.difference(cloudExportedAt).inSeconds.abs() <=
              1) {
        _webdavLastSyncTime = _formatSyncTimestamp(DateTime.now());
        notifyListeners();
        await _saveToStorage(markModified: false);
        return (success: true, message: '同步完成：当前已是最新状态');
      }

      // 情况 3：本地有新的修改 -> 自动上传至云端
      client.close(force: true);
      return await uploadToWebDav();
    } on FormatException {
      return (success: false, message: '云端数据格式解析失败');
    } on SocketException {
      return (success: false, message: '网络连接失败，无法同步至 WebDAV');
    } on TimeoutException {
      return (success: false, message: '同步超时，请稍后重试');
    } catch (e) {
      return (success: false, message: '同步异常: $e');
    } finally {
      client.close(force: true);
    }
  }

  String? _applyCloudBackupMap(Map<String, dynamic> decoded) {
    final dataMap = decoded['data'];
    if (dataMap is! Map<String, dynamic>) {
      return '云端备份缺少核心数据节点';
    }

    final settingsMap = decoded['settings'];
    if (settingsMap is Map<String, dynamic>) {
      _dayStartHourOffset =
          ((settingsMap['dayStartHourOffset'] as num?)?.toInt() ?? 0)
              .clamp(0, 12);
      _autoPenalizeMissedYesterday =
          settingsMap['autoPenalizeMissedYesterday'] as bool? ?? false;
      _lastAutoPenaltyDate = settingsMap['lastAutoPenaltyDate'] as String?;
      _displayMode =
          ((settingsMap['displayMode'] as num?)?.toInt() ?? 0) == 1 ? 1 : 0;

      if (settingsMap['scoreConfig'] is Map<String, dynamic>) {
        _scoreConfig = HabitScoreConfig.fromJson(
          settingsMap['scoreConfig'] as Map<String, dynamic>,
        );
      }
    }

    final nodesList = (dataMap['nodes'] as List<dynamic>?) ?? [];
    final connList = (dataMap['connections'] as List<dynamic>?) ?? [];
    final groupsList = (dataMap['groups'] as List<dynamic>?) ?? [];
    final historyList = (dataMap['history'] as List<dynamic>?) ?? [];

    _nodes
      ..clear()
      ..addAll(
        nodesList.map((e) => FocusNodeModel.fromJson(e as Map<String, dynamic>)),
      );
    _connections
      ..clear()
      ..addAll(
        connList.map((e) => FocusConnection.fromJson(e as Map<String, dynamic>)),
      );
    _groups
      ..clear()
      ..addAll(
        groupsList.map((e) => FocusGroupModel.fromJson(e as Map<String, dynamic>)),
      );
    _history
      ..clear()
      ..addAll(
        historyList.map((e) => ProgressRecord.fromJson(e as Map<String, dynamic>)),
      );

    _selectedNodeId = null;
    _selectedConnection = null;
    _isGroupSelectMode = false;
    _groupSelectedNodeIds.clear();
    _isArchiveMode = false;
    _archiveSelectedIds.clear();

    final cloudExportedAt = decoded['exportedAt'] is String
        ? DateTime.tryParse(decoded['exportedAt'] as String)
        : null;
    _localLastModifiedAt = cloudExportedAt ?? DateTime.now();
    _webdavLastSyncTime = _formatSyncTimestamp(DateTime.now());
    return null;
  }

  // ==========================================
  // 显示方式切换 (0: 分数, 1: 加减次数)
  // ==========================================

  void setDisplayMode(int mode) {
    final normalized = mode == 1 ? 1 : 0;
    if (_displayMode == normalized) return;
    _displayMode = normalized;
    notifyListeners();
    _saveToStorage();
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
        continue;
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

  bool isNodeCompletedToday(FocusNodeModel node) {
    if (node.isPrompt) return false;
    final today = getEffectiveDate(DateTime.now());
    return _history.any((r) =>
        !r.isEdit &&
        r.nodeId == node.id &&
        (r.delta != 0 || r.isSkip) &&
        _isSameDay(getEffectiveDate(r.time), today));
  }

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
  // 打卡流水（增加、减少、跳过）与编辑重算
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
    int? newDelta,
    bool? newIsSkip,
    String? newNote,
    List<String>? newTags,
    Map<String, double>? newAttributeDeltas,
  }) {
    final index = _history.indexWhere((r) => r.id == recordId);
    if (index == -1) return;
    final oldRecord = _history[index];
    if (oldRecord.isEdit) return;

    final finalIsSkip = newIsSkip ?? oldRecord.isSkip;
    final finalDelta = finalIsSkip ? 0 : (newDelta ?? oldRecord.delta);

    final nodeIndex = _nodes.indexWhere((n) => n.id == oldRecord.nodeId);
    if (nodeIndex != -1) {
      final node = _nodes[nodeIndex];
      for (final attr in node.numericAttributes) {
        final oldRaw = oldRecord.isSkip
            ? null
            : oldRecord.attributeDeltas?[attr.name];
        final newRaw =
            finalIsSkip ? null : newAttributeDeltas?[attr.name];

        final hadOld = oldRaw != null && oldRaw != 0;
        final hasNew = newRaw != null && newRaw != 0;

        final oldVal = hadOld ? oldRaw : 0.0;
        final newVal = hasNew ? newRaw : 0.0;

        attr.totalValue += (newVal - oldVal);
        if (!hadOld && hasNew) {
          attr.count += 1;
        } else if (hadOld && !hasNew) {
          attr.count = (attr.count - 1).clamp(0, 999999);
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
      delta: finalDelta,
      resultProgress: oldRecord.resultProgress,
      note: newNote?.trim().isEmpty == true ? null : newNote?.trim(),
      tags: (newTags != null && newTags.isNotEmpty) ? newTags : null,
      attributeDeltas: finalIsSkip ? null : newAttributeDeltas,
      revision: oldRecord.revision,
      isEdit: oldRecord.isEdit,
      isSkip: finalIsSkip,
      oldTitle: oldRecord.oldTitle,
      newTitle: oldRecord.newTitle,
      oldContent: oldRecord.oldContent,
      newContent: oldRecord.newContent,
      attributeChanges: oldRecord.attributeChanges,
      time: newDate,
    );

    _history[index] = updatedRecord;
    _recalculateNodeStats(oldRecord.nodeId);
    notifyListeners();
    _saveToStorage();
  }

  void _recalculateNodeStats(String nodeId) {
    final nodeIndex = _nodes.indexWhere((n) => n.id == nodeId);
    if (nodeIndex == -1) return;
    final node = _nodes[nodeIndex];

    final indexedRecords = <MapEntry<int, ProgressRecord>>[];
    for (int i = 0; i < _history.length; i++) {
      if (_history[i].nodeId == nodeId) {
        indexedRecords.add(MapEntry(i, _history[i]));
      }
    }

    indexedRecords.sort((a, b) {
      final cmp = a.value.time.compareTo(b.value.time);
      return cmp != 0 ? cmp : a.key.compareTo(b.key);
    });

    int runningProgress = 0;
    int incCount = 0;
    int decCount = 0;

    for (final entry in indexedRecords) {
      final idx = entry.key;
      final r = entry.value;
      if (!r.isEdit && !r.isSkip) {
        runningProgress += r.delta;
        if (r.delta > 0) {
          incCount++;
        } else if (r.delta < 0) {
          decCount++;
        }
      }
      _history[idx] = ProgressRecord(
        id: r.id,
        nodeId: r.nodeId,
        nodeTitle: r.nodeTitle,
        delta: r.delta,
        resultProgress: runningProgress,
        note: r.note,
        tags: r.tags,
        attributeDeltas: r.attributeDeltas,
        revision: r.revision,
        isEdit: r.isEdit,
        isSkip: r.isSkip,
        oldTitle: r.oldTitle,
        newTitle: r.newTitle,
        oldContent: r.oldContent,
        newContent: r.newContent,
        attributeChanges: r.attributeChanges,
        time: r.time,
      );
    }

    node.progress = runningProgress;
    node.increaseCount = incCount;
    node.decreaseCount = decCount;
  }

  void deleteRecord(String recordId) {
    final index = _history.indexWhere((r) => r.id == recordId);
    if (index == -1) return;
    final record = _history[index];
    if (record.isEdit) return;

    final nodeIndex = _nodes.indexWhere((n) => n.id == record.nodeId);
    if (nodeIndex != -1) {
      final node = _nodes[nodeIndex];
      if (!record.isSkip && record.attributeDeltas != null) {
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
    _recalculateNodeStats(record.nodeId);
    notifyListeners();
    _saveToStorage();
  }
}