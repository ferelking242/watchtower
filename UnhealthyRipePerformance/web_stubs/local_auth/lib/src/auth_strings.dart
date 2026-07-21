class AndroidAuthMessages {
  const AndroidAuthMessages({
    this.biometricHint,
    this.biometricNotRecognized,
    this.biometricRequiredTitle,
    this.biometricSuccess,
    this.cancelButton,
    this.deviceCredentialsRequiredTitle,
    this.deviceCredentialsSetupDescription,
    this.goToSettingsButton,
    this.goToSettingsDescription,
    this.negativeButton,
    this.signInTitle,
  });
  final String? biometricHint;
  final String? biometricNotRecognized;
  final String? biometricRequiredTitle;
  final String? biometricSuccess;
  final String? cancelButton;
  final String? deviceCredentialsRequiredTitle;
  final String? deviceCredentialsSetupDescription;
  final String? goToSettingsButton;
  final String? goToSettingsDescription;
  final String? negativeButton;
  final String? signInTitle;
}

class IOSAuthMessages {
  const IOSAuthMessages({
    this.goToSettingsButton,
    this.goToSettingsDescription,
    this.cancelButton,
    this.localizedFallbackTitle,
    this.lockOut,
  });
  final String? goToSettingsButton;
  final String? goToSettingsDescription;
  final String? cancelButton;
  final String? localizedFallbackTitle;
  final String? lockOut;
}
