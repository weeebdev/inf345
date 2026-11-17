# Lab 03 — CI/CD Pipeline

**Objective:** build a complete **CI/CD pipeline** in GitHub Actions for a
small containerized web service — lint, test on a matrix, build the image
and prove it starts, scan it for vulnerabilities, and **publish** it to a
registry only when you cut a release — with least-privilege permissions.

**Weight:** **15 %** of the course grade (see `SYLLABUS.md`). Autograded.

**Deadline:** **Wednesday, 25 November 2026, 23:59 (Almaty)** — week 13.
Your best **on-time** run counts. Late work counts only if your teacher
accepts it (with a penalty).

**Timebox:** ~4–6 hours spread over two weeks. If you're past double that,
stop and ask in the course discussion instead of pushing through alone.

**RHA lab:** N/A — GitHub-native lab (Red Hat Academy doesn't cover CI/CD).

**Builds on:** Practice 11 (*Your first pipeline*) — lint, `needs:`, the
Python matrix, pip caching and artifacts are exactly what you did there —
and the Containerfile skills from module 1 (Lab 01, Practices 03–06).

> **How to submit:** on **Maru**, like the practices. Click **Accept** on
> "Lab 03 — CI/CD Pipeline", accept the GitHub invite, clone your private
> repo under `weeebdev-edu`, and work there. Every push is graded
> automatically by `.github/workflows/classroom.yml` in a few minutes; the
> score shows up in Maru.

## What you'll build

```
push / pull request ──► lint ──► test (3.11, 3.12) ──► build + smoke test ──► scan (Trivy)
                                                                                  │
tag v1.2.3 ───────────────────────────────────────────────────────────────────────┴──► publish to GHCR
```

- **lint** — `ruff check .`
- **test** — pytest on Python **3.11 and 3.12**, pip cache, **coverage
  ≥ 80 %**, a JUnit report kept as an artifact (even when tests fail)
- **build** — build the container image from the `Containerfile`, run it,
  and check `GET /health` answers **200**
- **scan** — scan the image with **Trivy**; the pipeline **fails on any
  CRITICAL** vulnerability
- **publish** — push the image to **GitHub Container Registry**
  (`ghcr.io/weeebdev-edu/<your-repo>`) — **only** for tags `v*`, never
  for ordinary pushes or pull requests

Plus the guardrails every real pipeline has: read-only permissions by
default, `packages: write` only on the publish job, `concurrency` so a new
push cancels the old run, and `timeout-minutes` on every job.

## Setup

Python 3.11+ with `venv`, and Podman or Docker:

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt        # app + pytest, pytest-cov, ruff (pinned)
pytest && ruff check .                 # see what's failing before you start
```

No Python on your machine? Use a container:

```bash
docker run --rm -it -v "$PWD":/work -w /work python:3.12-slim \
  sh -c "pip install -q -r requirements.txt && ruff check . && pytest"
```

## What's in your repo

```
notes/__init__.py                  the notes web service — TODOs 1–3
tests/                             tests you can see (the grader checks more)
requirements.txt                   app and dev dependencies, pinned
pyproject.toml                     pytest, coverage and ruff settings
Containerfile                      builds the service image
ci.yml.example                     your pipeline's skeleton — copy it into place
.github/workflows/classroom.yml    the grader — don't edit
```

Your pipeline goes in **`.github/workflows/ci.yml`**, a file you create
(`mkdir -p .github/workflows && cp ci.yml.example .github/workflows/ci.yml`).
Everything the template ships in `.github/workflows/` belongs to the
grader: changing it voids the run.

## Tasks

Work in this order — each step keeps the pipeline green before you add the
next.

1. **The code TODOs** in `notes/__init__.py`:
   - **TODO 1** — `DELETE /notes/<id>`: `204` for an existing note (a later
     `GET` gives `404`), `404` for a missing one.
   - **TODO 2** — validation on create: an empty, whitespace-only or
     over-100-character title, a missing title, a non-string body or a body
     over 2000 characters → `400`; a 100-character title with a
     2000-character body is fine (`201`).
   - **TODO 3** — remove the unused import ruff flags.

   The visible tests describe the behaviour; the grader runs its own API
   checks of the same rules, so make it correct, not just green.
2. **Triggers.** `on:` push to `main`, pull requests to `main`, and tags
   matching `v*`. With `tags:` under `push`, also list `branches: [main]`
   — otherwise ordinary pushes stop running the pipeline.
3. **Guardrails.** Top-level `permissions: contents: read`; a
   `concurrency:` group keyed on the ref with `cancel-in-progress: true`;
   `timeout-minutes` on every job (a few minutes each).
4. **`lint`** — checkout, setup-python, install, `ruff check .`.
5. **`test`** — `needs: lint`; matrix `python-version: ["3.11", "3.12"]`;
   setup-python with `cache: pip`; run pytest **with coverage, failing
   under 80 %** (`--cov=notes --cov-fail-under=80`), writing a JUnit report
   (`--junitxml=…`); upload the report with
   `actions/upload-artifact@v4` (`if: always()`, one artifact name per
   Python version).
6. **`build`** — `needs: test`; build the image from the `Containerfile`;
   run it in the background (`docker run -d -p 8080:8080 …`), wait until
   it's up, and `curl` `/health` — the step must fail if the service
   doesn't answer 200.
7. **`scan`** — scan the image you just built with Trivy
   (`aquasecurity/trivy-action`, **pinned to a release** like `@v0.36.0`,
   never `@master`), in `build` or in a job that `needs: build`, with
   `image-ref:` your image, `severity:` including `CRITICAL` and
   `exit-code: "1"`. If it finds something, fix it (usually: a newer,
   slimmer base image), don't switch the check off.
8. **`publish`** — `needs:` the scan; runs **only** when the ref is a
   `v*` tag (`if: startsWith(github.ref, 'refs/tags/v')`); this job — and
   only this job — gets `permissions: packages: write` **and
   `contents: read`** (job permissions replace the workflow's: without
   `contents: read`, checkout fails); log in to `ghcr.io` with
   `GITHUB_TOKEN` and push `ghcr.io/<owner>/<repo>:<tag>`.
9. **Release it.** When everything is green on `main`:
   `git tag v1.0.0 && git push origin v1.0.0` — then check the run and the
   **Packages** section of your repo.

## How to test locally

```bash
ruff check .
ruff check --isolated .                         # what the grader runs
pytest --cov=notes --cov-fail-under=80
podman build -t lab03 .                         # or: docker build
podman run -d --rm -p 8080:8080 --name lab03 lab03
curl -fsS http://localhost:8080/health && echo OK
podman stop lab03
trivy image --severity CRITICAL --exit-code 1 lab03   # if you have Trivy
```

Optional: [`act`](https://github.com/nektos/act) runs your workflow
locally in Docker (`act push -j test`). Not required — pushing and watching
the **Actions** tab works just as well. (`act` can't really publish to
GHCR; test publishing with a real tag.)

## Definition of done

- [ ] All code TODOs done; `ruff check .` is clean; `pytest` passes with
      coverage ≥ 80 %
- [ ] `.github/workflows/ci.yml` runs on push and PRs to `main` and on `v*` tags
- [ ] `lint` → `test` → `build` → `scan` run in that order (`needs:`)
- [ ] `test` runs on Python 3.11 **and** 3.12 with pip caching and uploads
      a JUnit report per version, even on failure
- [ ] `build` builds the image and checks `/health` returns 200
- [ ] `scan` runs Trivy (pinned release) on that image and fails on CRITICAL
- [ ] `publish` runs only for `v*` tags, has `packages: write` +
      `contents: read` (nothing else writes), and pushes to `ghcr.io`
- [ ] Read-only `permissions` by default, `concurrency`, `timeout-minutes`
      on every job
- [ ] Your **CI** run is green on `main`, and a `v1.0.0` tag published the image
- [ ] Graded run in Maru shows your score before **25 Nov, 23:59**

## Grading

Real autograding on every push — the grader reads your `ci.yml` and checks
its structure, and runs lint, tests (including hidden ones) and the image
itself, out of 100 points:

| Check | Points |
|---|---|
| Workflow and triggers: valid `ci.yml`; `push` to `main` **and** tags `v*`; `pull_request` to `main` | 10 |
| `lint` job: checkout, setup-python (pinned majors), `ruff check` | 5 |
| `test` job: `needs: lint`, checkout, runs pytest | 5 |
| Matrix of ≥ 2 **quoted** Python versions; setup-python uses it with `cache: pip`; actions pinned to a major | 10 |
| Coverage gate: `--cov` and `--cov-fail-under` ≥ 80 | 5 |
| Test report: `--junitxml`, `upload-artifact@v4` with `if: always()`, the version in `name:`, a `path:` | 5 |
| `build` job (`needs:` test): builds the image, runs it, checks `/health` | 10 |
| Security scan: Trivy pinned to a release, on the built image, `CRITICAL`, `exit-code: "1"` | 15 |
| `publish` on `v*` tags only, after the scan; `ghcr.io` login with `GITHUB_TOKEN`; pushes `ghcr.io/<owner>/<repo>:<tag>`; job permissions `packages: write` + `contents: read` | 15 |
| Least privilege: top-level `contents: read`, no other job writes; `concurrency` with `cancel-in-progress: true`; `timeout-minutes` on every job | 5 |
| Image runs: the grader builds your `Containerfile`, and `/health` on port 8080 answers 200 within 30 s | 5 |
| Code and tests: `ruff check --isolated .` clean; `pytest --cov=notes --cov-fail-under=80` passes; the grader's own API checks of TODOs 1–2 pass | 10 |

Every check is pass/fail. The untouched starter scores **5** (its image
already runs).

Check the **Actions** tab for the run, or the run's **Summary** for the
exact score. **Don't edit `classroom.yml`**: a run with an edited grader
doesn't count. The grader only judges `classroom.yml` runs — your own
`ci.yml` being green is required by the checklist above, but it isn't what
sets your score.

## Common mistakes

- **`refusing to allow … to create or update workflow … without
  'workflow' scope`.** Your Git credentials can't push workflow files.
  Push over SSH, or `gh auth refresh -s workflow`, or sign in again in your
  credential manager.
- **The pipeline never starts.** It must be in `.github/workflows/` and end
  in `.yml` — `ci.yml.example` at the root does nothing.
- **`cache: pip` fails: "No file … matched to [**/requirements.txt]".**
  setup-python's pip cache looks for `requirements.txt` — keep that name and
  install from it.
- **Python 3.1 not found.** `[3.10, 3.11]` unquoted are numbers; quote
  them: `["3.11", "3.12"]`.
- **The health check passes even though the app is broken.** `curl`
  without `-f` exits 0 on a 500. Use `curl -fsS`, and retry for a few
  seconds while the container starts.
- **Publishing on every push.** `publish` must be guarded with
  `if: startsWith(github.ref, 'refs/tags/v')` — a pull request should never
  push an image.
- **`denied: permission_denied` from ghcr.io.** The publish job needs
  `permissions: packages: write` (job level), and the image name must be
  lowercase: `ghcr.io/weeebdev-edu/<repo>`.
- **Can't see the published image.** New GHCR packages are private and
  linked to the org; find it under your repo's **Packages**, or at
  `github.com/orgs/weeebdev-edu/packages`. You don't need to make it public.
- **The tag didn't trigger anything.** Tags need `on: push: tags: ["v*"]`,
  and you must push the tag itself: `git push origin v1.0.0`.
- **`tags:` under `push` and now nothing runs on `main`.** Once `push:`
  has `tags:`, also list `branches: [main]`.
- **`trivy-action@master`.** Pin a release (`@v0.36.0`) — a moving branch
  is a supply-chain risk, and the grader doesn't accept it.
- **Trivy prints findings but the job stays green.** You forgot
  `exit-code: "1"`.
- **`publish` fails at checkout.** Job-level `permissions:` replace the
  workflow's — give `publish` `contents: read` as well as
  `packages: write`.
- **Trivy fails on CRITICAL.** That's the check working. Move to a newer
  slim base image and rebuild; don't add `--exit-code 0` or
  `ignore-unfixed` to make it go away.
- **Editing `classroom.yml`.** Even a whitespace change voids that run.

## Academic integrity

This is individual work. Discuss ideas with classmates, but write your own
pipeline and code — and be ready to explain every line of `ci.yml`.
Maru flags signs of AI-agent-written work for your teacher (agent commit
trailers or authors, agent instruction files, the whole lab landing in one
commit minutes after Accept); a flag doesn't change your score, but it may
lead to a short oral check where you walk through your pipeline. Editing
the grading workflow voids the attempt (see `SYLLABUS.md`).
