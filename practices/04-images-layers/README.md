# Practice 04 — Multi-Stage Builds

**Objective:** write a multi-stage Containerfile that separates
build-time tooling from the runtime image — the skill from today's
lecture — and ship a final image under 50 MB.

**Timebox:** ~30 min of actual work within today's session.

> **How to submit:** this practice runs on **Maru**, not the fork+PR flow
> from earlier practices. Go to the Maru link posted in the course
> channel, sign in with your invited Google account, link your GitHub
> account (once, the first time), then click **Accept** on "Practice 04."
> Maru creates your own **private** repo under `weeebdev-edu` and invites
> you as a collaborator — accept the GitHub invite (check your email, or
> your GitHub notifications), clone it, and work there. Nobody else can
> see your repo. There's no PR: just commit and push to `main` —
> GitHub Actions grades every push automatically, in about a minute.

## Task

Your repo has one folder: `app/` — a tiny Go HTTP server (`main.go`) and
its `go.mod`, responding with exactly `INF345 Practice 04 OK` on port
`8080`. You did not write this app and don't need to touch it. Your job
is to containerize it properly — with a multi-stage build, not a
single-stage one.

Add a file named exactly `Containerfile` at the **root** of the repo
(not inside `app/`) that:

1. Uses a build stage — `FROM golang:1.23 AS builder` (or a similarly
   named stage) — that compiles the Go binary with `CGO_ENABLED=0` so
   it's static.
2. Uses a separate, minimal final stage (e.g. `alpine:3.20` or
   `scratch`).
3. Copies **only** the compiled binary from the build stage into the
   final stage via `COPY --from=builder ...` — nothing else from the
   builder.
4. `EXPOSE`s port `8080`.
5. Runs as a non-root `USER` before the final `CMD`.
6. `CMD`s the binary so it listens on `0.0.0.0:8080`.

This is the exact shape of the multi-stage Containerfile from today's
slides — same idea, applied to this app.

Test it locally before you push:

```bash
podman build -t practice04 .   # or: docker build -t practice04 .
podman run --rm -p 8080:8080 practice04
curl localhost:8080            # should print: INF345 Practice 04 OK
podman images practice04       # final image should be well under 50MB
```

## Definition of done

- [ ] `Containerfile` exists at the repo root
- [ ] It has a multi-stage structure: 2+ `FROM` instructions, a named
      build stage, and a `COPY --from=`
- [ ] It builds successfully
- [ ] The container runs and responds `INF345 Practice 04 OK` on `:8080`
- [ ] The final image is smaller than 50 MB
- [ ] The final image contains no Go toolchain (no `go` binary)
- [ ] It does **not** run as root
- [ ] Pushed to `main` before the session ends (this is also your
      attendance signal)

## Grading

Real autograding this time — GitHub Actions actually builds and runs
your container, out of 100 points total:

| Check | Points |
|---|---|
| Multi-stage structure (2+ `FROM`, a named stage, `COPY --from=`) | 20 |
| Image builds | 20 |
| Container runs and responds `INF345 Practice 04 OK` on `:8080` | 30 |
| Final image smaller than 50 MB | 20 |
| No Go toolchain (`go` binary) in the final image | 10 |

Check the **Actions** tab in your repo for the run, or the workflow
run's **Summary** for the exact score. Workflow:
`.github/workflows/classroom.yml` (in your repo, not this one).

This score is this session's grade within the **Weekly practice
sessions** category (10% of the final course grade, split evenly across
all ~14 practice sessions — see `SYLLABUS.md`), not 10% on its own.
