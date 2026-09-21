# Release History — Courtside Hoop Stats

Every version submitted to App Store Connect: which Xcode Cloud build carried
it, when it went in, when Apple approved it, and how long that took.

**Keep this current.** Add a row when a version is submitted (Approved =
`in review`), and fill in the approval and the split when the email arrives.
It's the only place these facts sit together — App Store Connect has the
timestamps but not the commit, and the build numbers can't be recovered from
git.

Times are from each version's **Activity** list in App Store Connect:
"Submitted" is *Waiting for Review*, "Approved" is *Ready for Distribution*.

## Submitted versions

| Version | Build | Commit | Submitted | Approved | Total | Queued | In review |
|---|---|---|---|---|---|---|---|
| v1.10 | 167 | — | Sun 2026-09-20, 8:48 PM | Mon 2026-09-21, 3:42 PM | 18h 54m | 16h 23m | 2h 31m |
| v1.9 | 157 | `f1f5ed9` | Fri 2026-09-18, 8:57 AM | Fri 2026-09-18, 11:22 AM | **2h 25m** | **42m** | 1h 43m |
| v1.8 | 147 | `911cdae` | Thu 2026-09-17, 7:32 PM | Fri 2026-09-18, 7:54 AM | **12h 22m** | 10h 34m | 1h 48m |
| v1.7 | 137 | `9a1a24d` | Wed 2026-09-16, 9:39 PM | Thu 2026-09-17, 7:42 AM | **10h 3m** | 9h 36m | **27m** |
| v1.6 | 128 | `f3e960d` | Sun 2026-09-13, 1:52 PM | Wed 2026-09-16, 4:19 PM | 3d 2h 27m | 3d 0h 5m | 2h 22m |
| v1.5 | 106 | `f6c0820` | Sat 2026-09-05, 8:33 PM | Sun 2026-09-13, 12:22 PM | 7d 16h | 7d 13h 27m | 2h 22m |
| v1.4 | 100 | — | Wed 2026-09-02, 6:18 PM | Sat 2026-09-05, 7:54 PM | 3d 2h | 2d 22h 7m | **3h 29m** |
| v1.3 | 89 | — | Wed 2026-09-02, 8:42 AM | Wed 2026-09-02, 12:36 PM | **3h 54m** | 1h 46m | 2h 8m |
| v1.2 | — | — | Mon 2026-08-17, 8:06 PM | Tue 2026-08-18, 1:27 PM | 17h 21m | 15h 57m | 1h 24m |
| v1.1 | — | — | Tue 2026-08-04, 10:43 PM | Mon 2026-08-17, 6:21 PM | 12d 20h | 12d 19h 21m | **17m** |
| v1.0 | — | — | Tue 2026-07-21, 12:52 PM | Mon 2026-08-03, 10:21 PM | **13d 9h** | 13d 9h 6m | 23m |

Weekdays are kept because **two of seven approvals landed at a weekend** (v1.4
Saturday, v1.5 Sunday). App Review is not on a business-day cycle, so
"nothing will move until Monday" is wrong for this app.

Builds 137 and 147 are both **confirmed** by App Store Connect, and both land
exactly where counting pushes from the anchor (130 = `b060d7e`) predicted. The
method has now been right three times running: count pushes to `main`, not
commits — with one caveat found the hard way on v1.9.

