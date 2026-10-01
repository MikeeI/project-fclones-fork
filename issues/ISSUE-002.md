# ISSUE-002 — Walking: one heap-backed scope task per regular file

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

[S] Directory traversal creates a separate heap-backed Rayon scope task for every regular file.

## Reach-and-Impact

[S] P2 reaches every directory scan through `Walk::run` and `group_files`.
[S] Task allocation count scales with file cardinality; throughput and locality require runtime verification.

## Evidence

- [S] `fclones/src/walk.rs:375-379` spawns one task per directory entry.
- [S] `fclones/src/walk.rs:398-418` preserves directory stealing and inode-local access.
- [S] Rayon scope tasks use heap allocations: https://docs.rs/rayon-core/1.12.0/rayon_core/fn.scope.html.

## Prior-Art

Coverage: local finding index and current canonical source.
Gaps: upstream issue, pull request, discussion, and release searches remain required before publication.
Contribution fit: one root cause; publication target remains user-selected.

## Proposed-Change

Batch neighboring regular files while leaving links and directories as individual scoped tasks.

## Scope-and-Constraints

- Preserve selection, link handling, completion, scoped lifetimes, and local access order.
- Exclude blocking worker semaphores, new tests, and unrelated cleanup; test decision: none.
- Authorization: the user requested implementation of P1–P4 and a before-and-after benchmark.

## Verification

[O] All 176 existing tests passed on Rust 1.74.1 with warnings denied.
[O] Baseline and optimized JSON reports matched in 24 disposable CLI scenarios with one and eight workers.
The fixture included 257 neighboring files, recursive directories, hardlinks, symlinks, and ignore rules.

## Performance-Evidence

Baseline: `benchmarks/results/20261001T033658.129441728-2ba6a49.json`.
Dataset: `/root/OneDriveBackup-2024-11-19/Archive`.
After: `benchmarks/results/20261001T035016.244028350-ee52ca2.json`.
[O] Median changed from 2.649543713 s to 2.725006814 s: 2.848% longer runtime.
[O] Mean changed from 2.675930562 s to 2.707691688 s: 1.187% longer runtime.
Each version used one warmup and three measured runs with identical scan options.
Timing ranges overlap; the baseline reports an outlier warning, so no reliable speedup is established.
The combined benchmark does not attribute changes to individual optimizations.
The combined benchmark cannot establish HDD locality on this machine.

## Publication-Blockers

Publication target, prior-art research, and approval of an exact external draft remain unresolved.

## Next-Action

Summary: Select publication target
Action: Choose an upstream publication target for the completed P2 source change.
Done-When: The user selects the publication target.

## Pull-Request-Implementation

Branch: perf/walk-file-batches
Base: `upstream/main@a74f90d293e05856d19a4c0ac2b29b46ef16cf23`
Scope: P2 regular-file scope-task batching.
Commit: 86c75c20bb88a469f6a426d6fb32ac511d6221af
Push: origin/perf/walk-file-batches
Checks:
- [O] Combined implementation at `ee52ca2` passes the following checks.
- `cargo +1.74.1 fmt --all -- --check` → passed.
- `cargo +1.74.1 clippy --locked -q --all -- -D warnings -D rust-2018-idioms` → passed.
- `RUSTFLAGS='-D warnings' cargo +1.74.1 build --locked -q --all` → passed.
- `RUST_BACKTRACE=1 RUSTFLAGS='-D warnings' cargo +1.74.1 test --locked -q` → 176 passed.
- Baseline-versus-optimized CLI comparison → 24 scenarios passed.
