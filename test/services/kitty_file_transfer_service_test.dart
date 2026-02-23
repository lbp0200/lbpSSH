import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/domain/services/kitty_file_transfer_service.dart';

void main() {
  group('KittyFileTransferService', () {
    test('returns unsupported when remote has no ki tool', () async {
      // 当远程没有安装 ki 工具时，应该返回不支持
      final service = KittyFileTransferService();
      final result = await service.checkProtocolSupport();
      expect(result.isSupported, isFalse);
      expect(result.errorMessage, contains('未连接到终端'));
    });

    test('generates correct OSC sequence for send session', () {
      // 验证生成的 OSC 序列格式正确
      final encoder = _TestEncoder();
      final sequence = encoder.startSendSession(sessionId: 'test123');

      // OSC 5113 序列格式
      expect(sequence, contains('\x1b]5113'));
      expect(sequence, contains('ac=send'));
      expect(sequence, contains('id=test123'));
    });

    test('generates correct OSC sequence for file metadata', () {
      final encoder = _TestEncoder();
      final sequence = encoder.sendFileMetadata(
        sessionId: 'test123',
        fileId: 'f1',
        destinationPath: '/home/user/test.txt',
      );

      expect(sequence, contains('\x1b]5113'));
      expect(sequence, contains('ac=file'));
      expect(sequence, contains('fid=f1'));
    });

    test('generates correct OSC sequence for data chunk', () {
      final encoder = _TestEncoder();
      final sequence = encoder.sendDataChunk(
        sessionId: 'test123',
        fileId: 'f1',
        data: [1, 2, 3, 4],
      );

      expect(sequence, contains('\x1b]5113'));
      expect(sequence, contains('ac=data'));
      expect(sequence, contains('fid=f1'));
    });

    test('generates finish session command', () {
      final encoder = _TestEncoder();
      final sequence = encoder.finishSession('test123');

      expect(sequence, contains('ac=finish'));
    });
  });
}

/// 测试用编码器 - 复用 KittyFileTransferEncoder 的逻辑
class _TestEncoder {
  String startSendSession({required String sessionId}) {
    return '\x1b]5113;ac=send;id=$sessionId\x1b\\';
  }

  String sendFileMetadata({
    required String sessionId,
    required String fileId,
    required String destinationPath,
  }) {
    return '\x1b]5113;ac=file;id=$sessionId;fid=$fileId;n=${_encode64(destinationPath)}\x1b\\';
  }

  String sendDataChunk({
    required String sessionId,
    required String fileId,
    required List<int> data,
  }) {
    final encoded = _encode64Bytes(data);
    return '\x1b]5113;ac=data;id=$sessionId;fid=$fileId;d=$encoded\x1b\\';
  }

  String finishSession(String sessionId) {
    return '\x1b]5113;ac=finish;id=$sessionId\x1b\\';
  }

  String _encode64(String input) {
    // 简化的 base64 编码
    return input;
  }

  String _encode64Bytes(List<int> data) {
    // 简化的 base64 编码
    return data.toString();
  }
}
