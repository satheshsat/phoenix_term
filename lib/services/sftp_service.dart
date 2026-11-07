import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:dartssh2/dartssh2.dart';

import '../models/host_model.dart';
import '../models/ssh_key_model.dart';

class SftpItem {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime modifiedTime;
  final String permissions;

  SftpItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.modifiedTime,
    required this.permissions,
  });

  String get formattedSize {
    if (isDirectory) return '--';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get extension {
    if (isDirectory) return '';
    final dot = name.lastIndexOf('.');
    if (dot != -1 && dot < name.length - 1) {
      return name.substring(dot + 1).toLowerCase();
    }
    return '';
  }
}

class SimulatedFileEntry {
  String path;
  String name;
  bool isDirectory;
  int size;
  DateTime modifiedTime;
  String permissions;
  Uint8List content;

  SimulatedFileEntry({
    required this.path,
    required this.name,
    required this.isDirectory,
    required this.size,
    required this.modifiedTime,
    required this.permissions,
    required this.content,
  });
}

class SftpService {
  static final Map<String, SSHClient> _clientCache = {};
  static final Map<String, SftpClient> _sftpCache = {};

  // Simulated Virtual Filesystem for offline/demo/mock hosts
  static final Map<String, SimulatedFileEntry> _virtualFs = {};
  static bool _virtualFsInitialized = false;

  static void _ensureVirtualFs() {
    if (_virtualFsInitialized) return;
    _virtualFsInitialized = true;
    final now = DateTime.now();

    void addDir(String p) {
      final n = p == '/' ? '/' : p.split('/').last;
      _virtualFs[p] = SimulatedFileEntry(
        path: p,
        name: n,
        isDirectory: true,
        size: 4096,
        modifiedTime: now,
        permissions: 'rwxr-xr-x',
        content: Uint8List(0),
      );
    }

    void addFile(String p, String text, {String perms = 'rw-r--r--'}) {
      final n = p.split('/').last;
      final bytes = Uint8List.fromList(utf8.encode(text));
      _virtualFs[p] = SimulatedFileEntry(
        path: p,
        name: n,
        isDirectory: false,
        size: bytes.length,
        modifiedTime: now,
        permissions: perms,
        content: bytes,
      );
    }

    // Standard directories
    addDir('/');
    addDir('/bin');
    addDir('/etc');
    addDir('/etc/nginx');
    addDir('/home');
    addDir('/home/user');
    addDir('/home/user/.ssh');
    addDir('/home/user/app');
    addDir('/home/user/logs');
    addDir('/var');
    addDir('/var/log');
    addDir('/usr');
    addDir('/opt');

    // Sample files
    addFile(
      '/home/user/app/docker-compose.yml',
      '''version: '3.8'
services:
  app:
    image: node:20-alpine
    restart: always
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
  redis:
    image: redis:7-alpine
    restart: always
''',
    );

    addFile(
      '/home/user/app/package.json',
      '''{
  "name": "phoenix-backend",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  }
}''',
    );

    addFile(
      '/home/user/app/production.env',
      '''PORT=3000
DATABASE_URL=postgres://user:password@localhost:5432/phoenix
JWT_SECRET=supersecretkey123
''',
      perms: 'rw-------',
    );

    addFile(
      '/home/user/deploy.sh',
      '''#!/usr/bin/env bash
set -e
echo "Starting Phoenix Deployment..."
git pull origin main
docker compose up -d --build
echo "Deployment completed successfully!"
''',
      perms: 'rwxr-xr-x',
    );

    addFile(
      '/home/user/config.json',
      '''{
  "server": "phoenix.term",
  "debug": false,
  "maxConnections": 50,
  "timeout": 30
}''',
    );

    addFile(
      '/home/user/.bashrc',
      '''# ~/.bashrc
export PATH=\$PATH:/usr/local/bin
alias ll='ls -la'
alias phoenix='echo "Phoenix Terminal Ready"'
''',
    );

    addFile(
      '/etc/nginx/nginx.conf',
      '''events {
    worker_connections 1024;
}
http {
    server {
        listen 80;
        server_name localhost;
        location / {
            proxy_pass http://127.0.0.1:3000;
        }
    }
}''',
    );
  }

