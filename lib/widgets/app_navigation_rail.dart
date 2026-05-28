import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/genogram_provider.dart';
import '../constants/app_theme.dart';
import '../models/person.dart';
import '../screens/settings_page.dart';

/// Full-height custom sidebar rail. Contains node-add actions, mode selection,
/// view/layout actions, and the overflow menu.
class AppNavigationRail extends StatefulWidget {
  final VoidCallback onExportJson;
  final VoidCallback onImportJson;
  final VoidCallback onExportPdf;

  const AppNavigationRail({
    super.key,
    required this.onExportJson,
    required this.onImportJson,
    required this.onExportPdf,
  });

  @override
  State<AppNavigationRail> createState() => _AppNavigationRailState();
}

class _AppNavigationRailState extends State<AppNavigationRail>
    with SingleTickerProviderStateMixin {
  bool _addOpen = false;
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggleAdd() {
    setState(() => _addOpen = !_addOpen);
    _addOpen ? _ctrl.forward() : _ctrl.reverse();
  }

  Size _canvasSize(BuildContext context) {
    final s = MediaQuery.of(context).size;
    return Size(s.width, (s.height - 88).clamp(100, double.infinity));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GenogramProvider>();

    return Container(
      width: 64,
      color: kSurface,
      child: Column(
        children: [
          const SizedBox(height: 8),

          // ── Expandable + button ────────────────────────────────
          InkWell(
            onTap: _toggleAdd,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: _addOpen
                    ? kAccentRed.withValues(alpha: 0.15)
                    : kAccentGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _addOpen
                      ? kAccentRed.withOpacity(0.4)
                      : kAccentGreen.withOpacity(0.4),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      _addOpen ? Icons.close : Icons.add,
                      key: ValueKey(_addOpen),
                      color: _addOpen ? kAccentRed : kAccent,
                      size: 18,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _addOpen ? 'CLOSE' : 'ADD',
                    style: TextStyle(
                      color: _addOpen ? kAccentRed : kAccent,
                      fontSize: 8,
                      fontFamily: 'monospace',
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded add options
          ScaleTransition(
            scale: _scaleAnim,
            alignment: Alignment.topCenter,
            child: _addOpen
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 4),
                      _RailActionBtn(
                        label: '+M',
                        icon: Icons.square_outlined,
                        color: kMaleColor,
                        onTap: () {
                          _toggleAdd();
                          provider.addPerson(
                            Gender.male,
                            viewportSize: _canvasSize(context),
                          );
                        },
                      ),
                      _RailActionBtn(
                        label: '+F',
                        icon: Icons.circle_outlined,
                        color: kFemaleColor,
                        onTap: () {
                          _toggleAdd();
                          provider.addPerson(
                            Gender.female,
                            viewportSize: _canvasSize(context),
                          );
                        },
                      ),
                      _RailActionBtn(
                        label: '+?',
                        icon: Icons.diamond_outlined,
                        color: kUnknownColor,
                        onTap: () {
                          _toggleAdd();
                          provider.addPerson(
                            Gender.unknown,
                            viewportSize: _canvasSize(context),
                          );
                        },
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),

          _RailDivider(),

          // ── Mode selection ─────────────────────────────────────
          _RailModeBtn(
            label: 'EDIT',
            icon: Icons.edit_outlined,
            activeIcon: Icons.edit,
            isSelected: provider.mode == AppMode.select,
            color: kAccent,
            onTap: () => provider.setMode(AppMode.select),
          ),
          _RailModeBtn(
            label: 'LINK',
            icon: Icons.link_outlined,
            activeIcon: Icons.link,
            isSelected: provider.mode == AppMode.connect,
            color: kAccentOrange,
            onTap: () => provider.toggleConnectMode(),
          ),
          _RailModeBtn(
            label: 'SELECT',
            icon: Icons.select_all_outlined,
            activeIcon: Icons.select_all,
            isSelected: provider.mode == AppMode.marquee,
            color: kAccentGreen,
            onTap: () => provider.setMode(
              provider.mode == AppMode.marquee
                  ? AppMode.select
                  : AppMode.marquee,
            ),
          ),

          _RailDivider(),

          // ── View / layout actions ──────────────────────────────
          Opacity(
            opacity: provider.canUndo ? 1.0 : 0.3,
            child: _RailActionBtn(
              label: 'UNDO',
              icon: Icons.undo,
              color: kText2,
              onTap: provider.canUndo ? provider.undo : () {},
            ),
          ),
          _RailActionBtn(
            label: 'LAYOUT',
            icon: Icons.auto_fix_high_outlined,
            color: kText2,
            onTap: () {
              provider.runAutoLayout();
              Future.delayed(const Duration(milliseconds: 80), () {
                if (context.mounted) {
                  final s = MediaQuery.of(context).size;
                  provider.fitView(Size(s.width, s.height - 100));
                }
              });
            },
          ),
          _RailActionBtn(
            label: 'FIT',
            icon: Icons.fit_screen_outlined,
            color: kText2,
            onTap: () {
              final s = MediaQuery.of(context).size;
              provider.fitView(Size(s.width, s.height - 100));
            },
          ),
          _RailModeBtn(
            label: 'EMOT.',
            icon: Icons.psychology_outlined,
            activeIcon: Icons.psychology,
            isSelected: provider.hideEmotionalTies,
            color: const Color(0xFFBA68C8),
            onTap: () => provider.toggleHideEmotionalTies(),
          ),

          const Spacer(),

          // ── Overflow menu ──────────────────────────────────────
          _RailMenuBtn(
            onExportJson: widget.onExportJson,
            onImportJson: widget.onImportJson,
            onExportPdf: widget.onExportPdf,
            provider: provider,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
// Rail helpers
// ────────────────────────────────────────────────────────────────

class _RailDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        color: kBorder,
      );
}

/// One-shot action button (no selection state).
class _RailActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RailActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 8,
                  fontFamily: 'monospace',
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Toggle/mode button — highlights when [isSelected].
class _RailModeBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _RailModeBtn({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border:
              isSelected ? Border.all(color: color.withValues(alpha: 0.4)) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? color : kText2,
              size: 18,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : kText2,
                fontSize: 8,
                fontFamily: 'monospace',
                letterSpacing: 0.5,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom menu button that opens a [PopupMenuButton].
class _RailMenuBtn extends StatelessWidget {
  final VoidCallback onExportJson;
  final VoidCallback onImportJson;
  final VoidCallback onExportPdf;
  final GenogramProvider provider;

  const _RailMenuBtn({
    required this.onExportJson,
    required this.onImportJson,
    required this.onExportPdf,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: kBorder),
      ),
      tooltip: 'Menu',
      onSelected: (val) => _handle(context, val),
      itemBuilder: (_) => <PopupMenuEntry<String>>[
        _item('export_json', 'Export JSON'),
        _item('import_json', 'Import JSON'),
        _item('export_pdf', 'Export PDF'),
        const PopupMenuDivider(),
        _item('settings', 'Settings'),
        const PopupMenuDivider(),
        _item('legend', 'Legend'),
        const PopupMenuDivider(),
        _item('clear', 'Clear All', danger: true),
      ],
      child: const SizedBox(
        width: double.infinity,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.more_horiz, color: kText2, size: 18),
              SizedBox(height: 2),
              Text(
                'MENU',
                style: TextStyle(
                  color: kText2,
                  fontSize: 8,
                  fontFamily: 'monospace',
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _item(String value, String label,
          {bool danger = false}) =>
      PopupMenuItem(
        value: value,
        child: Text(label,
            style: TextStyle(
                color: danger ? kAccentRed : kText, fontSize: 13)),
      );

  void _handle(BuildContext context, String action) {
    switch (action) {
      case 'export_json':
        onExportJson();
        break;
      case 'import_json':
        onImportJson();
        break;
      case 'export_pdf':
        onExportPdf();
        break;
      case 'settings':
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const SettingsPage1(),
            transitionDuration: const Duration(milliseconds: 240),
            reverseTransitionDuration: const Duration(milliseconds: 200),
            transitionsBuilder: (_, animation, __, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );
              return ScaleTransition(scale: curved, child: child);
            },
          ),
        );
        break;
      case 'legend':
        showDialog(
            context: context, builder: (_) => const _RailLegendDialog());
        break;
      case 'clear':
        _confirmClear(context);
        break;
    }
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: kBorder),
        ),
        title: const Text('Clear All?',
            style: TextStyle(color: kText, fontFamily: 'monospace')),
        content: const Text(
          'Deletes all persons and relationships. Export a backup first.',
          style: TextStyle(color: kText2, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: kText2)),
          ),
          TextButton(
            onPressed: () {
              provider.clearAll();
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: kAccentRed)),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
// Legend dialog (lives here now that the menu moved to the rail)
// ────────────────────────────────────────────────────────────────

class _RailLegendDialog extends StatelessWidget {
  const _RailLegendDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: kBorder),
      ),
      title: const Text(
        'LEGEND',
        style: TextStyle(
          color: kAccent,
          fontSize: 12,
          fontFamily: 'monospace',
          letterSpacing: 2,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section('NODES', [
              ('Square', 'Male'),
              ('Circle', 'Female'),
              ('Diamond', 'Unknown'),
              ('X overlay', 'Deceased'),
              ('Dashed border', 'Adopted'),
              ('Triangle', 'Pregnancy / special'),
            ]),
            _section('MARKERS', [
              ('Orange sq', 'Substance abuse'),
              ('Purple dot', 'Mental illness'),
              ('Red triangle', 'Physical illness'),
              ('A', 'Abuse perpetrator'),
              ('V', 'Abuse victim'),
              ('F', 'Foster'),
              ('IP', 'Index Person'),
            ]),
            _section('STRUCTURAL', [
              ('Double line', 'Married'),
              ('Single', 'Partnership'),
              ('Dashed', 'Separated'),
              ('Double + slashes', 'Divorced'),
              ('Short dash', 'Engaged'),
              ('Solid gray', 'Parent / Sibling'),
            ]),
            _section('EMOTIONAL', [
              ('Double blue', 'Close'),
              ('Triple blue', 'Very close / Fused'),
              ('Triple orange', 'Enmeshed'),
              ('Thin gray', 'Distant'),
              ('Red zigzag', 'Conflicted'),
              ('Dashed + break', 'Estranged'),
              ('Triple + zigzag', 'Fused-Conflicted'),
              ('Dark red zigzag', 'Abusive'),
            ]),
            _section('GESTURES', [
              ('Tap', 'Select'),
              ('Double-tap', 'Edit'),
              ('Long-press', 'Context menu'),
              ('Drag node', 'Move'),
              ('Drag canvas', 'Pan'),
              ('Pinch', 'Zoom'),
            ]),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: kAccent)),
        ),
      ],
    );
  }

  Widget _section(String title, List<(String, String)> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            color: kText3,
            fontSize: 9,
            fontFamily: 'monospace',
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        ...items.map(
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(children: [
              SizedBox(
                  width: 110,
                  child: Text(i.$1,
                      style: const TextStyle(
                          color: kAccent,
                          fontSize: 11,
                          fontFamily: 'monospace'))),
              Expanded(
                  child: Text(i.$2,
                      style: const TextStyle(
                          color: kText2, fontSize: 11))),
            ]),
          ),
        ),
      ],
    );
  }
}
