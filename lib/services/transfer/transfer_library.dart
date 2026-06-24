// Conditional export — web gets the no-op stub, native gets Isar impl.
export 'transfer_library_stub.dart'
    if (dart.library.io) 'transfer_library_io.dart';
