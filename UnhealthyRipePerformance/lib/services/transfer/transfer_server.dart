// Conditional export — web gets the no-op stub, native gets shelf_io impl.
export 'transfer_server_stub.dart'
    if (dart.library.io) 'transfer_server_io.dart';
