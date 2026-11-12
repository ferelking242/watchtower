part of '../database.dart';

class ColorConverter extends TypeConverter<Color, int> {
  const ColorConverter();

  @override
  Color fromSql(int fromDb) {
    return Color(fromDb);
  }

  @override
  int toSql(Color value) {
    return value.toARGB32();
  }
}

/// Accent colour persisted with the music module's own preferences.
///
/// The music module no longer offers its own colour picker: it follows the
/// app-wide theme chosen in Watchtower → Réglages → Apparence. The stored
/// value is kept as-is so existing databases keep loading; the format is
/// `name:argb` (e.g. `green:0xff4caf50`).
class MusicAccentColor extends Color {
  final String name;

  const MusicAccentColor(super.color, {required this.name});

  factory MusicAccentColor.fromString(String string) {
    final slices = string.split(":");
    return MusicAccentColor(int.parse(slices.last), name: slices.first);
  }

  @override
  String toString() {
    return "$name:${toARGB32()}";
  }
}

class MusicAccentColorConverter
    extends TypeConverter<MusicAccentColor, String> {
  const MusicAccentColorConverter();

  @override
  MusicAccentColor fromSql(String fromDb) {
    return MusicAccentColor.fromString(fromDb);
  }

  @override
  String toSql(MusicAccentColor value) {
    return value.toString();
  }
}
