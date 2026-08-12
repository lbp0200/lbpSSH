import 'dart:async';
import 'dart:io';

import 'package:utopia_tui/utopia_tui.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/data/repositories/connection_repository.dart';
import 'package:lbp_ssh/tui/tui_config_path.dart';
import 'package:lbp_ssh/tui/tui_controller.dart';
import 'package:lbp_ssh/tui/tui_router.dart';
import 'package:lbp_ssh/tui/key_parser.dart';

var _configFile = File('');
var _repo = ConnectionRepository();
late TuiController _controller;
StreamSubscription<List<int>>? _stdSub;

void main(List<String> args) async {
  _configFile = resolveTuiConfigFile();
  if (!await _configFile.exists()) {
    await _configFile.create(recursive: true);
    await _configFile.writeAsString('[]');
  }
  _repo = ConnectionRepository(configFile: _configFile);
  await _repo.init();
  _controller = TuiController(repository: _repo);
  _controller.state.connections = _repo.getAllConnections();

  while (_controller.running) {
    await _runTui();
    if (_controller.sshRequest != null) {
      final conn = _controller.sshRequest!;
      _controller.sshRequest = null;
      await _runSsh(conn);
      _controller.state.connections = _repo.getAllConnections();
    }
  }
}

final _term = TuiTerminal();

Future<void> _runTui() async {
  _term.write('\x1b[?1049h');
  _term.clearScreen();
  _term.hideCursor();

  stdin.echoMode = false;
  stdin.lineMode = false;

  var lastFrame = <String>[];
  _controller.running = true;

  final completer = Completer<void>();

  _render(lastFrame);

  await _stdSub?.cancel();
  _stdSub = stdin.listen((bytes) {
    final keys = _parseKeys(bytes);
    for (final k in keys) {
      if (k == 'ctrl_c') {
        _controller.running = false;
        completer.complete();
        return;
      }
      _controller.handleKey(k);
      _render(lastFrame);
    }
  });

  await completer.future;
  await _stdSub?.cancel();
  _term.write('\x1b[0m');
  _term.showCursor();
  _term.write('\x1b[?1049l');
  try {
    stdin.lineMode = true;
    stdin.echoMode = true;
  } catch (_) {}
}

void _render(List<String> lastFrame) {
  final ctx = TuiContext(_term);
  ctx.clear();
  paintCurrentScreen(_controller.state, ctx);

  final frame = ctx.snapshotStyled();
  for (var r = 0; r < frame.length; r++) {
    final prev = r < lastFrame.length ? lastFrame[r] : null;
    if (prev != frame[r]) {
      _term.setCursor(r, 0);
      _term.write(frame[r]);
    }
  }
  lastFrame
    ..clear()
    ..addAll(frame);
}

Future<void> _runSsh(SshConnection conn) async {
  stdout.writeln(
    '\nConnecting to ${conn.username}@${conn.host}:${conn.port}...',
  );
  stdout.writeln('Type "exit" or press Ctrl+D to return.\n');

  try {
    final result = await Process.run('ssh', [
      '-p',
      conn.port.toString(),
      '${conn.username}@${conn.host}',
    ], runInShell: true);
    if (result.exitCode != 0 && result.stderr.toString().isNotEmpty) {
      stderr.writeln(result.stderr);
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  } catch (e) {
    stderr.writeln('SSH failed: $e');
    await Future<void>.delayed(const Duration(seconds: 2));
  }
}

List<String> _parseKeys(List<int> bytes) => parseKeys(bytes);
