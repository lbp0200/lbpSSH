import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/tui/tui_config_path.dart';

void main() {
  group('resolveTuiConfigFile', () {
    test('Given HOME set and no LBPSSH_CONFIG_DIR, '
        'Then returns config under ~/.lbpSSH', () {
      final file = resolveTuiConfigFile({'HOME': '/home/user'});

      expect(file.path, '/home/user/.lbpSSH/ssh_connections.json');
    });

    test('Given LBPSSH_CONFIG_DIR set, '
        'Then it takes precedence over HOME', () {
      final file = resolveTuiConfigFile({
        'HOME': '/home/user',
        'LBPSSH_CONFIG_DIR': '/custom/dir',
      });

      expect(file.path, '/custom/dir/ssh_connections.json');
    });

    test('Given no HOME and no LBPSSH_CONFIG_DIR, '
        'Then falls back to current directory', () {
      final file = resolveTuiConfigFile({});

      expect(file.path, './.lbpSSH/ssh_connections.json');
    });

    test('Given empty env, '
        'Then falls back to current directory', () {
      final file = resolveTuiConfigFile(const {});

      expect(file.path, './.lbpSSH/ssh_connections.json');
    });
  });
}
