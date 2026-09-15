library phosphor_flutter;

import 'package:flutter/widgets.dart';

// Flutter 3.47 made IconData final. Keep the public type names as aliases so
// existing FlixQuest and Watchtower code continues to compile, while the
// generated icon constants use IconData directly.
typedef PhosphorIconData = IconData;
typedef PhosphorFlatIconData = IconData;
typedef PhosphorDuotoneIconData = IconData;
