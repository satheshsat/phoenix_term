import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dartssh2/dartssh2.dart';

import '../models/host_model.dart';
import '../models/terminal_session_model.dart';
import '../providers/app_provider.dart';
import '../services/sftp_service.dart';
import '../theme/app_theme.dart';

class SftpScreen extends StatefulWidget {
  const SftpScreen({super.key});

  @override
  State<SftpScreen> createState() => _SftpScreenState();
}

class _SftpScreenState extends State<SftpScreen> {
  HostModel? _selectedHost;
  SftpClient? _sftpClient;

  String _currentPath = '/';
  List<SftpItem> _items = [];

  bool _isConnecting = false;
  bool _isConnected = false;
  bool _isLoadingDirectory = false;
  bool _isSimulated = false;
  String? _errorMessage;

  String _searchQuery = '';
  bool _showHiddenFiles = true;

  final TextEditingController _pathController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final target = provider.sftpSelectedHost ??
          (provider.hosts.isNotEmpty ? provider.hosts.first : null);
      if (target != null) {
        _selectAndConnectHost(target);
      }
    });
  }

  @override
  void dispose() {
    _pathController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _selectAndConnectHost(HostModel host) async {
    setState(() {
      _selectedHost = host;
      _isConnecting = true;
      _isConnected = false;
      _errorMessage = null;
      _items = [];
    });

    final provider = Provider.of<AppProvider>(context, listen: false);

    // Look for an existing terminal session for this host
    TerminalSessionModel? existingSession;
    for (final s in provider.sessions) {
      if (s.host?.id == host.id) {
        existingSession = s;
        break;
      }
    }

    final bool forceSim =
        kIsWeb || (existingSession != null && existingSession.isSimulated);

    try {
      if (forceSim) {
        setState(() {
          _isSimulated = true;
          _isConnected = true;
          _isConnecting = false;
        });
        final initDir = await SftpService.getInitialDirectory(
          host: host,
          isSimulated: true,
        );
        _navigateTo(initDir);
      } else {
        final sftp = await SftpService.getClient(
          host: host,
          availableKeys: provider.keys,
          existingClient: existingSession?.client,
        );

        final initDir = await SftpService.getInitialDirectory(
          sftp: sftp,
          host: host,
          isSimulated: false,
        );

        if (mounted) {
          setState(() {
            _sftpClient = sftp;
            _isConnected = true;
            _isConnecting = false;
            _isSimulated = false;
          });
          _navigateTo(initDir);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _isConnected = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _loadDirectory() async {
    if (_selectedHost == null || (!_isConnected && !_isSimulated)) return;
    setState(() => _isLoadingDirectory = true);

    try {
      final items = await SftpService.listDirectory(
        sftp: _sftpClient,
        remotePath: _currentPath,
        isSimulated: _isSimulated,
      );

      if (mounted) {
        setState(() {
          _items = items;
          _isLoadingDirectory = false;
          _pathController.text = _currentPath;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDirectory = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to read directory: $e'),
            backgroundColor: AppColors.rose,
          ),
        );
      }
    }
  }

  void _navigateTo(String path) {
    String cleanPath = path.trim();
    if (cleanPath.isEmpty) cleanPath = '/';
    if (!cleanPath.startsWith('/')) cleanPath = '/$cleanPath';
    if (cleanPath.length > 1 && cleanPath.endsWith('/')) {
      cleanPath = cleanPath.substring(0, cleanPath.length - 1);
    }

    setState(() {
      _currentPath = cleanPath;
      _pathController.text = cleanPath;
    });
    _loadDirectory();
  }

  void _navigateUp() {
    if (_currentPath == '/' || _currentPath.isEmpty) return;
    final lastSlash = _currentPath.lastIndexOf('/');
    if (lastSlash <= 0) {
      _navigateTo('/');
    } else {
      _navigateTo(_currentPath.substring(0, lastSlash));
    }
  }

  void _navigateHome() async {
    if (_selectedHost == null) return;
    final home = await SftpService.getInitialDirectory(
      sftp: _sftpClient,
      host: _selectedHost!,
      isSimulated: _isSimulated,
    );
    _navigateTo(home);
  }

  // ==================== File Operations ====================

  Future<void> _uploadFiles() async {
    try {
      final List<PlatformFile> files = await FilePicker.pickFiles();

      if (files.isEmpty) return;

      int uploaded = 0;
      for (final file in files) {
        final Uint8List bytes = await file.xFile.readAsBytes();

        final remoteFile = _currentPath == '/'
            ? '/${file.name}'
            : '$_currentPath/${file.name}';

        await SftpService.writeFile(
          sftp: _sftpClient,
          remotePath: remoteFile,
          bytes: bytes,
          isSimulated: _isSimulated,
        );
        uploaded++;
      }

      _loadDirectory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploaded $uploaded file(s) successfully!'),
            backgroundColor: AppColors.emerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppColors.rose,
          ),
        );
      }
    }
  }

  Future<void> _downloadFile(SftpItem item) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fetching "${item.name}"...')),
      );

      final bytes = await SftpService.readFile(
        sftp: _sftpClient,
        remotePath: item.path,
        isSimulated: _isSimulated,
      );

      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Save ${item.name}',
        fileName: item.name,
        bytes: bytes,
      );

      if (savedPath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded "${item.name}" successfully!'),
            backgroundColor: AppColors.emerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: AppColors.rose,
          ),
        );
      }
    }
  }

  void _showCreateDirectoryDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Row(
            children: [
              Icon(Icons.create_new_folder, color: AppColors.amber, size: 20),
              SizedBox(width: 10),
              Text('Create New Folder'),
            ],
          ),
          content: TextField(
            controller: nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Folder Name',
              hintText: 'e.g. my-app',
              prefixIcon: Icon(Icons.folder_outlined),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.cyan, foregroundColor: Colors.black),
              onPressed: () async {
                final folderName = nameCtrl.text.trim();
                if (folderName.isEmpty) return;
                Navigator.pop(ctx);

                final dirPath = _currentPath == '/'
                    ? '/$folderName'
                    : '$_currentPath/$folderName';

                try {
                  await SftpService.createDirectory(
                    sftp: _sftpClient,
                    path: dirPath,
                    isSimulated: _isSimulated,
                  );
                  _loadDirectory();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Created folder "$folderName"'),
                        backgroundColor: AppColors.emerald,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Create folder error: $e'),
                        backgroundColor: AppColors.rose,
                      ),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _showCreateFileDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Row(
            children: [
              Icon(Icons.note_add, color: AppColors.cyan, size: 20),
              SizedBox(width: 10),
              Text('Create New File'),
            ],
          ),
          content: TextField(
            controller: nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'File Name',
              hintText: 'e.g. script.sh, server.conf',
              prefixIcon: Icon(Icons.description_outlined),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.cyan, foregroundColor: Colors.black),
              onPressed: () async {
                final fileName = nameCtrl.text.trim();
                if (fileName.isEmpty) return;
                Navigator.pop(ctx);

                final filePath = _currentPath == '/'
                    ? '/$fileName'
                    : '$_currentPath/$fileName';

                try {
                  await SftpService.writeFile(
                    sftp: _sftpClient,
                    remotePath: filePath,
                    bytes: Uint8List(0),
                    isSimulated: _isSimulated,
                  );
                  _loadDirectory();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Created empty file "$fileName"'),
                        backgroundColor: AppColors.emerald,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Create file error: $e'),
                        backgroundColor: AppColors.rose,
                      ),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _showRenameDialog(SftpItem item) {
    final nameCtrl = TextEditingController(text: item.name);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Rename Item'),
          content: TextField(
            controller: nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'New Name',
              prefixIcon: Icon(Icons.edit_outlined),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.cyan, foregroundColor: Colors.black),
              onPressed: () async {
                final newName = nameCtrl.text.trim();
                if (newName.isEmpty || newName == item.name) return;
                Navigator.pop(ctx);

                final parent = item.path.substring(0, item.path.lastIndexOf('/'));
                final newPath = parent.isEmpty || parent == '/'
                    ? '/$newName'
                    : '$parent/$newName';

                try {
                  await SftpService.rename(
                    sftp: _sftpClient,
                    oldPath: item.path,
                    newPath: newPath,
                    isSimulated: _isSimulated,
                  );
                  _loadDirectory();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Renamed to "$newName"'),
                        backgroundColor: AppColors.emerald,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Rename error: $e'),
                        backgroundColor: AppColors.rose,
                      ),
                    );
                  }
                }
              },
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(SftpItem item) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.rose),
              const SizedBox(width: 8),
              Text('Delete ${item.isDirectory ? "Folder" : "File"}?'),
            ],
          ),
          content: Text(
            'Are you sure you want to delete "${item.name}"?\n${item.isDirectory ? "All contents inside this folder will be deleted." : "This action cannot be undone."}',
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.rose),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await SftpService.deleteItem(
                    sftp: _sftpClient,
                    item: item,
                    isSimulated: _isSimulated,
                  );
                  _loadDirectory();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Deleted "${item.name}"'),
                        backgroundColor: AppColors.emerald,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Delete error: $e'),
                        backgroundColor: AppColors.rose,
                      ),
                    );
                  }
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _openFileViewer(SftpItem item) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final bytes = await SftpService.readFile(
        sftp: _sftpClient,
        remotePath: item.path,
        isSimulated: _isSimulated,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      String textContent;
      bool isBinary = false;
      try {
        textContent = utf8.decode(bytes);
      } catch (_) {
        isBinary = true;
        textContent = '';
      }

      final editorCtrl = TextEditingController(text: textContent);

      showDialog(
        context: context,
        builder: (ctx) {
          return Dialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              width: 780,
              height: 560,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _getFileIcon(item),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${item.path} · ${item.formattedSize}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.download, size: 20, color: AppColors.cyan),
                        tooltip: 'Download File',
                        onPressed: () {
                          Navigator.pop(ctx);
                          _downloadFile(item);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: isBinary
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const FaIcon(FontAwesomeIcons.file, size: 48, color: AppColors.textMuted),
                                const SizedBox(height: 16),
                                const Text('Binary file cannot be viewed in text editor.'),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _downloadFile(item);
                                  },
                                  icon: const Icon(Icons.download),
                                  label: const Text('Download to View'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.cyan,
                                    foregroundColor: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: TextField(
                              controller: editorCtrl,
                              maxLines: null,
                              expands: true,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                height: 1.4,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                  ),
                  if (!isBinary) ...[
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final newText = editorCtrl.text;
                            final newBytes = Uint8List.fromList(utf8.encode(newText));
                            Navigator.pop(ctx);
                            try {
                              await SftpService.writeFile(
                                sftp: _sftpClient,
                                remotePath: item.path,
                                bytes: newBytes,
                                isSimulated: _isSimulated,
                              );
                              _loadDirectory();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Saved "${item.name}" successfully!'),
                                    backgroundColor: AppColors.emerald,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Save error: $e'),
                                    backgroundColor: AppColors.rose,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.save, size: 16),
                          label: const Text('Save Changes'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.emerald,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to read file: $e'),
            backgroundColor: AppColors.rose,
          ),
        );
      }
    }
  }

  Widget _getFileIcon(SftpItem item) {
    if (item.isDirectory) {
      return const FaIcon(FontAwesomeIcons.folder, color: AppColors.amber, size: 18);
    }
    switch (item.extension) {
      case 'sh':
      case 'bash':
      case 'zsh':
        return const FaIcon(FontAwesomeIcons.terminal, color: AppColors.emerald, size: 18);
      case 'json':
      case 'yaml':
      case 'yml':
      case 'xml':
      case 'conf':
      case 'config':
      case 'env':
      case 'ini':
        return const Icon(Icons.settings, color: AppColors.purple, size: 18);
      case 'js':
      case 'ts':
      case 'py':
      case 'dart':
      case 'html':
      case 'css':
      case 'c':
      case 'cpp':
      case 'go':
      case 'rs':
        return const FaIcon(FontAwesomeIcons.code, color: AppColors.cyan, size: 18);
      case 'zip':
      case 'tar':
      case 'gz':
      case '7z':
      case 'rar':
        return const Icon(Icons.folder_zip, color: AppColors.rose, size: 18);
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'svg':
      case 'ico':
        return const Icon(Icons.image, color: AppColors.cyan, size: 18);
      case 'key':
      case 'pem':
      case 'pub':
      case 'crt':
        return const FaIcon(FontAwesomeIcons.key, color: AppColors.amber, size: 18);
      case 'log':
      case 'txt':
      case 'md':
        return const Icon(Icons.description, color: AppColors.blue, size: 18);
      default:
        return const FaIcon(FontAwesomeIcons.file, color: AppColors.textSecondary, size: 18);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final hosts = provider.hosts;

    // React if sftpSelectedHost was requested from HostsScreen
    if (provider.sftpSelectedHost != null &&
        provider.sftpSelectedHost?.id != _selectedHost?.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _selectAndConnectHost(provider.sftpSelectedHost!);
      });
    }

    final filteredItems = _items.where((it) {
      if (!_showHiddenFiles && it.name.startsWith('.')) return false;
      if (_searchQuery.isNotEmpty &&
          !it.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Top Bar with Host Selector, Status Badge, & Actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                const FaIcon(FontAwesomeIcons.folderOpen, color: AppColors.purple, size: 20),
                const SizedBox(width: 10),
                const Text(
                  'SFTP File Manager',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),

                // Host Selector Dropdown
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedHost?.id,
                      dropdownColor: AppColors.surface,
                      hint: const Text('Select Host'),
                      items: hosts.map((h) {
                        return DropdownMenuItem(
                          value: h.id,
                          child: Text('${h.alias} (${h.hostname})'),
                        );
                      }).toList(),
                      onChanged: (hostId) {
                        final found = hosts.firstWhere((h) => h.id == hostId);
                        _selectAndConnectHost(found);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Status Badge
                if (_isConnecting)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.cyan.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyan),
                        ),
                        SizedBox(width: 6),
                        Text('Connecting...', style: TextStyle(fontSize: 12, color: AppColors.cyan)),
                      ],
                    ),
                  )
                else if (_isConnected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.emerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.emerald.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, size: 13, color: AppColors.emerald),
                        const SizedBox(width: 5),
                        Text(
                          _isSimulated ? 'Simulated' : 'Connected',
                          style: const TextStyle(fontSize: 12, color: AppColors.emerald, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
                else if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.rose.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.rose.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 13, color: AppColors.rose),
                        SizedBox(width: 5),
                        Text('Disconnected', style: TextStyle(fontSize: 12, color: AppColors.rose)),
                      ],
                    ),
                  ),

                const Spacer(),

                // Action Buttons
                OutlinedButton.icon(
                  onPressed: (_isConnected || _isSimulated) ? _showCreateDirectoryDialog : null,
                  icon: const Icon(Icons.create_new_folder, size: 16),
                  label: const Text('New Folder'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: (_isConnected || _isSimulated) ? _showCreateFileDialog : null,
                  icon: const Icon(Icons.note_add, size: 16),
                  label: const Text('New File'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: (_isConnected || _isSimulated) ? _uploadFiles : null,
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: const Text('Upload'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cyan,
                    foregroundColor: Colors.black,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Refresh Directory',
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: (_isConnected || _isSimulated) ? _loadDirectory : null,
                ),
              ],
            ),
          ),

          // Path Navigation & Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.sidebar,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Parent Directory (..)',
                  icon: const Icon(Icons.arrow_upward, size: 18, color: AppColors.cyan),
                  onPressed: _currentPath == '/' ? null : _navigateUp,
                ),
                IconButton(
                  tooltip: 'Home Directory (~)',
                  icon: const Icon(Icons.home, size: 18, color: AppColors.cyan),
                  onPressed: (_isConnected || _isSimulated) ? _navigateHome : null,
                ),
                const SizedBox(width: 8),

                // Path Input Field (Editable & Navigable)
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        const FaIcon(FontAwesomeIcons.folder, size: 13, color: AppColors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _pathController,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onSubmitted: (val) => _navigateTo(val),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward, size: 16, color: AppColors.cyan),
                          tooltip: 'Go to Path',
                          onPressed: () => _navigateTo(_pathController.text),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Filter / Search Field
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: 'Filter files...',
                              hintStyle: TextStyle(fontSize: 12, color: AppColors.textMuted),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (val) {
                              setState(() => _searchQuery = val);
                            },
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: const Icon(Icons.clear, size: 14, color: AppColors.textMuted),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Hidden Files Toggle
                IconButton(
                  tooltip: _showHiddenFiles ? 'Hide Dotfiles' : 'Show Dotfiles',
                  icon: Icon(
                    _showHiddenFiles ? Icons.visibility : Icons.visibility_off,
                    size: 18,
                    color: _showHiddenFiles ? AppColors.cyan : AppColors.textMuted,
                  ),
                  onPressed: () {
                    setState(() => _showHiddenFiles = !_showHiddenFiles);
                  },
                ),
              ],
            ),
          ),

          // Main Content View
          Expanded(
            child: _selectedHost == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FaIcon(FontAwesomeIcons.server, size: 40, color: AppColors.textMuted),
                        SizedBox(height: 14),
                        Text('No Host Selected', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(height: 6),
                        Text('Select or add a host above to browse remote SFTP files.', style: TextStyle(color: AppColors.textMuted)),
                      ],
                    ),
                  )
                : _isConnecting
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Connecting to host via SSH/SFTP...', style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 500),
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.rose.withValues(alpha: 0.4)),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error_outline, size: 48, color: AppColors.rose),
                                  const SizedBox(height: 16),
                                  const Text('SFTP Connection Failed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () => _selectAndConnectHost(_selectedHost!),
                                        icon: const Icon(Icons.refresh, size: 16),
                                        label: const Text('Retry Connection'),
                                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.cyan, foregroundColor: Colors.black),
                                      ),
                                      const SizedBox(width: 12),
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _isSimulated = true;
                                            _isConnected = true;
                                            _errorMessage = null;
                                          });
                                          _navigateTo('/home/${_selectedHost?.username ?? "user"}');
                                        },
                                        icon: const Icon(Icons.science, size: 16),
                                        label: const Text('Use Simulation'),
                                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.purple),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _isLoadingDirectory
                            ? const Center(child: CircularProgressIndicator())
                            : filteredItems.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const FaIcon(FontAwesomeIcons.folderOpen, size: 42, color: AppColors.textMuted),
                                        const SizedBox(height: 14),
                                        Text(
                                          _searchQuery.isNotEmpty ? 'No matching files found' : 'Folder is empty',
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _searchQuery.isNotEmpty
                                              ? 'Try a different filter query'
                                              : 'Upload files or create a new folder above.',
                                          style: const TextStyle(color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: filteredItems.length,
                                    separatorBuilder: (ctx, i) => const Divider(height: 1, color: AppColors.border),
                                    itemBuilder: (context, index) {
                                      final item = filteredItems[index];
                                      return ListTile(
                                        leading: _getFileIcon(item),
                                        title: Text(
                                          item.name,
                                          style: TextStyle(
                                            fontWeight: item.isDirectory ? FontWeight.bold : FontWeight.normal,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${item.permissions} · ${DateFormat('MMM d, yyyy HH:mm').format(item.modifiedTime)}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              item.formattedSize,
                                              style: const TextStyle(
                                                fontFamily: 'monospace',
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(width: 8),

                                            // Quick download icon for files
                                            if (!item.isDirectory)
                                              IconButton(
                                                icon: const Icon(Icons.download, size: 18, color: AppColors.cyan),
                                                tooltip: 'Download',
                                                onPressed: () => _downloadFile(item),
                                              ),

                                            // Popup options menu
                                            PopupMenuButton<String>(
                                              icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
                                              color: AppColors.surface,
                                              onSelected: (val) {
                                                switch (val) {
                                                  case 'open':
                                                    if (item.isDirectory) {
                                                      _navigateTo(item.path);
                                                    } else {
                                                      _openFileViewer(item);
                                                    }
                                                    break;
                                                  case 'download':
                                                    _downloadFile(item);
                                                    break;
                                                  case 'rename':
                                                    _showRenameDialog(item);
                                                    break;
                                                  case 'delete':
                                                    _confirmDelete(item);
                                                    break;
                                                }
                                              },
                                              itemBuilder: (ctx) => [
                                                PopupMenuItem(
                                                  value: 'open',
                                                  child: Row(
                                                    children: [
                                                      Icon(item.isDirectory ? Icons.folder_open : Icons.edit, size: 16),
                                                      const SizedBox(width: 8),
                                                      Text(item.isDirectory ? 'Open Folder' : 'View / Edit'),
                                                    ],
                                                  ),
                                                ),
                                                if (!item.isDirectory)
                                                  const PopupMenuItem(
                                                    value: 'download',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.download, size: 16),
                                                        const SizedBox(width: 8),
                                                        Text('Download File'),
                                                      ],
                                                    ),
                                                  ),
                                                const PopupMenuItem(
                                                  value: 'rename',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.drive_file_rename_outline, size: 16),
                                                      const SizedBox(width: 8),
                                                      Text('Rename'),
                                                    ],
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'delete',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.delete_outline, color: AppColors.rose, size: 16),
                                                      const SizedBox(width: 8),
                                                      Text('Delete', style: TextStyle(color: AppColors.rose)),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        onTap: () {
                                          if (item.isDirectory) {
                                            _navigateTo(item.path);
                                          } else {
                                            _openFileViewer(item);
                                          }
                                        },
                                      );
                                    },
                                  ),
          ),

          // Status & Info Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Text(
                  '${filteredItems.length} item(s) (${filteredItems.where((i) => i.isDirectory).length} folders, ${filteredItems.where((i) => !i.isDirectory).length} files)',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const Spacer(),
                if (_selectedHost != null)
                  Text(
                    'Target: ${_selectedHost!.username}@${_selectedHost!.hostname}:${_selectedHost!.port}',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
