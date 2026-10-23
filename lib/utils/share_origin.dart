import 'package:flutter/widgets.dart';

/// Rectangle d'ancrage de la feuille de partage sur iPad.
///
/// iOS présente le partage dans un popover : sans origine, il s'affiche au
/// centre de l'écran, voire bloque l'interface sur les anciennes versions.
Rect? sharePositionOriginFor(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}
