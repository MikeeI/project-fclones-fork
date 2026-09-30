# project-fclones-fork

<essential-rule>
AGENTS.md is the sole authoritative project context file.
Read and edit AGENTS.md directly.
</essential-rule>

## Development Rules

Before launching agents, apply skill-xray, skill-expert, and skill-brutal to the task.
Surface expert-level issues, non-obvious issues, blindspots, stale assumptions, and hidden dependencies.
Also surface missed constraints, edge cases, false positives, verification gaps, overclaims, and weak assumptions.
Identify improvement potential, inefficiencies, and what is wrong without softening.
Use these findings to design safe slices, sequencing, checks, and boundaries for complete agent results.

Every agent prompt must require skill-xray, skill-expert, and skill-brutal for the assigned scope before acting.
It must surface non-obvious issues, blindspots, stale assumptions, hidden dependencies, and edge cases.
It must also surface verification gaps, overclaims, failure modes, weak assumptions, and what is wrong.
The agent must adjust its approach, challenge its assumptions, and flag misleading or incomplete output risks.

Implementation assignments must cover existing patterns, callers, exported-symbol consumers, and failure modes.
They must also cover concurrency safety and lifecycle cleanup.
Each assignment must state `Test decision: none` or `Test decision: update`.
`update` must name the exact existing test that follows an intentional contract change.
Never request new tests.
Prohibit broad edits, unrelated cleanup, and unassigned files.

No vague agents.
Each assignment needs exact targets, non-goals, evidence anchors, acceptance criteria, and an output contract.

Commit completed units continuously.
Before each commit, use skill-git-commit-format to determine whether staged effects are one coherent unit.
The skill owns commit-message format and evidence.
After the boundary is valid, run the repository-owned commit and push workflow.
Do not commit every trivial edit immediately or defer unrelated work into one end-of-session commit.

Every project-level quality command is quiet by default and verbose on demand.
This policy applies regardless of language or toolchain.
It covers Make targets, package scripts, Python CLIs, shell quality gates, and test runners.
Successful checks print only compact status such as `format: ok`, `lint: ok`, `test: ok`, or `check: ok`.
On failure, exit non-zero and print the failing step, exit code, and enough output to act without rerunning.
Full raw output must remain available through `--verbose`, `VERBOSE=1`, or the underlying tool's verbose mode.
New quality commands and future language setup must follow this policy instead of inventing another logging contract.

# Repository Guidelines

## Project Overview

This repository is a personal fork of fclones, a Rust CLI and public library for finding and removing duplicate files.
The Cargo workspace contains `fclones` and `gen-test-files`; root Cargo commands select `fclones` by default.
The CLI separates grouping and report generation from operations that remove, move, link, or deduplicate file data.
`fclones/README.md` owns user documentation; the root `README.md` is empty in the inherited upstream tree.

## Fork & Upstream Contribution Intent

