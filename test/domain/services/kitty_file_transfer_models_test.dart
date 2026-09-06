import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/domain/services/kitty_file_transfer_models.dart';

/// Kitty 文件传输模型测试。
///
/// 这些是纯数据类与枚举，是整个 Kitty 传输链路依赖的领域模型。重点锁定：
/// 1. 可选字段的默认值（fileType 默认 regular、可空字段默认 null）——默认值被改动
///    会静默破坏传输握手/进度显示；
/// 2. 每个构造参数都被如实存储（字段保真）。
void main() {
  // --------------------------------------------------------------------------
  // FileMetadata
  // --------------------------------------------------------------------------
  group('FileMetadata', () {
    test(
      'Given no optional args, When constructing, Then fileType defaults to regular and optionals are null',
      () {
        final meta = FileMetadata(name: 'a.txt');

        expect(meta.name, 'a.txt');
        expect(meta.fileType, FileType.regular);
        expect(meta.size, isNull);
        expect(meta.permissions, isNull);
        expect(meta.mtime, isNull);
        expect(meta.linkTarget, isNull);
      },
    );

    test(
      'Given all fields provided, When constructing, Then every field is stored faithfully',
      () {
        final meta = FileMetadata(
          name: 'report.pdf',
          fileType: FileType.symlink,
          size: 4096,
          // 755 (octal) = 493 decimal; Dart has no octal literal prefix
          permissions: 493,
          mtime: 1730000000000000000,
          linkTarget: '/etc/hosts',
        );

        expect(meta.name, 'report.pdf');
        expect(meta.fileType, FileType.symlink);
        expect(meta.size, 4096);
        expect(meta.permissions, 493);
        expect(meta.mtime, 1730000000000000000);
        expect(meta.linkTarget, '/etc/hosts');
      },
    );

    test(
      'Given directory file type, When constructing, Then fileType is stored as directory',
      () {
        final meta = FileMetadata(name: 'mydir', fileType: FileType.directory);
        expect(meta.fileType, FileType.directory);
      },
    );
  });

  // --------------------------------------------------------------------------
  // TransferStatus
  // --------------------------------------------------------------------------
  group('TransferStatus', () {
    test(
      'Given only required args, When constructing, Then optionals default to null',
      () {
        final status = TransferStatus(sessionId: 's1', isOk: true);

        expect(status.sessionId, 's1');
        expect(status.isOk, isTrue);
        expect(status.fileId, isNull);
        expect(status.errorMessage, isNull);
        expect(status.size, isNull);
      },
    );

    test(
      'Given a failure status with message and size, When constructing, Then all fields are stored',
      () {
        final status = TransferStatus(
          sessionId: 's2',
          fileId: 'f9',
          isOk: false,
          errorMessage: 'File not found',
          size: 0,
        );

        expect(status.isOk, isFalse);
        expect(status.fileId, 'f9');
        expect(status.errorMessage, 'File not found');
        // size == 0 must be preserved (not treated as "unset")
        expect(status.size, 0);
      },
    );
  });

  // --------------------------------------------------------------------------
  // TransferProgress
  // --------------------------------------------------------------------------
  group('TransferProgress', () {
    test(
      'Given progress values, When constructing, Then all five fields are stored faithfully',
      () {
        final p = TransferProgress(
          fileName: 'big.bin',
          transferredBytes: 512,
          totalBytes: 1024,
          percent: 50.0,
          bytesPerSecond: 256,
        );

        expect(p.fileName, 'big.bin');
        expect(p.transferredBytes, 512);
        expect(p.totalBytes, 1024);
        expect(p.percent, 50.0);
        expect(p.bytesPerSecond, 256);
      },
    );

    test(
      'Given zero progress, When constructing, Then zero values are preserved (not "unset")',
      () {
        final p = TransferProgress(
          fileName: 'x',
          transferredBytes: 0,
          totalBytes: 100,
          percent: 0.0,
          bytesPerSecond: 0,
        );

        expect(p.transferredBytes, 0);
        expect(p.percent, 0.0);
        expect(p.bytesPerSecond, 0);
      },
    );
  });

  // --------------------------------------------------------------------------
  // ProtocolSupportResult
  // --------------------------------------------------------------------------
  group('ProtocolSupportResult', () {
    test(
      'Given unsupported detection with a reason, When constructing, Then both fields are stored',
      () {
        final r = ProtocolSupportResult(
          isSupported: false,
          errorMessage: 'Kitty protocol not detected',
        );

        expect(r.isSupported, isFalse);
        expect(r.errorMessage, 'Kitty protocol not detected');
      },
    );

    test(
      'Given supported detection without message, When constructing, Then errorMessage defaults to null',
      () {
        final r = ProtocolSupportResult(isSupported: true);

        expect(r.isSupported, isTrue);
        expect(r.errorMessage, isNull);
      },
    );
  });

  // --------------------------------------------------------------------------
  // Enums — pin the value sets (guards against accidental removal/reorder)
  // --------------------------------------------------------------------------
  group('enums', () {
    test(
      'Given the protocol enums, When enumerated, Then they expose exactly the expected members',
      () {
        expect(CompressionType.values, [CompressionType.none, CompressionType.zlib]);
        expect(
          FileType.values,
          [FileType.regular, FileType.directory, FileType.symlink, FileType.link],
        );
        expect(
          TransmissionType.values,
          [TransmissionType.simple, TransmissionType.rsync],
        );
      },
    );
  });
}
