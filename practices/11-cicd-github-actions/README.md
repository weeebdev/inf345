# Practice 11 — Your First Pipeline

**Objective:** give a small Python project a real **CI pipeline** in
GitHub Actions: it runs on every push and pull request, **lints** the code,
then **tests** it on two Python versions at once (a **matrix**), caches
dependencies, and keeps each test report as an **artifact** — with
**least-privilege** permissions. The building blocks from today's lecture.

**Timebox:** ~30–35 min of actual work within today's session.

> **How to submit:** same as last week — on **Maru**. Click **Accept**
> on "Practice 11", accept the GitHub invite, clone your private repo
> under `weeebdev-edu`, and work there. Commit and push to `main` —
> GitHub Actions grades every push automatically, in about a minute.

## Setup

Python 3.11+ with `venv`:

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt        # pytest + ruff, pinned
```

No Python on your machine? Run everything in a container:

```bash
docker run --rm -it -v "$PWD":/work -w /work python:3.12-slim \
  sh -c "pip install -q -r requirements.txt && ruff check . && pytest"
```

Optional: [`act`](https://github.com/nektos/act) runs your workflow on your
own machine in Docker (`act push -j lint`). Not required — pushing and
watching the **Actions** tab works just as well.

## What's in your repo

```
textkit/__init__.py               TODO 1–2 — slugify, word_count, truncate
tests/test_textkit.py             done — what truncate() must do
pyproject.toml                    done — pytest and ruff settings
requirements.txt                  done — pytest, ruff (pinned)
Containerfile                     done — not graded today (Lab 03)
ci.yml.example                    TODO 3–7 — your pipeline, to copy into place
.github/workflows/classroom.yml   the grader — don't edit
```

Your pipeline goes in **`.github/workflows/ci.yml`** — a new file you
create. It isn't in the starter on purpose: everything the template ships
in `.github/workflows/` is the grader's, and changing it voids the run.

## Task

First see what CI would see:

```bash
ruff check .          # F401: an unused import
pytest                # 4 failed: truncate() isn't written yet
```

Then do the `TODO`s in order:

1. **`truncate()`** — `textkit/__init__.py`. Text that fits is returned
   as is; longer text is cut so that text + suffix is exactly `width`
   characters (`truncate("hello world", 8) == "hello w…"`); `width < 1`
   raises `ValueError`. The tests in `tests/test_textkit.py` are the spec.
2. **Lint** — remove the unused `import os`. `ruff check .` is clean.
3. **Triggers** — `mkdir -p .github/workflows && cp ci.yml.example
   .github/workflows/ci.yml`. Make it run on **push** and on
   **pull_request** to `main`.
4. **`lint` job** — `actions/checkout@v4`, `actions/setup-python@v5`
   (Python 3.12), `pip install -r requirements.txt`, `ruff check .`.
5. **`test` job** — `needs: lint` (no tests for code that doesn't even
   lint), `strategy.matrix.python-version: ["3.11", "3.12"]`, setup-python
   with `python-version: ${{ matrix.python-version }}` and `cache: pip`,
   then `pytest --junitxml=report-${{ matrix.python-version }}.xml`.
6. **Artifact** — `actions/upload-artifact@v4` with
   `name: test-report-${{ matrix.python-version }}` and the report as
   `path:`. Add `if: always()` so you get the report even when tests fail.
7. **Permissions** — at the top of the workflow:
   `permissions: { contents: read }`. CI that only reads code shouldn't get
   a token that can push.

Test it locally before you push:

```bash
ruff check .                                   # All checks passed!
pytest                                         # 6 passed
```

Then push, open the **Actions** tab, and watch your pipeline: `lint` first,
then two `test` jobs side by side, and two artifacts on the run's summary
page.

## Definition of done

- [ ] `ruff check .` is clean and `pytest` passes (6 tests)
- [ ] `.github/workflows/ci.yml` runs on push and on pull requests
- [ ] `lint` runs `ruff check`; `test` runs only after `lint` succeeds
- [ ] `test` runs on Python 3.11 **and** 3.12, with pip caching
- [ ] Each Python version uploads its own JUnit report artifact
- [ ] `permissions: contents: read`, nothing writes
- [ ] Your **CI** run is green in the Actions tab
- [ ] Pushed to `main` before the session ends (this is also your attendance signal)

## Common mistakes

- **`refusing to allow … to create or update workflow … without
  'workflow' scope`.** Your Git credentials can't push workflow files.
  Push over SSH, or run `gh auth refresh -s workflow` (GitHub CLI), or
  sign in again in your credential manager.
- **The pipeline never starts.** The file must be in
  `.github/workflows/` and end in `.yml` — `ci.yml.example` at the root
  does nothing.
- **Python 3.1 not found.** `[3.10, 3.11]` unquoted is the *number* 3.1.
  Quote versions: `["3.11", "3.12"]`.
- **"Unable to find any artifacts" / name conflict.** Two matrix jobs
  uploading the same artifact name collide; put the version in `name:`.
- **`cache: pip` fails: "No file … matched to [**/requirements.txt]".**
  setup-python's pip cache is keyed on `requirements.txt` — keep that file
  (don't rename it) and install from it, not with a bare
  `pip install pytest ruff`.
- **Test job never runs.** `needs: lint` waits for a job *named* `lint`;
  check the spelling of the job ids.
- **Editing `classroom.yml`.** Even a whitespace change voids that run.
  Your pipeline lives in its own file, `ci.yml`.

## Grading

Real autograding — the grader reads your `ci.yml` and checks its
structure, and runs ruff and pytest itself, out of 100 points:

| Check | Points |
|---|---|
| `.github/workflows/ci.yml` exists and is a valid workflow | 10 |
| Runs on `push` and `pull_request` (to `main`) | 10 |
| `lint` job: checkout, setup-python (pinned majors), `ruff check` | 15 |
| `test` job: `needs: lint`, runs pytest | 10 |
| Matrix of ≥ 2 Python versions; setup-python uses it, with `cache: pip` | 15 |
| `pytest --junitxml`, uploaded with `upload-artifact@v4`, one name per version | 10 |
| `permissions: contents: read`, nothing writes | 5 |
| `ruff check` is clean (default rules — your ruff config is ignored) | 10 |
| `pytest` passes, and `truncate()` passes the grader's own cases too | 15 |

Check the **Actions** tab in your repo for the run, or the workflow run's
**Summary** for the exact score. Workflow: `.github/workflows/classroom.yml`
(in your repo, not this one) — **don't edit it**: a run with an edited
grader doesn't count.

This score is this session's grade within the **Weekly practice sessions**
category — 1 point per practice, your best 10 count (see `SYLLABUS.md`).

## Connection to Lab 03

Lab 03 — **CI/CD pipeline** — is due in **week 13**. It starts from
exactly this: lint and test jobs, a matrix, caching and artifacts. Next
week adds building and publishing the container image (`Containerfile`
is already here) and running the pipeline on pull requests before merge.
