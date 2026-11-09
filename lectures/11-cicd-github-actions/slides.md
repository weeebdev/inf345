---
theme: seriph
title: "INF345 — Lecture 11: CI/CD Concepts & GitHub Actions Basics"
info: |
  INF345 — Fundamentals of DevOps
  Lecture 11 of 15
background: /cover-bg.svg
transition: fade
mdc: true
download: true
---

# INF 345 — Fundamentals of DevOps

## Lecture 11: CI/CD Concepts & GitHub Actions Basics

<div class="pt-8 opacity-70">
Adil Akhmetov · Lesson 11
</div>

---
layout: default
---

# Recap — Lesson 10 (Ansible in production)

<v-clicks>

- Same playbook, production instead of staging — how? <span v-click class="opacity-60">(`-i inventories/production`: same code, other inventory)</span>
- Where does a secret like `db_password` live? <span v-click class="opacity-60">(in a vault-encrypted `vault.yml`, used through a `vault_` variable, and kept out of logs with `no_log: true`)</span>
- `--tags config` — what runs? <span v-click class="opacity-60">(only tasks tagged `config`, plus anything tagged `always`)</span>
- The health check fails after a config change. What should happen? <span v-click class="opacity-60">(`rescue` restores the last good config — then `fail:`, so the run is red)</span>

</v-clicks>

---
---

# Where we are

<div class="grid grid-cols-3 gap-6 text-sm mt-6">
<div>

### Weeks 3–6 · Containers

Package an app with everything it needs: `Containerfile`, images, volumes,
non-root.

<div class="opacity-60 mt-2">Lab 01 — RHA DO188</div>

</div>
<div>

### Weeks 7–10 · Automation

Describe servers as code: Ansible roles, idempotence, environments,
secrets.

<div class="opacity-60 mt-2">Lab 02 — RHA RH294</div>

</div>
<div class="border-l-4 border-emerald-400 pl-4">

### Weeks 11–13 · CI/CD

Let a machine **build, test and ship** on every push — using the first two
modules.

<div class="opacity-60 mt-2">Lab 03 — on GitHub, due week 13</div>

</div>
</div>

<div v-click class="mt-10 text-center text-lg">
You've been <b>using</b> CI all term: every practice push runs a workflow.
Today you learn to <b>write</b> one.
</div>

---
---

# Today's agenda

<v-clicks>

- [ ] Why CI/CD: fast feedback, "works on my machine", small batches
- [ ] Continuous integration, delivery, deployment — what's the difference
- [ ] Anatomy of a GitHub Actions workflow: triggers, jobs, runners, steps
- [ ] Actions from the marketplace, variables, expressions
- [ ] Secrets, `GITHUB_TOKEN` and `permissions:`
- [ ] Bigger pipelines: `needs:`, matrix builds, caching, artifacts
- [ ] Status checks and branch protection — how your autograder works
- [ ] Worked example: lint → test → build an image
- [ ] Straight into today's practice

</v-clicks>

---
layout: center
class: text-center
---

# The scenario

<div class="text-lg text-left mt-4 max-w-2xl mx-auto">

A small Python web app. Four people push to it. On Friday someone merges a
change that passed on their laptop — Python 3.12, a package they had
installed globally. On the server (Python 3.11) the app won't start. Nobody
notices until Monday.

</div>

<div v-click class="mt-8 text-xl font-bold">
Today: every push is checked automatically, on a clean machine, in minutes
— and a red check stops the merge.
</div>

---
layout: section
transition: slide-left
---

# Block 1
## Why CI/CD

---
---

# "It works on my machine"

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

Your laptop is a terrible test environment:

<v-clicks>

- packages you installed months ago and forgot
- a different Python / Node / OS version than the server
- files that exist only on your disk (`.env`, a local database)
- you ran the tests… two commits ago

</v-clicks>

</div>
<div v-click>

**Continuous integration** answers one question for every change:

<div class="text-base italic mt-3">
"Does this commit build and pass its tests on a fresh machine?"
</div>

- a **clean runner** every time — only what's in the repo
- the **same steps** for everyone, written down in a file
- the answer in **minutes**, next to the commit

</div>
</div>

---
---

# Fast feedback, small batches

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

### Without CI

- merge once a week — a big pile of changes
- something breaks: which of 40 commits?
- "integration hell" before every release
- fear of deploying → deploy even less often

