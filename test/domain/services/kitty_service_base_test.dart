import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lbp_ssh/domain/services/kitty_service_base.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';

class _MockTerminalSession extends Mock implements TerminalSession {}

/// 测试用子类，暴露基类的会话管理/写入能力
class _TestService extends KittyServiceBase {
  _TestService({super.session});

  /// 供测试直接验证 [writeRaw] 的转发行为
  void sendViaWriteRaw(String data) => writeRaw(data);

  /// 供测试直接验证 [writeRawIfConnected] 的转发行为
  void sendViaWriteRawIfConnected(String data) => writeRawIfConnected(data);
}

void main() {
  group('KittyServiceBase', () {
    late _MockTerminalSession mockSession;

    setUp(() {
      mockSession = _MockTerminalSession();
    });

    group('isConnected', () {
      test('returns true when session is provided', () {
        final service = _TestService(session: mockSession);
        expect(service.isConnected, isTrue);
      });

      test('returns false when session is null', () {
        final service = _TestService();
        expect(service.isConnected, isFalse);
      });
    });

    group('session getter', () {
      test('returns the session when connected', () {
        final service = _TestService(session: mockSession);
        expect(service.session, same(mockSession));
      });

      test('throws when not connected', () {
        final service = _TestService();
        expect(() => service.session, throwsA(isA<Exception>()));
      });
    });

    group('sessionOrNull', () {
      test('returns the session when connected', () {
        final service = _TestService(session: mockSession);
        expect(service.sessionOrNull, same(mockSession));
      });

      test('returns null when not connected', () {
        final service = _TestService();
        expect(service.sessionOrNull, isNull);
      });
    });

    group('writeRaw', () {
      test('forwards data to the session when connected', () {
        final service = _TestService(session: mockSession);
        service.sendViaWriteRaw('test-cmd');
        verify(() => mockSession.writeRaw('test-cmd')).called(1);
      });

      test('throws when not connected', () {
        final service = _TestService();
        expect(
          () => service.sendViaWriteRaw('test-cmd'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('writeRawIfConnected', () {
      test('forwards data to the session when connected', () {
        final service = _TestService(session: mockSession);
        service.sendViaWriteRawIfConnected('test-cmd');
        verify(() => mockSession.writeRaw('test-cmd')).called(1);
      });

      test('silently ignores when not connected', () {
        final service = _TestService();
        expect(
          () => service.sendViaWriteRawIfConnected('test-cmd'),
          returnsNormally,
        );
      });
    });
  });
}
