import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/domain/services/jump_host_tunnel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JumpHostTunnel - findAvailablePort', () {
    test(
      'Given no port, When finding available port, Then returns valid port',
      () async {
        final port = await findAvailablePort();

        expect(port, greaterThan(0));
        expect(port, lessThan(65536));
      },
    );

    test(
      'Given multiple calls, When finding ports, Then returns valid ports',
      () async {
        final port1 = await findAvailablePort();
        final port2 = await findAvailablePort();

        expect(port1, greaterThan(0));
        expect(port2, greaterThan(0));
      },
    );
  });

  group('JumpHostTunnel - waitForTunnelReady', () {
    test(
      'Given open server socket, When waiting for tunnel, Then returns quickly',
      () async {
        // Start a real server to simulate ready tunnel
        final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final port = server.port;

        // waitForTunnelReady should connect successfully and return
        await expectLater(waitForTunnelReady(port), completes);

        await server.close();
      },
    );

    test(
      'Given no server, When waiting for tunnel, Then completes after timeout without throw',
      () async {
        // Find a port that is not listening (bind then close to free it, hope no one takes it)
        final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final port = server.port;
        await server.close();

        // No one is listening on this port, should timeout gracefully (no throw)
        await expectLater(waitForTunnelReady(port), completes);
      },
    );
  });
}
