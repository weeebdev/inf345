# Practice 12 — Build It, Test the Image, Publish on a Tag

**Objective:** take last week's pipeline (lint → tests on two Python
versions → test reports) and make it ship something: a **coverage gate**
that can say "no", a **build** job that builds the container image tagged
with the commit it came from, a **smoke test** of that exact image, and a
**publish** job that pushes it to the GitHub Container Registry — only when
you push a version tag. Plus the hygiene every real pipeline has:
**concurrency** and **timeouts**. The patterns from today's lecture.

**Timebox:** ~35 min of actual work within today's session.

> **How to submit:** same as last week — on **Maru**. Click **Accept**
> on "Practice 12", accept the GitHub invite, clone your private repo
> under `weeebdev-edu`, and work there. Commit and push to `main` —
> GitHub Actions grades every push automatically, in about a minute.

## Setup

Python 3.11+ and Docker (or Podman — `podman build` / `podman run` work
the same):

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt
```

No Docker on your machine? That's fine — the pipeline builds the image on
GitHub's runner, and you'll see the result in the **Actions** tab.

## What's in your repo

```
textkit/__init__.py            done — slugify, word_count, truncate (last week's)
textkit/__main__.py            done — the CLI: python -m textkit slugify "…"
tests/test_textkit.py          TODO 1 — tests for word_count and the CLI
Containerfile                  done — the image: runs the CLI, as a non-root user
requirements.txt               done — pytest, pytest-cov, ruff
.github/workflows/ci.yml       TODO 1–5 — last week's pipeline, to extend
.github/workflows/classroom.yml  the grader — don't edit
```

## Task

Look at what you have first:

```bash
pytest --cov=textkit --cov-report=term-missing   # passes… with 48% coverage
python -m textkit slugify "Hello, DevOps World!" # hello-devops-world
docker build -f Containerfile -t textkit .
docker run --rm textkit slugify "Hello, DevOps World!"
```

Then do the `TODO`s in order:

1. **Coverage gate** — in the `test` job, run
   `pytest --cov=textkit --cov-fail-under=90 --junitxml=…`. Push it and
   watch CI go **red**: 48% < 90%. Now write the missing tests in
   `tests/test_textkit.py` — `word_count()`, and the CLI:
   `main(["slugify", "Hello, DevOps World!"])` returns `0` and prints the
   slug (read the output with pytest's `capsys` fixture). Green again.
2. **Build job** — a job `build` with `needs: test`: check out the code and
   build the image tagged with the commit SHA:
   `docker build -f Containerfile -t textkit:${{ github.sha }} .`
   The SHA says exactly which commit this image was built from.
3. **Smoke test** — in the same job, run **that** image and check its answer
   exactly. The step must **fail** when the answer is wrong:
   ```bash
   out=$(docker run --rm textkit:${{ github.sha }} slugify "Hello, DevOps World!")
   test "$out" = "hello-devops-world"
   ```
4. **Publish on a tag** — add `tags: ["v*"]` under `on.push` (keep
   `branches: [main]` there too!). Then a job `publish`:
   - `if: startsWith(github.ref, 'refs/tags/v')` and `needs: build`;
   - its own `permissions:` — `packages: write` **and** `contents: read`;
   - `docker/login-action@v3` with `registry: ghcr.io`,
     `username: ${{ github.actor }}`, `password: ${{ secrets.GITHUB_TOKEN }}`;
   - build and push `ghcr.io/${{ github.repository }}:${{ github.ref_name }}`.

   Try it: `git tag v0.1.0 && git push origin v0.1.0` — the image shows up
   under your repo's **Packages**.
5. **Hygiene** — a top-level `concurrency:` (a `group:` per branch/tag,
   `cancel-in-progress: true`), and `timeout-minutes:` on every job.

Test it locally before you push:

```bash
ruff check .
pytest --cov=textkit --cov-fail-under=90          # Required test coverage of 90% reached
docker build -f Containerfile -t textkit .
docker run --rm textkit slugify "Hello, DevOps World!"   # hello-devops-world
docker run --rm --entrypoint id textkit -u               # not 0
```

## Definition of done

- [ ] `pytest --cov=textkit --cov-fail-under=90` passes, and CI enforces it
- [ ] `build` runs after `test` and builds `textkit:<commit sha>`
- [ ] The smoke test runs that image and fails on a wrong answer
- [ ] `publish` runs only for `v*` tags, after `build`, and pushes to `ghcr.io`
- [ ] Only `publish` can write (`packages: write`); everything else reads
- [ ] `concurrency` with `cancel-in-progress`, and a timeout on every job
- [ ] Pushed to `main` (and a tag `v0.1.0`, to see it publish) before the session ends (this is also your attendance signal)

## Common mistakes

- **Pushes to main stopped running CI.** `tags:` under `push` without
  `branches:` means "only tags". List both: `branches: [main]` and
  `tags: ["v*"]`.
- **Coverage is printed, but CI is still green at 48%.** `--cov` only
  reports; `--cov-fail-under=90` is the gate.
- **The smoke test is green even when the output is wrong.** `echo $out`
  or a bare `docker run` passes as long as the container exits 0. Compare
  the output: `test "$out" = "hello-devops-world"`.
- **`publish`: "Resource not accessible by integration" / checkout fails.**
  Job-level `permissions:` *replace* the top-level ones: list
  `contents: read` next to `packages: write`.
- **`denied: installation not allowed to Create organization package`.**
  Push to `ghcr.io/${{ github.repository }}` — your own repo's name — not
  an image name you made up. (Image names must be lowercase; your
  `weeebdev-edu` repo names already are.)
- **The tag ran nothing.** You pushed the commit but not the tag:
  `git push origin v0.1.0` (or `git push --tags`). Pushing the same tag
  twice needs a new tag (`v0.1.1`).
- **Pushing `ci.yml` is refused** ("refusing to allow … without `workflow`
  scope"): push with the GitHub CLI / SSH, or a token with the `workflow`
  scope.

## Grading

Real autograding — GitHub Actions reads your `ci.yml`, runs ruff and your
tests with the coverage gate on the runner, and builds and runs your image
itself, out of 100 points. It never depends on your own CI runs being green.

| Check | Points |
|---|---|
| Triggers: push to `main`, tags `v*`, pull requests | 10 |
| Lint job and the test matrix are still there | 10 |
| Coverage gate: `--cov` and `--cov-fail-under` ≥ 90 | 10 |
| `build` needs `test`, builds the image tagged with `github.sha` | 15 |
| Smoke test runs the image and checks `hello-devops-world` | 10 |
| `publish`: tags only, needs `build`, `packages: write` + `contents: read`, GHCR login with `GITHUB_TOKEN`, pushes to `ghcr.io` | 15 |
| Top-level `contents: read`, nothing else writes; `concurrency`; `timeout-minutes` on every job | 10 |
| `ruff check` clean | 5 |
| Tests pass with ≥ 90% coverage; the CLI is right on the grader's own cases | 10 |
| The image builds, prints `hello-devops-world`, and doesn't run as root | 5 |

Check the **Actions** tab in your repo for the run, or the workflow run's
**Summary** for the exact score. Workflow: `.github/workflows/classroom.yml`
(in your repo, not this one).

This score is this session's grade within the **Weekly practice sessions**
category — 1 point per practice, your best 10 count (see `SYLLABUS.md`).

## Connection to Lab 03

Lab 03 (the CI/CD pipeline, due in week 13) is this same pipeline on a
bigger app — a small notes API with a health endpoint — plus the one stage
you'll add next week: a **security scan** of the image before it's
published. Everything you build today carries over.
