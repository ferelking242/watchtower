import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/models/database/database.dart';

final databaseProvider = Provider((ref) => AppDatabase());
