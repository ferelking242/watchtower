import 'package:dio/dio.dart';
import 'package:watchtower/services/connectivity_service.dart';

/// Rejects a request immediately while the device has no Internet.
///
/// Without it every lyrics/metadata call still opens a socket, waits for the
/// OS DNS timeout and finally throws a raw `SocketException`; with it the call
/// fails at once with a typed, human-readable error, so callers can show the
/// "no connection" surface instead of a bug-looking trace. Requests resume by
/// themselves the moment the connection is back — nothing is queued here.
class OfflineGateInterceptor extends Interceptor {
  const OfflineGateInterceptor();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (ConnectivityService.instance.isOffline) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: const OfflineRequestError(),
          message: 'No Internet connection',
        ),
      );
      return;
    }
    handler.next(options);
  }
}

final globalDio = Dio()..interceptors.add(const OfflineGateInterceptor());
