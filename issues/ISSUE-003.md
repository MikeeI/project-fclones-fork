# ISSUE-003 — Reports: repeated argument-backed isolation filter construction

State: Investigating
Authorized-Work: Pull-Request-Implementation
Publication-Target: Not-Selected
External-Reference: Not published.
Contribution-Priority: Medium
Root-Cause-Confidence: High
Finding-Category: Performance
Created: 2026-10-01
Updated: 2026-10-01
Source: `upstream/main@a74f90d293e05856d19a4c0ac2b29b46ef16cf23`

## Root-Cause

[S] Both report-statistics folds reconstruct an unchanged argument-backed filter for every group.

## Reach-and-Impact

[S] P3 reaches `write_report` through the CLI and public library.
[S] Isolation root preparation repeats twice per result group; absolute runtime improvement remains unmeasured.

## Evidence

- [S] `fclones/src/group.rs:1279-1286` builds filters inside both statistics folds.
- [S] `fclones/src/config.rs:449-450` collects isolation roots each time.
- [S] `input_paths` consumes stdin; only argument-backed input is safely reusable.

## Prior-Art

Coverage: local finding index and current canonical source.
Gaps: upstream issue, pull request, discussion, and release searches remain required before publication.
Contribution fit: one root cause; publication target remains user-selected.

## Proposed-Change

Construct the argument-backed filter once and reuse it across both statistics folds.

## Scope-and-Constraints

- Preserve stdin consumption, root ordering, report statistics, and public APIs.
- Exclude new tests and unrelated cleanup; test decision: none.
- Authorization: the user requested implementation of P1–P4 and a before-and-after benchmark.

## Verification

[O] All 176 existing tests passed on Rust 1.74.1 with warnings denied.
[O] Baseline and optimized JSON reports matched in 24 disposable CLI scenarios with one and eight workers.
The scenarios included isolated duplicate and unique reports, hardlink matching, and stdin input.

## Performance-Evidence

Baseline: `benchmarks/results/20261001T033658.129441728-2ba6a49.json`.
Dataset: `/root/OneDriveBackup-2024-11-19/Archive`.
After: `benchmarks/results/20261001T035016.244028350-ee52ca2.json`.
[O] Combined median changed from 2.649543713 s to 2.725006814 s: 2.848% longer runtime.
Each version used one warmup and three measured runs with identical scan options.
The standard benchmark does not enable isolation and cannot establish P3-specific gains.

## Publication-Blockers

Publication target, prior-art research, and approval of an exact external draft remain unresolved.

## Next-Action

Summary: Select publication target
Action: Choose an upstream publication target for the completed P3 source change.
Done-When: The user selects the publication target.

## Pull-Request-Implementation

Branch: perf/report-filter
Base: `upstream/main@a74f90d293e05856d19a4c0ac2b29b46ef16cf23`
Scope: P3 argument-backed report filter reuse.
Commit: 24ac1c8f6c21b4efdb9278e723ec1d16e2bea91c
Push: origin/perf/report-filter
Checks:
- [O] Combined implementation at `ee52ca2` passes the following checks.
- `cargo +1.74.1 fmt --all -- --check` → passed.
- `cargo +1.74.1 clippy --locked -q --all -- -D warnings -D rust-2018-idioms` → passed.
- `RUSTFLAGS='-D warnings' cargo +1.74.1 build --locked -q --all` → passed.
- `RUST_BACKTRACE=1 RUSTFLAGS='-D warnings' cargo +1.74.1 test --locked -q` → 176 passed.
- Baseline-versus-optimized CLI comparison → 24 scenarios passed.
