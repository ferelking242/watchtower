// Conditional export — web gets the no-op stub, native gets UDP impl.
export 'transfer_discovery_stub.dart'
    if (dart.library.io) 'transfer_discovery_io.dart';
