import '../../data/models/ssh_connection.dart';
import '../../data/repositories/connection_repository.dart';
import 'tui_state.dart';

/// TUI 交互控制器：处理列表/表单按键，更新 [TuiState] 并持久化连接。
///
/// 从 `bin/lbpssh_tui.dart` 提取，使交互逻辑可独立测试。
class TuiController {
  TuiController({required ConnectionRepository repository})
    : _repository = repository;

  final ConnectionRepository _repository;

  /// 当前 UI 状态
  TuiState state = TuiState();

  /// 是否继续运行主循环（Ctrl+C 或选中连接时置 false）
  bool running = true;

  /// 用户选中的待连接服务器（列表 enter 键设置，主循环消费后清空）
  SshConnection? sshRequest;

  /// 表单字段顺序
  static const formFields = [
    'name',
    'host',
    'port',
    'username',
    'authType',
    'password',
    'privateKeyPath',
    'keyPassphrase',
  ];

  /// 字段是否根据当前认证方式可见
  bool formFieldVisible(String key) => switch (key) {
    'password' =>
      state.formAuthType == AuthType.password ||
          state.formAuthType == AuthType.keyWithPassword,
    'privateKeyPath' =>
      state.formAuthType == AuthType.key ||
          state.formAuthType == AuthType.keyWithPassword,
    'keyPassphrase' => state.formAuthType == AuthType.keyWithPassword,
    _ => true,
  };

  /// 当前可见的表单字段
  List<String> visibleFormFields() =>
      formFields.where(formFieldVisible).toList();

  /// 用待编辑连接填充表单
  void initFormFromEdit(SshConnection conn) {
    state.formValues = {
      'name': conn.name,
      'host': conn.host,
      'port': conn.port.toString(),
      'username': conn.username,
      'password': conn.password ?? '',
      'privateKeyPath': conn.privateKeyPath ?? '',
      'keyPassphrase': conn.keyPassphrase ?? '',
    };
    state.formAuthType = conn.authType;
    state.formFieldIndex = 0;
  }

  /// 处理单个按键，根据当前屏幕分发到列表/表单处理器
  void handleKey(String key) {
    if (state.screen == 'list') {
      _handleListKey(key);
    } else if (state.screen == 'form') {
      _handleFormKey(key);
    }
  }

  /// 依次处理一批按键并更新本控制器状态，返回是否应结束本次 TUI 循环。
  ///
  /// Enter 选中连接（[running] 置 false）或 Ctrl+C 都会使返回值变为 true；
  /// Ctrl+C 不作为普通按键分发给列表/表单处理器。TUI 主循环据此退出并消费
  /// [sshRequest]，从而真正建立连接（此前仅 Ctrl+C 会触发退出，Enter 选中
  /// 连接后 TUI 卡死、无法进入连接流程）。
  bool processKeys(List<String> keys) {
    for (final k in keys) {
      if (k == 'ctrl_c') {
        running = false;
      } else {
        handleKey(k);
      }
      if (!running) break;
    }
    return !running;
  }

  void _handleListKey(String key) {
    final conns = state.filteredConnections;

    if (state.isSearching) {
      if (key == 'esc') {
        state.searchQuery = '';
        state.isSearching = false;
        state.sel = 0;
      } else if (key == 'backspace') {
        if (state.searchQuery.isNotEmpty) {
          state.searchQuery = state.searchQuery.substring(
            0,
            state.searchQuery.length - 1,
          );
        }
        state.sel = 0;
      } else if (key.length == 1) {
        state.searchQuery += key;
        state.sel = 0;
      }
      return;
    }

    switch (key) {
      case 'down':
      case 'j':
        if (state.sel < conns.length - 1) state.sel++;
        break;
      case 'up':
      case 'k':
        if (state.sel > 0) state.sel--;
        break;
      case 'enter':
        if (conns.isNotEmpty) {
          sshRequest = conns[state.sel];
          running = false;
        }
        break;
      case '/':
        state.isSearching = true;
        state.searchQuery = '';
        break;
      case 'a':
        state = TuiState(
          connections: state.connections,
          screen: 'form',
          sel: state.sel,
        );
        break;
      case 'e':
        if (conns.isNotEmpty) {
          state = TuiState(
            connections: state.connections,
            screen: 'form',
            sel: state.sel,
            editConn: conns[state.sel],
          );
          initFormFromEdit(conns[state.sel]);
        }
        break;
      case 'd':
        if (conns.isNotEmpty) {
          _repository.deleteConnection(conns[state.sel].id);
          final updated = _repository.getAllConnections();
          state.connections = updated;
          state.sel = state.sel >= state.filteredConnections.length
              ? state.filteredConnections.length - 1
              : state.sel;
          if (state.sel < 0) state.sel = 0;
        }
        break;
    }
  }

  void _handleFormKey(String key) {
    switch (key) {
      case 'tab':
        final fields = visibleFormFields();
        state.formFieldIndex = (state.formFieldIndex + 1) % fields.length;
        break;
      case 'esc':
        state = TuiState(connections: state.connections, sel: state.sel);
        break;
      case 'enter':
        final conn = state.buildConnection();
        if (conn != null) {
          _repository.saveConnection(conn);
          state = TuiState(
            connections: _repository.getAllConnections(),
            sel: state.sel,
          );
        }
        break;
      case 'backspace':
        final fields = visibleFormFields();
        if (state.formFieldIndex < fields.length) {
          final k = fields[state.formFieldIndex];
          if (k == 'authType') break;
          final v = state.formValue(k);
          if (v.isNotEmpty) {
            state.setFormValue(k, v.substring(0, v.length - 1));
          }
        }
        break;
      case ' ':
        final fields = visibleFormFields();
        if (state.formFieldIndex < fields.length &&
            fields[state.formFieldIndex] == 'authType') {
          state.formAuthType = switch (state.formAuthType) {
            AuthType.password => AuthType.key,
            AuthType.key => AuthType.keyWithPassword,
            AuthType.keyWithPassword => AuthType.sshConfig,
            AuthType.sshConfig => AuthType.password,
          };
          state.formFieldIndex = 0;
        } else if (state.formFieldIndex < fields.length) {
          final k = fields[state.formFieldIndex];
          state.setFormValue(k, '${state.formValue(k)} ');
        }
        break;
      default:
        if (key.length == 1) {
          final fields = visibleFormFields();
          if (state.formFieldIndex < fields.length) {
            final k = fields[state.formFieldIndex];
            if (k == 'authType') break;
            state.setFormValue(k, state.formValue(k) + key);
          }
        }
    }
  }
}
