import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/custom_button.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'custom_buttons_provider.g.dart';

@riverpod
Stream<List<CustomButton>> getCustomButtonsStream(Ref ref) async* {
  yield* isar.customButtons.filter().idIsNotNull().sortByPos().watch(
    fireImmediately: true,
  );
}
