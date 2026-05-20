import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/genogram_state.dart';
import '../models/person.dart';
import '../models/relationship.dart';
import '../providers/genogram_provider.dart';
import '../services/export_service.dart';
import '../services/json_export_service.dart';
import '../services/import_service.dart';
import '../constants/app_theme.dart';
import '../widgets/canvas_widget.dart';


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GenogramProvider>();

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: _AppBar(
          onExportJson: () => JsonExportService.exportToJson(context, context.read<GenogramProvider>()),
          onImportJson: () => ImportService.importFromJson(context, context.read<GenogramProvider>()),
          onExportPdf: () => ExportService.exportToPdf(context, context.read<GenogramProvider>()),
        ),
      ),
      body: Stack(
        children: [
          const GenogramCanvas(),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _StatusBar(provider: provider),
          ),
          if (provider.mode == AppMode.connect)
            Positioned(
              top: 8, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: kAccentOrange.withOpacity(0.15),
                    border: Border.all(color: kAccentOrange.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    provider.connectSourceId == null
                        ? 'TAP the SOURCE person'
                        : 'TAP the TARGET person',
                    style: const TextStyle(
                      color: kAccentOrange, fontSize: 12,
                      fontFamily: 'monospace', letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _QuickAddFab(provider: provider),
    );
  }
}

// ----------------------------------------------------------------
// App bar - defined here to access callbacks cleanly
// ----------------------------------------------------------------
class _AppBar extends StatelessWidget {
  final VoidCallback onExportJson;
  final VoidCallback onImportJson;
  final VoidCallback onExportPdf;

  const _AppBar({
    required this.onExportJson,
    required this.onImportJson,
    required this.onExportPdf,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GenogramProvider>();
    final isConnect = provider.mode == AppMode.connect;

    return AppBar(
      titleSpacing: 12,
      title: const Text('GENOGRAM'),
      actions: [
        _tbBtn(context, '+ Male', () => provider.addPerson(Gender.male)),
        _tbBtn(context, '+ Female', () => provider.addPerson(Gender.female)),
        _tbBtn(context, '+ ?', () => provider.addPerson(Gender.unknown)),
        _divider(),
        _tbBtn(
          context,
          isConnect ? 'Cancel' : 'Link',
          () => provider.toggleConnectMode(),
          active: isConnect,
          activeColor: kAccentOrange,
        ),
        _divider(),
        _tbBtn(context, 'Layout', () {
          provider.runAutoLayout();
          Future.delayed(const Duration(milliseconds: 80), () {
            if (context.mounted) {
              final s = MediaQuery.of(context).size;
              provider.fitView(Size(s.width, s.height - 100));
            }
          });
        }),
        _tbBtn(context, 'Fit', () {
          final s = MediaQuery.of(context).size;
          provider.fitView(Size(s.width, s.height - 100));
        }),
        _divider(),
        _modeChip(isConnect, provider.connectSourceId),
        PopupMenuButton<String>(
          color: kSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: kBorder),
          ),
          icon: const Icon(Icons.more_vert, color: kText2, size: 20),
          onSelected: (val) => _handleMenu(context, val, provider),
          itemBuilder: (_) => <PopupMenuEntry<String>>[
            _menuItem('export_json', 'Export JSON'),
            _menuItem('import_json', 'Import JSON'),
            _menuItem('export_pdf', 'Export PDF'),
            const PopupMenuDivider(),
            _menuItem('legend', 'Legend'),
            const PopupMenuDivider(),
            _menuItem('clear', 'Clear All', danger: true),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _tbBtn(BuildContext context, String label, VoidCallback onTap,
      {bool active = false, Color? activeColor}) {
    final c = activeColor ?? kAccent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 9),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: active ? c : kSurface2,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: active ? c : kBorder),
        ),
        child: Text(label,
          style: TextStyle(
            color: active ? Colors.black : kText,
            fontSize: 10,
            fontFamily: 'monospace',
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          )),
      ),
    );
  }

  Widget _divider() => Container(
    width: 1, height: 26,
    margin: const EdgeInsets.symmetric(horizontal: 2),
    color: kBorder,
  );

  Widget _modeChip(bool isConnect, String? sourceId) {
    final color = isConnect ? kAccentOrange : kAccentGreen;
    final label = isConnect
        ? (sourceId != null ? 'PICK TARGET' : 'PICK SOURCE')
        : 'SELECT';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(label,
        style: TextStyle(color: color, fontSize: 8, fontFamily: 'monospace', letterSpacing: 1)),
    );
  }

  PopupMenuItem<String> _menuItem(String value, String label, {bool danger = false}) =>
      PopupMenuItem(
        value: value,
        child: Text(label, style: TextStyle(color: danger ? kAccentRed : kText, fontSize: 13)),
      );

  void _handleMenu(BuildContext context, String action, GenogramProvider provider) {
    switch (action) {
      case 'export_json': onExportJson();
      case 'import_json': onImportJson();
      case 'export_pdf': onExportPdf();
      case 'legend': _showLegend(context);
      case 'clear': _confirmClear(context, provider);
    }
  }

  void _showLegend(BuildContext context) {
    showDialog(context: context, builder: (_) => const _LegendDialog());
  }

  void _confirmClear(BuildContext context, GenogramProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: kBorder),
        ),
        title: const Text('Clear All?', style: TextStyle(color: kText, fontFamily: 'monospace')),
        content: const Text(
          'Deletes all persons and relationships. Export a backup first.',
          style: TextStyle(color: kText2, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: kText2))),
          TextButton(
            onPressed: () { provider.clearAll(); Navigator.pop(context); },
            child: const Text('Clear', style: TextStyle(color: kAccentRed)),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------
// Status bar
// ----------------------------------------------------------------
class _StatusBar extends StatelessWidget {
  final GenogramProvider provider;
  const _StatusBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      color: kSurface,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        _item('NODES', '${provider.persons.length}'),
        _sep(),
        _item('RELS', '${provider.relationships.length}'),
        _sep(),
        _item('MAX', '${GenogramState.maxNodes}'),
        _sep(),
        _item('ZOOM', '${(provider.viewScale * 100).round()}%'),
        const Spacer(),
        if (provider.selectedPersonId != null)
          _chip(provider.persons[provider.selectedPersonId]?.name.isNotEmpty == true
              ? provider.persons[provider.selectedPersonId]!.name
              : 'Person selected', kAccentGreen),
        if (provider.selectedRelationshipId != null)
          _chip(
            kRelationshipDefs[provider.relationships[provider.selectedRelationshipId]?.type]?.label
                ?? 'Relationship',
            kAccent,
          ),
      ]),
    );
  }

  Widget _item(String label, String value) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: const TextStyle(color: kText3, fontSize: 8, fontFamily: 'monospace')),
      const SizedBox(width: 4),
      Text(value, style: const TextStyle(color: kText2, fontSize: 8, fontFamily: 'monospace')),
    ],
  );

  Widget _sep() => Container(
    width: 1, height: 12, margin: const EdgeInsets.symmetric(horizontal: 8), color: kBorder,
  );

  Widget _chip(String text, Color color) => Container(
    margin: const EdgeInsets.only(left: 6),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      border: Border.all(color: color.withOpacity(0.3)),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(text, style: TextStyle(color: color, fontSize: 8, fontFamily: 'monospace')),
  );
}

