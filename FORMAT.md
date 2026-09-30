# Issue, Comment, and Pull Request Format

## Authority

`AGENTS.md` owns project identity, fork intent, branch roles, repository rules, and approval scope.
`ISSUES.md` owns `Next finding ID` and provides the compact overview of every finding.
Each `issues/ISSUE-NNN.md` is authoritative for that finding's complete state and evidence.
`skill-fork-contribution-tracking` owns the workflow connecting these files and upstream work.
`skill-maintainer-communication` owns external research and communication quality.
`skill-semantic-compression-3` owns meaning-preserving compression of tracking content.
Current upstream contribution guides, forms, and templates override these generic shapes.

- Investigate before drafting or implementing.
- Let the user choose `Authorized-Work` and `Publication-Target`.
- `Research-and-Reporting` permits issues and comments but no source implementation.
- `Pull-Request-Implementation` authorizes only the implementation scope recorded for the finding.
- Apply the contribution decision tree without treating its order as publication authorization.
- Show the exact current draft and target before publication.
- Publish only after the user approves that exact draft and target.
- Verify source claims against the current canonical upstream branch.
- Keep fork-only tracking content out of upstream contribution diffs.

## Evidence vocabulary

Use evidence labels at the claim they qualify:

- `[O]` Observed: reproduced behavior with command, version, environment, and result.
- `[S]` Source-proven: current control flow, API ownership, or deterministic data flow proves the claim.
- `[A]` Assumed: an unverified premise is required by the claim.

Never use one entry-wide label to upgrade weaker claims.
Never convert `[S]` behavior into `[O]` impact.
Preserve exact paths, symbols, commands, outputs, URLs, revisions, dates, and drafts.

## Finding IDs and duplicate prevention

- IDs use `ISSUE-NNN`, start at `ISSUE-001`, have at least three digits, and remain permanent.
- `Next finding ID: ISSUE-NNN` in `ISSUES.md` is the only allocator.
- Re-read the complete current `ISSUES.md` immediately before allocating.
- Search IDs, titles, symptoms, root causes, symbols, references, and proposed owners across `issues/`.
- Read every plausible matching issue record completely.
- Update the existing record when it already owns the root cause.
- Allocate the current ID, create its issue file, add its index row, and increment the allocator together.
- Never reuse, renumber, or create subsystem-, status-, session-, or contribution-specific sequences.
- External numbers and URLs belong in `External-Reference`; they never replace the internal ID.

## `ISSUES.md` projection

`ISSUES.md` provides overview, not the complete research record.
Open rows project ID, title, State, Authorized-Work, Publication-Target, and Contribution-Priority.
They also project `Next-Action/Summary` and External-Reference.
Archived rows project ID, title, Authorized-Work, Publication-Target, and Contribution-Priority.
They also project Archive-Reason and External-Reference.
The issue file is authoritative when a row disagrees with it.
Correct both in the same task and never leave a known projection mismatch.
Move archived findings to the archived table without changing their ID or file.

## Issue record contract

Every issue file contains these fields in this order:

```text
State: Investigating | Draft-Ready | Implementing | PR-Ready | Submitted | Archived
Authorized-Work: Research-and-Reporting | Pull-Request-Implementation | Not-Selected
Publication-Target: New-issue | Existing-issue-comment | New-pull-request | Existing-pull-request-comment | Not-Selected
External-Reference: <exact external URL or identifier | Not published.>
Contribution-Priority: High | Medium | Low
Root-Cause-Confidence: High | Medium | Low
Finding-Category: Correctness | Reliability | Performance | Maintainability | API | UI | Build | Test | Other
Created: <YYYY-MM-DD>
Updated: <YYYY-MM-DD>
Source: `upstream/<branch>@<commit>`
```

Every issue file contains these sections:

- `Root-Cause`: one cause and the behavior it owns.
- `Reach-and-Impact`: affected callers, users, states, frequency, and honest impact boundary.
- `Evidence`: exact source, reproduction, history, command, result, contract, or external evidence.
- `Prior-Art`: search coverage, relevant candidates, classifications, gaps, and target fit.
- `Proposed-Change`: smallest complete correction or ownership change.
- `Scope-and-Constraints`: behavior to preserve, compatibility limits, adoption cost, and excluded scope.
- `Verification`: narrowest checks that prove the proposed or implemented contract.
- `Publication-Blockers`: exact publication evidence still unresolved, or `None.`.
- `Next-Action`: one bounded action and one observable completion condition.

