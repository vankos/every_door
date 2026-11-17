// Copyright 2022-2025 Ilya Zverev
// This file is a part of Every Door, distributed under GPL v3 or later version.
// Refer to LICENSE file and https://www.gnu.org/licenses/gpl-3.0.html for details.
import 'package:eval_annotation/eval_annotation.dart';
import 'package:every_door/helpers/multi_icon.dart';
import 'package:flutter/material.dart';
import 'package:line_icons/line_icons.dart';
import 'package:every_door/generated/l10n/app_localizations.dart'
    show AppLocalizations;

@Bind()
class DrawingStyle {
  final String name;
  final Color color;
  final bool thin;
  final bool dashed;
  final MultiIcon icon;

  static const kDefaultStroke = 8.0;

  const DrawingStyle(
    this.name, {
    required this.color,
    required this.icon,
    this.thin = false,
    this.dashed = false,
  });

  double get stroke => thin ? kDefaultStroke / 2.0 : kDefaultStroke;

  Color get casing {
    return color.computeLuminance() > 0.4 ? Colors.black : Colors.white;
  }

  @override
  bool operator ==(Object other) {
    if (other is! DrawingStyle) return false;
    return name == other.name &&
        color == other.color &&
        stroke < kDefaultStroke == other.stroke < kDefaultStroke &&
        dashed == other.dashed;
  }

  @override
  int get hashCode => name.hashCode;
}

DrawingStyle styleByName(String? name) {
  if (name == 'scribble') {
    return kToolScribble;
  } else {
    final foundStyle = kDefaultTools.where((s) => s.name == name).firstOrNull;
    if (foundStyle != null) return foundStyle;
    // TODO: drawing style from plugins.
  }
  return kUnknownStyle;
}

/// Returns a localized name for a drawing style, for example for the
/// tool chooser or a list of drawings. Falls back to the internal name.
String localizedStyleName(DrawingStyle style, AppLocalizations loc) {
  switch (style.name) {
    case "scribble":
      return loc.drawScribble;
    case "eraser":
      return loc.drawEraser;
    case "road":
      return loc.drawRoad;
    case "track":
      return loc.drawTrack;
    case "footway":
      return loc.drawFootway;
    case "path":
      return loc.drawPath;
    case "cycleway":
      return loc.drawCycleway;
    case "cycleway_shared":
      return loc.drawCyclewayShared;
    case "wall":
      return loc.drawWall;
    case "fence":
      return loc.drawFence;
    case "power":
      return loc.drawPower;
    case "stream":
      return loc.drawStream;
    case "culvert":
      return loc.drawCulvert;
    default:
      return style.name;
  }
}

final kToolEraser = DrawingStyle("eraser",
    color: Colors.black54, icon: MultiIcon.font(LineIcons.eraser));
final kToolScribble = DrawingStyle("scribble",
    color: Colors.white, thin: true, icon: MultiIcon.font(Icons.draw));

final kUnknownStyleIcon = MultiIcon.font(Icons.line_axis);
final kUnknownStyle =
    DrawingStyle('', color: Colors.grey, icon: kUnknownStyleIcon);

final kDefaultTools = [
  // bottom to top, left to right, 2 columns
  DrawingStyle("road",
      color: Colors.white70, icon: MultiIcon.font(Icons.edit_road)),
  DrawingStyle("track",
      color: Colors.white70, dashed: true, icon: MultiIcon.font(Icons.forest)),

  DrawingStyle("footway",
      color: Colors.red, icon: MultiIcon.font(Icons.directions_walk)),
  DrawingStyle("path",
      color: Colors.red,
      dashed: true,
      icon: MultiIcon.font(Icons.directions_walk)),

  DrawingStyle("cycleway",
      color: Colors.purpleAccent, icon: MultiIcon.font(Icons.directions_bike)),
  DrawingStyle("power",
      color: Colors.orangeAccent,
      thin: true,
      icon: MultiIcon.font(Icons.power_input)),

  DrawingStyle("wall",
      color: Colors.yellow, thin: true, icon: MultiIcon.font(Icons.fence)),
  DrawingStyle("fence",
      color: Colors.yellow,
      dashed: true,
      thin: true,
      icon: MultiIcon.font(Icons.fence)),

  DrawingStyle("stream",
      color: Colors.lightBlue, icon: MultiIcon.font(Icons.water)),
  DrawingStyle("culvert",
      color: Colors.lightBlue, dashed: true, icon: MultiIcon.font(Icons.water)),
];
