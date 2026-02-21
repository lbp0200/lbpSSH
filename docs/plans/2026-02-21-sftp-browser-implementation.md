# SFTP Browser Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add SFTP file browser to lbpSSH with connection list entry, multi-tab support, and full file management capabilities.

**Architecture:** Create SftpService for SFTP operations, SftpProvider for state management, and SftpBrowserScreen for UI. Reuse existing SSH connections.

**Tech Stack:** Flutter, dartssh2 (SFTP support), Provider

---

### Task 1: Add SFTP getter to SSHService

**Files:**
- Modify: `lib/domain/services/ssh_service.dart`

**Step 1: Add getter for SSHClient**

Add this method to SshService class (around line 179):

```dart
/// 获取 SFTP 客户端（如果已连接）
SFTPClient? getSftpClient() {
  if (_client != null && _state == SshConnectionState.connected) {
    return _client!.sftp();
  }
  return null;
}
```

Add import at top:
```dart
import 'package:dartssh2/dartssh2.dart';
```

**Step 2: Verify it compiles**

Run: `flutter analyze lib/domain/services/ssh_service.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/domain/services/ssh_service.dart
git commit -m "feat: add getSftpClient to SSHService"
```

---

### Task 2: Create SftpService

**Files:**
- Create: `lib/domain/services/sftp_service.dart`

**Step 1: Write SftpService**

```dart
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/domain/services/ssh_config_service.dart';

/// SFTP 文件项
class SftpItem {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime? modified;

  SftpItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size = 0,
    this.modified,
  });
}

/// SFTP 服务
class SftpService {
  SFTPClient? _sftp;
  SshConnection? _connection;
  String _currentPath = '/';

  String get currentPath => _currentPath;
  bool get isConnected => _sftp != null;

  /// 连接 SFTP
  Future<void> connect(SshConnection connection, {String? password}) async {
    _connection = connection;
    final socket = await SSHSocket.connect(
      connection.host,
      connection.port,
    );

    final identities = await SSHKeyPair.fromPem(
      await SSHConfigService.getPrivateKey(connection),
      password,
    );

    _sftp = SSHClient(
      socket,
      username: connection.username,
      onPasswordRequest: connection.authType == AuthType.password
          ? () => password
          : null,
      identities: identities,
    ).sftp();

    // 获取初始目录
    _currentPath = await _sftp!.absolute('.');
  }

  /// 复用已有 SSH 连接
  void attachClient(SFTPClient client, String path) {
    _sftp = client;
    _currentPath = path;
  }

  /// 列出目录
  Future<List<SftpItem>> listDirectory(String path) async {
    if (_sftp == null) throw Exception('未连接到 SFTP');

    final items = await _sftp!.listdir(path);
    return items.map((item) {
      return SftpItem(
        name: item.filename,
        path: '$path/${item.filename}'.replaceAll('//', '/'),
        isDirectory: item.attr.isDirectory,
        size: item.attr.size ?? 0,
        modified: item.attr.modifyTime != null
            ? DateTime.fromMillisecondsSinceEpoch(item.attr.modifyTime! * 1000)
            : null,
      );
    }).toList();
  }

  /// 获取当前目录文件列表
  Future<List<SftpItem>> listCurrentDirectory() async {
    return listDirectory(_currentPath);
  }

  /// 进入目录
  Future<void> changeDirectory(String path) async {
    if (_sftp == null) throw Exception('未连接到 SFTP');

    final newPath = path.startsWith('/') ? path : '$_currentPath/$path';
    // 验证目录存在
    await _sftp!.listdir(newPath);
    _currentPath = newPath;
  }

  /// 返回上级目录
  Future<void> goUp() async {
    if (_currentPath == '/') return;
    final parts = _currentPath.split('/');
    parts.removeLast();
    _currentPath = parts.isEmpty ? '/' : parts.join('/');
  }

  /// 创建目录
  Future<void> createDirectory(String name) async {
    if (_sftp == null) throw Exception('未连接到 SFTP');
    final path = _currentPath == '/' ? '/$name' : '$_currentPath/$name';
    await _sftp!.mkdir(path);
  }

  /// 删除文件
  Future<void> removeFile(String path) async {
    if (_sftp == null) throw Exception('未连接到 SFTP');
    await _sftp!.remove(path);
  }

  /// 删除目录
  Future<void> removeDirectory(String path) async {
    if (_sftp == null) throw Exception('未连接到 SFTP');
    await _sftp!.rmdir(path);
  }

  /// 重命名
  Future<void> rename(String oldPath, String newName) async {
    if (_sftp == null) throw Exception('未连接到 SFTP');
    final parts = oldPath.split('/');
    parts.removeLast();
    final dir = parts.join('/');
    final newPath = dir.isEmpty ? '/$newName' : '$dir/$newName';
    await _sftp!.rename(oldPath, newPath);
  }

  /// 上传文件
  Future<void> uploadFile(String localPath, String remotePath) async {
    if (_sftp == null) throw Exception('未连接到 SFTP');
    final file = await _sftp!.open(
      remotePath,
      mode: SFTPFileMode.create | SFTPFileMode.write,
    );
    final localFile = await Dio().get<List<int>>(
      localPath,
      options: Options(responseType: ResponseType.bytes),
    );
    await file.write(Stream.value(Uint8List.fromList(localFile.data!)));
    await file.close();
  }

  /// 下载文件
  Future<Uint8List> downloadFile(String remotePath) async {
    if (_sftp == null) throw Exception('未连接到 SFTP');
    final file = await _sftp!.open(remotePath);
    final content = await file.read().toList();
    await file.close();
    return Uint8List.fromList(content);
  }

  /// 断开连接
  Future<void> disconnect() async {
    await _sftp?.close();
    _sftp = null;
    _currentPath = '/';
  }
}

// Helper for Dio - add to imports
import 'package:dio/dio.dart';
```

