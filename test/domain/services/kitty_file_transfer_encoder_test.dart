import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/domain/services/kitty_file_transfer_encoder.dart';

/// Frame-framing / round-trip tests for [KittyFileTransferEncoder].
///
/// Pins the protocol-contract parts that are unambiguous and spec-compliant:
///   * a regular-file `file` command carries EXACTLY ONE `n=` (name) field;
///   * `data` payloads base64-encode and round-trip back to the exact bytes;
///   * send/finish/cancel/status frames have the exact key=value layout the
///     kitty file-transfer protocol expects (`ac`, `id`, `fid`, `n`, `d`, ...);
///   * [KittyFileTransferEncoder.parseStatusResponse] decodes a status frame.
void main() {
  const enc = KittyFileTransferEncoder();
  const esc = '\x1b';
  const oscEnd = '\x1b\\'; // ESC backslash — OSC terminator

  /// Pull the `d=` (data) payload out of an `ac=data`/`end_data` frame.
  /// The base64 alphabet is A-Za-z0-9+/=, so this captures exactly the payload.
  String dataPayload(String frame) {
    final m = RegExp(r';d=([A-Za-z0-9+/=]+)').firstMatch(frame);
    expect(m, isNotNull, reason: 'frame has a d= payload: $frame');
    return m!.group(1)!;
  }

  group('KittyFileTransferEncoder framing', () {
    test('createSendSession: default vs optional params in fixed order', () {
      expect(enc.createSendSession('s1'), '$esc]5113;ac=send;id=s1$oscEnd');

      // All options set: zip, pw, q — appended in that order.
      expect(
        enc.createSendSession(
          's2',
          compression: CompressionType.zlib,
          bypass: 'secret',
          quiet: 2,
        ),
        '$esc]5113;ac=send;id=s2;zip=zlib;pw=secret;q=2$oscEnd',
      );

      // Baseline (no quiet / quiet<=0) must NOT emit a q= param; only >0 does.
      expect(enc.createSendSession('s3'), isNot(contains('q=')));
    });

    test('createFileMetadata (regular): exactly one n= field, correct size', () {
      final frame = enc.createFileMetadata(
        sessionId: 's1',
        fileId: 'f1',
        fileName: 'report.txt',
        fileSize: 123,
      );

      // Exact expected frame: ac=file, one n= (base64 name), sz (kitty 线上字段名，非 size), terminator.
      final b64 = base64Encode(utf8.encode('report.txt'));
      expect(frame, '$esc]5113;ac=file;id=s1;fid=f1;n=$b64;sz=123$oscEnd');

      // Invariant: a regular-file command carries EXACTLY ONE `n=` key.
      // (base64 alphabet is A-Za-z0-9+/=, so ';n=' can only be the name key.)
      expect(RegExp(r';n=').allMatches(frame).length, 1);
    });

    test('createFileMetadata (directory): ft=directory present', () {
      final frame = enc.createDirectoryMetadata(
        sessionId: 's1',
        fileId: 'd1',
        dirName: 'mydir',
      );
      expect(frame, contains(';ft=directory'));
      final b64 = base64Encode(utf8.encode('mydir'));
      expect(
        frame,
        '$esc]5113;ac=file;id=s1;fid=d1;n=$b64;ft=directory$oscEnd',
      );
    });

    test(
      'createFileMetadata symlink: documents current double-n target encoding',
      () {
        // Documents CURRENT behavior for a symbolic link (task #2): the encoder
        // emits the link name as `n=` and, when linkTarget is set, appends a
        // SECOND `n=` carrying the target. Note the kitty spec expects the
        // target in the data phase (`d=`), not a second `n=`; this test pins
        // the existing frame so any future change to the protocol flow (e.g.
        // moving the target into end_data) is an explicit, reviewed decision
        // rather than silent drift.
        final frame = enc.createFileMetadata(
          sessionId: 's1',
          fileId: 'f2',
          fileName: 'link',
          fileSize: 0,
          fileType: FileType.symlink,
          linkTarget: '/etc/passwd',
        );

        expect(frame.startsWith('$esc]5113;ac=file;id=s1;fid=f2;'), isTrue);
        // Exactly two `n=` fields: the name and the target (a known field).
        // Count `;n=` only — the base64 alphabet never contains ';', so this
        // can't false-match inside a payload blob.
        final nFields = RegExp(r';n=').allMatches(frame).length;
        expect(nFields, 2);
        expect(frame, contains(';ft=symlink'));

        final nameB64 = base64Encode(utf8.encode('link'));
        final targetB64 = base64Encode(utf8.encode('/etc/passwd'));
        // Base frame (name + sz), then ft, then the target as a second n=.
        expect(
          frame,
          '$esc]5113;ac=file;id=s1;fid=f2;n=$nameB64;sz=0;ft=symlink;n=$targetB64$oscEnd',
        );
      },
    );

    test(
      'createDataChunk: payload base64-encodes and round-trips to bytes',
      () {
        const payload = [0, 1, 2, 255, 168, 200, 7]; // incl. high/low bytes
        final frame = enc.createDataChunk(
          sessionId: 's1',
          fileId: 'f1',
          data: payload,
        );

        expect(frame.startsWith('$esc]5113;ac=data;id=s1;fid=f1;d='), isTrue);
        expect(frame.endsWith(oscEnd), isTrue);

        // The real round-trip: decode the emitted d= payload back to the bytes.
        final decoded = base64Decode(dataPayload(frame));
        expect(decoded, equals(payload));
      },
    );

    test('createEndData: with and without trailing data', () {
      // No trailing data: no d= field at all.
      final empty = enc.createEndData('s1', 'f1');
      expect(empty, '$esc]5113;ac=end_data;id=s1;fid=f1$oscEnd');
      expect(RegExp(r';d=').hasMatch(empty), isFalse);

      // With trailing data: d= present and round-trips.
      const tail = [9, 8, 7];
      final withData = enc.createEndData('s1', 'f1', data: tail);
      expect(base64Decode(dataPayload(withData)), equals(tail));
    });

    test('createFinishSession / createCancelSession: exact frames', () {
      expect(enc.createFinishSession('s9'), '$esc]5113;ac=finish;id=s9$oscEnd');
      expect(enc.createCancelSession('s9'), '$esc]5113;ac=cancel;id=s9$oscEnd');
    });

    test('parseStatusResponse: OK / non-OK / size / no-match', () {
      // Contract: parse a bare `ac=status;...` payload (no OSC wrapper).
      final ok = enc.parseStatusResponse('ac=status;id=s1;st=OK');
      expect(ok, isNotNull);
      expect(ok!.sessionId, 's1');
      expect(ok.isOk, isTrue);
      expect(ok.errorMessage, isNull);

      // Non-OK with a message.
      final err = enc.parseStatusResponse(
        'ac=status;id=s2;st=FAIL:file exists',
      );
      expect(err!.sessionId, 's2');
      expect(err.isOk, isFalse);
      expect(err.errorMessage, contains('file exists'));

      // A size (sz=N) is surfaced on the result.
      final sized = enc.parseStatusResponse('ac=status;id=s3;st=OK:ok sz=42');
      expect(sized!.isOk, isTrue);
      expect(sized.size, 42);

      // Unrelated text must not throw and yields null.
      expect(enc.parseStatusResponse('hello world'), isNull);
    });
  });
}
