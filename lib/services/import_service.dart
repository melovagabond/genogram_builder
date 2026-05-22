import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../constants/app_theme.dart';
import '../models/genogram_state.dart';
import '../models/person.dart';
import '../providers/genogram_provider.dart';

enum _ImportMode { clear, merge, mergeAll }

class ImportService {
  static Future<void> importFromJson(
    BuildContext context,
    GenogramProvider provider,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        if (context.mounted) _snack(context, 'Could not read file');
        return;
      }

      final jsonString = String.fromCharCodes(file.bytes!);
      final Map<String, dynamic> data;
      try {
        data = jsonDecode(jsonString) as Map<String, dynamic>;
      } catch (_) {
        if (context.mounted) _snack(context, 'Invalid JSON file');
        return;
      }
      final incoming = GenogramState.fromJson(data);

      if (!context.mounted) return;
      final mode = await _askMode(context, provider, incoming);
      if (mode == null) return;

      switch (mode) {
        case _ImportMode.clear:
          if (!context.mounted) return;
          final ok = await _confirmDanger(
            context,
            title: 'Clear & Import',
            body:
                'This will discard the current genogram and replace it with the imported file. '
                'You may lose unsaved work. Continue?',
            confirmLabel: 'CLEAR & IMPORT',
          );
          if (!ok) return;
          provider.importJson(jsonString);
          if (context.mounted) _snack(context, 'Imported (replaced)');
          return;

        case _ImportMode.mergeAll:
          if (!context.mounted) return;
          final ok = await _confirmDanger(
            context,
            title: 'Merge All (auto)',
            body:
                'This will auto-match incoming people to your existing genogram by name '
                'and birth year. Incorrect matches may merge unrelated people. '
                'You may lose data on poor matches. Continue?',
            confirmLabel: 'MERGE ALL',
          );
          if (!ok) return;
          final map = _autoMatch(provider.state.persons, incoming.persons);
          provider.mergeImport(incoming, map);
          if (context.mounted) {
            _snack(context,
                'Merged: ${map.length} matched, ${incoming.persons.length - map.length} added');
          }
          return;

        case _ImportMode.merge:
          if (!context.mounted) return;
          final map = await _interactiveMerge(
            context,
            existing: provider.state.persons,
            incoming: incoming.persons,
          );
          if (map == null) return; // cancelled
          provider.mergeImport(incoming, map);
          if (context.mounted) {
            _snack(context,
                'Merged: ${map.length} matched, ${incoming.persons.length - map.length} added');
          }
          return;
      }
    } catch (e) {
      if (context.mounted) _snack(context, 'Import failed: $e');
    }
  }

  // --------------------------------------------------------------
  // Dialogs
  // --------------------------------------------------------------
  static Future<_ImportMode?> _askMode(
    BuildContext context,
    GenogramProvider provider,
    GenogramState incoming,
  ) {
    final existingCount = provider.state.persons.length;
    return showDialog<_ImportMode>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text('Import Genogram',
            style: TextStyle(color: kText, fontFamily: 'monospace')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Incoming: ${incoming.persons.length} people, '
              '${incoming.relationships.length} relationships.\n'
              'Current: $existingCount people.',
              style: const TextStyle(color: kText2, fontSize: 12),
            ),
            const SizedBox(height: 16),
            _modeTile(
              ctx,
              icon: Icons.delete_forever,
              color: kAccentRed,
              title: 'CLEAR & IMPORT',
              body: 'Replace everything. Existing data is discarded.',
              onTap: () => Navigator.pop(ctx, _ImportMode.clear),
            ),
            const SizedBox(height: 8),
            _modeTile(
              ctx,
              icon: Icons.merge_type,
              color: kAccent,
              title: 'MERGE',
              body:
                  'Walk through each potential match. You confirm matches one by one.',
              onTap: () => Navigator.pop(ctx, _ImportMode.merge),
            ),
            const SizedBox(height: 8),
            _modeTile(
              ctx,
              icon: Icons.auto_fix_high,
              color: kAccentOrange,
              title: 'MERGE ALL (auto)',
              body:
                  'Auto-pick best matches by name + birth year. Faster, but riskier.',
              onTap: () => Navigator.pop(ctx, _ImportMode.mergeAll),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: kText2)),
          ),
        ],
      ),
    );
  }

  static Widget _modeTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String body,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: kSurface2,
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: color,
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  Text(body,
                      style: const TextStyle(color: kText2, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<bool> _confirmDanger(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: kAccentRed),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(color: kText, fontFamily: 'monospace')),
        ]),
        content: Text(body, style: const TextStyle(color: kText2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL', style: TextStyle(color: kText2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel,
                style: const TextStyle(
                    color: kAccentRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  /// Walk every incoming person that has at least one name-match candidate
  /// among existing persons. Returns null if the user cancels, otherwise a
  /// map of incoming id -> existing id for confirmed matches.
  static Future<Map<String, String>?> _interactiveMerge(
    BuildContext context, {
    required Map<String, Person> existing,
    required Map<String, Person> incoming,
  }) async {
    final map = <String, String>{};
    final usedExisting = <String>{};

    final entries = incoming.entries.toList();
    for (var i = 0; i < entries.length; i++) {
      final inc = entries[i].value;
      final candidates = _candidatesFor(inc, existing)
          .where((id) => !usedExisting.contains(id))
          .toList();
      if (candidates.isEmpty) continue;

      if (!context.mounted) return null;
      final result = await _askMatch(
        context,
        incoming: inc,
        candidates: [for (final id in candidates) existing[id]!],
        progress: '${i + 1} / ${entries.length}',
      );
      if (result == null) return null; // cancelled
      if (result == _kSkipAll) break; // stop, keep matches so far
      if (result == _kSkipOne) continue;
      map[inc.id] = result;
      usedExisting.add(result);
    }
    return map;
  }

  static const String _kSkipOne = '__skip_one__';
  static const String _kSkipAll = '__skip_all__';

  static Future<String?> _askMatch(
    BuildContext context, {
    required Person incoming,
    required List<Person> candidates,
    required String progress,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        title: Row(children: [
          const Icon(Icons.compare_arrows, color: kAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Possible match  ($progress)',
                style: const TextStyle(
                    color: kText, fontFamily: 'monospace', fontSize: 13)),
          ),
        ]),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Incoming person',
                    style: TextStyle(color: kText2, fontSize: 11)),
                const SizedBox(height: 4),
                _personCard(incoming, accent: kAccentOrange),
                const SizedBox(height: 12),
                const Text('Is this the same as any existing person?',
                    style: TextStyle(color: kText, fontSize: 12)),
                const SizedBox(height: 8),
                ...candidates.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx, c.id),
                      child:
                          _personCard(c, accent: kAccentGreen, showTapHint: true),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _kSkipOne),
            child: const Text('ADD AS NEW',
                style: TextStyle(color: kAccent, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _kSkipAll),
            child: const Text('STOP', style: TextStyle(color: kText2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('CANCEL', style: TextStyle(color: kAccentRed)),
          ),
        ],
      ),
    );
  }

  static Widget _personCard(Person p,
      {required Color accent, bool showTapHint = false}) {
    String fieldRow(String label, String value) =>
        '$label: ${value.isEmpty ? '—' : value}';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kSurface2,
        border: Border.all(color: accent.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(p.name.isEmpty ? '(no name)' : p.name,
                  style: TextStyle(
                      color: accent,
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
            if (showTapHint)
              const Text('TAP TO MATCH',
                  style: TextStyle(
                      color: kText3, fontSize: 9, letterSpacing: 1.2)),
          ]),
          const SizedBox(height: 4),
          Text(
            [
              fieldRow('gender', p.gender.name),
              fieldRow('birth', p.birthYear?.toString() ?? ''),
              fieldRow('death', p.deathYear?.toString() ?? ''),
              fieldRow('gen', p.generation.toString()),
              if (p.notes.isNotEmpty) fieldRow('notes', p.notes),
            ].join('   ·   '),
            style: const TextStyle(
                color: kText2, fontSize: 11, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------
  // Matching
  // --------------------------------------------------------------
  /// Auto-match incoming -> existing by score. Each existing person can be
  /// matched to at most one incoming person.
  static Map<String, String> _autoMatch(
    Map<String, Person> existing,
    Map<String, Person> incoming,
  ) {
    final pairs = <_MatchPair>[];
    for (final inc in incoming.values) {
      for (final ex in existing.values) {
        final score = _score(inc, ex);
        if (score >= 4) {
          pairs.add(_MatchPair(inc.id, ex.id, score));
        }
      }
    }
    pairs.sort((a, b) => b.score.compareTo(a.score));
    final result = <String, String>{};
    final usedExisting = <String>{};
    final usedIncoming = <String>{};
    for (final p in pairs) {
      if (usedIncoming.contains(p.incomingId)) continue;
      if (usedExisting.contains(p.existingId)) continue;
      result[p.incomingId] = p.existingId;
      usedIncoming.add(p.incomingId);
      usedExisting.add(p.existingId);
    }
    return result;
  }

  /// Candidate existing IDs for an incoming person -- requires at least
  /// a shared first or last name token. Sorted by score descending.
  static List<String> _candidatesFor(
      Person incoming, Map<String, Person> existing) {
    final scored = <MapEntry<String, int>>[];
    for (final ex in existing.values) {
      final score = _score(incoming, ex);
      if (score >= 2) scored.add(MapEntry(ex.id, score));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in scored) e.key];
  }

  static int _score(Person a, Person b) {
    final at = _nameTokens(a.name);
    final bt = _nameTokens(b.name);
    if (at.isEmpty || bt.isEmpty) return 0;
    var s = 0;
    final aFirst = at.first;
    final bFirst = bt.first;
    final aLast = at.last;
    final bLast = bt.last;
    if (aFirst == bFirst) s += 2;
    if (at.length > 1 && bt.length > 1 && aLast == bLast) s += 2;
    if (a.birthYear != null && a.birthYear == b.birthYear) s += 2;
    if (a.deathYear != null && a.deathYear == b.deathYear) s += 1;
    if (a.gender == b.gender) s += 1;
    return s;
  }

  static List<String> _nameTokens(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();

  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: kText)),
        backgroundColor: kSurface2,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _MatchPair {
  final String incomingId;
  final String existingId;
  final int score;
  _MatchPair(this.incomingId, this.existingId, this.score);
}