  /// Get or create an authenticated SFTP client for the given host
  static Future<SftpClient> getClient({
    required HostModel host,
    List<SSHKeyModel> availableKeys = const [],
    SSHClient? existingClient,
  }) async {
    // 1. If an existing live SSH client was passed in (e.g. from an active terminal session)
    if (existingClient != null && !existingClient.isClosed) {
      if (_sftpCache.containsKey(host.id)) {
        return _sftpCache[host.id]!;
      }
      final sftp = await existingClient.sftp();
      _sftpCache[host.id] = sftp;
      return sftp;
    }

    // 2. Check if we already have an active cached SFTP client
    if (_sftpCache.containsKey(host.id)) {
      return _sftpCache[host.id]!;
    }

    // 3. Establish TCP Socket connection
    final socket = await SSHSocket.connect(
      host.hostname,
      host.port,
      timeout: const Duration(seconds: 10),
    );

    // Prepare identities / keys if assigned
    List<SSHKeyPair> identities = [];
    if (host.keyId != null) {
      final keyModel = availableKeys.firstWhere(
        (k) => k.id == host.keyId,
        orElse: () => SSHKeyModel(
          id: '',
          name: '',
          publicKey: '',
          privateKey: '',
          createdAt: DateTime.now(),
        ),
      );

      if (keyModel.privateKey.isNotEmpty) {
        try {
          final parsed = SSHKeyPair.fromPem(
            keyModel.privateKey,
            host.passphrase.isNotEmpty ? host.passphrase : null,
          );
          identities.addAll(parsed);
        } catch (e) {
          debugPrint('Failed to parse key for SFTP: $e');
        }
      }
    }

    final client = SSHClient(
      socket,
      username: host.username,
      onPasswordRequest: () => host.password,
      identities: identities.isNotEmpty ? identities : null,
    );

    await client.authenticated;
    _clientCache[host.id] = client;

    final sftp = await client.sftp();
    _sftpCache[host.id] = sftp;
    return sftp;
  }

  /// Determine the default home directory on the remote server
  static Future<String> getInitialDirectory({
    SftpClient? sftp,
    required HostModel host,
    bool isSimulated = false,
  }) async {
    if (!isSimulated && sftp != null) {
      try {
        final abs = await sftp.absolute('.');
        if (abs.isNotEmpty && abs != '.') {
          return abs;
        }
      } catch (_) {}
    }

    if (host.username == 'root') return '/root';
    return '/home/${host.username}';
  }

  /// List remote files and folders at [remotePath]
  static Future<List<SftpItem>> listDirectory({
    SftpClient? sftp,
    required String remotePath,
    bool isSimulated = false,
  }) async {
    if (!isSimulated && sftp != null) {
      final names = await sftp.listdir(remotePath);
      final List<SftpItem> items = [];

      for (final entry in names) {
        if (entry.filename == '.' || entry.filename == '..') continue;
        final isDir = entry.attr.isDirectory;
        final fullPath = remotePath == '/'
            ? '/${entry.filename}'
            : remotePath.endsWith('/')
                ? '$remotePath${entry.filename}'
                : '$remotePath/${entry.filename}';

        items.add(
          SftpItem(
            name: entry.filename,
            path: fullPath,
            isDirectory: isDir,
            size: entry.attr.size ?? 0,
            modifiedTime: entry.attr.modifyTime != null
                ? DateTime.fromMillisecondsSinceEpoch(
                    entry.attr.modifyTime! * 1000)
                : DateTime.now(),
            permissions: isDir ? 'rwxr-xr-x' : 'rw-r--r--',
          ),
        );
      }

      // Sort: directories first, then alphabetical
      items.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      return items;
    }

    // Simulated filesystem logic
    _ensureVirtualFs();
    final normalized = remotePath.endsWith('/') && remotePath.length > 1
        ? remotePath.substring(0, remotePath.length - 1)
        : remotePath;

    final List<SftpItem> items = [];
    for (final entry in _virtualFs.values) {
      if (entry.path == normalized || entry.path == '/') continue;

      final lastSlash = entry.path.lastIndexOf('/');
      final parent = lastSlash <= 0 ? '/' : entry.path.substring(0, lastSlash);

      if (parent == normalized) {
        items.add(
          SftpItem(
            name: entry.name,
            path: entry.path,
            isDirectory: entry.isDirectory,
            size: entry.size,
            modifiedTime: entry.modifiedTime,
            permissions: entry.permissions,
          ),
        );
      }
    }

    items.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return items;
  }

