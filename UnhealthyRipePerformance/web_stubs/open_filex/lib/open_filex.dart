// Web stub for open_filex — native file opening not available on Flutter Web.

enum ResultType { done, fileNotFound, noAppToOpen, permissionDenied, error }

class OpenResult {
  final ResultType type;
  final String message;
  OpenResult({required this.type, required this.message});
}

class OpenFilex {
  static Future<OpenResult> open(String? filePath, {String? type, String? uti}) async =>
      OpenResult(
        type: ResultType.error,
        message: 'open_filex not available on Flutter Web',
      );
}
