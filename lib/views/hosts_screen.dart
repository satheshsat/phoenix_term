import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../models/host_model.dart';
import '../models/group_model.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class HostsScreen extends StatefulWidget {
  const HostsScreen({super.key});

  @override
  State<HostsScreen> createState() => _HostsScreenState();
}

class _HostsScreenState extends State<HostsScreen> {
  final TextEditingController _quickConnectController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _quickConnectController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final hosts = provider.filteredHosts;
    final groups = provider.groups;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Top Quick Connect & Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Quick connect input
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: TextField(
                          controller: _quickConnectController,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Quick Connect: ssh user@hostname:22 or hostname',
                            hintStyle: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                              fontFamily: 'monospace',
                            ),
                            prefixIcon: Padding(
                              padding: EdgeInsets.all(12),
                              child: FaIcon(
                                FontAwesomeIcons.terminal,
                                size: 14,
                                color: AppColors.cyan,
                              ),
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                          onSubmitted: (value) {
                            if (value.trim().isNotEmpty) {
                              provider.quickConnect(value);
                              _quickConnectController.clear();
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (_quickConnectController.text.trim().isNotEmpty) {
                          provider.quickConnect(_quickConnectController.text);
                          _quickConnectController.clear();
                        }
                      },
                      icon: const Icon(Icons.bolt, size: 18),
                      label: const Text('Connect'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () => _showAddHostDialog(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New Host'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surfaceElevated,
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: AppColors.cyan, width: 1.2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => _showManageGroupsDialog(context, provider),
                      icon: const Icon(Icons.folder_outlined, size: 18, color: AppColors.cyan),
                      label: Text(
                        groups.isEmpty ? 'Groups' : 'Groups (${groups.length})',
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surfaceElevated,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Filter and search controls
                Row(
                  children: [
                    // Search bar
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => provider.setHostSearchQuery(val),
                          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Search hosts by alias, IP, tag, notes...',
                            hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _searchController.clear();
                                      provider.setHostSearchQuery('');
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Group dropdown filter
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
                          value: (provider.selectedGroupFilter != null &&
                                  groups.any((g) => g.name == provider.selectedGroupFilter))
                              ? provider.selectedGroupFilter
                              : 'All',
                          dropdownColor: AppColors.surface,
                          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                          items: [
                            const DropdownMenuItem(value: 'All', child: Text('All Groups')),
                            ...groups.map((g) => DropdownMenuItem(
                                  value: g.name,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _parseColor(g.colorHex),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(g.name),
                                    ],
                                  ),
                                )),
                            const DropdownMenuItem(
                              value: '__manage_groups__',
                              child: Row(
                                children: [
                                  Icon(Icons.tune, size: 14, color: AppColors.cyan),
                                  SizedBox(width: 6),
                                  Text(
                                    'Manage Groups...',
                                    style: TextStyle(
                                      color: AppColors.cyan,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val == '__manage_groups__') {
                              _showManageGroupsDialog(context, provider);
                            } else {
                              provider.setSelectedGroupFilter(val == 'All' ? null : val);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Host list / grid
          Expanded(
            child: hosts.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: hosts.length,
                    itemBuilder: (context, index) {
                      final host = hosts[index];
                      return _buildHostCard(context, host, provider);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostCard(BuildContext context, HostModel host, AppProvider provider) {
    final hostColor = _parseColor(host.colorHex);
    final isOnline = host.status == 'online';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => provider.connectToHost(host),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Server avatar badge
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: hostColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: hostColor.withValues(alpha: 0.5)),
                  ),
                  child: Center(
                    child: FaIcon(
                      FontAwesomeIcons.server,
                      color: hostColor,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Host Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              host.alias,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Online badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isOnline ? AppColors.emerald : AppColors.amber).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: (isOnline ? AppColors.emerald : AppColors.amber).withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isOnline ? AppColors.emerald : AppColors.amber,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isOnline ? 'Online' : 'Standby',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isOnline ? AppColors.emerald : AppColors.amber,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Group chip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              host.group,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Connection target: user@hostname:port
                      Row(
                        children: [
                          const Icon(Icons.link, size: 14, color: AppColors.cyan),
                          const SizedBox(width: 4),
                          Text(
                            '${host.username}@${host.hostname}:${host.port}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (host.keyId != null) ...[
                            const SizedBox(width: 12),
                            const FaIcon(FontAwesomeIcons.key, size: 11, color: AppColors.purple),
                            const SizedBox(width: 4),
                            const Text(
                              'SSH Key',
                              style: TextStyle(fontSize: 11, color: AppColors.purple),
                            ),
                          ],
                        ],
                      ),
                      if (host.tags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: host.tags.map((t) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                '#$t',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.cyan,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      if (host.lastConnectedAt != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Last connected: ${DateFormat('MMM d, yyyy · HH:mm').format(host.lastConnectedAt!)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Action buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Favorite toggle
                    IconButton(
                      icon: Icon(
                        host.isFavorite ? Icons.star : Icons.star_border,
                        color: host.isFavorite ? AppColors.amber : AppColors.textMuted,
                        size: 20,
                      ),
                      onPressed: () => provider.toggleFavoriteHost(host.id),
                    ),
                    const SizedBox(width: 4),
                    // Connect button
                    ElevatedButton.icon(
                      onPressed: () => provider.connectToHost(host),
                      icon: const FaIcon(FontAwesomeIcons.terminal, size: 13),
                      label: const Text('SSH'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // SFTP button
                    OutlinedButton.icon(
                      onPressed: () {
                        // Switch to SFTP screen for this specific host
                        provider.openSftpForHost(host);
                      },
                      icon: const FaIcon(FontAwesomeIcons.folderOpen, size: 13),
                      label: const Text('SFTP'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.purple,
                        side: const BorderSide(color: AppColors.purple),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // More options popup menu
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                      color: AppColors.surface,
                      onSelected: (val) {
                        if (val == 'edit') {
                          _showEditHostDialog(context, host);
                        } else if (val == 'duplicate') {
                          final duplicate = host.copyWith(
                            id: 'host_${DateTime.now().millisecondsSinceEpoch}',
                            alias: '${host.alias} (Copy)',
                            createdAt: DateTime.now(),
                          );
                          provider.addHost(duplicate);
                        } else if (val == 'delete') {
                          _showDeleteConfirm(context, host);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 16, color: AppColors.cyan),
                              SizedBox(width: 10),
                              Text('Edit Host'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'duplicate',
                          child: Row(
                            children: [
                              Icon(Icons.copy, size: 16, color: AppColors.textSecondary),
                              SizedBox(width: 10),
                              Text('Duplicate'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 16, color: AppColors.rose),
                              SizedBox(width: 10),
                              Text('Delete Host', style: TextStyle(color: AppColors.rose)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: FaIcon(
                FontAwesomeIcons.server,
                size: 32,
                color: AppColors.cyan,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Hosts Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your SSH servers to manage and connect with one click.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _showAddHostDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Your First Host'),
          ),
        ],
      ),
    );
  }

  void _showAddHostDialog(BuildContext context) {
    _showHostFormDialog(context, null);
  }

  void _showEditHostDialog(BuildContext context, HostModel host) {
    _showHostFormDialog(context, host);
  }

  void _showHostFormDialog(BuildContext context, HostModel? existingHost) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final isEditing = existingHost != null;

    final aliasController = TextEditingController(text: existingHost?.alias ?? '');
    final hostController = TextEditingController(text: existingHost?.hostname ?? '');
    final portController = TextEditingController(text: (existingHost?.port ?? 22).toString());
    final userController = TextEditingController(text: existingHost?.username ?? 'root');
    final passController = TextEditingController(text: existingHost?.password ?? '');
    final passphraseController = TextEditingController(text: existingHost?.passphrase ?? '');
    final tagsController = TextEditingController(text: existingHost?.tags.join(', ') ?? '');
    final notesController = TextEditingController(text: existingHost?.notes ?? '');

    final availableGroups = provider.groups.map((g) => g.name).toList();
    if (!availableGroups.contains('Default')) {
      availableGroups.insert(0, 'Default');
    }
    String selectedGroup = existingHost?.group ?? (availableGroups.isNotEmpty ? availableGroups.first : 'Default');
    if (!availableGroups.contains(selectedGroup)) {
      availableGroups.add(selectedGroup);
    }
    String? selectedKeyId = existingHost?.keyId;
    String selectedColor = existingHost?.colorHex ?? '#00D2FF';

    final colorOptions = [
      '#00D2FF', // Cyan
      '#8B5CF6', // Purple
      '#10B981', // Emerald
      '#F59E0B', // Amber
      '#EC4899', // Pink
      '#3B82F6', // Blue
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  isEditing ? Icons.edit : Icons.add_circle,
                  color: AppColors.cyan,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  isEditing ? 'Edit SSH Host' : 'Add New SSH Host',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Alias & Group
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: aliasController,
                            decoration: const InputDecoration(
                              labelText: 'Label / Alias *',
                              hintText: 'e.g. Ubuntu Web Server',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: selectedGroup,
                                  decoration: const InputDecoration(labelText: 'Group'),
                                  dropdownColor: AppColors.surface,
                                  items: availableGroups.map((gName) {
                                    final matching = provider.groups
                                        .where((g) => g.name == gName)
                                        .firstOrNull;
                                    return DropdownMenuItem(
                                      value: gName,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (matching != null) ...[
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: _parseColor(matching.colorHex),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                          Flexible(
                                            child: Text(
                                              gName,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setDialogState(() => selectedGroup = val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.add_circle, color: AppColors.cyan, size: 22),
                                tooltip: 'Create New Group',
                                onPressed: () {
                                  _showGroupFormDialog(
                                    context,
                                    provider,
                                    onGroupCreated: (newGroup) {
                                      setDialogState(() {
                                        if (!availableGroups.contains(newGroup.name)) {
                                          availableGroups.add(newGroup.name);
                                        }
                                        selectedGroup = newGroup.name;
                                      });
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Hostname & Port
                    Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: TextField(
                            controller: hostController,
                            decoration: const InputDecoration(
                              labelText: 'Hostname or IP Address *',
                              hintText: '192.168.1.100 or server.com',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: portController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Port *'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Username & Password
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: userController,
                            decoration: const InputDecoration(labelText: 'Username *'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: passController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              hintText: 'Optional if using key',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // SSH Key Vault selector
                    DropdownButtonFormField<String?>(
                      initialValue: selectedKeyId,
                      decoration: const InputDecoration(
                        labelText: 'SSH Key Identity (Optional)',
                        prefixIcon: Padding(
                          padding: EdgeInsets.all(12),
                          child: FaIcon(FontAwesomeIcons.key, size: 14, color: AppColors.purple),
                        ),
                      ),
                      dropdownColor: AppColors.surface,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('None (Use Password)')),
                        ...provider.keys.map((k) {
                          return DropdownMenuItem(
                            value: k.id,
                            child: Text('${k.name} (${k.keyType})'),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setDialogState(() => selectedKeyId = val);
                      },
                    ),
                    if (selectedKeyId != null) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: passphraseController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Key Passphrase (if encrypted)',
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),

                    // Color Badge Picker
                    const Text('Color Badge', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Row(
                      children: colorOptions.map((c) {
                        final isSelected = selectedColor == c;
                        final color = _parseColor(c);
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedColor = c),
                          child: Container(
                            margin: const EdgeInsets.only(right: 10),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, size: 16, color: Colors.black)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Tags
                    TextField(
                      controller: tagsController,
                      decoration: const InputDecoration(
                        labelText: 'Tags (comma separated)',
                        hintText: 'prod, web, nginx, database',
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Notes
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes / Server Description',
                        hintText: 'Internal documentation or maintenance schedule',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () {
                  final alias = aliasController.text.trim();
                  final hostname = hostController.text.trim();
                  final port = int.tryParse(portController.text.trim()) ?? 22;
                  final username = userController.text.trim();

                  if (alias.isEmpty || hostname.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter alias and hostname')),
                    );
                    return;
                  }

                  final tagsList = tagsController.text
                      .split(',')
                      .map((t) => t.trim())
                      .where((t) => t.isNotEmpty)
                      .toList();

                  if (isEditing) {
                    final updated = existingHost.copyWith(
                      alias: alias,
                      hostname: hostname,
                      port: port,
                      username: username.isNotEmpty ? username : 'root',
                      password: passController.text,
                      keyId: selectedKeyId,
                      passphrase: passphraseController.text,
                      group: selectedGroup,
                      colorHex: selectedColor,
                      tags: tagsList,
                      notes: notesController.text,
                    );
                    provider.updateHost(updated);
                  } else {
                    final newHost = HostModel(
                      id: 'host_${DateTime.now().millisecondsSinceEpoch}',
                      alias: alias,
                      hostname: hostname,
                      port: port,
                      username: username.isNotEmpty ? username : 'root',
                      password: passController.text,
                      keyId: selectedKeyId,
                      passphrase: passphraseController.text,
                      group: selectedGroup,
                      colorHex: selectedColor,
                      tags: tagsList,
                      notes: notesController.text,
                      createdAt: DateTime.now(),
                      status: 'online',
                    );
                    provider.addHost(newHost);
                  }
                  Navigator.pop(ctx);
                },
                child: Text(isEditing ? 'Save Changes' : 'Create Host'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, HostModel host) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Host'),
        content: Text('Are you sure you want to remove "${host.alias}"? This will update termius_data.json immediately.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: () {
              provider.deleteHost(host.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  FaIconData _getGroupIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'cloud':
        return FontAwesomeIcons.cloud;
      case 'server':
        return FontAwesomeIcons.server;
      case 'database':
        return FontAwesomeIcons.database;
      case 'microchip':
        return FontAwesomeIcons.microchip;
      case 'terminal':
        return FontAwesomeIcons.terminal;
      case 'networkwired':
        return FontAwesomeIcons.networkWired;
      case 'shield':
        return FontAwesomeIcons.shieldHalved;
      case 'box':
        return FontAwesomeIcons.box;
      case 'globe':
        return FontAwesomeIcons.globe;
      case 'folder':
      default:
        return FontAwesomeIcons.folder;
    }
  }

  void _showManageGroupsDialog(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Consumer<AppProvider>(
          builder: (context, prov, _) {
            final currentGroups = prov.groups;

            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.folder_copy, color: AppColors.cyan, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Host Groups',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Organize servers into logical environments',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showGroupFormDialog(context, prov),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New Group', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 580,
                height: 400,
                child: currentGroups.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.card,
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Center(
                                child: FaIcon(
                                  FontAwesomeIcons.folderOpen,
                                  size: 26,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No Groups Created Yet',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Create groups to categorize hosts (e.g. Production, Staging, Homelab).',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _showGroupFormDialog(context, prov),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Create First Group'),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: currentGroups.length,
                        separatorBuilder: (context, _) => const SizedBox(height: 10),
                        itemBuilder: (ctx, index) {
                          final group = currentGroups[index];
                          final groupColor = _parseColor(group.colorHex);
                          final hostCount = prov.getGroupHostCount(group.name);

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                // Group Icon Box
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: groupColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: groupColor.withValues(alpha: 0.5)),
                                  ),
                                  child: Center(
                                    child: FaIcon(
                                      _getGroupIcon(group.iconName),
                                      color: groupColor,
                                      size: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Group Name & Description
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            group.name,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceElevated,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: AppColors.border),
                                            ),
                                            child: Text(
                                              '$hostCount ${hostCount == 1 ? "host" : "hosts"}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (group.description.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          group.description,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                // Actions
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 18, color: AppColors.cyan),
                                      tooltip: 'Edit Group',
                                      onPressed: () => _showGroupFormDialog(
                                        context,
                                        prov,
                                        existingGroup: group,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.rose),
                                      tooltip: 'Delete Group',
                                      onPressed: () => _confirmDeleteGroup(
                                        context,
                                        prov,
                                        group,
                                        hostCount,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showGroupFormDialog(
    BuildContext context,
    AppProvider provider, {
    GroupModel? existingGroup,
    Function(GroupModel)? onGroupCreated,
  }) {
    final isEditing = existingGroup != null;
    final nameController = TextEditingController(text: existingGroup?.name ?? '');
    final descController = TextEditingController(text: existingGroup?.description ?? '');

    String selectedColor = existingGroup?.colorHex ?? '#00D2FF';
    String selectedIcon = existingGroup?.iconName ?? 'folder';

    final colorOptions = [
      '#00D2FF', // Cyan
      '#8B5CF6', // Purple
      '#10B981', // Emerald
      '#F59E0B', // Amber
      '#F43F5E', // Rose
      '#3B82F6', // Blue
      '#EC4899', // Pink
      '#14B8A6', // Teal
      '#6366F1', // Indigo
      '#84CC16', // Lime
    ];

    final iconOptions = [
      {'name': 'folder', 'label': 'Folder', 'icon': FontAwesomeIcons.folder},
      {'name': 'server', 'label': 'Server', 'icon': FontAwesomeIcons.server},
      {'name': 'cloud', 'label': 'Cloud', 'icon': FontAwesomeIcons.cloud},
      {'name': 'database', 'label': 'Database', 'icon': FontAwesomeIcons.database},
      {'name': 'microchip', 'label': 'IoT / Pi', 'icon': FontAwesomeIcons.microchip},
      {'name': 'terminal', 'label': 'Terminal', 'icon': FontAwesomeIcons.terminal},
      {'name': 'networkWired', 'label': 'Network', 'icon': FontAwesomeIcons.networkWired},
      {'name': 'shield', 'label': 'Security', 'icon': FontAwesomeIcons.shieldHalved},
      {'name': 'box', 'label': 'Containers', 'icon': FontAwesomeIcons.box},
      {'name': 'globe', 'label': 'Web', 'icon': FontAwesomeIcons.globe},
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            title: Row(
              children: [
                Icon(
                  isEditing ? Icons.edit : Icons.create_new_folder,
                  color: AppColors.cyan,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  isEditing ? 'Edit Group' : 'Create New Group',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Group Name
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Group Name *',
                        hintText: 'e.g. Production Cluster, AWS Staging, Homelab',
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Description
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'Notes about the environments or servers in this group...',
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Color Picker
                    const Text(
                      'Group Color Theme',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: colorOptions.map((c) {
                        final color = _parseColor(c);
                        final isSelected = selectedColor.toUpperCase() == c.toUpperCase();
                        return InkWell(
                          onTap: () => setDialogState(() => selectedColor = c),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.5),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? const Center(
                                    child: Icon(Icons.check, size: 16, color: Colors.black),
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    // Icon Picker
                    const Text(
                      'Group Icon',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: iconOptions.map((item) {
                        final iconKey = item['name'] as String;
                        final iconData = item['icon'] as FaIconData;
                        final isSelected = selectedIcon.toLowerCase() == iconKey.toLowerCase();
                        final activeColor = _parseColor(selectedColor);

                        return InkWell(
                          onTap: () => setDialogState(() => selectedIcon = iconKey),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? activeColor.withValues(alpha: 0.2)
                                  : AppColors.card,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? activeColor : AppColors.border,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Center(
                              child: FaIcon(
                                iconData,
                                size: 16,
                                color: isSelected ? activeColor : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a group name.')),
                    );
                    return;
                  }

                  // Check unique name if creating or changing name
                  final exists = provider.groups.any(
                    (g) => g.name.toLowerCase() == name.toLowerCase() &&
                        (!isEditing || g.id != existingGroup.id),
                  );
                  if (exists) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('A group named "$name" already exists.')),
                    );
                    return;
                  }

                  if (isEditing) {
                    final updated = existingGroup.copyWith(
                      name: name,
                      description: descController.text.trim(),
                      colorHex: selectedColor,
                      iconName: selectedIcon,
                    );
                    provider.updateGroup(updated, oldName: existingGroup.name);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Group "$name" updated successfully!')),
                    );
                  } else {
                    final newGroup = GroupModel(
                      id: 'group_${DateTime.now().millisecondsSinceEpoch}',
                      name: name,
                      description: descController.text.trim(),
                      colorHex: selectedColor,
                      iconName: selectedIcon,
                    );
                    provider.addGroup(newGroup);
                    Navigator.pop(ctx);
                    if (onGroupCreated != null) {
                      onGroupCreated(newGroup);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Group "$name" created successfully!')),
                    );
                  }
                },
                child: Text(isEditing ? 'Save Changes' : 'Create Group'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteGroup(
    BuildContext context,
    AppProvider provider,
    GroupModel group,
    int hostCount,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.rose, size: 22),
            const SizedBox(width: 10),
            Text('Delete "${group.name}"?'),
          ],
        ),
        content: Text(
          hostCount > 0
              ? 'Are you sure you want to delete this group? The $hostCount ${hostCount == 1 ? "host" : "hosts"} assigned to this group will be moved to "Default".'
              : 'Are you sure you want to delete group "${group.name}"?',
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rose,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              provider.deleteGroup(group.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Group "${group.name}" deleted.')),
              );
            },
            child: const Text('Delete Group'),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      final buffer = StringBuffer();
      if (hex.length == 6 || hex.length == 7) buffer.write('ff');
      buffer.write(hex.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return AppColors.cyan;
    }
  }
}
