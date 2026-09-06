
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:watchtower/remote/remote_api_handler.dart';
import 'package:watchtower/remote/remote_server_service.dart';

const _kBox = 'remote_mode';
const _kEnabled = 'enabled';

class RemoteModeState {
  final bool isRunning;
  final String? localUrl;
  final String? tunnelUrl;
  final String? tunnelError;
  final double? downloadProgress;
  final String? apiKey;
  const RemoteModeState({
    this.isRunning = false,
    this.localUrl,
    this.tunnelUrl,
    this.tunnelError,
    this.downloadProgress,
    this.apiKey,
  });
}

class RemoteModeNotifier extends AsyncNotifier<RemoteModeState> {
  @override
  Future<RemoteModeState> build() async {
    RemoteServerService.instance.addListener(_onServerChange);
    ref.onDispose(() => RemoteServerService.instance.removeListener(_onServerChange));
    return RemoteModeState(
      isRunning: RemoteServerService.instance.isRunning,
      localUrl: RemoteServerService.instance.localUrl,
      tunnelUrl: RemoteServerService.instance.tunnelUrl,
      tunnelError: RemoteServerService.instance.tunnelError,
      downloadProgress: RemoteServerService.instance.downloadProgress,
      apiKey: RemoteServerService.instance.apiKey,
    );
  }

  void _onServerChange() {
    state = AsyncValue.data(RemoteModeState(
      isRunning: RemoteServerService.instance.isRunning,
      localUrl: RemoteServerService.instance.localUrl,
      tunnelUrl: RemoteServerService.instance.tunnelUrl,
      tunnelError: RemoteServerService.instance.tunnelError,
      downloadProgress: RemoteServerService.instance.downloadProgress,
      apiKey: RemoteServerService.instance.apiKey,
    ));
  }

  Future<void> toggle() async {
    if (kIsWeb) return;
    if (RemoteServerService.instance.isRunning) {
      await RemoteServerService.instance.stop();
      final box = await Hive.openBox(_kBox);
      await box.put(_kEnabled, false);
    } else {
      final handler = RemoteApiHandler(ProviderContainer());
      await RemoteServerService.instance.start(handler);
      final box = await Hive.openBox(_kBox);
      await box.put(_kEnabled, true);
    }
  }

  Future<void> regenerateApiKey() async {
    await RemoteServerService.instance.regenerateApiKey();
  }
}

final remoteModeProvider =
    AsyncNotifierProvider<RemoteModeNotifier, RemoteModeState>(
        RemoteModeNotifier.new);