</div>
<div v-click>

### With CI

- every push is built and tested
- a break is found **minutes** after the commit that caused it
- small changes, merged often, each one checked
- a green `main` you can release at any time

</div>
</div>

<div v-click class="mt-8 text-center opacity-80">
The cost of a bug grows with the time between writing it and finding it.
CI shrinks that time to minutes.
</div>

---
---

# CI, continuous delivery, continuous deployment

| | What happens on every change | Who presses "release" |
|---|---|---|
| **Continuous integration** | build + test, on every push and PR | — (nothing is released) |
| **Continuous delivery** | …and produce a **release-ready artifact** (an image, a package), deployed to staging | a human, with one click |
| **Continuous deployment** | …and **deploy to production automatically** if every check is green | nobody — the pipeline |

<v-clicks>

- Delivery vs deployment: the only difference is the **last, manual step**.
- Most teams start with CI, then delivery; automatic deployment needs very
  good tests (and the rollback habits from last week).
- The **pipeline** is the whole chain: lint → test → build → (deploy).

</v-clicks>

---
layout: center
class: text-center
---

# Quick check

<div class="text-xl mt-4 max-w-2xl mx-auto text-left">

Every merge to `main` builds an image and deploys it to **staging**
automatically. Production is deployed when the team lead clicks
"Approve". Is that continuous delivery or continuous deployment?

</div>

<div v-click class="mt-8 text-lg opacity-70">

**Continuous delivery** — production still needs a human. Continuous
deployment would ship to production with no click at all.

</div>

---
layout: section
transition: slide-left
---

# Block 2
## Anatomy of a GitHub Actions workflow

---
---

# Where workflows live

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```text
my-app/
├── .github/
│   └── workflows/
│       ├── ci.yml          ← one workflow
│       └── release.yml     ← another
├── app/
├── tests/
└── requirements.txt
```

</div>
<div>

<v-clicks>

- A workflow is a **YAML file** in `.github/workflows/` — any name ending
  in `.yml` / `.yaml`.
- It's part of the repo: versioned, reviewed, and run from the commit
  that triggered it.
- Each file is independent; a repo can have many.
- Results: the **Actions** tab, and a ✓ / ✗ next to every commit and PR.

</v-clicks>

</div>
</div>

---
---

# The smallest useful workflow

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```yaml
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - run: pip install -r requirements.txt
      - run: pytest
```

</div>
<div>

<v-clicks>

- **`on:`** — *when* it runs (the trigger)
- **`jobs:`** — *what* runs; each job gets its own fresh machine
- **`runs-on:`** — *which* machine (the runner)
- **`steps:`** — the commands, in order; one failing step fails the job
- **`uses:`** — run a ready-made **action**
- **`run:`** — run a **shell command**

</v-clicks>

</div>
</div>

---
---

# Triggers: `on:`

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```yaml
on:
  push:
    branches: [main]
    paths:
      - "app/**"
      - "requirements.txt"
  pull_request:
    branches: [main]
  workflow_dispatch:   # a "Run workflow" button
```

</div>
<div>

<v-clicks>

- **`push`** — a commit is pushed (to any branch, or the ones listed)
- **`pull_request`** — a PR is opened or updated; checks the merge result
- **`workflow_dispatch`** — run it by hand from the Actions tab
- **`branches:`** — only for these branches
- **`paths:`** — only if these files changed (docs-only change → no run)
- Also: `schedule:` (cron), `release:`, `workflow_run:` …

</v-clicks>

</div>
</div>

---
---

# Runners, jobs and steps

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

<v-clicks>

- A **runner** is the machine a job runs on. `ubuntu-latest` is a fresh
  GitHub-hosted VM — created for the job, **thrown away after**.
- Also `windows-latest`, `macos-latest`, or **self-hosted** runners (your
  own servers).
- **Jobs run in parallel** by default, each on its own runner — they
  don't share files.
- **Steps run in order**, in the same job, on the same machine — they
  share the workspace.

</v-clicks>

</div>
<div v-click>

```text
workflow  CI
├── job: lint   (runner 1)
│   ├── step: checkout
│   ├── step: setup-python
│   └── step: ruff check .
└── job: test   (runner 2, in parallel)
    ├── step: checkout
    ├── step: setup-python
    ├── step: pip install …
    └── step: pytest
```