Use conditional sections only when applicable:

- `Bug-Reproduction` for an observed user-visible bug.
- `Performance-Evidence` for latency, throughput, allocation, I/O, or resource claims.
- `Shared-Change-Pressure` for duplication or ownership findings.
- `API-and-Compatibility` for public, persisted, protocol, or migration boundaries.
- `Pull-Request-Implementation` while authorized implementation is active or submitted.
- `Publication-Draft` when an exact external draft exists.
- `Submitted-Text` when submitted text differs from the approved draft.
- `Archive` only when State is Archived.

## Lifecycle states

### Investigating

Use Investigating while required evidence, authorization, target, or direction is unresolved.
`Publication-Blockers` names every unresolved prerequisite.
`Next-Action` names the single bounded action that advances it.

### Draft-Ready

Use Draft-Ready only after research, authorization, target, and the exact publication draft are complete.
Draft-Ready does not authorize publication.

### Implementing

Use Implementing only for authorized Pull-Request-Implementation while the bounded source change is in progress.
Record branch, base revision, scope, commit state, push state, and focused checks.

### PR-Ready

Use PR-Ready when the source change is complete, verified, committed, pushed, and ready for an upstream pull request.
The exact publication draft and New-pull-request target must already exist.
PR-Ready does not authorize publication.

### Submitted

Use Submitted only after an observable external issue, comment, or pull request exists.
Record its exact URL in External-Reference immediately.
Preserve exact submitted text when it differs from the approved publication draft.

### Archived

Use Archived only when no current action remains and an Archive-Reason is recorded.
Move the record to `issues/archive/` and update its index link in the same change.
Preserve the ID, history, exact external reference, submitted text, and archive evidence.

## Next-Action contract

Every open record contains one compact projection and one current continuation action:

```text
Summary: <2–6 word action summary>
Action: <single bounded action>
Done-When: <observable evidence that completes it>
```

`ISSUES.md/Next-Action` must equal `Next-Action/Summary` exactly.
Replace Next-Action after completing the action and do not accumulate a task log.
Archived records use `Summary: —`, `Action: None.`, and `Done-When: None.`.

## Implementation and archive contracts

Pull-Request-Implementation records use:

```text
Branch: <contribution branch>
Base: `upstream/<branch>@<commit>`
Scope: <authorized source change>
Commit: <SHA | Pending.>
Push: <fork branch | Pending.>
Checks:
- <focused command> → <observed result>
```

Archived records use:

```text
Archive-Reason: Merged | Fixed-Elsewhere | Duplicate | Upstream-Declined | Superseded | Finding-Invalidated | Not-Worth-Pursuing | Withdrawn | Other
Detail: <exact reason when Archive-Reason is Other | None.>
Evidence: <external URL, commit, release, maintainer statement, or internal proof>
Checked: <YYYY-MM-DD>
```

Do not infer resolution from inactivity or branch deletion.
Read the final thread and linked work before archiving an externally submitted contribution.

## Ledger validation

Run the read-only validator bundled with `skill-fork-contribution-tracking` after every ledger mutation.
It checks allocator continuity, unique IDs, index-to-record links, projection equality, and lifecycle sections.
It rejects year-based IDs, stale Next-Action projections, missing submitted references, and misplaced archives.
It never edits files or claims that evidence, prior art, target fit, or publication value is true.

## Publication gate

Before publishing, verify the permanent ID, issue record, exact target, current upstream behavior, prior art, evidence labels, draft, and user approval.
Pull-Request-Implementation must be PR-Ready and its contribution diff must exclude fork-only tracking files.
Update External-Reference and State immediately after publication.

## Prohibited actions

- Never publish without approval of the exact current draft and target.
- Never choose Authorized-Work or Publication-Target for the user.
- Never implement without Pull-Request-Implementation authorization.
- Never publish a pull request before PR-Ready.
- Never treat source text, clone output, a TODO, or a search hit as sufficient evidence.
- Never inflate source invariants into observed user harm.
- Never split one root cause across multiple IDs.
- Never combine independent root causes in one contribution.
- Never expose internal priorities, confidence, local paths, or adversarial notes externally.
- Never include `AGENTS.md`, `FORMAT.md`, `ISSUES.md`, or `issues/` in an upstream contribution diff.
