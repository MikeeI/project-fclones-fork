# ISSUE-005 — Hashing: repeated Linux memory-status object construction

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

[S] Linux file hashes above 256 KiB construct a complete `sysinfo::System` before each memory refresh.
[S] Constructor work includes process-map allocation and boot-information reads that memory queries do not require.

## Reach-and-Impact

[S] `file_hash` invokes this check after successful reads; hash-cache hits and transformed streams bypass it.
[O] A standalone 10,000-iteration comparison measures substantial constructor overhead.
[A] End-to-end benefit depends on eligible file count and the workload's other costs.

## Evidence

- [S] Current `upstream/main` contains `evict_page_cache_if_low_mem` at `fclones/src/hasher.rs:511-532`.
- [S] `Cargo.lock` resolves `sysinfo` to 0.29.10.
- [S] That version's `src/linux/system.rs:224-245` initializes process and boot-information state.
- [S] `src/linux/system.rs:616-633` silently skips missing, unreadable, and unparseable memory data.
- [S] `refresh_memory()` returns no success status and offers no public memory-field reset.
- [S] Reused objects can retain old fields on failed or partial refreshes; fresh objects start with zeros.
- [O] Rust 1.74.1 rejected a zero-state `System::clone` probe with E0599; prototype cloning is unavailable.

## Prior-Art

Coverage: current canonical source, local index, and existing issue records.
Gaps: upstream issues, pull requests, discussions, and release searches remain required before publication.
Contribution fit: a bounded caller optimization would be useful only if fresh-instance failure behavior is preserved.

## Proposed-Change

Investigate memory-only initialization or a public reset/success API before considering thread-local reuse.
Do not apply TLS-only reuse: it changes decisions after silent or partial refresh failures.

## Scope-and-Constraints

- Preserve per-file refreshes, `free_memory()`, the 5% threshold, and the retained 256 KiB prefix.
- Preserve cgroup handling and fresh-instance behavior when refresh data are incomplete.
- Exclude global locks, interval sampling, dependency forks, new tests, and unrelated cleanup.
- Test decision: none.
- Authorization: the user requested implementation of all six reviewed SSD measures.
- Production reuse remains conditional on preserving the recorded successful and failed refresh behavior.

## Verification

[O] The release example `memory-refresh` ran five comparisons with 10,000 iterations each on Rust 1.74.1.
[S] The pinned dependency exposes no safe reset for its private memory fields.
[O] The compiler probe also ruled out cloning a fresh zero-memory prototype before each refresh.
No production hashing change was applied because TLS-only reuse does not meet the preserved failure contract.

## Performance-Evidence

Record: `benchmarks/results/20261001-memory-refresh.json`.
[O] Median fresh construction plus refresh: 0.701494248 s per 10,000 calls.
[O] Median reused-object refresh: 0.216552721 s per 10,000 calls.
[O] Median constructor-only time: 0.479419420 s per 10,000 calls.
These are isolated costs, not an observed application speedup.
[O] A real-corpus trace counted 4,304 eligible checks and 348 successful `POSIX_FADV_DONTNEED` calls.
The advised ranges totaled 2,086,172,485 bytes; successful advice does not prove actual eviction.
[A] Multiplying eligible checks by the isolated constructor rate gives a 0.206 s serial-time proxy, not wall-time savings.
Record: `benchmarks/results/20261001-performance-followup.json`.

## Publication-Blockers

A behavior-preserving implementation, end-to-end evidence, prior-art research, target selection, and approval remain absent.

## Next-Action

Summary: Resolve refresh failure contract
Action: Establish a memory-reset or refresh-success API that preserves fresh-instance failure behavior.
Done-When: A scoped implementation can preserve both successful and incomplete refresh semantics.

## Pull-Request-Implementation

Branch: perf/memory-status-reuse
Base: `upstream/main@a74f90d293e05856d19a4c0ac2b29b46ef16cf23`
Scope: Conditional worker-local memory-status reuse without changing refresh or failure semantics.
Commit: Pending.
Push: Pending.
Checks:
- `target/release/examples/memory-refresh --json --iterations 10000 --runs 5` → five complete comparisons.
- Source audit of `sysinfo 0.29.10` → no public reset or refresh-success API.
