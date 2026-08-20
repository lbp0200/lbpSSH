# Quality Improvement Design — lbpSSH

**Date:** 2026-04-09
**Status:** Approved
**Owner:** lbp

**Implementation status:** ✅ Completed (`flutter analyze` 0 issues, full test suite passing, coverage at `coverage/lcov.info`)

## Overview

Improve code quality of the lbpSSH Flutter project across three dimensions: lint cleanliness, test coverage, and baseline security hygiene — completing the Linear Design System release cycle.

## Phase 1 — Lint Cleanup

### Goals

- `flutter analyze --no-fatal-infos` reports **zero issues**
- No functional changes to any source file

### Approach

Run `dart fix --apply` to batch-fix all 161 info-level issues, including:

- **151** `prefer_const_constructors` — add `const` keyword
- **4** `prefer_final_fields` — add `final` keyword
- **1** `sized_box_for_whitespace` — replace `Container(width, height)` with `SizedBox(width, height)`
- **1** `deprecated_member_use` — replace `surfaceVariant` with `surfaceContainerHighest` in `terminal_view.dart:778`

### Verification

```bash
flutter analyze --no-fatal-infos
```

Expected: `No issues found!`

## Phase 2 — Test Coverage Improvement

### Goals

- Overall line coverage: **~32% → 80%+**
- All 70 source files have at least some test coverage
- Critical files (repository, sync, SSH service) reach **70%+** coverage

### Coverage Targets by Layer

| Layer | Files | Target Coverage |
|-------|-------|----------------|
| `data/repositories/` | 4 | 70%+ |
| `data/models/` | ~15 | 80%+ |
| `domain/services/` | ~12 | 60%+ |
| `presentation/providers/` | ~10 | 70%+ |
| `presentation/widgets/` | ~20 | 60%+ |

### Priority Files

**P0 — Critical (currently 0% or near 0%):**
- `lib/data/repositories/connection_repository.dart` — mock filesystem + JSON I/O
- `lib/domain/services/sync_service.dart` — mock Dio + File operations
- `lib/domain/services/ssh_service.dart` — mock SSH stream/PTY

**P1 — High Value:**
- `lib/domain/services/sftp_service.dart`
- `lib/domain/services/local_terminal_service.dart`
- `lib/domain/services/kitty_file_transfer_service.dart`
- `lib/domain/services/import_export_service.dart`

**P2 — Coverage extension:**
- `lib/presentation/providers/` — provider unit tests
- `lib/presentation/widgets/` — edge case and error state tests

### Test Strategy

- Use existing `flutter test` framework
- Mock at boundaries (filesystem, network, SSH streams)
- Prefer unit tests for business logic in domain layer
- Use integration tests for repository layer (mock JSON files)
- Widget tests for presentation layer

## Phase 3 — Verification & Release Prep

### Checklist

- [x] `flutter analyze --no-fatal-infos` → 0 issues
- [x] `flutter test` → all pass
- [x] Coverage report generated (`coverage/lcov.info`)
- [x] Git commit with all changes
- [x] Push to `origin/main`

## Non-Goals

- Security audit (deferred)
- Provider migration (Riverpod analysis already done in docs)
- Breaking API changes
- New features

## References

- CLAUDE.md — project conventions and build commands
- `docs/plans/2026-03-14-code-quality-plan.md` — prior quality plan (informational)
- `docs/plans/2026-03-14-riverpod-migration-analysis.md` — Riverpod migration analysis (informational)
