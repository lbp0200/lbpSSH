import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/utils/sentry_service.dart';
import 'package:sentry/sentry.dart';

/// 无网络 transport：接收事件后立即完成，避免真实 HTTP 请求挂起
class _NoOpTransport implements Transport {
  @override
  Future<SentryId?> send(SentryEnvelope envelope) async =>
      const SentryId.empty();
}

void main() {
  group('SentryService', () {
    test('is a singleton', () {
      final instance1 = SentryService();
      final instance2 = SentryService();
      expect(instance1, same(instance2));
    });

    test('init with empty DSN does not throw', () async {
      final service = SentryService();
      await service.init(dsn: '');
      // Should complete without throwing
    });

    test('captureException before init does not throw', () async {
      final service = SentryService();
      await service.captureException(Exception('test error'));
      // Should complete without throwing
    });

    test('double init with empty DSN does not throw', () async {
      final service = SentryService();
      await service.init(dsn: '');
      await service.init(dsn: '');
      // Should complete without throwing
    });

    test('captureException on uninitialised service does not throw', () async {
      final service = SentryService();
      await service.init(dsn: '');
      await service.captureException(Exception('after empty init'));
      // Should complete without throwing
    });

    test('init with valid DSN initializes the service', () async {
      final service = SentryService();
      await service.init(
        dsn: 'https://valid-dsn@sentry.io/1',
        transport: _NoOpTransport(),
      );
      // Should complete without throwing; Sentry.init was invoked
    });

    test('captureException after init does not throw', () async {
      final service = SentryService();
      await service.init(
        dsn: 'https://valid-dsn@sentry.io/1',
        transport: _NoOpTransport(),
      );
      await service.captureException(
        Exception('after init'),
        stackTrace: StackTrace.current,
      );
      // Should complete without throwing
    });
  });
}