  /// Read the full contents of a file
  static Future<Uint8List> readFile({
    SftpClient? sftp,
    required String remotePath,
    bool isSimulated = false,
  }) async {
    if (!isSimulated && sftp != null) {
      final file = await sftp.open(remotePath, mode: SftpFileOpenMode.read);
      try {
        return await file.readBytes();
      } finally {
        await file.close();
      }
    }

    _ensureVirtualFs();
    final entry = _virtualFs[remotePath];
    if (entry != null && !entry.isDirectory) {
      return entry.content;
    }
    throw Exception('File not found: $remotePath');
  }

  /// Write contents to a file (creates or overwrites)
  static Future<void> writeFile({
    SftpClient? sftp,
    required String remotePath,
    required Uint8List bytes,
    bool isSimulated = false,
  }) async {
    if (!isSimulated && sftp != null) {
      final file = await sftp.open(
        remotePath,
        mode: SftpFileOpenMode.create |
            SftpFileOpenMode.write |
            SftpFileOpenMode.truncate,
      );
      try {
        await file.writeBytes(bytes);
      } finally {
        await file.close();
      }
      return;
    }

    _ensureVirtualFs();
    final name = remotePath.split('/').last;
    _virtualFs[remotePath] = SimulatedFileEntry(
      path: remotePath,
      name: name,
      isDirectory: false,
      size: bytes.length,
      modifiedTime: DateTime.now(),
      permissions: 'rw-r--r--',
      content: bytes,
    );
  }

  /// Create a new directory
  static Future<void> createDirectory({
    SftpClient? sftp,
    required String path,
    bool isSimulated = false,
  }) async {
    if (!isSimulated && sftp != null) {
      await sftp.mkdir(path);
      return;
    }

    _ensureVirtualFs();
    final name = path.split('/').last;
    _virtualFs[path] = SimulatedFileEntry(
      path: path,
      name: name,
      isDirectory: true,
      size: 4096,
      modifiedTime: DateTime.now(),
      permissions: 'rwxr-xr-x',
      content: Uint8List(0),
    );
  }

  /// Delete a file or directory (recursively if folder)
  static Future<void> deleteItem({
    SftpClient? sftp,
    required SftpItem item,
    bool isSimulated = false,
  }) async {
    if (!isSimulated && sftp != null) {
      if (item.isDirectory) {
        await _deleteDirectoryRecursive(sftp, item.path);
      } else {
        await sftp.remove(item.path);
      }
      return;
    }

    _ensureVirtualFs();
    if (item.isDirectory) {
      _virtualFs.removeWhere((p, _) => p == item.path || p.startsWith('${item.path}/'));
    } else {
      _virtualFs.remove(item.path);
    }
  }

  static Future<void> _deleteDirectoryRecursive(
    SftpClient sftp,
    String dirPath,
  ) async {
    try {
      final entries = await sftp.listdir(dirPath);
      for (final entry in entries) {
        if (entry.filename == '.' || entry.filename == '..') continue;
        final childPath = dirPath == '/'
            ? '/${entry.filename}'
            : dirPath.endsWith('/')
                ? '$dirPath${entry.filename}'
                : '$dirPath/${entry.filename}';
        if (entry.attr.isDirectory) {
          await _deleteDirectoryRecursive(sftp, childPath);
        } else {
          await sftp.remove(childPath);
        }
      }
    } catch (_) {}
    await sftp.rmdir(dirPath);
  }

  /// Rename or move a file/directory
  static Future<void> rename({
    SftpClient? sftp,
    required String oldPath,
    required String newPath,
    bool isSimulated = false,
  }) async {
    if (!isSimulated && sftp != null) {
      await sftp.rename(oldPath, newPath);
      return;
    }

    _ensureVirtualFs();
    final item = _virtualFs.remove(oldPath);
    if (item != null) {
      final newName = newPath.split('/').last;
      item.path = newPath;
      item.name = newName;
      _virtualFs[newPath] = item;
    }
  }

  /// Disconnect and release resources for a specific host
  static void disconnect(String hostId) {
    try {
      _sftpCache[hostId]?.close();
    } catch (_) {}
    _sftpCache.remove(hostId);

    try {
      _clientCache[hostId]?.close();
    } catch (_) {}
    _clientCache.remove(hostId);
  }

  /// Disconnect all active SFTP sessions
  static void closeAll() {
    for (final sftp in _sftpCache.values) {
      try {
        sftp.close();
      } catch (_) {}
    }
    _sftpCache.clear();

    for (final client in _clientCache.values) {
      try {
        client.close();
      } catch (_) {}
    }
    _clientCache.clear();
  }
}
