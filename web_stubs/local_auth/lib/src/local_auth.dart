class LocalAuthentication {
  Future<bool> get canCheckBiometrics async => false;
  Future<bool> isDeviceSupported() async => false;
  Future<List<BiometricType>> getAvailableBiometrics() async => [];
  Future<bool> authenticate({
    required String localizedReason,
    bool biometricOnly = false,
    bool persistAcrossBackgrounding = true,
    bool stickyAuth = false,
    bool sensitiveTransaction = true,
    bool useErrorDialogs = true,
  }) async => true;
  Future<bool> stopAuthentication() async => true;
}

enum BiometricType { face, fingerprint, iris, strong, weak }