Wait, we don't have Dio in SftpService. Let me rewrite using dart:io:

```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/domain/services/ssh_config_service.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart' show AuthType;

/// SFTP 文件项
class SftpItem {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime? modified;

  SftpItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size = 0,
    this.modified,
  });
}

/// SFTP 服务
class SftpService {
  SFTPClient? _sftp;
  SshConnection? _connection;
  String _currentPath = '/';

  String get currentPath => _currentPath;
  bool get isConnected => _sftp != null;

  /// 连接 SFTP
  Future<void> connect(SshConnection connection, {String? password}) async {
    _connection = connection;
    final socket = await SSHSocket.connect(
      connection.host,
      connection.port,
    );

    final identities = await SSHKeyPair.fromPem(
      await SSHConfigService.getPrivateKey(connection),
      password,
    );

    _sftp = SSHClient(
      socket,
      username: connection.username,
      onPasswordRequest: connection.authType == AuthType.password
          ? () => password
          : null,
      identities: identities,
    ).sftp();

    // 获取初始目录
    _currentPath = await _sftp!.absolute('.');
  }

  /// 复用已有 SSH 连接
  void attachClient(SFTPClient client, String path) {
    _sftp = client;
    _currentPath = path;
  }

  /// 列出目录
  Future<List<SftpItem>> listDirectory(String path) async {
    if (_sftp == null) throw Exception('未连接到 SFTP');

    final items = await _sftp!.listdir(path);
    return items.where((item) => item.filename != '.' && item.filename != '..').map((item) {
      return SftpItem(
        name: item.filename,
        path: '$path/${item.filename}'.replaceAll('//', '/'),
        isDirectory: item.attr.isDirectory,
        size: item.attr.size ?? 0,
        modified: item.attr.modifyTime != null
            ? DateTime.fromMillisecondsSinceEpoch(item.attr.modifyTime! * 1000)
            : null,
      );
    }).toList();
  }

  /// 获取当前目录文件列表
  Future<List<SftpItem>> listCurrentDirectory() async {
    return listDirectory(_currentPath);
  }

  /// 进入目录
  Future<void> changeDirectory(String path) async {
    if (_sftp == null) throw Exception('未连接到 SFTP');

    final newPath = path.startsWith('/') ? path : '$_currentPath/$path';
    // 验证目录存在
    await _sftp!.listdir(newPath);
    _currentPath = newPath;
  }

  /// 返回上级目录
  Future<void> goUp() async {
    if (_currentPath == '/') return;
    final parts = _currentPath.split('/');
    parts.removeLast();
    _currentPath = parts.isEmpty ? '/' : parts.join('/');
  }

  /// 创建目录
  Future<void> createDirectory(String name) async {
    if (_sftp == null) throw Exception('未连接到 SFTP');
    final path = _currentPath == '/' ? '/$name' : '$_currentPath/$name';
    await _sftp!.mkdir(path);
  }

  /// 删除文件
  Future<void> removeFile(String path) async {
    if (_sftp == null) throw Exception('未连接到 SFTP');
    await _sftp!.remove(path);
  }

  /// 删除目录
  Future<void> removeDirectory(String path) async {
    if (_sftp == null) throw Exception('未连接到 SFTP');
    await _sftp!.rmdir(path);
  }

  /// 重命名
  Future<void> rename(String oldPath, String newName) async {
    if (_sftp == null) throw Exception('未连接到 SFTP');
    final parts = oldPath.split('/');
    parts.removeLast();
    final dir = parts.join('/');
    final newPath = dir.isEmpty ? '/$newName' : '$dir/$newName';
    await _sftp!.rename(oldPath, newPath);
  }

  /// 上传文件 (从本地路径)
  Future<void> uploadFile(String localPath, String remoteFileName) async {
    if (_sftp == null) throw Exception('未连接到 SFTP');
    final remotePath = _currentPath == '/' ? '/$remoteFileName' : '$_currentPath/$remoteFileName';

    final localFile = File(localPath);
    if (!await localFile.exists()) {
      throw Exception('本地文件不存在: $localPath');
    }

    final file = await _sftp!.open(
      remotePath,
      mode: SFTPFileMode.create | SFTPFileMode.write,
    );

    final stream = localFile.openRead();
    await file.write(Stream.asyncMap(stream, (chunk) async {
      return Uint8List.fromList(chunk);
    }));
    await file.close();
  }

  /// 下载文件 (到本地路径)
  Future<void> downloadFile(String remotePath, String localPath) async {
    if (_sftp == null) throw Exception('未连接到 SFTP');

    final file = await _sftp!.open(remotePath);
    final chunks = <int>[];
    await for (final chunk in file.read()) {
      chunks.addAll(chunk);
    }
    await file.close();

    final localFile = File(localPath);
    await localFile.writeAsBytes(Uint8List.fromList(chunks));
  }

  /// 断开连接
  Future<void> disconnect() async {
    await _sftp?.close();
    _sftp = null;
    _currentPath = '/';
  }
}
```