</div>
</div>

---
---

# `uses:` — actions from the marketplace

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```yaml
steps:
  - uses: actions/checkout@v4      # clone the repo
  - uses: actions/setup-python@v5  # install Python
    with:
      python-version: "3.12"
  - uses: actions/setup-node@v4    # install Node
    with:
      node-version: 20
```

</div>
<div>

<v-clicks>

- An **action** is a reusable step someone published: `owner/repo@version`.
- `with:` passes its inputs.
- **The runner starts empty** — without `actions/checkout`, your code
  isn't even there.
- **Pin a version** (`@v4`): `@main` can change under you tomorrow.
- Third-party actions run with your repo's permissions — prefer official
  (`actions/…`) or well-known ones.

</v-clicks>

</div>
</div>

---
---

# Variables and `${{ }}` expressions

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```yaml
env:
  APP_ENV: ci          # whole workflow

jobs:
  test:
    runs-on: ubuntu-latest
    env:
      LOG_LEVEL: debug # this job
    steps:
      - run: echo "Testing $APP_ENV on ${{ runner.os }}"
      - run: echo "Commit ${{ github.sha }}"
      - if: github.ref == 'refs/heads/main'
        run: echo "only on main"
```

</div>
<div>

<v-clicks>

- **`env:`** sets environment variables — at workflow, job or step level;
  read them in shell as `$NAME`.
- **`${{ … }}`** is evaluated by GitHub **before** the step runs:
  contexts like `github.sha`, `github.ref`, `runner.os`, `secrets.X`,
  `matrix.X`.
- **`if:`** runs a step or job only when the expression is true.
- Shell `$VAR` vs expression `${{ }}`: the first is read on the runner,
  the second is pasted into the YAML first.

</v-clicks>

</div>
</div>

---
layout: center
class: text-center
---

# Quick check

<div class="text-xl mt-4 max-w-2xl mx-auto text-left">

A job has `run: pytest` as its first step, and fails with
"no tests ran" / "file not found". The tests are in the repo. What's missing?

</div>

<div v-click class="mt-8 text-lg opacity-70">

**`- uses: actions/checkout@v4`** — the runner starts empty; nothing is
cloned until you check it out.

</div>

---
layout: section
transition: slide-left
---

# Block 3
## Secrets and permissions

---
---

# Secrets: `secrets.X`

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```yaml
steps:
  - name: Log in to the registry
    run: |
      echo "$REGISTRY_TOKEN" |
        podman login quay.io -u "$REGISTRY_USER" \
          --password-stdin
    env:
      REGISTRY_USER: ${{ secrets.REGISTRY_USER }}
      REGISTRY_TOKEN: ${{ secrets.REGISTRY_TOKEN }}
```

</div>
<div>

<v-clicks>

- Stored in **Settings → Secrets and variables → Actions**, encrypted;
  never in the repo.
- Read with `${{ secrets.NAME }}` — pass them in through `env:`, not
  pasted into the command line.
- GitHub **masks** known secret values in logs as `***` — but don't
  `echo` them, base64 them, or write them to files you upload.
- Workflows from **forks** don't get your secrets (so a stranger's PR
  can't steal them).
- This is where last week's vault password goes in real life.

</v-clicks>

</div>
</div>

---
---

# `GITHUB_TOKEN` and `permissions:`

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```yaml
# default for the whole workflow
permissions:
  contents: read

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:          # only this job:
      contents: write     #   tags, releases
      packages: write     #   GitHub Packages
    steps:
      - uses: actions/checkout@v4
      - run: gh release create v1.0 --generate-notes
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

</div>
<div>

<v-clicks>

- Every run gets an automatic, short-lived **`GITHUB_TOKEN`** — no setup.
- It can only do what **`permissions:`** allows, and only in this repo.
- **Least privilege:** `contents: read` by default; give `write` only to
  the job that needs it.
- The token expires when the job ends.

</v-clicks>

</div>
</div>

---
layout: section
transition: slide-left
---

# Block 4
## Bigger pipelines

---
---

# Job order: `needs:`

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    steps: [ … ]

  test:
    needs: lint            # wait for lint
    runs-on: ubuntu-latest
    steps: [ … ]

  build:
    needs: [lint, test]    # wait for both
    runs-on: ubuntu-latest
    steps: [ … ]
```

</div>
<div>