- Official upstream: [pkolaczk/fclones](https://github.com/pkolaczk/fclones).
- This checkout is the [MikeeI/project-fclones-fork](https://github.com/MikeeI/project-fclones-fork) fork, not an independently owned product.
- The goal is to support upstream with evidence-backed issues, comments, and pull requests.
- `ISSUES.md` provides the compact finding overview and global ID allocator.
- `issues/ISSUE-NNN.md` owns the complete durable record for one root cause.
- `FORMAT.md` owns research, drafting, implementation authorization, approval, and publication rules.
- Prefer small, well-scoped corrections with outsized maintainer or user value.
- Recommend a pull request when a bounded verified fix is ready and no active implementation owns it.
- Otherwise recommend a comment, a new issue, or continued investigation according to the evidence.
- Apply `skill-fork-contribution-tracking` for ledger, lifecycle, personal-branch, and upstream handoff work.
- Apply `skill-maintainer-communication` before external issues, pull requests, reviews, comments, or discussions.
- Search existing work first and follow current upstream templates and disclosure rules.
- Apply `skill-semantic-compression-3` when authoring or restructuring tracking content.
- Apply `skill-git-commit-format` while respecting explicit upstream contribution conventions.
- Never choose `Authorized-Work` or `Publication-Target` on the user's behalf.
- `Research-and-Reporting` permits research, issues, and comments but no source implementation.
- `Pull-Request-Implementation` authorizes only the scoped implementation recorded for that finding.
- Base upstream contribution branches on current `upstream/main`.
- Keep fork-only context, ledgers, configuration, and personal commits out of upstream contribution diffs.
- Reproduce claimed bugs against current upstream and run the narrowest conclusive verification.
- Publish one coherent root cause per issue, comment, or pull request.

## Finding and Contribution Ledger

- At the start of every agent session, agents MUST read root `ISSUES.md` before repository work.
- `ISSUES.md` owns the global `Next finding ID` allocator and compact cross-finding overview.
- Each `issues/ISSUE-NNN.md` owns one finding's state, evidence, drafts, and next action.
- `FORMAT.md` is authoritative for research, drafting, implementation boundaries, and publication format.
- Before adding a finding, search the index and every relevant issue record for the same symptom or root cause.
- New findings MUST use `Next finding ID`.
- Create the issue file, add its index row, and increment the allocator together.
- Finding IDs use `ISSUE-NNN`, start at `ISSUE-001`, and remain permanent.
- Never reuse, renumber, or scope IDs by subsystem, status, session, or contribution type.
- Update the issue file and `ISSUES.md` together after state, authorization, target, priority, next action, or reference changes.
- Every issue record MUST use the field and section contract in `FORMAT.md`.
- New findings start with `State: Investigating`, `Authorized-Work: Not-Selected`, and `Publication-Target: Not-Selected`.
- New findings use `External-Reference: Not published.` until an external reference exists.
- Keep findings Investigating until currentness, prior art, impact, and correction value are evidence-backed.
- Clone detectors, AST matches, text similarity, shared names, and TODOs produce candidates only.
- A duplication finding requires shared change pressure, realistic drift, and simpler consolidation.
- The user selects `Authorized-Work` for each finding.
- `Research-and-Reporting` MUST NOT implement the finding.
- `Pull-Request-Implementation` MAY implement only the recorded scope after research resolves callers and failure modes.
- Pull-request work MUST verify behavior, commit, push, and reach `PR-Ready` before publication.
- Show the exact draft and target before publishing an issue, comment, or pull request to official upstream.
- Publish to official upstream only after the user approves the exact current draft and target.
- Any draft or target change requires showing the complete current draft and target again before publication.
- Run the read-only validator bundled with `skill-fork-contribution-tracking` after every ledger mutation.
- Record the final external URL in `External-Reference` immediately after publication.
- Keep `FORMAT.md`, `ISSUES.md`, `issues/`, and fork-only `AGENTS.md` changes out of upstream contribution diffs.

### External publication approval

Only an external issue, comment, review, discussion, or pull request write is approval-gated.
Before publication, read current contribution guidance and explain applicable project policy.
The human must be able to review and own every submission statement.
Fork commits, pushes, tracking updates, and source implementation follow the active repository contract.

## Branch Roles

- Personal branch: `main`, tracking `origin/main`; it owns fork-only context and the contribution ledger.
- `origin`: `git@github.com:MikeeI/project-fclones-fork.git`.
- `upstream`: `git@github.com:pkolaczk/fclones.git`; `upstream/main` is the contribution base.
- Fetch current `upstream/main` before recording a source revision or creating an upstream contribution branch.
- Create contribution branches or worktrees directly from `upstream/main`, not personal `main`.
- Check the complete contribution diff against its upstream base before publication.

## Architecture & Data Flow

- `main.rs` parses Clap configuration, prepares logging and thread pools, and dispatches commands.
- `config.rs` owns CLI configuration, command validation, filtering options, and parallelism settings.
- `group.rs` scans selected files and groups by size, file identity, prefix hash, suffix hash, and full-content hash.
- `walk.rs`, `selector.rs`, `pattern.rs`, and `regex.rs` own traversal and selection.
- `device.rs`, `hasher.rs`, and `cache.rs` support device-aware parallel hashing and optional persistent hashes.
- `report.rs` owns report serialization and parsing; cleanup commands consume earlier grouping reports.
- `dedupe.rs` partitions files to retain or drop and generates filesystem commands before execution or dry-run output.
- `lock.rs` and `reflink.rs` support filesystem locking and platform-specific copy-on-write operations.
- `lib.rs` owns the public API exports, including grouping, reporting, deduplication, configuration, and file types.

## Key Directories

- `fclones/src/`: CLI, public library, and module-local tests.
- `gen-test-files/src/`: separate executable for generating test datasets.
- `.circleci/`: upstream formatting, build, Clippy, and test jobs.
- `packaging/`: upstream container and release-packaging scripts.
- `issues/`: open finding records; `issues/archive/` contains archived records.

## Development Commands

Run Cargo commands from the repository root.
These are upstream-owned commands, not new fork-specific quality wrappers.

- Build the main package: `cargo build -p fclones`.
- Build both workspace members, as CI does: `cargo build --all`.
- Run the CLI help: `cargo run -p fclones -- --help`.
- Format Rust changes before the CI format gate: `cargo fmt --all`.
- Upstream CI format gate: `cargo fmt --all -- --check`.
- Upstream CI lint gate: `cargo clippy --all -- -D warnings -D rust-2018-idioms`.
- Focused regression verification: `cargo test -p fclones <test-name>`.
- Upstream CI tests: `RUST_BACKTRACE=1 RUSTFLAGS='-D warnings' cargo test`.
- Test dataset generator help: `cargo run -p gen-test-files -- --help`.
- Ledger validation: `bun $HOME/projects/project-settings-omp/data/sync/agent/skills/skill-fork-contribution-tracking/scripts/validate-ledger.js .`.

## Code Conventions

- Preserve the existing Rust 2021 workspace layout, Cargo manifests, feature names, and upstream tooling.
- Keep public API compatibility explicit when changing exports in `lib.rs` or their underlying types.
- Preserve OS-native paths and file identities across filesystem and report boundaries.
- Review `#[cfg]` branches when touching Unix, Windows, Linux, locking, or reflink behavior.
- Preserve report compatibility because cleanup commands reconstruct earlier grouping configuration from reports.
- Keep file-retention rules, metadata checks, and lock behavior intact when changing deduplication.

## Important Files

- `Cargo.toml`: workspace membership, default package, resolver, and release profile.
- `Cargo.lock`: inherited workspace dependency resolution; retain it.
- `fclones/Cargo.toml`: package MSRV, optional hash features, and platform dependencies.
- `fclones/README.md`: CLI usage, report workflows, filesystem caveats, and algorithm description.
- `.circleci/config.yml`: authoritative upstream CI commands and Rust image.
- `FORMAT.md` and `ISSUES.md`: fork-only finding schema and overview.

## Runtime/Tooling Preferences

- Use Cargo for Rust development; do not run setup-project or replace the inherited build system.
- The `fclones` package declares Rust 1.74 as its MSRV; upstream CI uses `cimg/rust:1.74.0`.
- Rayon owns the parallel processing model; hashing can use per-device pools.
- Optional hash features and OS-specific dependencies are declared in `fclones/Cargo.toml`.
- `group_files` must not run on a Rayon pool because its internal scheduling can deadlock there.
- Keep upstream `LICENSE`, package metadata, and lockfiles; this is an open-source fork, not a new private project.

## Testing & QA

- Existing Rust tests are embedded in source modules; select the affected test by name for scoped verification.
- Use disposable datasets for filesystem-operation reproductions, not personal files or production storage.
- Inspect `--dry-run` output before executing remove, move, link, or dedupe scenarios within authorized datasets.
- Check link identity, retained replicas, metadata changes, and report compatibility for cleanup-related changes.
- Treat hash matches as the grouping mechanism, not a byte-by-byte comparison guarantee.
- For tracking-only changes, run the bundled ledger validator; Cargo builds and tests do not validate this contract.
