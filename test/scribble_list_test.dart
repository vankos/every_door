// Copyright 2022-2025 Ilya Zverev
// This file is a part of Every Door, distributed under GPL v3 or later version.
// Refer to LICENSE file and https://www.gnu.org/licenses/gpl-3.0.html for details.
import 'package:every_door/helpers/draw_style.dart';
import 'package:every_door/helpers/geometry/geometry.dart';
import 'package:every_door/models/note.dart';
import 'package:every_door/screens/modes/scribble_list.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

MapDrawing _drawing(DateTime created) => MapDrawing(
      path: LineString([LatLng(59.4, 24.7), LatLng(59.401, 24.701)]),
      style: kToolScribble,
      created: created,
    );

void main() {
  test('groups drawings by day, the newest day first', () {
    final firstDay = DateTime(2026, 11, 15, 10, 30);
    final secondDay = DateTime(2026, 11, 17, 8);

    final groups = groupDrawingsByDay([
      _drawing(firstDay),
      _drawing(secondDay),
      _drawing(secondDay.add(const Duration(hours: 2))),
    ]);

    expect(groups.keys.toList(), [
      DateTime(2026, 11, 17),
      DateTime(2026, 11, 15),
    ]);
    expect(groups[DateTime(2026, 11, 17)]!.length, 2);
    expect(groups[DateTime(2026, 11, 15)]!.length, 1);
  });

  test('sorts drawings within a day, the newest first', () {
    final morning = DateTime(2026, 11, 17, 8);
    final evening = DateTime(2026, 11, 17, 21);

    final groups = groupDrawingsByDay([
      _drawing(morning),
      _drawing(evening),
    ]);

    final day = groups[DateTime(2026, 11, 17)]!;
    expect(day.length, 2);
    expect(day.first.created, evening);
    expect(day.last.created, morning);
  });

  test('returns an empty map when there is nothing to show', () {
    expect(groupDrawingsByDay([]), isEmpty);
  });
}
