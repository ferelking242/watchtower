import 'package:flutter/foundation.dart';

  class AppConfig {
    const AppConfig._();

    static const String githubToken = String.fromEnvironment(
      'GITHUB_TOKEN',
      defaultValue: '',
    );
  }
  