<v-clicks>

- Without `needs:`, jobs start **in parallel**.
- `needs: lint` — start only after `lint` **succeeded**; if it failed,
  this job is **skipped**.
- Chain them into a pipeline: **lint → test → build → deploy**.
- Cheap, fast checks first: no point building an image for code that
  doesn't even lint.

</v-clicks>

</div>
</div>

---
---

# Matrix builds

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```yaml
jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, windows-latest]
        python-version: ["3.11", "3.12", "3.13"]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}
      - run: pip install -r requirements.txt
      - run: pytest
```

</div>
<div>

<v-clicks>

- One job definition, **many runs**: every combination — here 2 × 3 = **6
  jobs**, in parallel.
- Read the current values with `${{ matrix.<name> }}`.
- This is the scenario's fix: test on **3.11 and 3.12**, not just your
  laptop's version.
- `fail-fast: false` — let the others finish when one fails, so you see
  *all* the broken combinations.

</v-clicks>

</div>
</div>

---
---

# Caching

<div class="grid grid-cols-[3fr_2fr] gap-6 text-xs">
<div>

```yaml
# The easy way: setup-python caches pip for you
- uses: actions/setup-python@v5
  with:
    python-version: "3.12"
    cache: pip   # keyed on requirements*.txt

# The general way
- uses: actions/cache@v4
  with:
    path: ~/.cache/pip
    key: pip-${{ runner.os }}-${{ hashFiles('requirements.txt') }}
    restore-keys: pip-${{ runner.os }}-
```

</div>
<div>

<v-clicks>

- Every runner starts empty → `pip install` downloads everything, every
  time.
- A **cache** saves a directory after the job and restores it next time.
- The **key** decides when it's reused: `hashFiles('requirements.txt')`
  changes when the dependencies change → a fresh cache.
- Cache **dependencies**, never build results you need to trust.

</v-clicks>

</div>
</div>

---
---

# Artifacts

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: pip install -r requirements.txt
      - run: pytest --junitxml=report.xml
      - uses: actions/upload-artifact@v4
        if: always()             # even if tests failed
        with:
          name: test-report
          path: report.xml
```

</div>
<div>

<v-clicks>

- Jobs don't share files — and the runner is deleted afterwards.
- An **artifact** is a file the run keeps: test reports, coverage, a built
  binary. Download it from the run's page.
- `actions/download-artifact@v4` gets it in a **later job** (`needs:`).
- `if: always()` — upload the report especially when tests **fail**:
  that's when you need it.
- Cache = speed (may be missing). Artifact = output (kept on purpose).

</v-clicks>

</div>
</div>

---
layout: center
class: text-center
---

# Quick check

<div class="text-xl mt-4 max-w-2xl mx-auto text-left">

`test` has `strategy.matrix.python-version: ["3.11", "3.12"]` and
`build` has `needs: test`. The 3.11 run fails, 3.12 passes. What happens
to `build`?

</div>

<div v-click class="mt-8 text-lg opacity-70">

**It's skipped.** `needs: test` waits for *every* matrix run, and one of
them failed.

</div>

---
layout: section
transition: slide-left
---

# Block 5
## Status checks — and how your autograder works

---
---

# Status checks and branch protection

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

<v-clicks>

- Every job reports a **status check** on the commit: ✓, ✗, or pending.
- On a PR, the checks show above the merge button.
- **Branch protection** (Settings → Branches) can make checks
  **required**: no merge into `main` until they're green.
- Also: no force-push, no deleting the branch, reviews required.
- Result: a broken change **can't** reach `main` — the scenario's Friday
  merge would have been blocked.

</v-clicks>

</div>
<div v-click>

```text
Pull request #42  Add /health endpoint

  ✓ CI / lint (pull_request)
  ✓ CI / test (3.11)
  ✗ CI / test (3.12)        ← required
  ─────────────────────────────────
  Merging is blocked
  Required statuses must pass.
