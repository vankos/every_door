// Copyright 2022-2025 Ilya Zverev
// This file is a part of Every Door, distributed under GPL v3 or later version.
// Refer to LICENSE file and https://www.gnu.org/licenses/gpl-3.0.html for details.
import 'dart:math' as math;

import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:every_door/constants.dart';
import 'package:every_door/helpers/draw_style.dart';
import 'package:every_door/models/note.dart';
import 'package:every_door/providers/notes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:every_door/generated/l10n/app_localizations.dart'
    show AppLocalizations;

/// Groups drawings by the local calendar day they were created on.
/// Days go from the newest to the oldest, and drawings inside a day
/// are sorted from the newest to the oldest as well.
Map<DateTime, List<MapDrawing>> groupDrawingsByDay(
    Iterable<MapDrawing> drawings) {
  final unsorted = <DateTime, List<MapDrawing>>{};
  for (final drawing in drawings) {
    final day = DateTime(
        drawing.created.year, drawing.created.month, drawing.created.day);
    (unsorted[day] ??= []).add(drawing);
  }

  final days = unsorted.keys.toList()..sort((a, b) => b.compareTo(a));
  return {
    for (final day in days)
      day: unsorted[day]!..sort((a, b) => b.created.compareTo(a.created)),
  };
}

/// A sheet listing the user's own scribbles, grouped by day,
/// with a button to delete all scribbles of a day.
class ScribbleListSheet extends ConsumerStatefulWidget {
  /// Called with the drawings deleted from the database, so that the map
  /// can be refreshed without waiting for it.
  final void Function(Iterable<MapDrawing>)? onDeleted;

  const ScribbleListSheet({super.key, this.onDeleted});

  @override
  ConsumerState<ScribbleListSheet> createState() => _ScribbleListSheetState();
}

class _ScribbleListSheetState extends ConsumerState<ScribbleListSheet> {
  List<MapDrawing>? _drawings;

  @override
  void initState() {
    super.initState();
    _loadDrawings();
  }

  Future<void> _loadDrawings() async {
    final drawings = await ref.read(notesProvider.notifier).fetchMyDrawings();
    if (mounted) setState(() => _drawings = drawings);
  }

  /// Formats a day for the day group header. Uses Material localizations,
  /// so it works for every language the app supports.
  String _formatDay(DateTime day) =>
      MaterialLocalizations.of(context).formatFullDate(day);

  /// Formats a day for the deletion dialog, short enough to be a part
  /// of a sentence.
  String _formatShortDay(DateTime day) =>
      MaterialLocalizations.of(context).formatShortDate(day);

  String _formatTime(DateTime date) => MaterialLocalizations.of(context)
      .formatTimeOfDay(TimeOfDay.fromDateTime(date));

  String _dayLabel(DateTime day, AppLocalizations loc) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return loc.notesScribblesToday;
    if (day == DateTime(now.year, now.month, now.day - 1))
      return loc.notesScribblesYesterday;
    return _formatDay(day);
  }

  Future<void> _deleteDay(DateTime day, List<MapDrawing> drawings) async {
    final loc = AppLocalizations.of(context)!;
    final answer = await showOkCancelAlertDialog(
      context: context,
      title: loc.notesScribblesDeleteDay,
      message: loc.notesScribblesDeleteDayMessage(_formatShortDay(day)),
      okLabel: loc.notesDelete,
      cancelLabel: MaterialLocalizations.of(context).cancelButtonLabel,
      isDestructiveAction: true,
    );
    if (answer != OkCancelResult.ok) return;

    await ref.read(notesProvider.notifier).deleteDrawings(drawings);
    widget.onDeleted?.call(drawings);
    if (!mounted) return;
    final deleted = drawings.toSet();
    setState(() {
      _drawings?.removeWhere(deleted.contains);
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 4.0, top: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    loc.notesScribblesTitle,
                    style: TextStyle(fontSize: kFieldFontSize + 2),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(height: 1.0),
          Flexible(child: _buildContent(loc)),
        ],
      ),
    );
  }

  Widget _buildContent(AppLocalizations loc) {
    final drawings = _drawings;
    if (drawings == null)
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(child: CircularProgressIndicator()),
      );

    if (drawings.isEmpty)
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
        child: Text(
          loc.notesScribblesEmpty,
          textAlign: TextAlign.center,
          style: kFieldTextStyle,
        ),
      );

    final groups = groupDrawingsByDay(drawings);
    return ListView(
      shrinkWrap: true,
      children: [
        for (final day in groups.keys) ...[
          _buildDayHeader(day, groups[day]!, loc),
          for (final drawing in groups[day]!)
            ListTile(
              dense: true,
              leading: ScribblePreview(drawing: drawing),
              title: Text(localizedStyleName(drawing.style, loc)),
              subtitle: Text(_formatTime(drawing.created)),
            ),
        ],
        SizedBox(height: 16.0),
      ],
    );
  }

  Widget _buildDayHeader(
      DateTime day, List<MapDrawing> drawings, AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 4.0, 0.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _dayLabel(day, loc),
                  style: TextStyle(
                    fontSize: kFieldFontSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  loc.notesScribblesCount(drawings.length),
                  style: TextStyle(
                    fontSize: kFieldFontSize - 4.0,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete),
            color: Colors.red,
            tooltip: loc.notesDelete,
            onPressed: () {
              _deleteDay(day, drawings);
            },
          ),
        ],
      ),
    );
  }
}

/// A small picture of a scribble, to make the list more recognizable.
class ScribblePreview extends StatelessWidget {
  final MapDrawing drawing;
  final double size;

  const ScribblePreview({super.key, required this.drawing, this.size = 48.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: CustomPaint(painter: ScribblePreviewPainter(drawing)),
    );
  }
}

class ScribblePreviewPainter extends CustomPainter {
  final MapDrawing drawing;

  const ScribblePreviewPainter(this.drawing);

  static const kPadding = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final nodes = drawing.path.nodes;
    final width = size.width - kPadding * 2;
    final height = size.height - kPadding * 2;
    if (nodes.length < 2 || width <= 0 || height <= 0) return;

    final bounds = drawing.path.bounds;
    final latSpan = bounds.north - bounds.south;
    // Longitudes shrink towards the poles, compensate for that.
    final lonFactor = math.cos(bounds.center.latitude * math.pi / 180.0);
    final lonSpan = (bounds.east - bounds.west) * lonFactor;

    final scaleX = lonSpan > 0 ? width / lonSpan : double.infinity;
    final scaleY = latSpan > 0 ? height / latSpan : double.infinity;
    final scale = math.min(scaleX, scaleY);
    final usedScale = scale.isFinite ? scale : 1.0;

    final dx = kPadding + (width - lonSpan * usedScale) / 2;
    final dy = kPadding + (height - latSpan * usedScale) / 2;

    final path = Path();
    for (int i = 0; i < nodes.length; i++) {
      final x = dx + (nodes[i].longitude - bounds.west) * lonFactor * usedScale;
      final y =
          size.height - dy - (nodes[i].latitude - bounds.south) * usedScale;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final stroke = math.max(size.width / 24.0, 1.5);
    final casing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke + 1.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = drawing.style.casing.withValues(alpha: 0.5);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = drawing.style.color;

    canvas.drawPath(path, casing);
    canvas.drawPath(
        drawing.style.dashed
            ? dashPath(path,
                dashArray: CircularIntervalList<double>([4.0, 4.0]))
            : path,
        paint);
  }

  @override
  bool shouldRepaint(covariant ScribblePreviewPainter oldDelegate) =>
      oldDelegate.drawing != drawing;
}
