import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/tui/key_parser.dart';

void main() {
  group('parseKeys', () {
    test('parses regular characters', () {
      expect(parseKeys([97, 98, 99]), ['a', 'b', 'c']);
    });

    test('parses uppercase letters', () {
      expect(parseKeys([65, 66, 67]), ['A', 'B', 'C']);
    });

    test('parses digits', () {
      expect(parseKeys([48, 49, 50]), ['0', '1', '2']);
    });

    test('parses Enter key (13)', () {
      expect(parseKeys([13]), ['enter']);
    });

    test('parses Enter key (10)', () {
      expect(parseKeys([10]), ['enter']);
    });

    test('parses Tab key', () {
      expect(parseKeys([9]), ['tab']);
    });

    test('parses Escape key', () {
      expect(parseKeys([27]), ['esc']);
    });

    test('parses Backspace (127)', () {
      expect(parseKeys([127]), ['backspace']);
    });

    test('parses Backspace (8)', () {
      expect(parseKeys([8]), ['backspace']);
    });

    test('parses Ctrl+C', () {
      expect(parseKeys([3]), ['ctrl_c']);
    });

    test('parses Ctrl+D', () {
      expect(parseKeys([4]), <String>[]);
    });

    test('parses Ctrl+Q', () {
      expect(parseKeys([17]), <String>[]);
    });

    test('parses arrow Up (ESC [ A)', () {
      expect(parseKeys([27, 91, 65]), <String>['up']);
    });

    test('parses arrow Down (ESC [ B)', () {
      expect(parseKeys([27, 91, 66]), ['down']);
    });

    test('parses arrow Right (ESC [ C)', () {
      expect(parseKeys([27, 91, 67]), ['right']);
    });

    test('parses arrow Left (ESC [ D)', () {
      expect(parseKeys([27, 91, 68]), ['left']);
    });

    test('parses Home (ESC [ H)', () {
      expect(parseKeys([27, 91, 72]), ['home']);
    });

    test('parses End (ESC [ F)', () {
      expect(parseKeys([27, 91, 70]), ['end']);
    });

    test('handles empty input', () {
      expect(parseKeys([]), <String>[]);
    });

    test('handles mixed input: arrow then character', () {
      expect(parseKeys([27, 91, 65, 97]), <String>['up', 'a']);
    });

    test('handles mixed input: characters then Enter', () {
      expect(parseKeys([108, 115, 13]), <String>['l', 's', 'enter']);
    });

    test('ignores non-printable control chars (Ctrl+A)', () {
      expect(parseKeys([1]), <String>[]);
    });

    test('ignores non-printable control chars (Ctrl+Z)', () {
      expect(parseKeys([26]), <String>[]);
    });

    test('parses 2-byte UTF-8 character (é)', () {
      expect(parseKeys([0xC3, 0xA9]), ['é']);
    });

    test('parses 3-byte UTF-8 character (€)', () {
      expect(parseKeys([0xE2, 0x82, 0xAC]), ['€']);
    });

    test('parses 4-byte UTF-8 character (emoji)', () {
      expect(parseKeys([0xF0, 0x9F, 0x98, 0x80]), ['😀']);
    });

    test('parses mixed ASCII and multibyte UTF-8', () {
      expect(parseKeys([97, 0xC3, 0xA9, 98]), ['a', 'é', 'b']);
    });

    test('skips truncated UTF-8 sequence (header claims 3 bytes, has 2)', () {
      expect(parseKeys([0xE2, 0x82]), <String>[]);
    });

    test('skips truncated 4-byte UTF-8 sequence', () {
      expect(parseKeys([0xF0, 0x9F]), <String>[]);
    });

    test('skips invalid UTF-8 leading byte (0x80)', () {
      expect(parseKeys([0x80]), <String>[]);
    });

    test('skips malformed continuation byte after valid multibyte', () {
      // 0xC3 声明 2 字节，但第二个字节是非法 continuation 0x41
      expect(parseKeys([0xC3, 0x41]), <String>[]);
    });
  });
}
