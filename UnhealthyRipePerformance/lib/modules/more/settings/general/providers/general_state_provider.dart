import 'package:watchtower/main.dart';
import 'package:watchtower/models/settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:watchtower/utils/constant.dart';
part 'general_state_provider.g.dart';

@riverpod
class CustomDnsState extends _$CustomDnsState {
  @override
  String build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).customDns ?? "";
  }

  void set(String value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..customDns = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class EnableDiscordRpcState extends _$EnableDiscordRpcState {
  @override
  bool build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).enableDiscordRpc ?? true;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..enableDiscordRpc = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class HideDiscordRpcInIncognitoState extends _$HideDiscordRpcInIncognitoState {
  @override
  bool build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).hideDiscordRpcInIncognito ?? true;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..hideDiscordRpcInIncognito = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class RpcShowReadingWatchingProgressState
    extends _$RpcShowReadingWatchingProgressState {
  @override
  bool build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).rpcShowReadingWatchingProgress ?? true;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..rpcShowReadingWatchingProgress = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class RpcShowTitleState extends _$RpcShowTitleState {
  @override
  bool build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).rpcShowTitle ?? true;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..rpcShowTitle = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class RpcShowCoverImageState extends _$RpcShowCoverImageState {
  @override
  bool build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).rpcShowCoverImage ?? true;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..rpcShowCoverImage = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class UserAgentState extends _$UserAgentState {
  @override
  String build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).userAgent!;
  }

  void set(String value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..userAgent = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
