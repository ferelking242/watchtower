import 'package:flutter/material.dart';

const nfBackgroundColor      = Color(0xff010101);
const nfBottomSheetColor     = Color(0xff2b2b2b);
const nfBottomSheetIconColor = Color(0xff3d3d3d);
const nfRedColor             = Color(0xffe50914);

final nfShimmerGradient = LinearGradient(
  begin: Alignment.topLeft,
  end:   Alignment.bottomRight,
  colors: <Color>[
    Colors.grey[900]!,
    Colors.grey[900]!,
    Colors.grey[800]!,
    Colors.grey[900]!,
    Colors.grey[900]!,
  ],
  stops: const <double>[0.0, 0.35, 0.5, 0.65, 1.0],
);
