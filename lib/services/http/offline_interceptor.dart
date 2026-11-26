import 'package:http_interceptor/http_interceptor.dart';
import 'package:watchtower/services/connectivity_service.dart';

/// Refuses extension requests immediately when the app knows it is offline.
///
/// Without this, every cached-screen rebuild that still asks for remote data
/// paid a 30–60 s socket timeout and made the UI feel frozen. Local addresses
/// are always allowed (remote server / extension tester).
class OfflineInterceptor extends InterceptorContract {
  OfflineInterceptor();

  @override
  Future<BaseRequest> interceptRequest({required BaseRequest request}) async {
    final host = request.url.host;
    if (host == 'localhost' || host == '127.0.0.1') return request;
    if (ConnectivityService.instance.isOffline) {
      throw const OfflineRequestError();
    }
    return request;
  }

  @override
  Future<BaseResponse> interceptResponse({
    required BaseResponse response,
  }) async => response;
}
