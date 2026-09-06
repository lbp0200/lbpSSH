import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';

/// Fuzz for [SshConfigEntry.parse] — parses untrusted user `~/.ssh/config`.
///
/// Generates randomized Host blocks (varying property sets, out-of-range
/// ports, repeated IdentityFile/HostName/User, and noise lines) and asserts
/// the parser's actual invariants:
///   * one entry per `Host` block;
///   * `hostName` is the Host alias verbatim;
///   * FIRST-wins for `HostName` (→ actualHost) and `User` — matching standard
///     ssh_config semantics ("first value obtained is used");
///   * `Port` clamps to 1-65535 else null;
///   * `identityFiles` accumulates every IdentityFile in order (null if none);
///   * blank / comment / single-token junk lines are skipped without crash.
void main() {
  group('fuzz: SshConfigEntry.parse (randomized ~/.ssh/config)', () {
    int fuzzSeed = 0x53524946; // deterministic LCG seed

    int nextInt() {
      fuzzSeed = (fuzzSeed * 1103515245 + 12345) & 0x7fffffff;
      return fuzzSeed;
    }

    String randomHostToken() => 'host-${nextInt() % 1000}';

    test(
      'Given N randomized Host blocks, When parse called, Then invariants hold',
      () {
        const blockCount = 60;
        final blocks = <String>[]; // generated lines, in order
        final expected = <Map<String, Object?>>[];

        for (var i = 0; i < blockCount; i++) {
          final hostAlias = randomHostToken();
          blocks.add('Host $hostAlias');

          String? expActualHost; // from HostName (first wins)
          String? expUser; // from User (first wins)
          int? expPort;
          final idFiles = <String>[];

          // Optional HostName -> actualHost, FIRST occurrence wins.
          if (nextInt() % 3 != 0) {
            expActualHost = '192.168.${nextInt() % 255}.${1 + nextInt() % 254}';
            blocks.add('    HostName $expActualHost');
            // A second HostName must be IGNORED (first wins).
            if (nextInt() % 2 == 0) {
              blocks.add('    HostName override.example.com');
            }
          }

          // Optional User -> user, FIRST occurrence wins.
          if (nextInt() % 3 != 0) {
            expUser = 'user${nextInt() % 50}';
            blocks.add('    User $expUser');
            // A second User must be IGNORED (first wins).
            if (nextInt() % 2 == 0) {
              blocks.add('    User finaluser_$i');
            }
          }

          // Optional Port: mix of valid, boundary, and out-of-range.
          if (nextInt() % 4 != 0) {
            final caseRoll = nextInt() % 5;
            String portToken;
            switch (caseRoll) {
              case 0: // normal
                portToken = '${1 + nextInt() % 65535}';
                break;
              case 1: // upper boundary
                portToken = '65535';
                break;
              case 2: // zero -> invalid
                portToken = '0';
                break;
              case 3: // negative -> invalid
                portToken = '-42';
                break;
              default: // far out of range -> invalid
                portToken = '${65536 + nextInt() % 1000}';
            }
            blocks.add('    Port $portToken');
            final p = int.tryParse(portToken);
            expPort = (p != null && p >= 1 && p <= 65535) ? p : null;
          }

          // IdentityFile: 0..3, order preserved.
          final nKeys = nextInt() % 4;
          for (var k = 0; k < nKeys; k++) {
            final path = '/home/u/key_${i}_$k';
            idFiles.add(path);
            blocks.add('    IdentityFile $path');
          }

          // Noise that must be skipped without creating/altering the entry:
          // a blank line, an indented comment, and a single-token junk line.
          if (nextInt() % 5 == 0) {
            blocks.add('');
            blocks.add('    # a comment line');
            blocks.add('BareJunkToken');
          }

          expected.add({
            'hostName': hostAlias,
            'actualHost': expActualHost,
            'user': expUser,
            'port': expPort,
            'identityFiles': idFiles,
          });
        }

        final entries = SshConfigEntry.parse(blocks.join('\n'));

        // One entry per Host block.
        expect(entries.length, blockCount);

        for (var i = 0; i < blockCount; i++) {
          final e = expected[i];
          final item = entries[i];
          expect(item.hostName, e['hostName'], reason: 'hostName idx=$i');
          // HostName value -> actualHost, first wins.
          expect(item.actualHost, e['actualHost'], reason: 'actualHost idx=$i');
          // User -> user, first wins.
          expect(item.user, e['user'], reason: 'user idx=$i');
          // Port clamps to 1-65535 else null.
          expect(item.port, e['port'], reason: 'port idx=$i');
          // identityFiles accumulate in order; null when none present.
          final expId = e['identityFiles'] as List<String>;
          expect(
            item.identityFiles,
            expId.isEmpty ? isNull : equals(expId),
            reason: 'identityFiles idx=$i',
          );
        }
      },
    );
  });
}
