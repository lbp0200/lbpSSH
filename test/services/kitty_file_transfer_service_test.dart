import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/domain/services/kitty_file_transfer_service.dart';

void main() {
  late KittyFileTransferEncoder encoder;

  setUp(() {
    encoder = KittyFileTransferEncoder();
  });

  group('KittyFileTransferEncoder', () {
    group('encodeFileName', () {
      test(
          'Given simple filename, When encoding, Then returns base64 encoded string',
          () {
        final result = encoder.encodeFileName('test.txt');
        expect(result, base64Encode(utf8.encode('test.txt')));
      });

      test(
          'Given filename with special characters, When encoding, Then returns base64 encoded string',
          () {
        final result = encoder.encodeFileName('文件.txt');
        expect(result, base64Encode(utf8.encode('文件.txt')));
      });
    });

    group('createSendSession', () {
      test(
          'Given sessionId, When creating send session, Then generates correct OSC sequence',
          () {
        final sequence = encoder.createSendSession('test123');

        // OSC 5113 sequence format
        expect(sequence, contains('\x1b]5113'));
        expect(sequence, contains('ac=send'));
        expect(sequence, contains('id=test123'));
        expect(sequence, endsWith('\x1b\\'));
      });

      test(
          'Given sessionId with zlib compression, When creating send session, Then includes compression',
          () {
        final sequence = encoder.createSendSession(
          'test123',
          compression: CompressionType.zlib,
        );

        expect(sequence, contains('zip=zlib'));
      });

      test(
          'Given sessionId with bypass password, When creating send session, Then includes password',
          () {
        final sequence = encoder.createSendSession(
          'test123',
          bypass: 'secret',
        );

        expect(sequence, contains('pw=secret'));
      });

      test(
          'Given quiet mode, When creating send session, Then includes quiet parameter',
          () {
        final sequence = encoder.createSendSession(
          'test123',
          quiet: 1,
        );

        expect(sequence, contains('q=1'));
      });
    });

    group('createReceiveSession', () {
      test(
          'Given sessionId, When creating receive session, Then generates correct OSC sequence',
          () {
        final sequence = encoder.createReceiveSession('test123');

        expect(sequence, contains('\x1b]5113'));
        expect(sequence, contains('ac=recv'));
        expect(sequence, contains('id=test123'));
      });
    });

    group('createFileMetadata', () {
      test(
          'Given file metadata, When creating file metadata sequence, Then generates correct OSC sequence',
          () {
        final sequence = encoder.createFileMetadata(
          sessionId: 'test123',
          fileId: 'f1',
          fileName: 'test.txt',
          fileSize: 1024,
        );

        expect(sequence, contains('\x1b]5113'));
        expect(sequence, contains('ac=file'));
        expect(sequence, contains('id=test123'));
        expect(sequence, contains('fid=f1'));
        expect(sequence, contains('size=1024'));
      });

      test(
          'Given directory file type, When creating file metadata, Then includes directory type',
          () {
        final sequence = encoder.createFileMetadata(
          sessionId: 'test123',
          fileId: 'f1',
          fileName: 'mydir',
          fileSize: 4096,
          fileType: FileType.directory,
        );

        expect(sequence, contains('ft=directory'));
      });

      test(
          'Given symlink file type, When creating file metadata, Then includes symlink type',
          () {
        final sequence = encoder.createFileMetadata(
          sessionId: 'test123',
          fileId: 'f1',
          fileName: 'link',
          fileSize: 0,
          fileType: FileType.symlink,
          linkTarget: 'target',
        );

        expect(sequence, contains('ft=symlink'));
      });

      test(
          'Given rsync transmission type, When creating file metadata, Then includes rsync type',
          () {
        final sequence = encoder.createFileMetadata(
          sessionId: 'test123',
          fileId: 'f1',
          fileName: 'test.txt',
          fileSize: 1024,
          transmissionType: TransmissionType.rsync,
        );

        expect(sequence, contains('tt=rsync'));
      });

      test(
          'Given permissions, When creating file metadata, Then includes permissions',
          () {
        final sequence = encoder.createFileMetadata(
          sessionId: 'test123',
          fileId: 'f1',
          fileName: 'test.txt',
          fileSize: 1024,
          permissions: 420, // 0o644 = 420
        );

        expect(sequence, contains('prm=420'));
      });
    });

    group('createDirectoryMetadata', () {
      test(
          'Given directory metadata, When creating directory metadata sequence, Then generates correct OSC sequence',
          () {
        final sequence = encoder.createDirectoryMetadata(
          sessionId: 'test123',
          fileId: 'd1',
          dirName: 'mydir',
        );

        expect(sequence, contains('\x1b]5113'));
        expect(sequence, contains('ac=file'));
        expect(sequence, contains('ft=directory'));
      });
    });

    group('createDataChunk', () {
      test(
          'Given data chunk, When creating data chunk sequence, Then generates correct OSC sequence',
          () {
        final sequence = encoder.createDataChunk(
          sessionId: 'test123',
          fileId: 'f1',
          data: [1, 2, 3, 4],
        );

        expect(sequence, contains('\x1b]5113'));
        expect(sequence, contains('ac=data'));
        expect(sequence, contains('fid=f1'));
        expect(sequence, contains('d='));
      });
    });

    group('createEndData', () {
      test(
          'Given sessionId and fileId, When creating end data sequence, Then generates correct OSC sequence',
          () {
        final sequence = encoder.createEndData('test123', 'f1');

        expect(sequence, contains('ac=end_data'));
        expect(sequence, contains('id=test123'));
        expect(sequence, contains('fid=f1'));
      });

      test(
          'Given data with sessionId and fileId, When creating end data sequence, Then includes data',
          () {
        final sequence = encoder.createEndData('test123', 'f1', data: [1, 2, 3]);

        expect(sequence, contains('d='));
      });
    });

    group('createFinishSession', () {
      test(
          'Given sessionId, When creating finish session sequence, Then generates correct OSC sequence',
          () {
        final sequence = encoder.createFinishSession('test123');

        expect(sequence, contains('ac=finish'));
        expect(sequence, contains('id=test123'));
      });
    });

    group('createCancelSession', () {
      test(
          'Given sessionId, When creating cancel session sequence, Then generates correct OSC sequence',
          () {
        final sequence = encoder.createCancelSession('test123');

        expect(sequence, contains('ac=cancel'));
        expect(sequence, contains('id=test123'));
      });
    });

    group('parseStatusResponse', () {
      test(
          'Given OK status response, When parsing, Then returns TransferStatus with isOk true',
          () {
        const response = 'ac=status;id=test123;st=OK';
        final result = encoder.parseStatusResponse(response);

        expect(result, isNotNull);
        expect(result!.isOk, isTrue);
        expect(result.sessionId, 'test123');
      });

      test(
          'Given ERROR status response, When parsing, Then returns TransferStatus with isOk false',
          () {
        const response = 'ac=status;id=test123;st=ERROR:File not found';
        final result = encoder.parseStatusResponse(response);

        expect(result, isNotNull);
        expect(result!.isOk, isFalse);
        expect(result.errorMessage, 'File not found');
      });

      test(
          'Given response with size, When parsing, Then extracts size',
          () {
        const response = 'ac=status;id=test123;st=OK;sz=1024';
        final result = encoder.parseStatusResponse(response);

        expect(result!.size, 1024);
      });

      test(
          'Given invalid response, When parsing, Then returns null',
          () {
        const response = 'invalid response';
        final result = encoder.parseStatusResponse(response);

        expect(result, isNull);
      });
    });
  });

  group('KittyFileTransferService', () {
    test(
        'Given no terminal connection, When checking protocol support, Then returns unsupported',
        () async {
      final service = KittyFileTransferService();
      final result = await service.checkProtocolSupport();
      expect(result.isSupported, isFalse);
      expect(result.errorMessage, contains('未连接到终端'));
    });

    test(
        'Given no terminal connection, When accessing isConnected, Then returns false',
        () {
      final service = KittyFileTransferService();
      expect(service.isConnected, isFalse);
    });

    test(
        'Given no terminal connection, When accessing supportsKittyProtocol, Then returns false',
        () {
      final service = KittyFileTransferService();
      expect(service.supportsKittyProtocol, isFalse);
    });

    test(
        'Given initial path, When creating service, Then sets currentPath',
        () {
      final service = KittyFileTransferService(initialPath: '/home/user');
      expect(service.currentPath, '/home/user');
    });
  });
}
