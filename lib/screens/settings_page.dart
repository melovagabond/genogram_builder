import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/genogram_provider.dart';

class SettingsPage1 extends StatefulWidget {
  const SettingsPage1({super.key});

  @override
  State<SettingsPage1> createState() => _SettingsPage1State();
}

class _SettingsPage1State extends State<SettingsPage1> {
  Size _canvasSize(BuildContext context) {
    final s = MediaQuery.of(context).size;
    return Size(s.width, (s.height - 100).clamp(100, double.infinity));
  }

  void _showMessage(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 1100)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GenogramProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: ListView(
            children: [
              _SingleSection(
                title: 'Visibility',
                children: [
                  _CustomListTile(
                    title: 'Hide Emotional Ties',
                    subtitle: 'Show structural relationships only',
                    icon: Icons.visibility_off_outlined,
                    trailing: Switch.adaptive(
                      value: provider.hideEmotionalTies,
                      onChanged: provider.setHideEmotionalTies,
                    ),
                  ),
                  _CustomListTile(
                    title: 'Focus Depth',
                    subtitle:
                        'How many relationship hops are visible in focus mode',
                    icon: Icons.tune_outlined,
                    trailing: Switch.adaptive(
                      value: provider.focusDepth >= 2,
                      onChanged: (value) {
                        provider.setFocusDepth(value ? 2 : 1);
                      },
                    ),
                  ),
                  _CustomListTile(
                    title: 'Clear Focus Mode',
                    subtitle: provider.isFocused
                        ? 'Focus is active'
                        : 'No focus is currently active',
                    icon: Icons.filter_center_focus_outlined,
                    enabled: provider.isFocused,
                    onTap: provider.isFocused
                        ? () {
                            provider.clearFocus();
                            _showMessage(context, 'Focus mode cleared');
                          }
                        : null,
                  ),
                ],
              ),
              _SingleSection(
                title: 'Canvas',
                children: [
                  _CustomListTile(
                    title: 'Run Auto Layout',
                    subtitle: 'Rearrange nodes for cleaner structure',
                    icon: Icons.auto_fix_high_outlined,
                    onTap: () {
                      provider.runAutoLayout();
                      provider.fitView(_canvasSize(context));
                      _showMessage(context, 'Auto layout applied');
                    },
                  ),
                  _CustomListTile(
                    title: 'Fit View',
                    subtitle: 'Center and zoom to include all nodes',
                    icon: Icons.fit_screen_outlined,
                    onTap: () {
                      provider.fitView(_canvasSize(context));
                      _showMessage(context, 'Canvas fitted');
                    },
                  ),
                  _CustomListTile(
                    title: 'Reset Zoom',
                    subtitle: 'Return to 100% zoom and origin position',
                    icon: Icons.zoom_out_map,
                    onTap: () {
                      provider.resetZoom();
                      _showMessage(context, 'Zoom reset');
                    },
                  ),
                  _CustomListTile(
                    title: 'Current Zoom',
                    subtitle: '${(provider.viewScale * 100).round()}%',
                    icon: Icons.search,
                    onTap: null,
                  ),
                ],
              ),
              _SingleSection(
                title: 'Data',
                children: [
                  _CustomListTile(
                    title: 'Undo Last Change',
                    subtitle: provider.canUndo
                        ? 'Revert the latest edit'
                        : 'No undo history available',
                    icon: Icons.undo,
                    enabled: provider.canUndo,
                    onTap: provider.canUndo
                        ? () {
                            provider.undo();
                            _showMessage(context, 'Undid last change');
                          }
                        : null,
                  ),
                  _CustomListTile(
                    title: 'Total Persons',
                    subtitle: '${provider.persons.length}',
                    icon: Icons.people_alt_outlined,
                    onTap: null,
                  ),
                  _CustomListTile(
                    title: 'Total Relationships',
                    subtitle: '${provider.relationships.length}',
                    icon: Icons.link,
                    onTap: null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  const _CustomListTile({
    required this.title,
    required this.icon,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      leading: Icon(icon),
      enabled: enabled,
      trailing: trailing ??
          (onTap == null
              ? null
              : const Icon(Icons.chevron_right, size: 18)),
      onTap: enabled ? onTap : null,
    );
  }
}

class _SingleSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SingleSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontSize: 16),
          ),
        ),
        Container(
          width: double.infinity,
          color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
          child: Column(children: children),
        ),
      ],
    );
  }
}
