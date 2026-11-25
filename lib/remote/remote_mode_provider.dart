
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
  final String? tunnelProvider;
  final String? tunnelError;
  final double? downloadProgress;
  final String? apiKey;
  final String? publicUrl;
  final bool exposeNsfw;
  const RemoteModeState({
    this.isRunning = false,
    this.localUrl,
    this.tunnelUrl,
    this.tunnelProvider,
    this.tunnelError,
    this.downloadProgress,
    this.apiKey,
    this.publicUrl,
    this.exposeNsfw = false,
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
      tunnelProvider: RemoteServerService.instance.tunnelProvider,
      tunnelError: RemoteServerService.instance.tunnelError,
      downloadProgress: RemoteServerService.instance.downloadProgress,
      apiKey: RemoteServerService.instance.apiKey,
      publicUrl: await RemoteServerService.instance.loadPublicUrl(),
      exposeNsfw: RemoteServerService.instance.exposeNsfw,
    );
  }

  void _onServerChange() {
    final current = state.asData?.value;
    state = AsyncValue.data(RemoteModeState(
      isRunning: RemoteServerService.instance.isRunning,
      localUrl: RemoteServerService.instance.localUrl,
      tunnelUrl: RemoteServerService.instance.tunnelUrl,
      tunnelProvider: RemoteServerService.instance.tunnelProvider,
      tunnelError: RemoteServerService.instance.tunnelError,
      downloadProgress: RemoteServerService.instance.downloadProgress,
      apiKey: RemoteServerService.instance.apiKey,
      publicUrl: current?.publicUrl,
      exposeNsfw: RemoteServerService.instance.exposeNsfw,
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

  Future<void> setExposeNsfw(bool value) async {
    await RemoteServerService.instance.setExposeNsfw(value);
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncValue.data(RemoteModeState(
      isRunning: current.isRunning,
      localUrl: current.localUrl,
      tunnelUrl: current.tunnelUrl,
      tunnelProvider: current.tunnelProvider,
      tunnelError: current.tunnelError,
      downloadProgress: current.downloadProgress,
      apiKey: current.apiKey,
      publicUrl: current.publicUrl,
      exposeNsfw: value,
    ));
  }

  Future<void> retryTunnel() async {
    await RemoteServerService.instance.restartTunnel();
  }

  Future<void> setPublicUrl(String? url) async {
    await RemoteServerService.instance.setPublicUrl(url);
    final current = state.asData?.value;
    if (current == null) return;
    final clean = (url == null || url.trim().isEmpty) ? null : url.trim();
    state = AsyncValue.data(RemoteModeState(
      isRunning: current.isRunning,
      localUrl: current.localUrl,
      tunnelUrl: current.tunnelUrl,
      tunnelProvider: current.tunnelProvider,
      tunnelError: current.tunnelError,
      downloadProgress: current.downloadProgress,
      apiKey: current.apiKey,
      publicUrl: clean,
      exposeNsfw: current.exposeNsfw,
    ));
  }
}

final remoteModeProvider =
    AsyncNotifierProvider<RemoteModeNotifier, RemoteModeState>(
        RemoteModeNotifier.new);
