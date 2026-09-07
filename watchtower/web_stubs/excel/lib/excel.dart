// Web stub for excel — NFile document viewer is never accessed on Flutter Web.
import 'dart:typed_data';

class Excel {
  final Map<String, Sheet> tables = {};

  static Excel decodeBytes(List<int> bytes) => Excel._();
  static Excel decodeBuffer(Uint8List bytes) => Excel._();
  static Excel createExcel() => Excel._();

  Excel._();
}

class Sheet {
  final String sheetName;
  final List<List<Data?>> rows = [];
  Sheet(this.sheetName);
}

class Data {
  final dynamic value;
  Data(this.value);
}
