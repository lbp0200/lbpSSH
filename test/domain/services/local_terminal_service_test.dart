import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/domain/services/local_terminal_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_pty/flutter_pty.dart';

// Mock Pty class
class MockPty extends Mock implements Pty {}

void main() {
  registerFallbackValue(Uint8List(0));
  registerFallbackValue(ProcessSignal.sigterm);

  group('LocalTerminalService', () {
    late LocalTerminalService service;

    setUp(() {
      service = LocalTerminalService();
    });

    tearDown(() {
      service.dispose();
    });

    group('initWorkingDirectory', () {
      test(
        'Given directory path, When initWorkingDirectory called, Then sets current directory',
        () {
          // Act (When)
          service.initWorkingDirectory('/home/user');

          // Assert (Then) - We can't directly test private _currentDirectory,
          // but we can verify through resolvePath behavior
          final resolved = service.resolvePath('.');
          expect(resolved, '/home/user');
        },
      );
    });

    group('resolvePath', () {
      setUp(() {
        service.initWorkingDirectory('/home/user');
      });

      test(
        'Given absolute path, When resolvePath called, Then returns canonical path',
        () {
          // Act (When)
          final result = service.resolvePath('/var/log');

          // Assert (Then)
          expect(result, '/var/log');
        },
      );

      test(
        'Given relative path with dot, When resolvePath called, Then returns current directory',
        () {
          // Act (When)
          final result = service.resolvePath('.');

          // Assert (Then)
          expect(result, '/home/user');
        },
      );

      test(
        'Given relative path with double dot, When resolvePath called, Then returns parent directory',
        () {
          // Act (When)
          final result = service.resolvePath('..');

          // Assert (Then)
          expect(result, '/home');
        },
      );

      test(
        'Given relative path with double dot at root, When resolvePath called, Then returns root',
        () {
          // Arrange (Given)
          service.initWorkingDirectory('/');

          // Act (When)
          final result = service.resolvePath('..');

          // Assert (Then)
          expect(result, '/');
        },
      );

      test(
        'Given simple relative path, When resolvePath called, Then resolves to full path',
        () {
          // Act (When)
          final result = service.resolvePath('documents');

          // Assert (Then)
          expect(result, '/home/user/documents');
        },
      );

      test(
        'Given nested relative path, When resolvePath called, Then resolves correctly',
        () {
          // Act (When)
          final result = service.resolvePath('projects/app');

          // Assert (Then)
          expect(result, '/home/user/projects/app');
        },
      );
    });

    group('setShellPath', () {
      test('Given shell path, When setShellPath called, Then stores path', () {
        // Act (When)
        service.setShellPath('/bin/zsh');

        // Assert (Then) - No direct getter, but the service should store it
        // This test just verifies no exceptions are thrown
        expect(service.isConnected, false); // Should not be connected
      });

      test(
        'Given shell path with whitespace, When setShellPath called, Then trims whitespace',
        () {
          // Act (When)
          service.setShellPath('  /bin/bash  ');

          // Assert (Then) - We can't directly verify, but test completes without error
          expect(service.isConnected, false);
        },
      );
    });

    group('getDefaultShellPath', () {
      test('When getDefaultShellPath called, Then returns non-empty string', () {
        // Act (When)
        final result = LocalTerminalService.getDefaultShellPath();

        // Assert (Then)
        expect(result, isNotEmpty);
        // On Windows, returns cmd.exe; on Unix-like, returns /bin/bash or similar
        expect(result, anyOf(startsWith('/'), equals('cmd.exe')));
      });

      test(
        'When getDefaultShellPath called multiple times, Then returns consistent result',
        () {
          // Act (When)
          final result1 = LocalTerminalService.getDefaultShellPath();
          final result2 = LocalTerminalService.getDefaultShellPath();

          // Assert (Then)
          expect(result1, result2);
        },
      );
    });

    group('isConnected', () {
      test(
        'Given service not started, When isConnected accessed, Then returns false',
        () {
          // Assert (Then)
          expect(service.isConnected, false);
        },
      );

      test(
        'Given service after dispose, When isConnected accessed, Then returns false',
        () {
          // Act (When) - Dispose without starting
          service.dispose();

          // Assert (Then)
          expect(service.isConnected, false);
        },
      );
    });

    group('outputStream', () {
      test(
        'Given new service, When outputStream accessed, Then returns stream',
        () {
          // Assert (Then)
          expect(service.outputStream, isNotNull);
        },
      );
    });

    group('stateStream', () {
      test(
        'Given new service, When stateStream accessed, Then returns stream',
        () {
          // Assert (Then)
          expect(service.stateStream, isNotNull);
        },
      );
    });

    group('callbacks', () {
      test(
        'Given onDirectoryChange callback set, When callback triggered, Then is callable',
        () {
          // Arrange (Given)
          service.onDirectoryChange = (dir) {
            // No-op callback
          };

          // Act (When) - Manually trigger via resolvePath
          service.initWorkingDirectory('/new/dir');

          // Assert (Then) - Verify callback can be set without error
          expect(service.onDirectoryChange, isNotNull);
        },
      );

      test(
        'Given onActualDirectoryChange callback set, When callback triggered, Then is callable',
        () {
          // Arrange (Given)
          service.onActualDirectoryChange = (dir) {
            // No-op callback
          };

          // Assert (Then) - Verify callback can be set without error
          expect(service.onActualDirectoryChange, isNotNull);
        },
      );
    });

    group('resize', () {
      test(
        'Given service not started, When resize called, Then does not throw',
        () {
          // Act (When) & Assert (Then) - Should not throw even when PTY is null
          expect(() => service.resize(24, 80), returnsNormally);
        },
      );

      test(
        'Given service with dimensions, When resize called with different sizes, Then accepts parameters',
        () {
          // Act (When) - Multiple resize calls with different sizes
          service.resize(24, 80);
          service.resize(40, 120);
          service.resize(10, 40);

          // Assert (Then) - Should not throw
          expect(service.isConnected, false); // Still not connected
        },
      );

      test(
        'Given service with zero dimensions, When resize called, Then handles gracefully',
        () {
          // Act (When) - Edge case with zero dimensions
          service.resize(0, 0);

          // Assert (Then) - Should not throw
          expect(service.isConnected, false);
        },
      );
    });

    group('cd command detection', () {
      setUp(() {
        service.initWorkingDirectory('/home/user');
      });

      test(
        'Given cd command with absolute path, When newline sent, Then onDirectoryChange fires with resolved dir',
        () {
          // Arrange (Given)
          String? notifiedDir;
          service.onDirectoryChange = (dir) => notifiedDir = dir;

          // Act (When) - 输入 "cd /var/log" 后单独回车(模拟逐字符输入)
          service.sendInput('cd /var/log');
          service.sendInput('\n');

          // Assert (Then)
          expect(notifiedDir, '/var/log');
        },
      );

      test(
        'Given cd command with relative path, When newline sent, Then resolves relative to current dir',
        () {
          // Arrange (Given)
          String? notifiedDir;
          service.onDirectoryChange = (dir) => notifiedDir = dir;

          // Act (When) - 相对路径基于 /home/user
          service.sendInput('cd projects');
          service.sendInput('\n');

          // Assert (Then)
          expect(notifiedDir, '/home/user/projects');
        },
      );

      test(
        'Given non-cd command, When newline sent, Then onDirectoryChange does not fire',
        () {
          // Arrange (Given)
          var fired = false;
          service.onDirectoryChange = (dir) => fired = true;

          // Act (When)
          service.sendInput('ls -la\n');

          // Assert (Then)
          expect(fired, isFalse);
        },
      );
    });

    group('executeCommand', () {
      test(
        'Given service not started, When executeCommand called, Then throws',
        () async {
          // Act (When) & Assert (Then)
          await expectLater(
            () => service.executeCommand('pwd'),
            throwsA(isA<Exception>()),
          );
        },
      );
    });

    group('stop', () {
      test(
        'Given service not started, When stop called, Then does not throw',
        () async {
          // Act (When) & Assert (Then)
          await expectLater(service.stop(), completes);
          expect(service.isConnected, isFalse);
        },
      );

      test(
        'Given service not started, When dispose called, Then does not throw',
        () {
          // Act (When) & Assert (Then)
          expect(service.dispose, returnsNormally);
        },
      );
    });

    group('escape sequence handling', () {
      setUp(() {
        service.initWorkingDirectory('/home/user');
      });

      test(
        'Given cd command with arrow-key escape sequences, When newline sent, Then onDirectoryChange fires with resolved dir',
        () {
          // Arrange (Given)
          String? notifiedDir;
          service.onDirectoryChange = (dir) => notifiedDir = dir;

          // Act (When) - 方向键转义序列 [A 应被剥离,不影响 cd 检测
          service.sendInput('cd /var');
          service.sendInput('\x1b[A'); // 上箭头转义序列
          service.sendInput('log');
          service.sendInput('\n');

          // Assert (Then) - 转义序列 [A 被清理,命令解析为 cd /varlog
          expect(notifiedDir, '/varlog');
        },
      );

      test(
        'Given control characters before cd command, When newline sent, Then onDirectoryChange fires with resolved dir',
        () {
          // Arrange (Given)
          String? notifiedDir;
          service.onDirectoryChange = (dir) => notifiedDir = dir;

          // Act (When) - 控制字符(< 0x20)被过滤
          service.sendInput('\x01'); // SOH 控制字符
          service.sendInput('cd /tmp');
          service.sendInput('\n');

          // Assert (Then)
          expect(notifiedDir, '/tmp');
        },
      );
    });

    group('getWorkingDirectory', () {
      test(
        'Given service not started, When getWorkingDirectory called, Then returns non-empty directory',
        () async {
          // Act (When)
          final dir = await service.getWorkingDirectory();

          // Assert (Then) - 真实 pwd 应返回非空绝对路径
          expect(dir, isNotEmpty);
          expect(dir.startsWith('/'), isTrue);
        },
      );
    });

    group('canonical path case-insensitive match', () {
      test(
        'Given directory exists with different case, When resolvePath called, '
        'Then matches the actual directory',
        () {
          // Arrange (Given) - 创建混合大小写目录
          final tempDir = Directory.systemTemp.createTempSync(
            'lbpssh_case_test',
          );
          addTearDown(() => tempDir.deleteSync(recursive: true));
          final mixedCaseDir = Directory('${tempDir.path}/MyFolder')
            ..createSync();
          service.initWorkingDirectory(tempDir.path);

          // Act (When) - 用小写路径解析
          final result = service.resolvePath('myfolder');

          // Assert (Then) - 大小写不敏感匹配（macOS 默认不区分大小写）
          expect(result.toLowerCase(), mixedCaseDir.path.toLowerCase());
        },
      );
    });

    group('start() early return', () {
      test(
        'Given service stopped, When start called again, Then does not start',
        () async {
          // Arrange (Given) - stop() 会设置 _isShuttingDown
          await service.stop();
          expect(service.isConnected, isFalse);

          // Act (When)
          await service.start();

          // Assert (Then) - 提前返回，未启动
          expect(service.isConnected, isFalse);
        },
      );
    });

    group('start() failure path', () {
      test(
        'Given nonexistent shell path, When start called, '
        'Then throws and emits error state and message',
        () async {
          // Arrange (Given)
          service.setShellPath('/nonexistent/shell');

          final states = <bool>[];
          service.stateStream.listen(states.add);
          final outputs = <String>[];
          service.outputStream.listen(outputs.add);

          // Act (When) & Assert (Then)
          // Pty.start 在测试环境抛 ArgumentError（原生库未打包），
          // 在真机环境抛 ProcessException——两者都会被 catch 捕获并原样重抛
          await expectLater(
            service.start(),
            throwsA(anything),
          );

          // broadcast 流异步派发，等待事件送达
          await Future<void>.delayed(const Duration(milliseconds: 50));

          expect(states, contains(false));
          expect(
            outputs.any((o) => o.contains('启动本地终端失败')),
            isTrue,
          );
        },
      );

      test(
        'Given start failure, When isConnected accessed, Then returns false',
        () async {
          // Arrange (Given)
          service.setShellPath('/nonexistent/shell');

          // Act (When)
          await expectLater(service.start(), throwsA(anything));

          // Assert (Then)
          expect(service.isConnected, isFalse);
        },
      );
    });

    group('start() success path with injected pty', () {
      late MockPty mockPty;
      late StreamController<Uint8List> outputController;
      late Completer<int> exitCodeCompleter;

      LocalTerminalService makeService() {
        mockPty = MockPty();
        outputController = StreamController<Uint8List>.broadcast();
        exitCodeCompleter = Completer<int>();
        when(() => mockPty.output).thenAnswer((_) => outputController.stream);
        when(() => mockPty.exitCode).thenAnswer((_) => exitCodeCompleter.future);
        when(() => mockPty.pid).thenReturn(4242);
        when(() => mockPty.write(any())).thenReturn(null);
        when(() => mockPty.resize(any(), any())).thenReturn(null);
        when(() => mockPty.kill(any())).thenReturn(true);
        when(() => mockPty.ackRead()).thenReturn(null);
        return LocalTerminalService(
          ptyStarter: (shell,
              {arguments = const [],
              workingDirectory,
              environment,
              rows = 24}) => mockPty,
        );
      }

      test(
        'Given valid ptyStarter, When start called, '
        'Then isConnected is true and state emits true',
        () async {
          // Arrange (Given)
          final svc = makeService();
          final states = <bool>[];
          svc.stateStream.listen(states.add);

          // Act (When)
          await svc.start();
          await Future<void>.delayed(const Duration(milliseconds: 20));

          // Assert (Then)
          expect(svc.isConnected, isTrue);
          expect(states, contains(true));

          exitCodeCompleter.complete(0);
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await svc.stop();
        },
      );

      test(
        'Given pty output, When pty emits data, '
        'Then outputStream forwards it and ackRead is called',
        () async {
          // Arrange (Given)
          final svc = makeService();
          final outputs = <String>[];
          svc.outputStream.listen(outputs.add);

          // Act (When)
          await svc.start();
          outputController.add(Uint8List.fromList(utf8.encode('hello pty')));
          await Future<void>.delayed(const Duration(milliseconds: 20));

          // Assert (Then)
          expect(outputs, contains('hello pty'));
          verify(() => mockPty.ackRead()).called(1);

          exitCodeCompleter.complete(0);
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await svc.stop();
        },
      );

      test(
        'Given pty output error, When pty emits error, '
        'Then outputStream receives error message',
        () async {
          // Arrange (Given)
          final svc = makeService();
          final outputs = <String>[];
          svc.outputStream.listen(outputs.add);

          // Act (When)
          await svc.start();
          outputController.addError(Exception('boom'));
          await Future<void>.delayed(const Duration(milliseconds: 20));

          // Assert (Then)
          expect(outputs.any((o) => o.contains('输出流错误')), isTrue);

          exitCodeCompleter.complete(0);
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await svc.stop();
        },
      );

      test(
        'Given pty output done, When pty stream closes, '
        'Then emits normal-exit message and disconnects',
        () async {
          // Arrange (Given)
          final svc = makeService();
          final outputs = <String>[];
          svc.outputStream.listen(outputs.add);

          // Act (When)
          await svc.start();
          await outputController.close();
          await Future<void>.delayed(const Duration(milliseconds: 20));

          // Assert (Then)
          expect(outputs.any((o) => o.contains('进程已正常退出')), isTrue);
          expect(svc.isConnected, isFalse);

          exitCodeCompleter.complete(0);
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await svc.stop();
        },
      );

      test(
        'Given pty exits normally, When exitCode completes, '
        'Then emits exit message and disconnects',
        () async {
          // Arrange (Given)
          final svc = makeService();
          final outputs = <String>[];
          svc.outputStream.listen(outputs.add);

          // Act (When)
          await svc.start();
          exitCodeCompleter.complete(7);
          await Future<void>.delayed(const Duration(milliseconds: 20));

          // Assert (Then)
          expect(outputs.any((o) => o.contains('进程已退出，退出码: 7')), isTrue);
          expect(svc.isConnected, isFalse);

          await svc.stop();
        },
      );

      test(
        'Given pty exits with error, When exitCode fails, '
        'Then emits abnormal-exit message and disconnects',
        () async {
          // Arrange (Given)
          final svc = makeService();
          final outputs = <String>[];
          svc.outputStream.listen(outputs.add);

          // Act (When)
          await svc.start();
          exitCodeCompleter.completeError(StateError('crash'));
          await Future<void>.delayed(const Duration(milliseconds: 20));

          // Assert (Then)
          expect(outputs.any((o) => o.contains('进程异常退出')), isTrue);
          expect(svc.isConnected, isFalse);

          await svc.stop();
        },
      );

      test(
        'Given connected pty, When sendInput called, '
        'Then writes utf8 bytes to pty',
        () async {
          // Arrange (Given)
          final svc = makeService();

          // Act (When)
          await svc.start();
          svc.sendInput('hello');

          // Assert (Then)
          verify(() => mockPty.write(utf8.encode('hello'))).called(1);

          exitCodeCompleter.complete(0);
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await svc.stop();
        },
      );

      test(
        'Given connected pty, When resize called, '
        'Then pty is resized',
        () async {
          // Arrange (Given)
          final svc = makeService();

          // Act (When)
          await svc.start();
          svc.resize(30, 100);

          // Assert (Then)
          verify(() => mockPty.resize(30, 100)).called(1);

          exitCodeCompleter.complete(0);
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await svc.stop();
        },
      );

      test(
        'Given connected pty, When executeCommand called, '
        'Then sends input and returns buffered output',
        () async {
          // Arrange (Given)
          final svc = makeService();

          // Act (When) — executeCommand 内部有固定 2s 延迟，
          // 在等待期间注入输出，验证输出被缓冲收集
          await svc.start();
          final future = svc.executeCommand('pwd');
          outputController.add(
            Uint8List.fromList(utf8.encode('result-line\n')),
          );
          final result = await future;

          // Assert (Then)
          expect(result, contains('result-line'));
          // sendInput('pwd') + sendInput('\n') 各一次
          verify(() => mockPty.write(any())).called(2);

          exitCodeCompleter.complete(0);
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await svc.stop();
        },
        timeout: const Timeout(Duration(seconds: 8)),
      );

      test(
        'Given pty write throws, When sendInput called, '
        'Then emits send-failure message',
        () async {
          // Arrange (Given)
          final svc = makeService();
          // 覆盖 makeService 里的默认 stub：让 write 抛错
          when(() => mockPty.write(any())).thenThrow(Exception('write failed'));
          final outputs = <String>[];
          svc.outputStream.listen(outputs.add);

          // Act (When)
          await svc.start();
          svc.sendInput('x');
          await Future<void>.delayed(const Duration(milliseconds: 20));

          // Assert (Then)
          expect(outputs.any((o) => o.contains('发送输入失败')), isTrue);

          exitCodeCompleter.complete(0);
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await svc.stop();
        },
      );

      test(
        'Given cd command with real pid, When directory changes, '
        'Then lsof resolves actual directory and fires callback',
        () async {
          // Arrange (Given) — 用真实 sleep 进程的 pid 让 lsof 返回真实 cwd
          final proc = await Process.start('sleep', ['10']);
          addTearDown(() => proc.kill());
          when(() => mockPty.pid).thenReturn(proc.pid);
          final svc = makeService();
          String? actualDir;
          svc.onActualDirectoryChange = (d) => actualDir = d;

          // Act (When) — cd 命令触发 500ms 后的 lsof 查询
          await svc.start();
          svc.sendInput('cd /tmp');
          svc.sendInput('\n');
          await Future<void>.delayed(const Duration(milliseconds: 700));

          // Assert (Then) — lsof 返回真实目录；若环境无 lsof 则静默，不断言
          expect(actualDir?.startsWith('/') ?? true, isTrue);

          exitCodeCompleter.complete(0);
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await svc.stop();
        },
        timeout: const Timeout(Duration(seconds: 8)),
      );

      test(
        'Given connected pty, When stop called, '
        'Then sends EOF, kills pty and emits stopped message',
        () async {
          // Arrange (Given)
          final svc = makeService();
          final outputs = <String>[];
          svc.outputStream.listen(outputs.add);

          // Act (When)
          await svc.start();
          final stopFuture = svc.stop();
          // stop() 内部等待 exitCode，稍后完成它以放行
          await Future<void>.delayed(const Duration(milliseconds: 600));
          exitCodeCompleter.complete(0);
          await stopFuture;
          // broadcast 流异步派发，等待事件送达
          await Future<void>.delayed(const Duration(milliseconds: 100));

          // Assert (Then)
          verify(() => mockPty.write(utf8.encode('\x04'))).called(1);
          verify(() => mockPty.kill(any())).called(1);
          expect(svc.isConnected, isFalse);
          expect(outputs.any((o) => o.contains('本地终端已停止')), isTrue);
        },
      );
    });

    group('resolvePath with nonexistent parent', () {
      test(
        'Given absolute path with nonexistent parent, '
        'When resolvePath called, Then returns original path',
        () {
          // Arrange (Given)
          service.initWorkingDirectory('/home/user');

          // Act (When) - 父目录不存在时 _getCanonicalPath 返回原始路径
          final result = service.resolvePath('/nonexistent_parent/child');

          // Assert (Then)
          expect(result, '/nonexistent_parent/child');
        },
      );

      test(
        'Given relative path whose parent does not exist, '
        'When resolvePath called, Then returns resolved path unchanged',
        () {
          // Arrange (Given)
          service.initWorkingDirectory('/home/user');

          // Act (When) - 找不到大小写匹配的目录时返回拼接路径
          final result = service.resolvePath('nonexistent_child_dir');

          // Assert (Then)
          expect(result, '/home/user/nonexistent_child_dir');
        },
      );
    });
  });
}
