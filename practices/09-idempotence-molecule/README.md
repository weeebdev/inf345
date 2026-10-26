# Practice 09 — Make It Idempotent, Test It with Molecule

**Objective:** take a `webapp` role that *works* but isn't idempotent —
every run reports "changed", `.env` grows a line, the secret key changes,
`--check` mode breaks — and fix it: real modules where one exists,
`creates:` / `changed_when:` / `check_mode:` where a command is unavoidable.
Then finish a **Molecule** scenario that proves it: converge, run again and
expect no changes, verify the result. The skills from today's lecture.

**Timebox:** ~30 min of actual work within today's session.

> **How to submit:** same as last week — on **Maru**. Click **Accept**
> on "Practice 09", accept the GitHub invite, clone your private repo
> under `weeebdev-edu`, and work there. Commit and push to `main` —
> GitHub Actions grades every push automatically, in about a minute.

## Setup

Ansible as before, plus Molecule:

```bash
pipx install ansible-core
pipx install molecule                  # brings its own Ansible for its runs
```

No Ansible on your machine (e.g. Windows without WSL)? Run it in a container:

```bash
docker run --rm -it -v "$PWD":/work -w /work python:3.12-slim \
  sh -c "pip install -q ansible-core molecule && ansible-playbook site.yml && molecule test"
```

Molecule here uses the **default driver** against `localhost` — no
containers to start, the scenario tests the role on the machine you run it
on (the same way the grader does on GitHub's runner).

## What's in your repo

```
ansible.cfg              done
inventory.ini            done — [web] localhost, local connection
site.yml                 done — applies the webapp role
group_vars/web.yml       done — app_port: 8081
roles/webapp/
  defaults/main.yml      done — app_root /tmp/inf345-p09/app, port 8080, …
  tasks/main.yml         TODO 1–5 — works, but not idempotent
  handlers/main.yml      done — "Reload app"
  templates/app.conf.j2  done
  files/index.html       done
molecule/default/
  molecule.yml           done — default driver, localhost
  converge.yml           TODO 6
  verify.yml             TODO 7–8
```

## Task

Run it twice first and watch what's wrong:

```bash
rm -rf /tmp/inf345-p09
ansible-playbook site.yml                 # changed=…
ansible-playbook site.yml                 # still changed — that's the problem
cat /tmp/inf345-p09/app/.env              # APP_ENV=production … twice
ansible-playbook site.yml --check --diff  # fails
```

Then do the `TODO`s in order:

1. **App directory** — `command: mkdir -p` → the `file` module,
   `state: directory`, mode `0755`.
2. **Home page** — `shell: cp … && chmod …` → the `copy` module
   (`src: index.html`, mode `0644`).
3. **`APP_ENV` in `.env`** — `echo … >>` appends on *every* run. Use
   `lineinfile` (`create: true`, mode `0644`): the line, exactly once.
4. **Secret key** — no module generates a random key, so the `shell` task
   stays. But it must run **once**: add `creates:` (under `args:`). A new
   key on every run would log everyone out.
5. **Checksum** — the `command` only *reads*, yet reports "changed" every
   run: add `changed_when: false`. In `--check` mode Ansible skips
   commands, so the next task has nothing to print and fails: add
   `check_mode: false` (safe — it only reads).
6. **`molecule/default/converge.yml`** — a play on `hosts: all` that
   applies the `webapp` role.
7. – 8. **`molecule/default/verify.yml`** — `stat` + `assert`: the
   directory is `0755`, `index.html` is `0644`; `slurp` + `assert`:
   `app.conf` has `port = 8080` (the role default — Molecule doesn't load
   `group_vars`), `.env` has `APP_ENV=production` **exactly once**. A check
   that can't fail isn't a check — the grader breaks your deployment on
   purpose and expects `verify` to notice.

**The rule this week:** `shell` / `command` only with `creates:`,
`removes:` or `changed_when:` — and never for something a real module does.

Test it locally before you push:

```bash
rm -rf /tmp/inf345-p09
ansible-playbook site.yml                   # changed=6, the handler runs
ansible-playbook site.yml                   # changed=0
ansible-playbook site.yml --check --diff    # no failures, changed=0
grep -c APP_ENV /tmp/inf345-p09/app/.env    # 1
rm -rf /tmp/inf345-p09 && molecule test     # syntax → converge → idempotence → verify
```

## Definition of done

- [ ] A second `ansible-playbook site.yml` reports `changed=0`
- [ ] `.env` has `APP_ENV=production` exactly once, however many runs
- [ ] The secret key is generated once and stays the same
- [ ] `--check --diff` after a run: no failures, `changed=0`
- [ ] The directory, `index.html` and `.env` use `file`, `copy`, `lineinfile`
- [ ] Every `shell` / `command` left has `creates:` / `removes:` / `changed_when:`
- [ ] `molecule test` passes — including its idempotence step
- [ ] `verify.yml` fails if the port, a file mode or the `.env` line is wrong
- [ ] Pushed to `main` before the session ends (this is also your attendance signal)

## Common mistakes

- **Still `changed=1` on the second run.** Look at *which* task: the
  `TASK [...]` line right above `changed:` in the output. A `command` that
  only reads needs `changed_when: false`.
- **The secret key is still regenerated.** `creates:` goes under `args:`
  (or under the module with the free-form command), and must be the
  file the command writes: `{{ app_root }}/secret.key`.
- **`--check` fails with "'dict object' has no attribute 'stdout'".**
  The checksum command was skipped in check mode — `check_mode: false` on
  that task.
- **`molecule test`: "the role 'webapp' was not found".** Run it from the
  repo root; `molecule.yml` points `ANSIBLE_ROLES_PATH` at `../../roles`.
- **Verify passes but the grader says it caught nothing.** Your asserts
  check only that files *exist*. Check the mode, the port, and that the
  `.env` line appears once.
- **"Idempotence test failed".** Molecule ran converge twice and the
  second run changed something — the same bug as above, caught by the test.

## Grading

Real autograding — GitHub Actions installs Ansible and Molecule, runs
your playbook and your Molecule scenario on the runner itself, and checks
what they did, out of 100 points:

| Check | Points |
|---|---|
| `--syntax-check` passes; the Molecule scenario applies the role | 10 |
| Playbook runs: directory, `index.html`, `app.conf`, `.env`, `secret.key` right | 15 |
| Idempotent: second run `changed=0`, one `.env` line, the same key | 20 |
| `--check --diff` after a run: no failures, `changed=0` | 15 |
| Real modules where one exists; commands only with a guard | 10 |
| `molecule test` passes (converge, idempotence, verify) | 15 |
| `verify.yml` catches a broken port, file mode and `.env` | 15 |

Check the **Actions** tab in your repo for the run, or the workflow run's
**Summary** for the exact score. Workflow: `.github/workflows/classroom.yml`
(in your repo, not this one).

This score is this session's grade within the **Weekly practice sessions**
category — 1 point per practice, your best 10 count (see `SYLLABUS.md`).

## Connection to Lab 02

Lab 02 is Red Hat Academy **RH294**, due **Wed, Nov 4**. Its chapters on
writing idempotent tasks and checking playbooks before running them
(`--check`, `--syntax-check`) are exactly today's material.
