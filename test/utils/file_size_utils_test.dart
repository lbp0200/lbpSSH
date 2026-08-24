import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/utils/file_size_utils.dart';

void main() {
  group('formatFileSize', () {
    test('Given 0 bytes, When formatting, Then returns 0 B', () {
      expect(formatFileSize(0), '0 B');
    });

    test('Given bytes < 1024, When formatting, Then returns B', () {
      expect(formatFileSize(1), '1 B');
      expect(formatFileSize(1023), '1023 B');
    });

    test('Given exactly 1024 bytes, When formatting, Then returns 1.0 KB', () {
      expect(formatFileSize(1024), '1.0 KB');
    });

    test(
      'Given KB range, When formatting, Then returns KB with one decimal',
      () {
        expect(formatFileSize(1536), '1.5 KB');
        expect(formatFileSize(1024 * 512), '512.0 KB');
      },
    );

    test('Given exactly 1 MB, When formatting, Then returns 1.0 MB', () {
      expect(formatFileSize(1024 * 1024), '1.0 MB');
    });

    test('Given MB range, When formatting, Then returns MB', () {
      expect(formatFileSize(1024 * 1024 * 5 + 512 * 1024), '5.5 MB');
    });

    test('Given exactly 1 GB, When formatting, Then returns 1.0 GB', () {
      expect(formatFileSize(1024 * 1024 * 1024), '1.0 GB');
    });

    test('Given GB range, When formatting, Then returns GB', () {
      expect(formatFileSize((1.5 * 1024 * 1024 * 1024).toInt()), '1.5 GB');
    });

    test(
      'Given large file, When formatting, Then matches existing dialog behavior',
      () {
        // 与 transfer_progress_dialog / sftp_browser_screen 旧实现保持一致
        expect(formatFileSize(1024 * 1024 * 1024 * 2), '2.0 GB');
      },
    );
  });
}