**Pushing a PR branch builds too, and the count has to include it.** v1.10
went out as build **167** where counting pushes to `main` predicted 162 — five
low, across a stretch with three feature branches (#196, #198, #200). Branch
pushes consume numbers alongside merges, so "+1 per push to `main`" only holds
for a release built straight off `main`. Where PRs were involved, the number
from counting is a **floor**; read the real one off the build list, which names
each build's source branch.

**Two pushes seconds apart can share a build.** `7d74293` and `d375957` went
up 17 seconds apart and Xcode Cloud started one build for the pair, so eleven
pushes past the confirmed 147 produced ten builds and the estimate ran one
high (158 predicted, 157 actual, user-confirmed). The rule is still "count
pushes, not commits" — but a push that lands while a build is starting can be
swept into it, exactly as commits seconds apart usually share a push. When
pushes have been rapid, treat the count as a ceiling and confirm against the
build list.

Four releases in a row have cleared inside a day: v1.7 10h 3m, v1.8 12h 22m,
v1.9 **2h 25m** (the record, and the only one approved the same morning it went
in), v1.10 18h 54m. v1.9's **42-minute queue** is still the shortest recorded
here, less than half the previous best (v1.3, 1h 46m).

**Submitting at night buys nothing.** v1.8 and v1.10 both went in during the
evening and both waited out the night — 10h 34m and 16h 23m queued. v1.9 went
in on a weekday morning and was picked up in 42 minutes. One data point each
way, so it's a hint, not a rule.

v1.7 was the fastest total until v1.9's 2h 25m, and still holds the
**fastest review at 27 minutes** — it went in overnight and was queued
9h 36m, which is most of it.

## The wait is the queue. The review is hours.

| | Range | Spread |
|---|---|---|
| **Queued** (*Waiting for Review*) | 42m → 13d 9h | **460×** |
| **In review** (*In Review*) | 17m → 3h 29m | 12× |

v1.6 fits the pattern exactly: **3d 0h queued, 2h 22m in review.**

Every multi-day wait this app has had was spent **queued, untouched**. Once a
human starts, it has always finished the same working day — the longest was
v1.4 at 3h 29m.

Two things follow, and they're the reason this table exists:

1. **Elapsed days carry no information; the status does.** A submission out
   for a week is in a queue, not under scrutiny — there is nothing in the
   binary or the metadata to second-guess while waiting.
2. **Once it flips to *In Review*, it's nearly over.** Expect an answer inside
   a few hours, same day.

So **don't read silence as a problem.** Nothing here supports "it's stuck" at
3, 5 or even 8 days — v1.5 sat 7d 13h in the queue and was approved in 2h 22m
without a single question. A *Rejected* or *Metadata Rejected* status is the
signal; elapsed time is not.

## Queue depth, not release size

| | |
|---|---|
| Fastest | **2h 25m (v1.9)** |
| Slowest | 13d 9h (v1.0) |
| Median | ~3 days |

**Total turnaround has no relation to the size of the change.** v1.3 was a
bigger release than v1.4 and cleared in under four hours; v1.5 was small and
took a week; v1.9 was pure polish and set the record at 2h 25m. What varies is queue depth on the day, which is unknowable in
advance — so don't plan a release date around a predicted approval.

The one visible pattern is that the queue got dramatically shorter after the
first two releases: 13 days for v1.0 and v1.1, then 16 hours or less for v1.2
and v1.3. A new app's first submissions appear to be queued differently.

### Time before submitting is ours, not Apple's

v1.0 sat **4d 14h** between *Prepare for Submission* and *Waiting for Review*
— the beta-macOS toolchain blocker, entirely this side of the fence. Every
release since has closed that gap in 1–25 minutes. Worth separating when
judging how long a release "took": the queue is Apple's, the prep gap is ours.

## Gaps, deliberately left blank

Blank means *not known*, not *none* — don't fill these by inference.

- **v1.0–v1.2 build numbers** predate the tracked build↔commit anchors. Xcode
  Cloud numbering can't be reconstructed backwards from git: it counts
  *pushes*, not commits, and at least one push was silently dropped. They're
  readable from each version's page in App Store Connect if ever needed.
- **Commits** for v1.0–v1.4 weren't captured at submission time.

## Rules that shape the table

- **One version in review at a time.** Apple closes a version's train once
  it's approved, so the next release needs a new `MARKETING_VERSION` — not
  just a new build. The data shows this as a chain of same-day handoffs: v1.2
  went in 2h after v1.1 was approved, v1.4 6h after v1.3, v1.6 90 minutes
  after v1.5, v1.8 12h after v1.7, and v1.9 **1h 3m** after v1.8 — the fastest
  handoff yet.
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
