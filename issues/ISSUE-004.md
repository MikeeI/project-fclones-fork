# ISSUE-004 — JSON reports: redundant hash and path clones

State: Investigating
Authorized-Work: Pull-Request-Implementation
Publication-Target: Not-Selected
External-Reference: Not published.
Contribution-Priority: Low
Root-Cause-Confidence: High
Finding-Category: Performance
Created: 2026-10-01
Updated: 2026-10-01
Source: `upstream/main@a74f90d293e05856d19a4c0ac2b29b46ef16cf23`

## Root-Cause

[S] JSON serialization clones each group's hash and paths into an additional owning file group.

## Reach-and-Impact

[S] P4 reaches JSON output through `ReportWriter::write_as_json`.
[S] Copies scale with emitted paths, while the largest group determines the additional group buffer.

## Evidence

- [S] `fclones/src/report.rs:277-285` constructs the redundant owning group.
- [S] `IteratorWrapper` already streams the outer group sequence.
- [S] Serde supports borrowed elements: https://docs.rs/serde/1.0.189/serde/ser/trait.SerializeSeq.html.

## Prior-Art

Coverage: local finding index and current canonical source.
Gaps: upstream issue, pull request, discussion, and release searches remain required before publication.
Contribution fit: one root cause; publication target remains user-selected.

## Proposed-Change

Serialize borrowed group fields and individual paths without an additional owning path vector.

## Scope-and-Constraints

- Preserve owned and borrowed group inputs, JSON field order, escaping, streaming, and write errors.
- Exclude new tests and unrelated cleanup; test decision: none.
- Authorization: the user requested implementation of P1–P4 and a before-and-after benchmark.

## Verification

[O] All 176 existing tests passed on Rust 1.74.1 with warnings denied, including JSON and non-UTF-8 round trips.
[O] Baseline and optimized JSON reports matched in 24 disposable CLI scenarios with one and eight workers.
The existing suite exercises owned and borrowed group inputs.

## Performance-Evidence

Baseline: `benchmarks/results/20261001T033658.129441728-2ba6a49.json`.
Dataset: `/root/OneDriveBackup-2024-11-19/Archive`.
After: `benchmarks/results/20261001T035016.244028350-ee52ca2.json`.
[O] Combined median changed from 2.649543713 s to 2.725006814 s: 2.848% longer runtime.
Each version used one warmup and three measured runs with identical scan options.
The standard benchmark emits text and cannot establish P4-specific gains.

## Publication-Blockers

Publication target, prior-art research, and approval of an exact external draft remain unresolved.

## Next-Action

Summary: Select publication target
Action: Choose an upstream publication target for the completed P4 source change.
Done-When: The user selects the publication target.

## Pull-Request-Implementation

Branch: perf/json-borrowed-paths
Base: `upstream/main@a74f90d293e05856d19a4c0ac2b29b46ef16cf23`
Scope: P4 borrowed group and path serialization.
Commit: 139ce44cddf323d4d5e17a51442b0e08d3e3b67f
Push: origin/perf/json-borrowed-paths
Checks:
- [O] Combined implementation at `ee52ca2` passes the following checks.
- `cargo +1.74.1 fmt --all -- --check` → passed.
- `cargo +1.74.1 clippy --locked -q --all -- -D warnings -D rust-2018-idioms` → passed.
- `RUSTFLAGS='-D warnings' cargo +1.74.1 build --locked -q --all` → passed.
- `RUST_BACKTRACE=1 RUSTFLAGS='-D warnings' cargo +1.74.1 test --locked -q` → 176 passed.
- Baseline-versus-optimized CLI comparison → 24 scenarios passed.
