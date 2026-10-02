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
[O] A real-corpus CPU profile attributes 1.94% of sampled CPU work to construction, not elapsed-time savings.

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

Propose an additive Linux/Android `System::reset_memory(&mut self)` API for pinned `sysinfo 0.29.10`.
Reset all nine memory-refresh fields before every existing refresh, then consider worker-local reuse.
Do not apply TLS-only reuse: it changes decisions after silent or partial refresh failures.

## Scope-and-Constraints

- Preserve per-file refreshes, `free_memory()`, the 5% threshold, and the retained 256 KiB prefix.
- Preserve cgroup handling and fresh-instance behavior when refresh data are incomplete.
- Exclude global locks, interval sampling, dependency forks, new tests, and unrelated cleanup.
- Test decision: none.
- Authorization: the user requested implementation of all six reviewed SSD measures.
- Production reuse remains conditional on preserving the recorded successful and failed refresh behavior.

## API-and-Compatibility

[S] `src/linux/system.rs:154-162,252-318` owns all nine fields read or written by the memory refresh.
The following proposal is not applied or runtime-verified:

```diff
+impl System {
+    pub fn reset_memory(&mut self) {
+        // Clear every refresh-owned field to preserve fresh-instance behavior on partial input.
+        self.mem_total = 0;
+        self.mem_free = 0;
+        self.mem_available = 0;
+        self.mem_buffers = 0;
+        self.mem_page_cache = 0;
+        self.mem_shmem = 0;
+        self.mem_slab_reclaimable = 0;
+        self.swap_total = 0;
+        self.swap_free = 0;
+    }
+}
```

The caller must execute `reset_memory(); refresh_memory()` on its own worker-local instance before each query.
[S] The Linux refresh reads no process, CPU, boot, or network state, so those constructor side effects need not repeat.
Leave `/proc/meminfo` parsing, `MemAvailable` fallback, and both cgroup branches unchanged.
An inherent backend method avoids adding a required method to the public, unsealed `SystemExt` trait.
A portable API would need matching fresh-memory resets in every platform backend.
This proposal covers the pinned dependency only; current sysinfo API fit and maintainer preference remain unknown.

## Verification

[O] The release example `memory-refresh` ran five comparisons with 10,000 iterations each on Rust 1.74.1.
[S] The pinned dependency exposes no safe reset for its private memory fields.
[O] The compiler probe also ruled out cloning a fresh zero-memory prototype before each refresh.
No production hashing change was applied because TLS-only reuse does not meet the preserved failure contract.
[O] `archive-corpus` reproduced all real size, prefix, prefix-suffix, and content-group partitions without source bytes.
[O] Actual default cached and uncached scans of that generated corpus produced identical duplicate reports.
Required after any reset implementation: compare reset-plus-refresh with fresh-plus-refresh under isolated input faults.
Cover complete and partial `/proc/meminfo`, missing input, and cgroup v1/v2 fallback paths in disposable namespaces.
Do not modify host `/proc` or `/sys`, add permanent tests, or treat a source audit as fault-injection proof.

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
[O] A 499 Hz CPU profile with 32 KiB DWARF stacks recorded 7,682 samples and zero lost samples.
[O] Construction appeared in 149 samples: 0.298597192 s of aggregate CPU time, or 1.9396% of sampled CPU work.
[O] Memory refresh appeared in 62 samples, or 0.8071% of sampled CPU work.
[O] Direct child-PID uprobes observed 4,305 constructors, including one device-initialization constructor.
[O] Summed instrumented entry-to-return duration was 0.284418761 s.
Uprobe durations include probe overhead and scheduling; concurrent thread durations are not wall-time savings.
An earlier four-process, 8 KiB-stack profile had inconsistent attribution and is not the accepted percentage estimate.
Zero lost samples does not guarantee complete call stacks.
The preferred scan took 2.48 s; a separate three-run uninstrumented median was 2.959777416 s.
Different residency and shared-host load prevent interpreting that difference as profiler overhead or speedup.
Record: `benchmarks/results/20261001-memory-constructor-profile.json`.
The measured cost supports a small API proposal, not a dependency fork; contribution priority remains Low.

## Publication-Blockers

A verified implementation, elapsed-time benefit, current sysinfo API fit, and prior-art research remain absent.
Target selection and approval remain required for publication.

## Next-Action

Summary: Assess upstream reset API
Action: Check current sysinfo API and prior art for an additive memory-reset operation.
Done-When: Evidence identifies a compatible adoption path without a dependency fork or changed failure semantics.

## Pull-Request-Implementation

Branch: perf/memory-status-reuse
Base: `upstream/main@a74f90d293e05856d19a4c0ac2b29b46ef16cf23`
Scope: Conditional worker-local memory-status reuse without changing refresh or failure semantics.
Commit: Pending.
Push: Pending.
Checks:
- `target/release/examples/memory-refresh --json --iterations 10000 --runs 5` → five complete comparisons.
- Source audit of `sysinfo 0.29.10` → no public reset or refresh-success API.
