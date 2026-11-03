import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'hosts_screen.dart';
import 'terminal_screen.dart';
import 'snippets_screen.dart';
import 'sftp_screen.dart';
import 'port_forwarding_screen.dart';
import 'keys_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    if (provider.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.cyan),
              SizedBox(height: 16),
              Text(
                'Loading term data from JSON file...',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final screens = const [
      HostsScreen(),
      TerminalScreen(),
      SnippetsScreen(),
      SftpScreen(),
      PortForwardingScreen(),
      KeysScreen(),
      SettingsScreen(),
    ];

    final isDesktop = MediaQuery.of(context).size.width >= 800;

    if (!isDesktop) {
      // Mobile View with bottom navigation
      return Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(
          index: provider.currentNavIndex,
          children: screens,
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: AppColors.sidebar,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: BottomNavigationBar(
            currentIndex: provider.currentNavIndex > 4 ? 0 : provider.currentNavIndex,
            onTap: (index) => provider.setNavIndex(index),
            backgroundColor: AppColors.sidebar,
            selectedItemColor: AppColors.cyan,
            unselectedItemColor: AppColors.textMuted,
            type: BottomNavigationBarType.fixed,
            selectedFontSize: 11,
            unselectedFontSize: 10,
            items: [
              const BottomNavigationBarItem(
                icon: FaIcon(FontAwesomeIcons.server, size: 16),
                label: 'Hosts',
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: provider.sessions.isNotEmpty,
                  label: Text('${provider.sessions.length}'),
                  backgroundColor: AppColors.cyan,
                  textColor: Colors.black,
                  child: const FaIcon(FontAwesomeIcons.terminal, size: 16),
                ),
                label: 'Terminal',
              ),
              const BottomNavigationBarItem(
                icon: FaIcon(FontAwesomeIcons.code, size: 16),
                label: 'Snippets',
              ),
              const BottomNavigationBarItem(
                icon: FaIcon(FontAwesomeIcons.folderOpen, size: 16),
                label: 'SFTP',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.settings, size: 18),
                label: 'Settings',
              ),
            ],
          ),
        ),
      );
    }

    // Desktop & Tablet View with Left Sidebar Navigation
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 240,
            decoration: const BoxDecoration(
              color: AppColors.sidebar,
              border: Border(right: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: [
                // Termius Branding
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Image.asset(
                          'assets/icon/app_icon.png',
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.cyan, AppColors.purple],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Center(
                              child: FaIcon(
                                FontAwesomeIcons.terminal,
                                color: Colors.black,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Phoenix Term',
                            style: TextStyle(
                              letterSpacing: 2.0,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'SSH & Terminal Suite',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: AppColors.cyan,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),
                const SizedBox(height: 12),

                // Navigation Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _buildNavItem(
                        index: 0,
                        icon: FontAwesomeIcons.server,
                        label: 'Hosts & Servers',
                        badge: '${provider.hosts.length}',
                        provider: provider,
                      ),
                      _buildNavItem(
                        index: 1,
                        icon: FontAwesomeIcons.terminal,
                        label: 'Terminal',
                        badge: provider.sessions.isNotEmpty
                            ? '${provider.sessions.length}'
                            : null,
                        badgeColor: AppColors.cyan,
                        provider: provider,
                      ),
                      _buildNavItem(
                        index: 2,
                        icon: FontAwesomeIcons.code,
                        label: 'Snippets',
                        badge: '${provider.snippets.length}',
                        provider: provider,
                      ),
                      _buildNavItem(
                        index: 3,
                        icon: FontAwesomeIcons.folderOpen,
                        label: 'SFTP Files',
                        provider: provider,
                      ),
                      _buildNavItem(
                        index: 4,
                        icon: FontAwesomeIcons.networkWired,
                        label: 'Port Forwarding',
                        badge: '${provider.portForwards.length}',
                        provider: provider,
                      ),
                      _buildNavItem(
                        index: 5,
                        icon: FontAwesomeIcons.key,
                        label: 'SSH Key Vault',
                        badge: '${provider.keys.length}',
                        provider: provider,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1),
                      ),
                      _buildNavItem(
                        index: 6,
                        iconData: Icons.settings,
                        label: 'Settings & JSON',
                        provider: provider,
                      ),
                    ],
                  ),
                ),

                // Bottom JSON File status banner
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.emerald,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'JSON STORAGE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: AppColors.emerald,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'termius_data.json synced',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Screen Area
          Expanded(
            child: IndexedStack(
              index: provider.currentNavIndex,
              children: screens,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    FaIconData? icon,
    IconData? iconData,
    required String label,
    String? badge,
    Color badgeColor = AppColors.surfaceElevated,
    required AppProvider provider,
  }) {
    final isSelected = provider.currentNavIndex == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isSelected ? AppColors.surfaceElevated : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => provider.setNavIndex(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                if (icon != null)
                  FaIcon(
                    icon,
                    size: 15,
                    color: isSelected ? AppColors.cyan : AppColors.textSecondary,
                  )
                else if (iconData != null)
                  Icon(
                    iconData,
                    size: 16,
                    color: isSelected ? AppColors.cyan : AppColors.textSecondary,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.cyan.withValues(alpha: 0.2) : badgeColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppColors.cyan : AppColors.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
