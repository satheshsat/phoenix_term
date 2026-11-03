import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import '../models/host_model.dart';
import '../models/group_model.dart';
import '../models/ssh_key_model.dart';
import '../models/snippet_model.dart';
import '../models/port_forward_model.dart';
import '../models/terminal_session_model.dart';
import '../services/storage_service.dart';
import '../services/ssh_service.dart';

class AppProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String _jsonFilePath = '';
  String get jsonFilePath => _jsonFilePath;

  DateTime? _lastSaved;
  DateTime? get lastSaved => _lastSaved;

  // Data collections
  List<HostModel> _hosts = [];
  List<GroupModel> _groups = [];
  List<SSHKeyModel> _keys = [];
  List<SnippetModel> _snippets = [];
  List<PortForwardModel> _portForwards = [];
  Map<String, dynamic> _settings = {};

  List<HostModel> get hosts => _hosts;
  List<GroupModel> get groups => _groups;
  List<SSHKeyModel> get keys => _keys;
  List<SnippetModel> get snippets => _snippets;
  List<PortForwardModel> get portForwards => _portForwards;
  Map<String, dynamic> get settings => _settings;

  // Search & Filter state
  String _hostSearchQuery = '';
  String? _selectedGroupFilter;
  String? _selectedTagFilter;

  String get hostSearchQuery => _hostSearchQuery;
  String? get selectedGroupFilter => _selectedGroupFilter;
  String? get selectedTagFilter => _selectedTagFilter;

  // Navigation: 0=Hosts, 1=Terminal, 2=Snippets, 3=SFTP, 4=Port Forwarding, 5=Keys Vault, 6=Settings & JSON
  int _currentNavIndex = 0;
  int get currentNavIndex => _currentNavIndex;

  // SFTP Target Host
  HostModel? _sftpSelectedHost;
  HostModel? get sftpSelectedHost => _sftpSelectedHost;

  void openSftpForHost(HostModel host) {
    _sftpSelectedHost = host;
    _currentNavIndex = 3;
    notifyListeners();
  }

  void setSftpSelectedHost(HostModel? host) {
    _sftpSelectedHost = host;
    notifyListeners();
  }

  // Terminal Sessions
  final List<TerminalSessionModel> _sessions = [];
  int _activeSessionIndex = 0;

  List<TerminalSessionModel> get sessions => _sessions;
  int get activeSessionIndex => _activeSessionIndex;
  TerminalSessionModel? get activeSession =>
      _sessions.isNotEmpty && _activeSessionIndex < _sessions.length
          ? _sessions[_activeSessionIndex]
          : null;

  AppProvider() {
    init();
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      _jsonFilePath = await _storageService.getJsonFilePath();
      final bundle = await _storageService.loadData();
      _hosts = bundle.hosts;
      _groups = bundle.groups;
      _keys = bundle.keys;
      _snippets = bundle.snippets;
      _portForwards = bundle.portForwards;
      _settings = bundle.settings;
      _lastSaved = bundle.lastModified;
    } catch (e) {
      debugPrint('Error initializing app provider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setNavIndex(int index) {
    _currentNavIndex = index;
    notifyListeners();
  }

  void setHostSearchQuery(String query) {
    _hostSearchQuery = query;
    notifyListeners();
  }

  void setSelectedGroupFilter(String? group) {
    _selectedGroupFilter = group;
    notifyListeners();
  }

  void setSelectedTagFilter(String? tag) {
    _selectedTagFilter = tag;
    notifyListeners();
  }

  List<HostModel> get filteredHosts {
    return _hosts.where((h) {
      if (_selectedGroupFilter != null &&
          _selectedGroupFilter != 'All' &&
          h.group != _selectedGroupFilter) {
        return false;
      }
      if (_selectedTagFilter != null && !h.tags.contains(_selectedTagFilter)) {
        return false;
      }
      if (_hostSearchQuery.isNotEmpty) {
        final q = _hostSearchQuery.toLowerCase();
        final matchAlias = h.alias.toLowerCase().contains(q);
        final matchHost = h.hostname.toLowerCase().contains(q);
        final matchUser = h.username.toLowerCase().contains(q);
        final matchNotes = h.notes.toLowerCase().contains(q);
        final matchTags = h.tags.any((t) => t.toLowerCase().contains(q));
        return matchAlias || matchHost || matchUser || matchNotes || matchTags;
      }
      return true;
    }).toList();
  }

  // ==================== Storage Saving ====================
  Future<void> _persist() async {
    final bundle = StorageDataBundle(
      hosts: _hosts,
      groups: _groups,
      keys: _keys,
      snippets: _snippets,
      portForwards: _portForwards,
      settings: _settings,
      lastModified: DateTime.now(),
    );
    _lastSaved = bundle.lastModified;
    await _storageService.saveData(bundle);
    notifyListeners();
  }

  // ==================== Terminal Session Management ====================
  void connectToHost(HostModel host, {bool forceSimulation = false}) {
    // Check if session already exists for this host
    final existingIdx = _sessions.indexWhere((s) => s.host?.id == host.id);
    if (existingIdx != -1) {
      _activeSessionIndex = existingIdx;
      _currentNavIndex = 1; // switch to Terminal view
      notifyListeners();
      return;
    }

    final terminal = Terminal(maxLines: 2000);
    final controller = TerminalController();
    final newSession = TerminalSessionModel(
      id: 'session_${DateTime.now().millisecondsSinceEpoch}',
      title: host.alias,
      host: host,
      terminal: terminal,
      controller: controller,
    );

    _sessions.add(newSession);
    _activeSessionIndex = _sessions.length - 1;
    _currentNavIndex = 1; // switch to Terminal screen
    notifyListeners();

    // Update host last connected time
    final updatedHost = host.copyWith(lastConnectedAt: DateTime.now());
    updateHost(updatedHost, save: true);

    // Launch connection
    SSHService.connectSession(
      session: newSession,
      host: host,
      availableKeys: _keys,
      forceSimulation: forceSimulation,
    ).then((_) {
      notifyListeners();
    });
  }

  void quickConnect(String connectionString) {
    if (connectionString.trim().isEmpty) return;
    String raw = connectionString.trim();
    if (raw.startsWith('ssh ')) raw = raw.substring(4).trim();

    String username = 'root';
    String hostname = raw;
    int port = 22;

    if (hostname.contains('@')) {
      final parts = hostname.split('@');
      username = parts[0];
      hostname = parts[1];
    }

    if (hostname.contains(':')) {
      final parts = hostname.split(':');
      hostname = parts[0];
      port = int.tryParse(parts[1]) ?? 22;
    }

    final tempHost = HostModel(
      id: 'quick_${DateTime.now().millisecondsSinceEpoch}',
      alias: '$username@$hostname',
      hostname: hostname,
      port: port,
      username: username,
      group: 'Quick Connect',
      colorHex: '#00D2FF',
      createdAt: DateTime.now(),
    );

    connectToHost(tempHost);
  }

  void createNewLocalTab() {
    final localHost = HostModel(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      alias: 'Local Shell',
      hostname: '127.0.0.1',
      port: 22,
      username: 'user',
      colorHex: '#10B981',
      createdAt: DateTime.now(),
    );
    connectToHost(localHost, forceSimulation: true);
  }

  void closeSession(String id) {
    final idx = _sessions.indexWhere((s) => s.id == id);
    if (idx != -1) {
      _sessions[idx].dispose();
      _sessions.removeAt(idx);
      if (_activeSessionIndex >= _sessions.length) {
        _activeSessionIndex = _sessions.isEmpty ? 0 : _sessions.length - 1;
      }
      notifyListeners();
    }
  }

  void selectSession(int index) {
    if (index >= 0 && index < _sessions.length) {
      _activeSessionIndex = index;
      notifyListeners();
    }
  }

  // ==================== Host CRUD ====================
  void addHost(HostModel host) {
    _hosts.insert(0, host);
    _persist();
  }

  void updateHost(HostModel host, {bool save = true}) {
    final idx = _hosts.indexWhere((h) => h.id == host.id);
    if (idx != -1) {
      _hosts[idx] = host;
      if (save) _persist();
    }
  }

  void deleteHost(String id) {
    _hosts.removeWhere((h) => h.id == id);
    _persist();
  }

  void toggleFavoriteHost(String id) {
    final idx = _hosts.indexWhere((h) => h.id == id);
    if (idx != -1) {
      _hosts[idx] = _hosts[idx].copyWith(isFavorite: !_hosts[idx].isFavorite);
      _persist();
    }
  }

  // ==================== Group CRUD ====================
  void addGroup(GroupModel group) {
    _groups.add(group);
    _persist();
  }

  void updateGroup(GroupModel group, {String? oldName}) {
    final idx = _groups.indexWhere((g) => g.id == group.id);
    if (idx != -1) {
      final prevName = oldName ?? _groups[idx].name;
      _groups[idx] = group;

      // Cascade update to hosts if group name changed
      if (prevName != group.name) {
        for (int i = 0; i < _hosts.length; i++) {
          if (_hosts[i].group == prevName) {
            _hosts[i] = _hosts[i].copyWith(group: group.name);
          }
        }
        if (_selectedGroupFilter == prevName) {
          _selectedGroupFilter = group.name;
        }
      }
      _persist();
    }
  }

  void deleteGroup(String id) {
    final idx = _groups.indexWhere((g) => g.id == id);
    if (idx != -1) {
      final groupName = _groups[idx].name;
      _groups.removeAt(idx);

      // Reassign affected hosts to Default
      for (int i = 0; i < _hosts.length; i++) {
        if (_hosts[i].group == groupName) {
          _hosts[i] = _hosts[i].copyWith(group: 'Default');
        }
      }

      if (_selectedGroupFilter == groupName) {
        _selectedGroupFilter = null;
      }

      _persist();
    }
  }

  int getGroupHostCount(String groupName) {
    return _hosts.where((h) => h.group == groupName).length;
  }

  // ==================== Snippet CRUD ====================
  void addSnippet(SnippetModel snippet) {
    _snippets.insert(0, snippet);
    _persist();
  }

  void updateSnippet(SnippetModel snippet) {
    final idx = _snippets.indexWhere((s) => s.id == snippet.id);
    if (idx != -1) {
      _snippets[idx] = snippet;
      _persist();
    }
  }

  void deleteSnippet(String id) {
    _snippets.removeWhere((s) => s.id == id);
    _persist();
  }

  void runSnippetInActiveSession(SnippetModel snippet) {
    if (activeSession != null) {
      SSHService.sendInput(activeSession!, snippet.command);
      _currentNavIndex = 1; // jump to terminal
      notifyListeners();
    }
  }

  // ==================== Key CRUD ====================
  void addKey(SSHKeyModel key) {
    _keys.insert(0, key);
    _persist();
  }

  void deleteKey(String id) {
    _keys.removeWhere((k) => k.id == id);
    _persist();
  }

  SSHKeyModel generateNewKey({
    required String name,
    required String keyType,
    String comment = 'termius-client',
  }) {
    final rand = Random.secure();
    final randomBytes = List<int>.generate(32, (_) => rand.nextInt(256));
    final base64Key = base64Encode(randomBytes);
    final fingerprint =
        'SHA256:${base64Encode(randomBytes.sublist(0, 16)).replaceAll('=', '')}';

    String pubKey = '';
    String privKey = '';

    if (keyType == 'Ed25519') {
      pubKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI$base64Key $comment';
      privKey =
          '-----BEGIN OPENSSH PRIVATE KEY-----\nb3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW\nQyNTUxOQAAAC$base64Key==\n-----END OPENSSH PRIVATE KEY-----';
    } else {
      pubKey = 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQ$base64Key $comment';
      privKey =
          '-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEA$base64Key\n-----END RSA PRIVATE KEY-----';
    }

    final newKey = SSHKeyModel(
      id: 'key_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      keyType: keyType,
      publicKey: pubKey,
      privateKey: privKey,
      fingerprint: fingerprint,
      createdAt: DateTime.now(),
    );

    addKey(newKey);
    return newKey;
  }

  // ==================== Port Forward CRUD ====================
  void addPortForward(PortForwardModel pf) {
    _portForwards.add(pf);
    _persist();
  }

  void togglePortForward(String id) {
    final idx = _portForwards.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _portForwards[idx] =
          _portForwards[idx].copyWith(isActive: !_portForwards[idx].isActive);
      _persist();
    }
  }

  void deletePortForward(String id) {
    _portForwards.removeWhere((p) => p.id == id);
    _persist();
  }

  // ==================== Settings ====================
  void updateSetting(String key, dynamic value) {
    _settings[key] = value;
    _persist();
  }

  // ==================== JSON File Export & Import ====================
  Future<String> exportJsonString() async {
    final bundle = StorageDataBundle(
      hosts: _hosts,
      groups: _groups,
      keys: _keys,
      snippets: _snippets,
      portForwards: _portForwards,
      settings: _settings,
      lastModified: DateTime.now(),
    );
    return _storageService.exportRawJson(bundle);
  }

  Future<bool> importJsonString(String rawJson) async {
    final bundle = await _storageService.importFromJsonString(rawJson);
    if (bundle != null) {
      _hosts = bundle.hosts;
      _groups = bundle.groups;
      _keys = bundle.keys;
      _snippets = bundle.snippets;
      _portForwards = bundle.portForwards;
      _settings = bundle.settings;
      _lastSaved = bundle.lastModified;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> resetToDefaults() async {
    final defaultBundle = StorageService.createDefaultData();
    _hosts = defaultBundle.hosts;
    _groups = defaultBundle.groups;
    _keys = defaultBundle.keys;
    _snippets = defaultBundle.snippets;
    _portForwards = defaultBundle.portForwards;
    _settings = defaultBundle.settings;
    _lastSaved = defaultBundle.lastModified;
    await _storageService.saveData(defaultBundle);
    notifyListeners();
  }
}
