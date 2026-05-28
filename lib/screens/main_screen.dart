import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/genogram_state.dart';
import '../models/relationship.dart';
import '../providers/genogram_provider.dart';
import '../services/export_service.dart';
import '../services/json_export_service.dart';
import '../services/import_service.dart';
import '../constants/app_motion.dart';
import '../constants/app_theme.dart';
import '../widgets/canvas_widget.dart';
import '../widgets/app_navigation_rail.dart';

/// Returns the canvas area size (full screen minus app bar + status bar).
/// Used so newly-added nodes spawn inside the currently visible viewport.
Size _canvasSize(BuildContext context) {
  final s = MediaQuery.of(context).size;
  // App bar ~52, status bar ~36
  return Size(s.width, (s.height - 88).clamp(100, double.infinity));
}


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const Duration _overlayAnimDuration = AppMotion.standard;
  static const Curve _overlayAnimCurve = AppMotion.standardCurve;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GenogramProvider>();

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: const _AppBar(),
      ),
      body: Stack(
        children: [
          // Canvas + overlays offset to clear the nav rail.
          Positioned.fill(
            left: 65,
            child: Stack(
              children: [
                const GenogramCanvas(),
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: _StatusBar(provider: provider),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: AnimatedAlign(
                      duration: _overlayAnimDuration,
                      curve: _overlayAnimCurve,
                      alignment: provider.mode == AppMode.connect
                          ? Alignment.topCenter
                          : const Alignment(0, -1.35),
                      child: AnimatedOpacity(
                        duration: _overlayAnimDuration,
                        curve: _overlayAnimCurve,
                        opacity: provider.mode == AppMode.connect ? 1 : 0,
                        child: IgnorePointer(
                          ignoring: provider.mode != AppMode.connect,
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
                                color: kAccentOrange,
                                fontSize: 12,
                                fontFamily: 'monospace',
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: AnimatedAlign(
                      duration: _overlayAnimDuration,
                      curve: _overlayAnimCurve,
                      alignment: provider.mode == AppMode.marquee
                          ? Alignment.topCenter
                          : const Alignment(0, -1.35),
                      child: AnimatedOpacity(
                        duration: _overlayAnimDuration,
                        curve: _overlayAnimCurve,
                        opacity: provider.mode == AppMode.marquee ? 1 : 0,
                        child: IgnorePointer(
                          ignoring: provider.mode != AppMode.marquee,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: kAccentGreen.withOpacity(0.15),
                              border: Border.all(color: kAccentGreen.withOpacity(0.5)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              provider.selectedPersonIds.isEmpty
                                  ? 'DRAG to select  /  TAP to toggle'
                                  : '${provider.selectedPersonIds.length} selected',
                              style: const TextStyle(
                                color: kAccentGreen,
                                fontSize: 12,
                                fontFamily: 'monospace',
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 36),
                    child: AnimatedAlign(
                      duration: _overlayAnimDuration,
                      curve: _overlayAnimCurve,
                      alignment: provider.selectedPersonIds.isNotEmpty
                          ? Alignment.bottomCenter
                          : const Alignment(0, 1.3),
                      child: AnimatedOpacity(
                        duration: _overlayAnimDuration,
                        curve: _overlayAnimCurve,
                        opacity: provider.selectedPersonIds.isNotEmpty ? 1 : 0,
                        child: IgnorePointer(
                          ignoring: provider.selectedPersonIds.isEmpty,
                          child: _MultiSelectActionBar(provider: provider),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: AnimatedAlign(
                      duration: _overlayAnimDuration,
                      curve: _overlayAnimCurve,
                      alignment: provider.isFocused
                          ? Alignment.topCenter
                          : const Alignment(0, -1.35),
                      child: AnimatedOpacity(
                        duration: _overlayAnimDuration,
                        curve: _overlayAnimCurve,
                        opacity: provider.isFocused ? 1 : 0,
                        child: IgnorePointer(
                          ignoring: !provider.isFocused,
                          child: _FocusBanner(provider: provider),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 56, right: 12, bottom: 48),
                    child: AnimatedAlign(
                      duration: _overlayAnimDuration,
                      curve: _overlayAnimCurve,
                      alignment: provider.isInspecting
                          ? Alignment.centerRight
                          : const Alignment(1.25, 0),
                      child: AnimatedOpacity(
                        duration: _overlayAnimDuration,
                        curve: _overlayAnimCurve,
                        opacity: provider.isInspecting ? 1 : 0,
                        child: IgnorePointer(
                          ignoring: !provider.isInspecting,
                          child: _InspectPanel(provider: provider),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 12, bottom: 96,
                  child: _ZoomControls(provider: provider),
                ),
              ],
            ),
          ),
          // Navigation rail — always on top, pinned to the left.
          Positioned(
            left: 0, top: 0, bottom: 0,
            child: AppNavigationRail(
              onExportJson: () => JsonExportService.exportToJson(context, context.read<GenogramProvider>()),
              onImportJson: () => ImportService.importFromJson(context, context.read<GenogramProvider>()),
              onExportPdf: () => ExportService.exportToPdf(context, context.read<GenogramProvider>()),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------
// App bar
// ----------------------------------------------------------------
class _AppBar extends StatelessWidget {
  const _AppBar();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GenogramProvider>();
    final isConnect = provider.mode == AppMode.connect;

    return AppBar(
      titleSpacing: 12,
      title: const Text('GENOGRAM'),
      actions: [
        if (provider.selectedPersonId != null)
          _tbBtn(
            context,
            provider.focusPersonId == provider.selectedPersonId
                ? 'Unfocus'
                : 'Focus',
            () {
              final sel = provider.selectedPersonId;
              if (sel == null) return;
              if (provider.focusPersonId == sel) {
                provider.clearFocus();
              } else {
                provider.setFocusPerson(sel);
              }
            },
            active: provider.focusPersonId == provider.selectedPersonId,
            activeColor: const Color(0xFFFFC83D),
          ),
        if (provider.selectedPersonId != null)
          _tbBtn(
            context,
            provider.isInspecting ? 'Hide Ties' : 'Show Ties',
            () {
              if (provider.isInspecting) {
                provider.hideInspect();
              } else {
                final sel = provider.selectedPersonId;
                if (sel != null) provider.setInspectPerson(sel);
              }
            },
            active: provider.isInspecting,
            activeColor: kAccentOrange,
          ),
        if (provider.selectedPersonId != null) _divider(),
        if (isConnect)
          _modeChip(provider.connectSourceId),
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

  Widget _modeChip(String? sourceId) {
    const color = kAccentOrange;
    final label = sourceId != null ? 'PICK TARGET' : 'PICK SOURCE';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(label,
        style: const TextStyle(color: color, fontSize: 8, fontFamily: 'monospace', letterSpacing: 1)),
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
// Multi-select action bar
// ----------------------------------------------------------------
class _MultiSelectActionBar extends StatelessWidget {
  final GenogramProvider provider;
  const _MultiSelectActionBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    final count = provider.selectedPersonIds.length;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: kSurface,
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '$count selected',
                style: const TextStyle(
                  color: kText, fontSize: 12,
                  fontFamily: 'monospace', letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(width: 6),
            _barBtn(
              label: 'Link All',
              color: kAccentOrange,
              enabled: count >= 2,
              onTap: () => _showLinkAllPicker(context, provider),
            ),
            const SizedBox(width: 6),
            _barBtn(
              label: 'Delete',
              color: kAccentRed,
              enabled: count >= 1,
              onTap: () => _confirmDelete(context, provider),
            ),
            const SizedBox(width: 6),
            _barBtn(
              label: 'Clear',
              color: kText2,
              onTap: () => provider.clearMultiSelection(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barBtn({
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: kSurface2,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color, fontSize: 11,
              fontFamily: 'monospace', letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, GenogramProvider provider) {
    final n = provider.selectedPersonIds.length;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        title: Text('Delete $n people?', style: const TextStyle(color: kText)),
        content: const Text(
          'This will also remove every relationship attached to them.',
          style: TextStyle(color: kText2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: kText2)),
          ),
          TextButton(
            onPressed: () {
              provider.deleteSelectedPersons();
              Navigator.of(ctx).pop();
            },
            child: const Text('Delete', style: TextStyle(color: kAccentRed)),
          ),
        ],
      ),
    );
  }

  void _showLinkAllPicker(BuildContext context, GenogramProvider provider) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        side: BorderSide(color: kBorder),
      ),
      builder: (_) {
        final Map<String, List<RelationshipType>> grouped = {};
        for (final t in RelationshipType.values) {
          final cat = kRelationshipDefs[t]!.category;
          grouped.putIfAbsent(cat, () => []).add(t);
        }
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Link all ${provider.selectedPersonIds.length} people pairwise as…',
                    style: const TextStyle(color: kText, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  for (final entry in grouped.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: Text(
                        entry.key.toUpperCase(),
                        style: const TextStyle(
                          color: kText2, fontSize: 10,
                          fontFamily: 'monospace', letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final t in entry.value)
                          GestureDetector(
                            onTap: () {
                              final added = provider.connectSelectedAs(t);
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    added == 0
                                        ? 'No new links added (pairs already linked).'
                                        : 'Added $added link${added == 1 ? '' : 's'}.',
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: kSurface2,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: kBorder),
                              ),
                              child: Text(
                                kRelationshipDefs[t]!.label,
                                style: const TextStyle(
                                    color: kText, fontSize: 11),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ----------------------------------------------------------------
// Zoom controls (floating, right side)
// ----------------------------------------------------------------
class _ZoomControls extends StatelessWidget {
  final GenogramProvider provider;
  const _ZoomControls({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.add, 'Zoom in', () {
            provider.zoomBy(1.2, canvasSize: _canvasSize(context));
          }),
          Container(height: 1, width: 32, color: kBorder),
          _btn(Icons.crop_free, 'Reset zoom', () {
            provider.resetZoom();
          }, label: '${(provider.viewScale * 100).round()}%'),
          Container(height: 1, width: 32, color: kBorder),
          _btn(Icons.remove, 'Zoom out', () {
            provider.zoomBy(1 / 1.2, canvasSize: _canvasSize(context));
          }),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, String tooltip, VoidCallback onTap, {String? label}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 36, height: 32,
          child: Center(
            child: label != null
                ? Text(label, style: const TextStyle(
                    color: kText2, fontSize: 10, fontFamily: 'monospace'))
                : Icon(icon, size: 16, color: kText2),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------
// Focus banner — shown at top when focus mode is active.
// ----------------------------------------------------------------
class _FocusBanner extends StatelessWidget {
  final GenogramProvider provider;
  const _FocusBanner({required this.provider});

  @override
  Widget build(BuildContext context) {
    final id = provider.focusPersonId;
    if (id == null) return const SizedBox.shrink();
    final p = provider.persons[id];
    final name = p?.name.isNotEmpty == true ? p!.name : '(unnamed)';
    const gold = Color(0xFFFFC83D);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: gold.withOpacity(0.12),
        border: Border.all(color: gold.withOpacity(0.55)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'FOCUS: $name',
            style: const TextStyle(
              color: gold, fontSize: 12,
              fontFamily: 'monospace', letterSpacing: 1,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 10),
          _depthBtn('−', () =>
              provider.setFocusDepth(provider.focusDepth - 1)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: kSurface2,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: kBorder),
            ),
            child: Text(
              'depth ${provider.focusDepth}',
              style: const TextStyle(
                color: kText, fontSize: 10, fontFamily: 'monospace'),
            ),
          ),
          _depthBtn('+', () =>
              provider.setFocusDepth(provider.focusDepth + 1)),
          const SizedBox(width: 8),
          _depthBtn('✕', provider.clearFocus, danger: true),
        ],
      ),
    );
  }

  Widget _depthBtn(String label, VoidCallback onTap, {bool danger = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: kSurface2,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: danger ? kAccentRed : kBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: danger ? kAccentRed : kText,
            fontSize: 12,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------
// Inspect panel — readable summary of emotional ties to a person.
// Categories shown: Positive, Negative, Violence, Abuse, Control.
// (Neutral and Structural are intentionally omitted.)
// ----------------------------------------------------------------
class _InspectPanel extends StatelessWidget {
  final GenogramProvider provider;
  const _InspectPanel({required this.provider});

  static const Map<String, Color> _catColor = {
    'Positive': Color(0xFF4CAF50),
    'Negative': Color(0xFFE57373),
    'Violence': Color(0xFFD32F2F),
    'Abuse': Color(0xFFB71C1C),
    'Control': Color(0xFFBA68C8),
  };
  static const List<String> _catOrder = [
    'Positive', 'Negative', 'Violence', 'Abuse', 'Control',
  ];

  @override
  Widget build(BuildContext context) {
    final id = provider.inspectPersonId;
    if (id == null) return const SizedBox.shrink();
    final subject = provider.persons[id];
    final subjectName =
        (subject?.name.isNotEmpty == true) ? subject!.name : '(unnamed)';

    final rels = provider.inspectEmotionalRels;
    final grouped = <String, List<Relationship>>{};
    for (final r in rels) {
      final cat = kRelationshipDefs[r.type]?.category ?? 'Other';
      grouped.putIfAbsent(cat, () => []).add(r);
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: kSurface.withOpacity(0.96),
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: kBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TIES TO',
                            style: TextStyle(
                                color: kText2, fontSize: 9,
                                fontFamily: 'monospace', letterSpacing: 1)),
                        const SizedBox(height: 2),
                        Text(subjectName,
                            style: const TextStyle(
                                color: kText, fontSize: 14,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: provider.hideInspect,
                    icon: const Icon(Icons.close,
                        size: 16, color: kText2),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 28, minHeight: 28),
                    splashRadius: 16,
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            // Body
            Flexible(
              child: rels.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                        'No emotional, violence, or abuse ties recorded.',
                        style: TextStyle(
                            color: kText2, fontSize: 12,
                            fontFamily: 'monospace'),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      children: [
                        for (final cat in _catOrder)
                          if (grouped[cat] != null)
                            _CategorySection(
                              category: cat,
                              color: _catColor[cat]!,
                              relationships: grouped[cat]!,
                              subjectId: id,
                              provider: provider,
                            ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final String category;
  final Color color;
  final List<Relationship> relationships;
  final String subjectId;
  final GenogramProvider provider;
  const _CategorySection({
    required this.category,
    required this.color,
    required this.relationships,
    required this.subjectId,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 6),
              Text(category.toUpperCase(),
                  style: TextStyle(
                      color: color, fontSize: 10,
                      fontFamily: 'monospace', letterSpacing: 1,
                      fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              Text('(${relationships.length})',
                  style: const TextStyle(
                      color: kText2, fontSize: 10,
                      fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 4),
          for (final rel in relationships)
            _TieRow(rel: rel, subjectId: subjectId, provider: provider),
        ],
      ),
    );
  }
}

class _TieRow extends StatelessWidget {
  final Relationship rel;
  final String subjectId;
  final GenogramProvider provider;
  const _TieRow({
    required this.rel,
    required this.subjectId,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final otherId =
        rel.sourceId == subjectId ? rel.targetId : rel.sourceId;
    final other = provider.persons[otherId];
    final name =
        (other?.name.isNotEmpty == true) ? other!.name : '(unnamed)';
    final label = kRelationshipDefs[rel.type]?.label ?? rel.type.name;
    final note = rel.notes;

    // Direction arrow only useful when the relationship is directional
    // (source -> target). For symmetric ties we just show "↔".
    final outgoing = rel.sourceId == subjectId;
    final arrow = outgoing ? '→' : '←';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(arrow,
                  style: const TextStyle(
                      color: kText2, fontSize: 11,
                      fontFamily: 'monospace')),
              const SizedBox(width: 6),
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        color: kText, fontSize: 12,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 17, top: 1),
            child: Text(label,
                style: const TextStyle(
                    color: kText2, fontSize: 11,
                    fontFamily: 'monospace')),
          ),
          if (note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 17, top: 2),
              child: Text('“$note”',
                  style: const TextStyle(
                      color: kText2, fontSize: 10,
                      fontFamily: 'monospace',
                      fontStyle: FontStyle.italic)),
            ),
        ],
      ),
    );
  }
}
