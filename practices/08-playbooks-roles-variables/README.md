# Practice 08 — Refactor into a Role

**Objective:** take last week's playbook and turn it into a reusable
**role** — variables as role defaults, tasks in the role, a **handler**
that runs only when something changed — and see variable precedence at
work: `group_vars` beat role defaults, `-e` beats everything. The skills
from today's lecture.

**Timebox:** ~30 min of actual work within today's session.

> **How to submit:** same as last week — on **Maru**. Click **Accept**
> on "Practice 08", accept the GitHub invite, clone your private repo
> under `weeebdev-edu`, and work there. Commit and push to `main` —
> GitHub Actions grades every push automatically, in about a minute.

## Setup

Same as Practice 07 — `pipx install ansible-core` (Linux/macOS/WSL), or
run it in a container:

```bash
docker run --rm -it -v "$PWD":/work -w /work python:3.12-slim \
  sh -c "pip install -q ansible-core && ansible-playbook site.yml"
```

## What's in your repo

```
ansible.cfg              done — inventory + roles_path = roles
inventory.ini            done — [web] localhost, local connection
site.yml                 TODO 1
group_vars/web.yml       TODO 8
roles/webapp/
  defaults/main.yml      TODO 2
  tasks/main.yml         TODO 3–6
  handlers/main.yml      TODO 7
  templates/app.conf.j2  done — same template as last week
  files/index.html       done
```

## Task

Do the `TODO`s in order:

1. **`site.yml`** — one play on `web` that applies the role:
   `roles: [webapp]`. No tasks in `site.yml` itself.
2. **`roles/webapp/defaults/main.yml`** — `app_root:
   /tmp/inf345-p08/app`, `app_name: inf345`, `app_port: 8080`,
   `app_env: production`. Defaults are the *weakest* variables — that's
   what lets users of the role override them.
3. – 6. **`roles/webapp/tasks/main.yml`** — last week's four tasks, now
   under `{{ app_root }}`: the directory (`file`, `0755`), `index.html`
   (`copy`, `0644`), `app.conf` (`template`) and the `APP_ENV` line in
   `.env` (`lineinfile`, `create: true`). Inside a role, `src: index.html`
   and `src: app.conf.j2` are enough — Ansible looks in the role's
   `files/` and `templates/`. The template task must **`notify: Reload
   app`**.
7. **`roles/webapp/handlers/main.yml`** — a handler named exactly
   `Reload app` that writes `{{ app_root }}/.reloaded` with the line
   `reloaded on port {{ app_port }}` (module `copy` with `content:`). A
   real app would restart a service here.
8. **`group_vars/web.yml`** — this environment runs the app on port
   **8081**: override `app_port`. Don't touch the role's default.

**Real modules only** — no `shell`, `command`, `raw` or `script`.

Test it locally before you push:

```bash
ansible-playbook site.yml --syntax-check
rm -rf /tmp/inf345-p08
ansible-playbook site.yml                    # changed=5, the handler runs
ansible-playbook site.yml                    # changed=0, no handler
cat /tmp/inf345-p08/app/app.conf             # port = 8081
cat /tmp/inf345-p08/app/.reloaded            # reloaded on port 8081
ansible-playbook site.yml -e app_port=9090   # app.conf changes -> handler runs
cat /tmp/inf345-p08/app/.reloaded            # reloaded on port 9090
```

## Definition of done

- [ ] `roles/webapp/` has `tasks/`, `defaults/`, `handlers/`, `templates/`, `files/`
- [ ] The defaults are exactly the four variables above
- [ ] `site.yml` only applies the role; `--syntax-check` passes
- [ ] The playbook creates the directory (0755), `index.html` (0644), `app.conf` and `.env`
- [ ] `app.conf` says `port = 8081` — group_vars won over the default
- [ ] `-e app_port=9090` makes it `port = 9090`
- [ ] The handler runs when `app.conf` changes, and not on a run that changes nothing
- [ ] A second run reports `changed=0`
- [ ] No `shell` / `command` / `raw` / `script`
- [ ] Pushed to `main` before the session ends (this is also your attendance signal)

## Common mistakes

- **`app.conf` still says 8080.** You put the variables in
  `roles/webapp/vars/main.yml` — role *vars* are stronger than
  `group_vars`, so the override is ignored. Role variables meant to be
  overridden go in `defaults/`.
- **"the role 'webapp' was not found".** Run from the repo root, where
  `ansible.cfg` sets `roles_path = roles`.
- **"Could not find or access 'roles/webapp/files/index.html'".** Inside
  a role, write `src: index.html`, not a path.
- **The handler never runs.** The `notify:` text must match the handler's
  `name:` exactly — `Reload app`. And it runs at the *end* of the play,
  not right after the task.
- **The handler runs every time.** Something keeps reporting "changed" —
  a task that isn't idempotent. Fix that, and the handler stops too.

## Grading

Real autograding — GitHub Actions installs Ansible, runs your playbook
against the runner itself, and checks what it did, out of 100 points:

| Check | Points |
|---|---|
| Role structure and defaults | 10 |
| `site.yml` applies the role; `--syntax-check` passes | 10 |
| Playbook runs: directory, `index.html`, `.env` right | 15 |
| `app.conf` rendered; `group_vars` beat the default (8081) | 15 |
| `-e app_port=9090` beats everything | 10 |
| Handler runs on change, and only then | 15 |
| Idempotent: second run `changed=0` | 15 |
| Only real modules | 10 |

Check the **Actions** tab in your repo for the run, or the workflow run's
**Summary** for the exact score. Workflow: `.github/workflows/classroom.yml`
(in your repo, not this one).

This score is this session's grade within the **Weekly practice sessions**
category — 1 point per practice, your best 10 count (see `SYLLABUS.md`).

## Connection to Lab 02

Lab 02 is Red Hat Academy **RH294**, due **Wed, Nov 4**. Its chapters on
variables, handlers and roles are exactly today's material.