// ----------------------------------------------------------------
// Quick-add FAB
// ----------------------------------------------------------------
class _QuickAddFab extends StatefulWidget {
  final GenogramProvider provider;
  const _QuickAddFab({required this.provider});

  @override
  State<_QuickAddFab> createState() => _QuickAddFabState();
}

class _QuickAddFabState extends State<_QuickAddFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _toggle() {
    setState(() => _open = !_open);
    _open ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ScaleTransition(
            scale: _anim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _mini('Male', kMaleColor, () { _toggle(); widget.provider.addPerson(Gender.male); }),
                const SizedBox(height: 8),
                _mini('Female', kFemaleColor, () { _toggle(); widget.provider.addPerson(Gender.female); }),
                const SizedBox(height: 8),
                _mini('Unknown', kUnknownColor, () { _toggle(); widget.provider.addPerson(Gender.unknown); }),
                const SizedBox(height: 8),
              ],
            ),
          ),
          FloatingActionButton(
            onPressed: _toggle,
            backgroundColor: _open ? kAccentRed : kAccent,
            foregroundColor: Colors.black,
            child: Icon(_open ? Icons.close : Icons.add, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _mini(String label, Color color, VoidCallback onTap) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: kSurface, borderRadius: BorderRadius.circular(4),
          border: Border.all(color: kBorder),
        ),
        child: Text(label, style: const TextStyle(color: kText2, fontSize: 11, fontFamily: 'monospace')),
      ),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15), shape: BoxShape.circle,
            border: Border.all(color: color),
          ),
          child: Icon(Icons.add, color: color, size: 18),
        ),
      ),
    ],
  );
}

// ----------------------------------------------------------------
// Legend dialog
// ----------------------------------------------------------------
class _LegendDialog extends StatelessWidget {
  const _LegendDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: kBorder),
      ),
      title: const Text('LEGEND', style: TextStyle(
        color: kAccent, fontSize: 12, fontFamily: 'monospace', letterSpacing: 2,
      )),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section('NODES', [
              ('Square', 'Male'), ('Circle', 'Female'), ('Diamond', 'Unknown'),
              ('X overlay', 'Deceased'), ('Dashed border', 'Adopted'),
              ('Triangle', 'Pregnancy / special'),
            ]),
            _section('MARKERS', [
              ('Orange sq', 'Substance abuse'), ('Purple dot', 'Mental illness'),
              ('Red triangle', 'Physical illness'), ('A', 'Abuse perpetrator'),
              ('V', 'Abuse victim'), ('F', 'Foster'), ('IP', 'Index Person'),
            ]),
            _section('STRUCTURAL', [
              ('Double line', 'Married'), ('Single', 'Partnership'),
              ('Dashed', 'Separated'), ('Double + slashes', 'Divorced'),
              ('Short dash', 'Engaged'), ('Solid gray', 'Parent / Sibling'),
            ]),
            _section('EMOTIONAL', [
              ('Double blue', 'Close'), ('Triple blue', 'Very close / Fused'),
              ('Triple orange', 'Enmeshed'), ('Thin gray', 'Distant'),
              ('Red zigzag', 'Conflicted'), ('Dashed + break', 'Estranged'),
              ('Triple + zigzag', 'Fused-Conflicted'), ('Dark red zigzag', 'Abusive'),
            ]),
            _section('GESTURES', [
              ('Tap', 'Select'), ('Double-tap', 'Edit'),
              ('Long-press', 'Context menu'), ('Drag node', 'Move'),
              ('Drag canvas', 'Pan'), ('Pinch', 'Zoom'),
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
        Text(title, style: const TextStyle(
          color: kText3, fontSize: 9, fontFamily: 'monospace', letterSpacing: 1,
        )),
        const SizedBox(height: 4),
        ...items.map((i) => Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(children: [
            SizedBox(width: 110, child: Text(i.$1,
              style: const TextStyle(color: kAccent, fontSize: 11, fontFamily: 'monospace'))),
            Expanded(child: Text(i.$2,
              style: const TextStyle(color: kText2, fontSize: 11))),
          ]),
        )),
      ],
    );
  }
}
