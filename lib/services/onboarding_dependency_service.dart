import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/foundation.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/services/download_manager/engines/aria2_binary_manager.dart';
import 'package:watchtower/services/download_manager/m3u8/ffmpeg_binary_manager.dart';
import 'package:watchtower/services/mpv_config_service.dart';

enum OnboardingDependencyId { ffmpeg, mpv, aria2 }

class OnboardingDependencyInfo {
  final OnboardingDependencyId id;
  final String name;
  final String purpose;
  final String alternative;
  final bool required;
  final bool bundled;

  const OnboardingDependencyInfo({
    required this.id,
    required this.name,
    required this.purpose,
    required this.alternative,
    required this.required,
    required this.bundled,
  });
}

class OnboardingDependencyService {
  OnboardingDependencyService._();

  static const catalog = <OnboardingDependencyInfo>[
    OnboardingDependencyInfo(
      id: OnboardingDependencyId.ffmpeg,
      name: 'FFmpeg runtime',
      purpose: 'Fusionner les fragments TS en fichiers MP4 lisibles.',
      alternative: 'La concaténation directe des fragments reste disponible sans exécutable FFmpeg.',
      required: false,
      bundled: false,
    ),
    OnboardingDependencyInfo(
      id: OnboardingDependencyId.mpv,
      name: 'Configuration MPV',
      purpose: 'Télécharge uniquement mpv.conf, input.conf et les réglages avancés.',
      alternative: 'Le moteur MPV est déjà fourni par l’application.',
      required: false,
      bundled: false,
    ),
    OnboardingDependencyInfo(
      id: OnboardingDependencyId.aria2,
      name: 'aria2c',
      purpose: 'Téléchargements multi-connexions plus rapides et reprise réseau.',
      alternative: 'Le téléchargeur interne est installé et ne nécessite rien.',
      required: false,
      bundled: false,
    ),
  ];

  static Future<bool> isInstalled(OnboardingDependencyId id) async {
    switch (id) {
      case OnboardingDependencyId.ffmpeg:
        return await FfmpegBinaryManager.instance.isInstalled();
      case OnboardingDependencyId.mpv:
        if (kIsWeb) return true;
        final directory = await StorageProvider().getMpvDirectory();
        if (directory == null) return false;
        return await File('${directory.path}/mpv.conf').exists() &&
            await File('${directory.path}/input.conf').exists();
      case OnboardingDependencyId.aria2:
        return await Aria2BinaryManager.instance.isInstalled();
    }
  }

  static Future<void> install(OnboardingDependencyId id) async {
    switch (id) {
      case OnboardingDependencyId.ffmpeg:
        if (await FfmpegBinaryManager.instance.resolveExecutable() == null) {
          throw const OnboardingDependencyException(
            'FFmpeg runtime absent. Installez un binaire vérifié dans le '
            'stockage privé de Watchtower avant une fusion HLS.',
          );
        }
        return;
      case OnboardingDependencyId.mpv:
        final directory = await StorageProvider().getMpvDirectory();
        if (directory == null) {
          throw const OnboardingDependencyException(
            'Le dossier MPV est indisponible sur cet appareil.',
          );
        }
        await MpvConfigService.install(directory);
      case OnboardingDependencyId.aria2:
        final path = await Aria2BinaryManager.instance.resolveExecutable();
        if (path == null) {
          throw const OnboardingDependencyException(
            'Aucun binaire aria2c compatible avec cet appareil n’a été trouvé.',
          );
        }
    }
  }
}

class OnboardingDependencyException implements Exception {
  final String message;

  const OnboardingDependencyException(this.message);

  @override
  String toString() => message;
}