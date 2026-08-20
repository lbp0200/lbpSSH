import 'package:sentry/sentry.dart';

class SentryService {
  static final SentryService _instance = SentryService._internal();
  factory SentryService() => _instance;
  SentryService._internal();

  bool _isInitialized = false;

  Future<void> init({required String dsn, Transport? transport}) async {
    if (_isInitialized || dsn.isEmpty) return;
    await Sentry.init((options) {
      options.dsn = dsn;
      options.environment = 'production';
      // 测试时可注入无网络 transport，避免真实 HTTP 请求
      if (transport != null) {
        options.transport = transport;
      }
    });
    _isInitialized = true;
  }

  Future<void> captureException(Object e, {StackTrace? stackTrace}) async {
    if (!_isInitialized) return;
    await Sentry.captureException(e, stackTrace: stackTrace);
  }
}
