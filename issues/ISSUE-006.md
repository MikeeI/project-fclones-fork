# ISSUE-006 — Progress: hidden status workers spin without sleeping

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

[S] `ProgressBar::new_hidden` starts a `status-line` worker with a zero refresh interval.
[S] On Unix, zero-duration `thread::sleep` returns immediately, so the invisible worker polls continuously.
Reference: https://doc.rust-lang.org/std/thread/fn.sleep.html

## Reach-and-Impact

[S] `--progress=false`, `--quiet`, and automatic progress with nonterminal stderr reach the hidden constructor.
[S] Public library consumers can invoke `ProgressBar::new_hidden` directly.
[O] Earlier process-scoped sampling attributed 17.14% of CPU samples to the hidden status worker.
That profile used binary SHA-256 `187f14cb866d5fb8c7dcb5fceaaf6cf6f29aebc71b3488977d530ade7c7206ce`.
[A] CPU savings do not imply the same percentage reduction in elapsed scan time.

## Evidence

- [S] Canonical `fclones/src/progress.rs:157-168` sets zero refresh and creates `StatusLine`.
- [S] `status-line 0.2.0` starts a worker unconditionally and sleeps with the supplied interval.
- [S] `fclones/src/log.rs:87-129` uses hidden bars when progress is disabled.
- [S] `fclones/src/lib.rs:1-4` exports the concrete progress and logging APIs.
- [O] The fixed public API probe held one hidden bar for 300 ms with one process thread throughout.
- [O] Baseline and fixed JSON reports matched exactly after removing timestamp and command headers.
- [O] Identical two-file CLI reproductions created 11 threads before the fix and three afterward.
- [O] The eight removed creations are additional to unchanged one-thread main and device pools.

## Prior-Art

Coverage: fetched canonical source, local index, source callers, dependency implementation, and runtime observations.
Gaps: upstream issue and pull-request searches remain required before publication.

## Proposed-Change

Implemented: represent a permanently hidden `ProgressBar` without a `StatusLine`.
Hidden increments, ticks, and clearing skip counter and renderer work; message printing remains available.
Visible bars retain their renderer and temporary visibility transitions.
Disabled trait-based logging returns the existing `NoProgressBar` rather than a concrete hidden bar.

## Scope-and-Constraints

- Preserve public types, method signatures, report contents, and visible terminal behavior.
- Keep temporarily invisible renderers distinct from permanently hidden bars.
- Exclude refresh throttling, dependency changes, and unrelated logging cleanup.
- Test decision: none; no permanent tests were added.
- Authorization: the user requested fixes and implementation of the recommended performance work.

## Verification

- `cargo +1.74.1 test --locked -q -p fclones progress::test` → three existing tests passed.
- MSRV release CLI and examples build → passed.
- Public hidden-bar lifecycle smoke → no additional worker while held or after drop.
- Real-corpus JSON comparison → 9,356 groups and normalized reports identical.
- Actual PTY scan with `--progress=true` → visible phase and byte progress retained.
- Final MSRV format, Clippy, warning-denying workspace build, and all 176 tests → passed.
- Final CLI scans with `--progress=false`, nonterminal auto mode, and Quiet overriding `--progress=true` → passed.
- Final real-corpus JSON comparison and actual PTY rendering → passed.

## Performance-Evidence

The implementation removes the hidden worker and counter updates by construction.
Before and after process sampling used `cpu-clock`, 99 Hz, DWARF stacks, and reported no sample loss.
Benchmark records preserve exact binary hashes, commands, resource samples, and individual timings.
Do not infer a controlled elapsed-time improvement from isolated profiling or diagnostic runs.
Alternating baseline/fixed runs did not demonstrate a reliable reduction in elapsed scan time.
The final two-file reproduction independently confirms removal of eight hidden worker creations.
Record: `benchmarks/results/20261001-performance-followup.json`.

## Publication-Blockers

Publication target, exact draft, prior-art research, and approval remain absent.

## Next-Action

Summary: Select publication target
Action: Select an upstream publication target after completing prior-art research.
Done-When: The user selects the target and reviews its exact draft.

## Pull-Request-Implementation

Branch: fix/hidden-progress-worker
Base: `upstream/main@a74f90d293e05856d19a4c0ac2b29b46ef16cf23`
Scope: Thread-free permanently hidden progress and disabled no-op trackers without public API changes.
Commit: `e7debc16b6548585d2138fa6e6a5fc25cc0275b0`
Push: origin/fix/hidden-progress-worker
Checks:
- Existing progress tests, public API smoke, real-corpus report equivalence, and actual PTY scan → passed.
- Complete contribution diff against upstream → only `fclones/src/progress.rs` and `fclones/src/log.rs`.