**Step 2: Verify it compiles**

Run: `flutter analyze lib/domain/services/sftp_service.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/domain/services/sftp_service.dart
git commit -m "feat: add SftpService for SFTP operations"
```

---

### Task 3: Create SftpProvider

**Files:**
- Create: `lib/presentation/providers/sftp_provider.dart`

**Step 1: Write SftpProvider**

```dart
import 'package:flutter/foundation.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/domain/services/sftp_service.dart';
import 'package:lbp_ssh/presentation/providers/terminal_provider.dart';

/// SFTP 标签页数据
class SftpTab {
  final String id;
  final SshConnection connection;
  final SftpService service;
  String currentPath;

  SftpTab({
    required this.id,
    required this.connection,
    required this.service,
    required this.currentPath,
  });
}

/// SFTP 提供者
class SftpProvider extends ChangeNotifier {
  final TerminalProvider _terminalProvider;
  final Map<String, SftpTab> _tabs = {};

  SftpProvider(this._terminalProvider);

  List<SftpTab> get tabs => _tabs.values.toList();

  /// 打开 SFTP 标签页
  Future<SftpTab> openTab(SshConnection connection, {String? password}) async {
    final tabId = '${connection.id}_${DateTime.now().millisecondsSinceEpoch}';

    // 尝试复用已有连接
    final sshService = _terminalProvider.getSshService(connection.id);
    SftpService sftpService;

    if (sshService != null && sshService.state.name == 'connected') {
      // 复用 SSH 连接
      sftpService = SftpService();
      final client = sshService.getSftpClient();
      if (client != null) {
        sftpService.attachClient(client, '/');
      } else {
        await sftpService.connect(connection, password: password);
      }
    } else {
      // 创建新连接
      sftpService = SftpService();
      await sftpService.connect(connection, password: password);
    }

    final tab = SftpTab(
      id: tabId,
      connection: connection,
      service: sftpService,
      currentPath: '/',
    );

    _tabs[tabId] = tab;
    notifyListeners();
    return tab;
  }

  /// 关闭标签页
  Future<void> closeTab(String tabId) async {
    final tab = _tabs[tabId];
    if (tab != null) {
      // 不关闭共享的 SFTP 连接
      _tabs.remove(tabId);
      notifyListeners();
    }
  }

  /// 获取标签页
  SftpTab? getTab(String tabId) => _tabs[tabId];
}
```

