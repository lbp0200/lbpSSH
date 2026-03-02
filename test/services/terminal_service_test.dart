import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';
import 'package:lbp_ssh/domain/services/local_terminal_service.dart';

void main() {
  group('LocalTerminalSession Name', () {
    test('should update name to local {folder_name} when directory changes', () async {
      // 创建一个本地终端服务
      final localService = LocalTerminalService();

      // 创建一个模拟的 TerminalSession
      final session = TerminalSession(
        id: 'test-session',
        name: 'local /Users/test',
        inputService: localService,
      );

      // 模拟设置工作目录
      session.setWorkingDirectoryAndUpdateName('/Users/test/project');

      // 验证名称更新逻辑
      expect(session.workingDirectory, '/Users/test/project');
      expect(session.name, 'local project');
    });

    test('should update name to local / for root directory', () async {
      // 创建一个本地终端服务
      final localService = LocalTerminalService();

      // 创建一个模拟的 TerminalSession
      final session = TerminalSession(
        id: 'test-session',
        name: 'local test',
        inputService: localService,
      );

      // 模拟设置工作目录为根目录
      session.setWorkingDirectoryAndUpdateName('/');

      expect(session.name, 'local /');
    });

    test('should extract correct folder name from path', () {
      final paths = [
        '/Users/lbp/Projects/lbpSSH',
        '/home/user/documents',
        '/var/log',
        '/',
      ];

      final expectedFolders = [
        'lbpSSH',
        'documents',
        'log',
        '', // 根目录没有文件夹名
      ];

      for (var i = 0; i < paths.length; i++) {
        final path = paths[i];
        final parts = path.split('/');
        final folderName = parts.last;
        expect(folderName, expectedFolders[i]);
      }
    });
  });
}
