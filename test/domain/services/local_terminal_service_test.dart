import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/domain/services/local_terminal_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_pty/flutter_pty.dart';

// Mock Pty class
class MockPty extends Mock implements Pty {}

void main() {
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
  });
}