**Step 2: Verify it compiles**

Run: `flutter analyze lib/presentation/providers/sftp_provider.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/presentation/providers/sftp_provider.dart
git commit -m "feat: add SftpProvider for state management"
```

---

### Task 4: Create SftpBrowserScreen

**Files:**
- Create: `lib/presentation/screens/sftp_browser_screen.dart`

**Step 1: Write SftpBrowserScreen**

```dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/domain/services/sftp_service.dart';
import 'package:lbp_ssh/presentation/providers/sftp_provider.dart';

/// SFTP 浏览器界面
class SftpBrowserScreen extends StatefulWidget {
  final SshConnection connection;

  const SftpBrowserScreen({
    super.key,
    required this.connection,
  });

  @override
  State<SftpBrowserScreen> createState() => _SftpBrowserScreenState();
}

class _SftpBrowserScreenState extends State<SftpBrowserScreen> {
  SftpService? _sftpService;
  List<SftpItem> _items = [];
  bool _loading = false;
  String _currentPath = '/';
  String? _error;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final provider = context.read<SftpProvider>();
      final tab = await provider.openTab(widget.connection);
      setState(() {
        _sftpService = tab.service;
        _currentPath = tab.currentPath;
      });
      await _refresh();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    if (_sftpService == null) return;

    setState(() {
      _loading = true;
    });

    try {
      final items = await _sftpService!.listCurrentDirectory();
      setState(() {
        _items = items;
        _currentPath = _sftpService!.currentPath;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _onItemTap(SftpItem item) async {
    if (item.isDirectory) {
      await _sftpService?.changeDirectory(item.name);
      await _refresh();
    }
  }

  Future<void> _goUp() async {
    await _sftpService?.goUp();
    await _refresh();
  }

  Future<void> _createFolder() async {
    final name = await _showNameDialog('新建文件夹', '新建文件夹');
    if (name != null && name.isNotEmpty) {
      try {
        await _sftpService?.createDirectory(name);
        await _refresh();
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      try {
        await _sftpService?.uploadFile(
          result.files.single.path!,
          result.files.single.name,
        );
        await _refresh();
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  Future<void> _downloadFile(SftpItem item) async {
    final result = await FilePicker.platform.saveFile(
      fileName: item.name,
    );
    if (result != null) {
      try {
        await _sftpService?.downloadFile(item.path, result);
        _showMessage('下载成功');
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  Future<void> _deleteItem(SftpItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 "${item.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (item.isDirectory) {
          await _sftpService?.removeDirectory(item.path);
        } else {
          await _sftpService?.removeFile(item.path);
        }
        await _refresh();
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  Future<String?> _showNameDialog(String title, String hint) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _currentPath != '/' ? _goUp : null,
            ),
            Expanded(
              child: Text(
                _currentPath,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refresh,
            ),
          ],
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildToolbar(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Colors.red[300])),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _connect,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(child: Text('目录为空'));
    }

    // 按目录、文件分组排序
    final dirs = _items.where((i) => i.isDirectory).toList();
    final files = _items.where((i) => !i.isDirectory).toList();
    final sorted = [...dirs, ...files];

    return ListView.builder(
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final item = sorted[index];
        return ListTile(
          leading: Icon(
            item.isDirectory ? Icons.folder : _getFileIcon(item.name),
          ),
          title: Text(item.name),
          subtitle: item.isDirectory ? null : Text(_formatSize(item.size)),
          onTap: () => _onItemTap(item),
          onLongPress: () => _showItemMenu(item),
        );
      },
    );
  }

  Widget _buildToolbar() {
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.upload),
            onPressed: _uploadFile,
            tooltip: '上传',
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            onPressed: _createFolder,
            tooltip: '新建文件夹',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: '刷新',
          ),
        ],
      ),
    );
  }

  void _showItemMenu(SftpItem item) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('下载'),
            onTap: () {
              Navigator.pop(context);
              if (!item.isDirectory) _downloadFile(item);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('删除', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _deleteItem(item);
            },
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'bmp':
        return Icons.image;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'txt':
      case 'md':
      case 'json':
      case 'xml':
      case 'yaml':
      case 'yml':
        return Icons.description;
      case 'zip':
      case 'tar':
      case 'gz':
      case 'rar':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
```

