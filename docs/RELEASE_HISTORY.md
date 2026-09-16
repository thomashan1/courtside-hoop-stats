# Release History — Courtside Hoop Stats

Every version submitted to App Store Connect: which Xcode Cloud build carried
it, when it went in, when Apple approved it, and how long that took.

**Keep this current.** Add a row when a version is submitted (Approved =
`in review`), and fill in the approval date and turnaround when the email
arrives. It's the only place these three facts sit together — App Store
Connect shows the dates but not the commit, and the build numbers can't be
recovered from git.

## Submitted versions

| Version | Build | Commit | Submitted | Approved | Turnaround |
|---|---|---|---|---|---|
| v1.6 | 128 | `f3e960d` | Sun 2026-09-13 | *in review* | — |
| v1.5 | 106 | `f6c0820` | Sat 2026-09-05, 8:33 PM PDT | **Sun 2026-09-13** | **8 days** |
| v1.4 | 100 | — | Wed 2026-09-02, 6:18 PM PDT | Sat 2026-09-05 | 3 days |
| v1.3 | 89 | — | Wed 2026-09-02, 8:41 AM PDT | Wed 2026-09-02 | same day |
| v1.2 | — | — | Mon 2026-08-17, 8:06 PM PDT | Tue 2026-08-18 | under 1 day |
| v1.1 | — | — | Tue 2026-08-04 | Mon 2026-08-17 | 13 days |
| v1.0 | — | — | — | — | — |

Weekdays are in the table because they carry information: **two of five
approvals landed on a weekend** — v1.4 on a Saturday and v1.5 on a Sunday, and
that Sunday approval is what unblocked submitting v1.6 the same day. Two
submissions went in at a weekend too. App Review isn't on a business-day
cycle, so "it's the weekend, nothing will move" is wrong here.

### Gaps, deliberately left blank

Blank means *not known*, not *none* — don't fill these by inference.

- **v1.0–v1.2 build numbers** predate the tracked build↔commit anchors, and
  Xcode Cloud numbering can't be reconstructed backwards from git (it counts
  *pushes*, and a push can be silently dropped). They're recoverable from the
  App Store Connect build list if ever needed.
- **v1.0's dates** aren't recorded anywhere in the repo.
- **Commits** for v1.1–v1.4 weren't captured at submission time.

## What the turnaround actually tells you

| | |
|---|---|
| Fastest | same day (v1.3) |
| Slowest | 13 days (v1.1) |
| Median | ~3 days |

**There is no pattern by size of change**, and that matters more than the
average: v1.3 was a bigger release than v1.4 and cleared in hours, while v1.5
— a small one — sat 8 days. v1.1's 13 days overlapped the beta-macOS toolchain
blocker, so it isn't clean queue time either.

**So don't read silence as a problem.** Nothing here supports "it's stuck" at
3, 5, or even 7 days; v1.5 is the counter-example at 8 days and a normal
approval. Two weeks with no *Metadata Rejected* or *Rejected* status would be
the first real signal.

## Rules that shape the table

- **One version in review at a time.** Apple closes a version's train once
  it's approved, so the next release needs a new `MARKETING_VERSION` — not
  just a new build. v1.7 can't be submitted until v1.6 clears.
- **Build numbers are Xcode Cloud's, not `CURRENT_PROJECT_VERSION`'s.** They
  run in their own sequence, +1 per **push** to `main` (not per commit), and
  increment whether the build succeeds or not.
- **A submitted version is frozen.** Before submission, extra builds are free;
  after it, a new build means resubmitting. That's the only point where "this
  costs a build" is worth saying out loud.

## See also

- [`APP_STORE_LISTING.md`](APP_STORE_LISTING.md) §5 — the per-version *What's
  New* copy, one block per version.
- [`APP_STORE_LISTING.md`](APP_STORE_LISTING.md) §11 — the pre-submission and
  per-release checklists.
