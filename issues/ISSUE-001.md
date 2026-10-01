# ISSUE-001 — Grouping: materialized subgroups for boolean replication filters

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

[S] Rootless boolean replication filters materialize all subgroups before comparing their count.

## Reach-and-Impact

[S] P1 reaches size and hash-stage filtering through `group_files`.
[S] Distinct file IDs allocate unnecessary membership vectors; P1-specific wall-clock improvement remains unmeasured.

## Evidence

- [S] `fclones/src/group.rs:354-368` compares subgroup counts with replication thresholds.
- [S] `fclones/src/group.rs:430-431` materializes subgroups solely to count them.
- [S] The pre-change source matches the fetched canonical upstream revision.

## Prior-Art

Coverage: local finding index and current canonical source.
Gaps: upstream issue, pull request, discussion, and release searches remain required before publication.
Contribution fit: one root cause; publication target remains user-selected.

## Proposed-Change

Use file count or short-circuit distinct-ID counting for rootless boolean filters.

## Scope-and-Constraints

- Preserve root grouping, exact statistics, hardlink identity, and public APIs.
- Exclude new tests and unrelated cleanup; test decision: none.
- Authorization: the user requested implementation of P1–P4 and a before-and-after benchmark.

## Verification

[O] All 176 existing tests passed on Rust 1.74.1 with warnings denied.
[O] Baseline and optimized JSON reports matched in 24 disposable CLI scenarios with one and eight workers.
The scenarios covered replication thresholds, hardlinks, isolated roots, selection, symlinks, and stdin.

## Performance-Evidence

Baseline: `benchmarks/results/20261001T033658.129441728-2ba6a49.json`.
Dataset: `/root/OneDriveBackup-2024-11-19/Archive`.
After: `benchmarks/results/20261001T035016.244028350-ee52ca2.json`.
[O] Median changed from 2.649543713 s to 2.725006814 s: 2.848% longer runtime.
[O] Mean changed from 2.675930562 s to 2.707691688 s: 1.187% longer runtime.
Each version used one warmup and three measured runs with identical scan options.
Timing ranges overlap; the baseline reports an outlier warning, so no reliable speedup is established.
The combined benchmark does not attribute gains to individual changes.

## Publication-Blockers

Publication target, prior-art research, and approval of an exact external draft remain unresolved.

## Next-Action

Summary: Select publication target
Action: Choose an upstream publication target for the completed P1 source change.
Done-When: The user selects the publication target.

## Pull-Request-Implementation

Branch: perf/replication-filter
Base: `upstream/main@a74f90d293e05856d19a4c0ac2b29b46ef16cf23`
Scope: P1 rootless boolean replication filters.
Commit: 74a54a21f95ebfc2972d58c1d9b8d316c5773bad
Push: origin/perf/replication-filter
Checks:
- [O] Combined implementation at `ee52ca2` passes the following checks.
- `cargo +1.74.1 fmt --all -- --check` → passed.
- `cargo +1.74.1 clippy --locked -q --all -- -D warnings -D rust-2018-idioms` → passed.
- `RUSTFLAGS='-D warnings' cargo +1.74.1 build --locked -q --all` → passed.
- `RUST_BACKTRACE=1 RUSTFLAGS='-D warnings' cargo +1.74.1 test --locked -q` → 176 passed.
- Baseline-versus-optimized CLI comparison → 24 scenarios passed.