**Step 2: Verify it compiles**

Run: `flutter analyze lib/presentation/screens/sftp_browser_screen.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/presentation/screens/sftp_browser_screen.dart
git commit -m "feat: add SftpBrowserScreen UI"
```

---

### Task 5: Add SFTP button to connection list

**Files:**
- Modify: `lib/presentation/widgets/connection_list.dart`

**Step 1: Add SFTP callback**

Add callback parameter to ConnectionList:
```dart
final Function(SshConnection)? onSftpTap;
```

**Step 2: Pass callback to _ConnectionListItem**

In itemBuilder, add:
```dart
onSftpTap: () => onSftpTap?.call(connection),
```

**Step 3: Add SFTP button to _ConnectionListItem**

Add parameter and button:
```dart
final VoidCallback? onSftpTap;

const _ConnectionListItem({
  ...
  this.onSftpTap,
});

// In trailing, add IconButton before PopupMenuButton:
trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    IconButton(
      icon: const Icon(Icons.folder_copy),
      onPressed: onSftpTap,
      tooltip: 'SFTP',
    ),
    PopupMenuButton(...),
  ],
),
```

**Step 4: Verify it compiles**

Run: `flutter analyze lib/presentation/widgets/connection_list.dart`
Expected: No errors

**Step 5: Commit**

```bash
git add lib/presentation/widgets/connection_list.dart
git commit -m "feat: add SFTP button to connection list"
```

---

### Task 6: Register SftpProvider in main.dart

**Files:**
- Modify: `lib/main.dart`

**Step 1: Add import**

```dart
import 'presentation/providers/sftp_provider.dart';
```

**Step 2: Add provider**

In MultiProvider, add:
```dart
ChangeNotifierProvider(
  create: (context) => SftpProvider(
    context.read<TerminalProvider>(),
  ),
),
```

**Step 3: Verify it compiles**

Run: `flutter analyze lib/main.dart`
Expected: No errors

**Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat: register SftpProvider in main.dart"
```

---

### Task 7: Wire up SFTP button in TerminalView

**Files:**
- Modify: `lib/presentation/widgets/terminal_view.dart`

**Step 1: Add import**

```dart
import 'sftp_browser_screen.dart';
```

**Step 2: Add SFTP navigation**

In the connection list callbacks, add onSftpTap to navigate:
```dart
onSftpTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => SftpBrowserScreen(connection: connection),
    ),
  );
},
```

**Step 3: Verify it compiles**

Run: `flutter analyze lib/presentation/widgets/terminal_view.dart`
Expected: No errors

**Step 4: Commit**

```bash
git add lib/presentation/widgets/terminal_view.dart
git commit -m "feat: wire up SFTP button to browser screen"
```

---

### Task 8: Final verification

**Step 1: Run full analysis**

Run: `flutter analyze`
Expected: No errors

**Step 2: Run tests**

Run: `flutter test`
Expected: All tests pass

**Step 3: Commit**

```bash
git add .
git commit -m "feat: complete SFTP browser implementation"
```
