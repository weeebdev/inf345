# Lab design — DevOps I

## How this maps to the course decisions

Two different kinds of labs live here, and they work completely
differently:

| Type | Where the work happens | What's graded |
|---|---|---|
| **RHA labs** (Containers, Automation) | Entirely on Red Hat Academy's own cloud lab environment (DO188, RH294) — rha.ole.redhat.com | The instructor assigns the grade directly from RHA lab completion. There is nothing to submit in this repo — each lab's README just points you to the RHA lab and explains what it's grading. |
| **GitHub-native labs** (CI/CD, Capstone) | Your own private repo, made by **Accept** on Maru | A real, autograded build-and-run check on every push — this *is* the grade, because there's no RHA equivalent to lean on |

## Lab list

1. **`01-containers-podman/`** — Containers module. Instructions-only —
   graded entirely from RHA **DO188**.
2. **`02-automation-ansible/`** — Automation module. Instructions-only —
   graded entirely from RHA **RH294**.
3. **`03-cicd-pipeline/`** — CI/CD module, GitHub-native (RHA doesn't cover
   this topic at all): lint → test → build → Trivy scan → publish to GHCR on
   `v*` tags. Accept on Maru; due week 13 (Wed 25 Nov, 23:59).
4. **`04-capstone/`** — integration project, GitHub-native, spec only for
   now (fleshed out once the first three labs have run with a real cohort).

## GitHub Free tier minute budget

Only Labs 03 and Capstone run any CI at all, so the only minute cost is
theirs. We are **not** assuming GitHub Education/Team approval is in
place — every workflow is designed to run comfortably inside GitHub
Free's **2,000 shared Actions minutes/month**. Rules
applied to every GitHub-native workflow:

1. **`ubuntu-latest` only.** Windows runners cost 2x minutes, macOS costs
   10x. Never justified for these labs.
2. **`concurrency: cancel-in-progress: true`**, keyed on `github.ref`. A
   student iterating rapidly (normal while debugging) won't burn minutes
   on superseded runs — only the latest push actually finishes.
3. **`timeout-minutes` capped low** on every job (2-5 min) so a hung
   container or infinite loop can't quietly eat the org's monthly budget.
4. **Docker layer caching** (`actions/cache` keyed on the
   Dockerfile/lockfile hash) keeps repeat runs fast.

Rough semester estimate for a ~30-student cohort, assuming students push
~10-15 times per lab while iterating: roughly 1,500-1,800 minutes total
across Lab 03 + Capstone if run at ~1-2 min/run. That's tight if both land
in the same calendar month, so: apply for GitHub Education org benefits
anyway (free, just takes verification time) as headroom — but the design
doesn't *depend* on it.

## `_template/`

Starting point for a new GitHub-native lab (03/04-style, not 01/02-style).
Copy it, don't start from scratch — the autograder workflow already has
the minute-budget guardrails baked in.
