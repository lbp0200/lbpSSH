import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/domain/services/file_list_parser.dart';

void main() {
  group('FileListParser', () {
    group('parse', () {
      test(
        'Given valid Linux ls -la output (long-iso format), When parse called, Then returns file items',
        () {
          // Arrange (Given) - Using --time-style=long-iso format: permissions links user group size date time name
          const output = '''total 24
drwxr-xr-x  5 user user 4096 2024-02-24 20:08 dirname
-rw-r--r--  1 user user  1234 2024-02-24 20:08 file.txt
-rw-r--r--  1 user user  5678 2024-01-15 10:30 another-file.log''';

          // Act (When)
          final items = FileListParser.parse(output, '/home/user');

          // Assert (Then)
          expect(items.length, 3); // Excludes . and ..
          expect(items[0].name, 'dirname');
          expect(items[0].isDirectory, true);
          expect(items[0].size, 4096);
          expect(items[1].name, 'file.txt');
          expect(items[1].isDirectory, false);
          expect(items[1].size, 1234);
          expect(items[2].name, 'another-file.log');
          expect(items[2].isDirectory, false);
          expect(items[2].size, 5678);
        },
      );

      test(
        'Given long-iso output with filename containing spaces, When parse called, Then preserves full filename',
        () {
          // Arrange (Given) - long-iso format: 名称从索引 7 起（date time name）
          const output = '''total 24
-rw-r--r--  1 user user 1234 2024-02-24 20:08 my file.txt
drwxr-xr-x  5 user user 4096 2024-02-24 20:08 my dir''';

          // Act (When)
          final items = FileListParser.parse(output, '/home/user');

          // Assert (Then) - 名称须保留完整（含首段 "my"），日期仍按 long-iso 解析
          expect(items.length, 2);
          expect(items[0].name, 'my file.txt');
          expect(items[1].name, 'my dir');
          expect(items[0].modified!.year, 2024);
          expect(items[0].modified!.month, 2);
          expect(items[0].modified!.day, 24);
        },
      );

      test(
        'Given macOS ls -la output, When parse called, Then returns file items',
        () {
          // Arrange (Given)
          const output = '''total 24
drwxr-xr-x   5 user  staff   160 Feb 24 20:08 .
drwxr-xr-x   1 user  staff   160 Feb 24 20:08 ..
drwxr-xr-x   3 user  staff   96 Dec 24 10:30 Documents
-rw-r--r--   1 user  staff  1234 Feb 24 20:08 test.txt''';

          // Act (When)
          final items = FileListParser.parse(
            output,
            '/Users/user',
            osType: 'darwin',
          );

          // Assert (Then)
          expect(items.length, 2);
          expect(items[0].name, 'Documents');
          expect(items[0].isDirectory, true);
          expect(items[1].name, 'test.txt');
          expect(items[1].isDirectory, false);
        },
      );

      test(
        'Given empty output, When parse called, Then returns empty list',
        () {
          // Arrange (Given)
          const output = '';

          // Act (When)
          final items = FileListParser.parse(output, '/home/user');

          // Assert (Then)
          expect(items, isEmpty);
        },
      );

      test(
        'Given output with only total line, When parse called, Then returns empty list',
        () {
          // Arrange (Given)
          const output = 'total 0';

          // Act (When)
          final items = FileListParser.parse(output, '/home/user');

          // Assert (Then)
          expect(items, isEmpty);
        },
      );

      test(
        'Given output with whitespace lines, When parse called, Then skips empty lines',
        () {
          // Arrange (Given)
          const output = '''total 24

drwxr-xr-x  5 user user 4096 Feb 24 20:08 dirname

-rw-r--r--  1 user user 1234 Feb 24 20:08 file.txt
''';

          // Act (When)
          final items = FileListParser.parse(output, '/home/user');

          // Assert (Then)
          expect(items.length, 2);
        },
      );

      test(
        'Given filename with spaces, When parse called, Then preserves filename',
        () {
          // Arrange (Given)
          const output = '''total 24
-rw-r--r--  1 user user 1234 Feb 24 20:08 file with spaces.txt
drwxr-xr-x  3 user user 4096 Feb 24 10:30 dir name''';

          // Act (When)
          final items = FileListParser.parse(output, '/home/user');

          // Assert (Then)
          expect(items.length, 2);
          expect(items[0].name, 'file with spaces.txt');
          expect(items[1].name, 'dir name');
        },
      );

      test(
        'Given symlink, When parse called, Then identifies as file (not directory)',
        () {
          // Arrange (Given)
          const output = '''total 8
lrwxrwxrwx  1 user user   24 Feb 24 20:08 link -> target''';

          // Act (When)
          final items = FileListParser.parse(output, '/home/user');

          // Assert (Then)
          expect(items.length, 1);
          expect(items[0].name, 'link -> target');
          expect(
            items[0].isDirectory,
            false,
          ); // symlink starts with 'l', not 'd'
        },
      );

      test(
        'Given full path construction, When parse called, Then constructs correct full path',
        () {
          // Arrange (Given)
          const output = '''total 8
-rw-r--r--  1 user user 100 Feb 24 20:08 file.txt''';

          // Act (When)
          final items = FileListParser.parse(output, '/home/user');

          // Assert (Then)
          expect(items[0].path, '/home/user/file.txt');
        },
      );

      test(
        'Given root path, When parse called, Then constructs correct full path',
        () {
          // Arrange (Given)
          const output = '''total 8
drwxr-xr-x  2 root root 4096 Feb 24 20:08 etc''';

          // Act (When)
          final items = FileListParser.parse(output, '/');

          // Assert (Then)
          expect(items[0].path, '/etc');
        },
      );
    });

    group('parse with date formats', () {
      test(
        'Given ISO date format (Linux), When parse called, Then parses date correctly',
        () {
          // Arrange (Given)
          const output = '''total 8
-rw-r--r--  1 user user 1234 2024-01-15 10:30 file.txt''';

          // Act (When)
          final items = FileListParser.parse(output, '/home/user');

          // Assert (Then)
          expect(items[0].modified, isNotNull);
          expect(items[0].modified!.year, 2024);
          expect(items[0].modified!.month, 1);
          expect(items[0].modified!.day, 15);
          expect(items[0].modified!.hour, 10);
          expect(items[0].modified!.minute, 30);
        },
      );

      test(
        'Given macOS date format, When parse called, Then parses date correctly',
        () {
          // Arrange (Given)
          const output = '''total 8
-rw-r--r--  1 user staff 1234 Dec 25 14:30 file.txt''';

          // Act (When)
          final items = FileListParser.parse(
            output,
            '/Users/user',
            osType: 'darwin',
          );

          // Assert (Then)
          expect(items[0].modified, isNotNull);
          expect(items[0].modified!.month, 12);
          expect(items[0].modified!.day, 25);
          expect(items[0].modified!.hour, 14);
          expect(items[0].modified!.minute, 30);
        },
      );

      test(
        'Given invalid date format, When parse called, Then returns null for modified',
        () {
          // Arrange (Given)
          const output = '''total 8
-rw-r--r--  1 user user 1234 unknown date file.txt''';

          // Act (When)
          final items = FileListParser.parse(output, '/home/user');

          // Assert (Then)
          expect(items[0].modified, isNull);
        },
      );
    });

    group('parse with special cases', () {
      test(
        'Given file with sticky bit permissions, When parse called, Then parses correctly',
        () {
          // Arrange (Given)
          const output = '''total 8
drwxrwxrwt  5 root root 4096 Feb 24 20:08 tmp''';

          // Act (When)
          final items = FileListParser.parse(output, '/tmp');

          // Assert (Then)
          expect(items.length, 1);
          expect(items[0].name, 'tmp');
          expect(items[0].isDirectory, true);
        },
      );

      test(
        'Given file with setuid/setgid permissions, When parse called, Then parses correctly',
        () {
          // Arrange (Given)
          const output = '''total 8
-rwsr-sr-x  1 root root 1234 Feb 24 20:08 privileged''';

          // Act (When)
          final items = FileListParser.parse(output, '/usr/bin');

          // Assert (Then)
          expect(items.length, 1);
          expect(items[0].name, 'privileged');
          expect(items[0].isDirectory, false);
        },
      );

      test(
        'Given hidden file starting with dot, When parse called, Then includes in list',
        () {
          // Arrange (Given)
          const output = '''total 8
-rw-r--r--  1 user user 1234 Feb 24 20:08 .hidden''';

          // Act (When)
          final items = FileListParser.parse(output, '/home/user');

          // Assert (Then)
          expect(items.length, 1);
          expect(items[0].name, '.hidden');
        },
      );

      test(
        'Given file with very long name, When parse called, Then preserves full name',
        () {
          // Arrange (Given)
          final longName = 'a' * 200;
          final output = '''total 8
-rw-r--r--  1 user user 1234 Feb 24 20:08 $longName''';

          // Act (When)
          final items = FileListParser.parse(output, '/home/user');

          // Assert (Then)
          expect(items.length, 1);
          expect(items[0].name, longName);
        },
      );

      test('Given file with zero size, When parse called, Then size is 0', () {
        // Arrange (Given)
        const output = '''total 0
-rw-r--r--  1 user user 0 Feb 24 20:08 empty''';

        // Act (When)
        final items = FileListParser.parse(output, '/home/user');

        // Assert (Then)
        expect(items.length, 1);
        expect(items[0].size, 0);
      });
    });

    group('fuzz (randomized ls -la output)', () {
      // Deterministic LCG so the fuzz is reproducible across runs/CI.
      int fuzzSeed = 20260905;
      int nextInt() {
        fuzzSeed = (fuzzSeed * 1103515245 + 12345) & 0x7fffffff;
        return fuzzSeed;
      }

      // Realistic filename fragments (single spaces only, so round-trip is exact).
      const fragments = [
        'a', 'b.txt', 'file-log.tar.gz', 'data_2024.csv', 'x_y_z',
        'dir.name', 'a-b.c.d', 'notes (final).md', '1 2 3', 'report v2.pdf'
      ];

      String randomName() {
        final words = List<String>.generate(
          1 + nextInt() % 4, // 1..4 words
          (_) => fragments[nextInt() % fragments.length],
        );
        return words.join(' ');
      }

      const monthNums = {
        'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
        'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12
      };
      final monthKeys = monthNums.keys.toList();

      String p2(int v) => v.toString().padLeft(2, '0');

      test(
          'Given randomized long-iso and month-name lines with spaced/symlink names, When parse called, Then names, paths, sizes, dirs, dates round-trip',
          () {
        final fixedNow = DateTime(2026, 3, 4, 5, 6); // deterministic clock

        // One generated record: the raw ls line + what the parser MUST yield.
        final records = <Map<String, Object>>[];
        for (var i = 0; i < 200; i++) {
          // Sprinkle skip-able lines to pin the '.'/'..'/'total' short-circuits.
          if (i % 25 == 0) {
            records.add({
              'line': 'drwxr-xr-x 2 user group 4096 2024-01-15 10:30 .',
              'skip': true,
            });
            continue;
          }
          if (i % 25 == 1) {
            records.add({'line': 'total ${100 + i}', 'skip': true});
            continue;
          }

          final useIso = nextInt() % 2 == 0;
          final kind = nextInt() % 3; // 0 file, 1 dir, 2 symlink
          final isDir = kind == 1;
          final symlink = kind == 2;
          String name = randomName();
          if (symlink) name = '$name -> ${randomName()}';

          final size = nextInt() % 50000;
          final y = 2020 + (nextInt() % 6);
          final mo = 1 + nextInt() % 12;
          final d = 1 + nextInt() % 28;
          final hh = nextInt() % 24;
          final mm = nextInt() % 60;

          final perms = isDir ? 'drwxr-xr-x' : symlink ? 'lrwxrwxrwx' : '-rw-r--r--';
          String line;
          DateTime expMod;
          if (useIso) {
            line = '$perms 1 user group $size '
                '${y.toString().padLeft(4, '0')}-${p2(mo)}-${p2(d)} '
                '${p2(hh)}:${p2(mm)} $name';
            expMod = DateTime(y, mo, d, hh, mm);
          } else {
            final mk = monthKeys[nextInt() % monthKeys.length];
            line = '$perms 1 user group $size '
                '$mk ${p2(d)} ${p2(hh)}:${p2(mm)} $name';
            // month-name lines carry no year -> parser uses clock.year (2026).
            expMod = DateTime(fixedNow.year, monthNums[mk]!, d, hh, mm);
          }

          records.add({
            'line': line,
            'skip': false,
            'name': name,
            'isDir': isDir,
            'size': size,
            'expMod': expMod,
          });
        }

        for (final basePath in const ['/', '/home/user']) {
          final output = records.map((r) => r['line'] as String).join('\n');
          final items =
              FileListParser.parse(output, basePath, clock: () => fixedNow);

          final expectedRecords = records.where((r) => r['skip'] == false).toList();

          // Count invariant: only non-skipped lines produce items.
          expect(items.length, expectedRecords.length, reason: 'basePath=$basePath');

          for (var i = 0; i < expectedRecords.length; i++) {
            final e = expectedRecords[i];
            final item = items[i];
            // Name round-trips verbatim (incl. internal spaces and " -> target").
            expect(item.name, e['name'], reason: 'name basePath=$basePath idx=$i');
            // Path is always derived from name + currentPath.
            final expPath = basePath == '/' ? '/${item.name}' : '$basePath/${item.name}';
            expect(item.path, expPath, reason: 'path basePath=$basePath idx=$i');
            expect(item.isDirectory, e['isDir'] as bool);
            expect(item.size, e['size'] as int);
            // Date round-trips to the exact expected instant.
            expect(item.modified, e['expMod'], reason: 'date basePath=$basePath idx=$i');
          }
        }
      });
    });
  });
}
