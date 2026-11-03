import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'file_io.dart';

import '../models/host_model.dart';
import '../models/group_model.dart';
import '../models/ssh_key_model.dart';
import '../models/snippet_model.dart';
import '../models/port_forward_model.dart';

class StorageDataBundle {
  final List<HostModel> hosts;
  final List<GroupModel> groups;
  final List<SSHKeyModel> keys;
  final List<SnippetModel> snippets;
  final List<PortForwardModel> portForwards;
  final Map<String, dynamic> settings;
  final DateTime lastModified;

  StorageDataBundle({
    required this.hosts,
    required this.groups,
    required this.keys,
    required this.snippets,
    required this.portForwards,
    required this.settings,
    required this.lastModified,
  });

  Map<String, dynamic> toJson() {
    return {
      'version': '1.0.0',
      'appName': 'Phoenix Term',
      'lastModified': lastModified.toIso8601String(),
      'settings': settings,
      'groups': groups.map((g) => g.toJson()).toList(),
      'hosts': hosts.map((h) => h.toJson()).toList(),
      'keys': keys.map((k) => k.toJson()).toList(),
      'snippets': snippets.map((s) => s.toJson()).toList(),
      'portForwards': portForwards.map((p) => p.toJson()).toList(),
    };
  }

  factory StorageDataBundle.fromJson(Map<String, dynamic> json) {
    return StorageDataBundle(
      hosts: (json['hosts'] as List<dynamic>?)
              ?.map((item) => HostModel.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      groups: (json['groups'] as List<dynamic>?)
              ?.map((item) => GroupModel.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      keys: (json['keys'] as List<dynamic>?)
              ?.map((item) => SSHKeyModel.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      snippets: (json['snippets'] as List<dynamic>?)
              ?.map((item) => SnippetModel.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      portForwards: (json['portForwards'] as List<dynamic>?)
              ?.map((item) =>
                  PortForwardModel.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      settings: (json['settings'] as Map<String, dynamic>?) ?? {},
      lastModified: json['lastModified'] != null
          ? DateTime.tryParse(json['lastModified'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class StorageService {
  static const String _prefKey = 'termius_data_json_backup';
  static const String fileName = 'termius_data.json';

  String? _cachedFilePath;

  String? get currentFilePath => _cachedFilePath;

  /// Returns the absolute path where termius_data.json is stored (executable directory on desktop)
  Future<String> getJsonFilePath() async {
    if (_cachedFilePath != null) return _cachedFilePath!;

    if (kIsWeb) {
      _cachedFilePath = 'Browser LocalStorage ($fileName)';
      return _cachedFilePath!;
    }

    try {
      _cachedFilePath = await getExecutableStoragePath(fileName);
      return _cachedFilePath!;
    } catch (e) {
      debugPrint('Error getting executable directory: $e');
      _cachedFilePath = fileName;
      return fileName;
    }
  }

  // Known legacy sample/seed IDs to automatically purge from storage if encountered
  static const Set<String> _seedGroupIds = {
    'group_cloud',
    'group_aws',
    'group_homelab',
    'group_db',
  };

  static const Set<String> _seedHostIds = {
    'host_ubuntu_demo',
    'host_aws_ec2',
    'host_rpi5',
    'host_postgres',
    'host_local_dev',
  };

  static const Set<String> _seedKeyIds = {
    'key_prod',
    'key_homelab',
  };

  static const Set<String> _seedSnippetIds = {
    'snip_docker_ps',
    'snip_htop',
    'snip_disk_usage',
    'snip_listening_ports',
    'snip_nginx_reload',
    'snip_tail_logs',
    'snip_sys_info',
  };

  static const Set<String> _seedPortForwardIds = {
    'pf_postgres',
    'pf_redis',
  };

  /// Sanitizes a bundle by removing all legacy sample seed data items if present.
  /// Returns a new sanitized [StorageDataBundle] if any items were purged, or null if already clean.
  static StorageDataBundle? sanitize(StorageDataBundle bundle) {
    bool changed = false;

    final sanitizedHosts = bundle.hosts.where((h) {
      if (_seedHostIds.contains(h.id)) {
        changed = true;
        return false;
      }
      return true;
    }).toList();

    final sanitizedGroups = bundle.groups.where((g) {
      if (_seedGroupIds.contains(g.id)) {
        changed = true;
        return false;
      }
      return true;
    }).toList();

    final sanitizedKeys = bundle.keys.where((k) {
      if (_seedKeyIds.contains(k.id)) {
        changed = true;
        return false;
      }
      return true;
    }).toList();

    final sanitizedSnippets = bundle.snippets.where((s) {
      if (_seedSnippetIds.contains(s.id)) {
        changed = true;
        return false;
      }
      return true;
    }).toList();

    final sanitizedPortForwards = bundle.portForwards.where((pf) {
      if (_seedPortForwardIds.contains(pf.id)) {
        changed = true;
        return false;
      }
      return true;
    }).toList();

    if (!changed) return null;

    return StorageDataBundle(
      hosts: sanitizedHosts,
      groups: sanitizedGroups,
      keys: sanitizedKeys,
      snippets: sanitizedSnippets,
      portForwards: sanitizedPortForwards,
      settings: bundle.settings,
      lastModified: DateTime.now(),
    );
  }

  /// Load data from termius_data.json or fallback to clean initial state
  Future<StorageDataBundle> loadData() async {
    try {
      String? jsonString;

      if (!kIsWeb) {
        final filePath = await getJsonFilePath();
        jsonString = await readTextFile(filePath);

        if (jsonString != null && jsonString.isNotEmpty) {
          debugPrint('Loaded term data from JSON file: $filePath');
        }
      }

      // Check SharedPreferences if not on disk or on web
      if (jsonString == null || jsonString.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        jsonString = prefs.getString(_prefKey);
      }

      if (jsonString != null && jsonString.isNotEmpty) {
        final decoded = json.decode(jsonString) as Map<String, dynamic>;
        var bundle = StorageDataBundle.fromJson(decoded);

        // Sanitize out any legacy default seeding data
        final cleanedBundle = sanitize(bundle);
        if (cleanedBundle != null) {
          debugPrint('Purged legacy seed data from storage');
          bundle = cleanedBundle;
          await saveData(bundle);
        }

        return bundle;
      }
    } catch (e, stack) {
      debugPrint('Error loading JSON data: $e\n$stack');
    }

    // If nothing found or error, create clean default data and save to file immediately
    final defaultBundle = createDefaultData();
    await saveData(defaultBundle);
    return defaultBundle;
  }

  /// Save data to termius_data.json and sync to preferences
  Future<bool> saveData(StorageDataBundle bundle) async {
    try {
      final encoder = const JsonEncoder.withIndent('  ');
      final jsonString = encoder.convert(bundle.toJson());

      // Save to SharedPreferences as backup & for Web
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonString);

      // Save to physical JSON file on native platforms (Linux, macOS, Windows, Android, iOS)
      if (!kIsWeb) {
        final filePath = await getJsonFilePath();
        await writeTextFile(filePath, jsonString);
        debugPrint('Successfully saved data to JSON file: $filePath');
      }

      return true;
    } catch (e, stack) {
      debugPrint('Error saving JSON data: $e\n$stack');
      return false;
    }
  }

  /// Get the raw formatted JSON string for export or viewing
  Future<String> exportRawJson(StorageDataBundle bundle) async {
    final encoder = const JsonEncoder.withIndent('  ');
    return encoder.convert(bundle.toJson());
  }

  /// Import from a raw JSON string
  Future<StorageDataBundle?> importFromJsonString(String rawJson) async {
    try {
      final decoded = json.decode(rawJson) as Map<String, dynamic>;
      final bundle = StorageDataBundle.fromJson(decoded);
      await saveData(bundle);
      return bundle;
    } catch (e) {
      debugPrint('Import error: $e');
      return null;
    }
  }

  /// Default clean empty data for a fresh start (no sample seed data)
  static StorageDataBundle createDefaultData() {
    final now = DateTime.now();

    final settings = {
      'theme': 'Termius Obsidian Dark',
      'fontFamily': 'JetBrains Mono',
      'fontSize': 14.0,
      'cursorBlink': true,
      'cursorStyle': 'block', // 'block', 'underline', 'bar'
      'soundBell': false,
      'autoSave': true,
    };

    return StorageDataBundle(
      hosts: [],
      groups: [],
      keys: [],
      snippets: [],
      portForwards: [],
      settings: settings,
      lastModified: now,
    );
  }
}