```

</div>
</div>

---
---

# You've been using this all term

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

<v-clicks>

- Every practice repo has **`.github/workflows/classroom.yml`**.
- `on: push` → on every push a fresh runner checks out your commit and
  runs the grading checks.
- Its result is a **status check** on your commit — that's the ✓ / ✗ on
  GitHub.
- Maru receives a webhook when the run completes, reads the score, and
  shows it on your practice page.
- Your branch has protection: no force-push, no deletion — history can't
  be rewritten to fake a run.

</v-clicks>

</div>
<div v-click>

**Why editing `classroom.yml` voids the attempt**

The workflow decides your score. If a run's `classroom.yml` differs from
the template's, Maru doesn't count that run — and your practice page
says so.

<div class="mt-4 opacity-70">
Your own workflows (like today's <code>ci.yml</code>) live next to it.
Add as many as you like — just leave the grader alone.
</div>

</div>
</div>

---
layout: center
---

# Worked example

<div class="text-lg opacity-80">
A Python app's pipeline: <b>lint → test (two Python versions) → build the
container image</b> — with caching and a test report.
</div>

---
---

# The app

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```text
hello-api/
├── .github/workflows/ci.yml
├── app/
│   ├── __init__.py
│   └── main.py          ← a tiny Flask app
├── tests/
│   └── test_main.py
├── requirements.txt
├── requirements-dev.txt ← pytest, ruff
└── Containerfile        ← from module 1
```

</div>
<div>

```dockerfile
# Containerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app/ app/
USER 1001
EXPOSE 8080
CMD ["python", "-m", "app.main"]
```

<div class="opacity-70 mt-2">
Non-root, small base, dependencies before code — the module 1 habits.
</div>

</div>
</div>

---
---

# ci.yml — lint and test

<div class="grid grid-cols-2 gap-6 text-xs">
<div>

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
permissions:
  contents: read

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
          cache: pip
      - run: pip install -r requirements-dev.txt
      - run: ruff check .
```

</div>
<div>

```yaml
  test:
    needs: lint
    runs-on: ubuntu-latest
    strategy:
      matrix:
        py: ["3.11", "3.12"]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.py }}
          cache: pip
      - run: >-
          pip install -r requirements.txt
          -r requirements-dev.txt
      - run: pytest --junitxml=report.xml
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: report-${{ matrix.py }}
          path: report.xml
```

</div>
</div>

---
---

# ci.yml — build the image

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```yaml
  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build the image
        run: podman build -t hello-api:$GITHUB_SHA .
      - name: Smoke test
        run: |
          podman run -d --name api \
            -p 8080:8080 hello-api:$GITHUB_SHA
          sleep 3
          curl --fail localhost:8080/health
```

</div>
<div>

<v-clicks>

- Runs only after **lint and both tests** passed.
- Podman is already on `ubuntu-latest` — the same commands as in weeks 3–6.
- Tag with the **commit SHA** (`$GITHUB_SHA`, set on every runner): every
  image traces back to its commit.
- A **smoke test**: start it, hit `/health`, `--fail` turns an HTTP error
  into a red step.
- Next week: pushing the image to a registry with secrets, and more
  testing.

</v-clicks>

</div>
</div>

---
---

# Watching it run

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```text
CI  ·  push to main  ·  a1b2c3d

  ✓ lint               18s
  ✓ test (3.11)        41s
  ✓ test (3.12)        39s
  ✓ build             1m 12s

  Artifacts
    test-report-3.11
    test-report-3.12
```

</div>
<div>

<v-clicks>

- **Actions** tab → the run → each job → each step's log.
- A red step: open it, read the **last lines** of its log first.
- **Re-run failed jobs** after fixing a flaky network step — not after
  fixing code (push the fix instead).
- Run it by hand? Add `workflow_dispatch:`.
- Test a workflow change on a **branch** with a PR before it reaches
  `main`.

</v-clicks>

</div>
</div>

---
layout: section
transition: slide-left
---

# Block 6
## Common mistakes

---
---

# When it doesn't work — the workflow

| Symptom | Likely cause |
|---|---|
| The workflow never runs | File not in `.github/workflows/`, wrong extension, or `on:` doesn't match (other branch, `paths:` filter) |
| "Invalid workflow file" | YAML indentation — or `steps` not a list (`- uses:` / `- run:`) |
| `No such file or directory` in a step | Missing `actions/checkout` — the runner starts empty |
| `pytest: command not found` | Dependencies not installed in **this** job — jobs don't share anything |
| Passes locally, fails in CI | A package installed globally on your laptop but missing from `requirements*.txt` |
| A job is "skipped" | Something in its `needs:` failed — or its `if:` was false |

---
---

# When it doesn't work — secrets, cache, artifacts

