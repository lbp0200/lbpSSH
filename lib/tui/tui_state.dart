import '../data/models/ssh_connection.dart';

class TuiState {
  List<SshConnection> connections;
  String screen;
  int sel;
  SshConnection? editConn;
  String searchQuery;
  bool isSearching;
  int formFieldIndex;
  Map<String, String> formValues;
  AuthType formAuthType;

  TuiState({
    this.connections = const [],
    this.screen = 'list',
    this.sel = 0,
    this.editConn,
    this.searchQuery = '',
    this.isSearching = false,
    this.formFieldIndex = 0,
    Map<String, String>? formValues,
    this.formAuthType = AuthType.password,
  }) : formValues = formValues ?? <String, String>{};

  List<SshConnection> get filteredConnections {
    if (searchQuery.isEmpty) return connections;
    final q = searchQuery.toLowerCase();
    return connections
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.host.toLowerCase().contains(q) ||
              c.username.toLowerCase().contains(q),
        )
        .toList();
  }

  String formValue(String key, {String fallback = ''}) =>
      formValues[key] ?? fallback;

  void setFormValue(String key, String value) => formValues[key] = value;

  SshConnection? buildConnection() {
    final name = formValue('name');
    final host = formValue('host');
    final username = formValue('username');
    if (name.isEmpty || host.isEmpty || username.isEmpty) return null;
    final port = int.tryParse(formValue('port', fallback: '22')) ?? 22;
    final password = formValue('password');
    final privateKeyPath = formValue('privateKeyPath');
    final keyPassphrase = formValue('keyPassphrase');

    // 编辑现有连接：用 copyWith 仅更新 TUI 表单管理的 8 个字段，保留非表单字段
    // （jumpHost / socks5Proxy / sshConfigHost / notes / privateKeyContent /
    // version / createdAt）。否则会新建 SshConnection 把这些字段重置为 null/默认值，
    // 保存后跳板机、SOCKS5 代理、备注等配置全部丢失。
    final editConn = this.editConn;
    if (editConn != null) {
      return editConn.copyWith(
        name: name,
        host: host,
        port: port,
        username: username,
        authType: formAuthType,
        password: password,
        privateKeyPath: privateKeyPath,
        keyPassphrase: keyPassphrase,
      );
    }

    // 新建连接：默认构造，非表单字段保持 null/默认值。
    return SshConnection(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      host: host,
      port: port,
      username: username,
      authType: formAuthType,
      password: password,
      privateKeyPath: privateKeyPath,
      keyPassphrase: keyPassphrase,
    );
  }
}