| Symptom | Likely cause |
|---|---|
| The secret is empty | Wrong name, set in another repo — or the run comes from a **fork** |
| `Resource not accessible by integration` | `GITHUB_TOKEN` lacks a permission — add it under `permissions:` |
| The cache is never used | The key changes every run (e.g. contains `github.sha`) |
| Old dependencies after updating `requirements.txt` | The cache key doesn't include `hashFiles('requirements.txt')` |
| Test report missing when tests fail | `upload-artifact` without `if: always()` |
| Practice score "doesn't count" | `classroom.yml` was edited — restore it from the template |

---
---

# Self-check

<v-clicks>

- What's the difference between continuous delivery and continuous deployment? <span v-click class="opacity-60">(delivery: release-ready, a human ships to production; deployment: green → production automatically)</span>
- Where must a workflow file be? <span v-click class="opacity-60">(`.github/workflows/`, a `.yml` / `.yaml` file)</span>
- `uses:` vs `run:`? <span v-click class="opacity-60">(`uses:` runs a published action; `run:` runs a shell command)</span>
- Two jobs without `needs:` — in what order do they run? <span v-click class="opacity-60">(in parallel, each on its own runner)</span>
- Where does a registry password go? <span v-click class="opacity-60">(a repository secret, read as `${{ secrets.NAME }}` through `env:` — never in the repo, never echoed)</span>
- Why `if: always()` on an artifact upload? <span v-click class="opacity-60">(so the test report is kept even when tests fail)</span>

</v-clicks>

---
layout: section
transition: slide-left
---

# Block 7
## Today's practice

---
---

# Practice 11 — Your first pipeline

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

A small Python app, without CI. Copy the skeleton **`ci.yml.example`** to **`.github/workflows/ci.yml`** and fill it in:

1. triggers on **push** and **pull_request**
2. a **lint** job (`ruff check .`)
3. a **test** job with `needs: lint`, running `pytest` on a **Python
   version matrix**
4. **pip caching** via `actions/setup-python`
5. the test report uploaded as an **artifact**

</div>
<div>

```bash
git checkout -b ci
mkdir -p .github/workflows
cp ci.yml.example .github/workflows/ci.yml
$EDITOR .github/workflows/ci.yml
git add .github/workflows/ci.yml
git commit -m "Add CI"
git push -u origin ci
# then open a PR to see the checks
```

<div v-click class="mt-4 opacity-70">
Same flow as always: accept "Practice 11" on Maru, work in your repo,
push. Graded automatically on every push — by <code>classroom.yml</code>,
which you <b>don't</b> edit.
</div>

</div>
</div>

---
---

# Lab 03 — your CI/CD pipeline

<v-clicks>

- **Lab 03 (15 points)** is graded **on GitHub**, autograded like the
  practices — no Red Hat Academy this time.
- It builds directly on today: a full pipeline for an app — lint, test,
  build an image — then next week's topics (registries, secrets,
  scanning).
- **Due week 13** (Wed, Nov 25), the end of the CI/CD module.
- Today's practice is a small version of it: get the `ci.yml` habits
  right now.

</v-clicks>

---
---

# By the end of this lesson, you should be able to

<v-clicks>

- [ ] Explain CI, continuous delivery and continuous deployment — and why small, checked batches beat big merges
- [ ] Write a workflow in `.github/workflows/` with the right `on:` triggers
- [ ] Use jobs, runners and steps; `uses:` actions and `run:` commands
- [ ] Use `env:`, `${{ }}` expressions, `secrets.X` and least-privilege `permissions:`
- [ ] Chain jobs with `needs:`, test on a matrix, cache dependencies, keep artifacts
- [ ] Explain how status checks and branch protection guard `main` — and your autograder

</v-clicks>

---
layout: default
---

# Before next lecture

- [ ] Finish **Practice 11** if you didn't wrap it up in session — same
      Maru flow as always
- [ ] Open the **Actions** tab of your Practice 11 repo and read one full
      run log, step by step
- [ ] Skim the GitHub docs page *"Workflow syntax for GitHub Actions"* —
      keep it open while you write YAML

<div class="mt-8 text-sm opacity-60">
Lab 03 is due in two weeks — the pipeline you write today is its first
half.
</div>

---
layout: end
---

# Next lecture

Building & testing pipelines — registries, secrets in practice, tests that
catch real bugs.
