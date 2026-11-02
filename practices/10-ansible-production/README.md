# Practice 10 — Ship It to Two Environments

**Objective:** take last week's idempotent `webapp` role and make it
production-ready: one role, two inventories (**staging** and
**production**), the database password encrypted with **Ansible Vault**
and kept out of the logs, **tags** to run just the config or just the
deploy, and a **block / rescue** that rolls back a config that fails its
health check. The patterns from today's lecture.

**Timebox:** ~30–35 min of actual work within today's session.

> **How to submit:** same as last week — on **Maru**. Click **Accept**
> on "Practice 10", accept the GitHub invite, clone your private repo
> under `weeebdev-edu`, and work there. Commit and push to `main` —
> GitHub Actions grades every push automatically, in about a minute.

## Setup

Ansible as before (`ansible-vault` comes with it):

```bash
pipx install ansible-core
```

No Ansible on your machine (e.g. Windows without WSL)? Run it in a container:

```bash
docker run --rm -it -v "$PWD":/work -w /work python:3.12-slim \
  sh -c "pip install -q ansible-core && ansible-playbook site.yml"
```

Both inventories point at `localhost`, so you can try both environments on
your own machine: staging deploys to `/tmp/inf345-p10/staging`, production
to `/tmp/inf345-p10/production` (`app_root` is built from `app_env`).

## What's in your repo

```
ansible.cfg                       done — staging by default, vault_password_file = .vault_pass
.vault_pass                       done — the vault password (practice only!)
site.yml                          done — applies the webapp role
inventories/
  staging/hosts                   done — [web] localhost, local connection
  staging/group_vars/web/
    vars.yml                      done — app_env staging, port 8081, db_password → vault
    vault.yml                     TODO 2 — the secret, still in plaintext
  production/hosts                done
  production/group_vars/web/
    vars.yml                      TODO 1
    vault.yml                     TODO 2 — the secret, still in plaintext
roles/webapp/
  defaults/main.yml               done — app_root /tmp/inf345-p10/{{ app_env }}
  tasks/main.yml                  TODO 3–5
  handlers/main.yml               done — "Reload app"
  templates/app.conf.j2, env.j2   done
  files/index.html                done
  files/healthcheck.py            done — fails unless app.conf has a valid port
```

## Task

Run staging first and look at what's wrong:

```bash
rm -rf /tmp/inf345-p10
ansible-playbook site.yml --diff                    # the password, right there in the output
ls -l /tmp/inf345-p10/staging/.env                  # -rw-r--r-- : anyone can read it
ansible-playbook -i inventories/production site.yml # fails: production has no variables yet
ansible-playbook site.yml -e app_port=notaport      # fails — and leaves the bad config behind
```

Then do the `TODO`s in order:

1. **Production variables** — `inventories/production/group_vars/web/vars.yml`:
   `app_env: production`, `app_port: 80`, and
   `db_password: "{{ vault_db_password }}"` — the same shape as staging's.
2. **Encrypt both secrets** —
   `ansible-vault encrypt inventories/staging/group_vars/web/vault.yml`, and
   the same for production. Read them back with `ansible-vault view …`,
   change them with `ansible-vault edit …`. The `vault_` prefix + a plain
   variable pointing at it (`db_password`) is the usual pattern: `grep`
   still finds where the secret is used, without decrypting anything.
3. **Keep the secret secret** — the `.env` task: mode `0600` and
   `no_log: true` (otherwise `--diff` prints the password). Delete the
   "Debug the connection settings" leftover.
4. **Tags** — the directory: `[config, deploy]`; `.env` and the config
   block: `config`; the home page: `deploy`. Then
   `--tags config` touches only the config, `--tags deploy` only the release.
5. **Block / rescue** — put "App config" and "Health check" in a `block:`
   (tagged `config`). At its end, copy `app.conf` to `app.conf.good`
   (`remote_src: true`) — the last config that passed. In `rescue:`, copy
   `app.conf.good` back over `app.conf` and stop with `fail:` and a clear
   message. A broken deploy should fail **loudly** — and leave the server
   on its last good config.

**About `.vault_pass`:** it is committed here **for this practice only**,
so the grader can decrypt your files. In a real project the vault password
lives in a password manager or the CI's secret store — never in git.

Test it locally before you push:

```bash
rm -rf /tmp/inf345-p10
ansible-playbook site.yml                              # staging
ansible-playbook site.yml                              # changed=0
ansible-playbook -i inventories/production site.yml    # production, port 80
head -1 inventories/*/group_vars/web/vault.yml         # $ANSIBLE_VAULT;1.1;AES256
ansible-playbook site.yml --diff -v | grep -c Hx7q2    # 0 — or your own password
rm -rf /tmp/inf345-p10 && ansible-playbook site.yml --tags config
ls /tmp/inf345-p10/staging                             # app.conf .env — no index.html
ansible-playbook site.yml -e app_port=notaport         # fails: "rolled back"
grep port /tmp/inf345-p10/staging/app.conf             # port = 8081
```

## Definition of done

- [ ] Production deploys to `/tmp/inf345-p10/production` with `port = 80`
- [ ] Both `vault.yml` files are encrypted and decrypt with `.vault_pass`
- [ ] `.env` has the right `DB_PASSWORD` for each environment, mode `0600`
- [ ] `--diff -v` never prints the password
- [ ] `--tags config` writes `app.conf` and `.env`, not `index.html`
- [ ] `-e app_port=notaport` fails, and `app.conf` still has the good port
- [ ] A second run is `changed=0` in both environments
- [ ] Pushed to `main` before the session ends (this is also your attendance signal)

## Common mistakes

- **"Attempting to decrypt but no vault secrets found".** Run from the
  repo root, so `ansible.cfg` (and its `vault_password_file`) is used. On
  WSL under `/mnt/c/…` Ansible ignores an `ansible.cfg` in a
  world-writable directory — work in your Linux home instead.
- **"'vault_db_password' is undefined" for production.** The file must be
  `inventories/production/group_vars/web/vault.yml` — a folder named
  after the group, with both `vars.yml` and `vault.yml` in it.
- **The password still shows up.** `no_log: true` goes on the task, at the
  same level as `name:` — not inside the module's arguments. And the debug
  leftover prints it too: delete that task.
- **`--tags config` does nothing.** The directory task needs the tag too,
  or there is no directory to write into. A tag on a `block:` applies to
  every task inside it.
- **The rollback restores nothing.** `app.conf.good` is written at the
  *end* of the block, after the health check passed — not before the
  template, or you'd save the bad config as "good".
- **Second run `changed=1`.** Copy `app.conf.good` with `copy` +
  `remote_src: true` (it compares checksums), not with a `command: cp`.

## Grading

Real autograding — GitHub Actions installs Ansible, runs your playbook
against the runner itself with each inventory, and checks what it did,
out of 100 points:

| Check | Points |
|---|---|
| `--syntax-check` passes for both inventories; `ansible.cfg` finds `.vault_pass` | 10 |
| Staging: `/tmp/inf345-p10/staging`, `port = 8081`, `index.html`, `.env` | 15 |
| Production: `/tmp/inf345-p10/production`, `port = 80`, `index.html`, `.env` | 15 |
| Both `vault.yml` encrypted; the secret reaches `.env`, mode `0600` | 15 |
| The password never appears in `--diff -v` output | 10 |
| `--tags config` only the config; `--tags deploy` only the home page | 10 |
| `-e app_port=notaport` fails and the last good `app.conf` is restored | 15 |
| Idempotent: second run `changed=0` in both environments | 10 |

Check the **Actions** tab in your repo for the run, or the workflow run's
**Summary** for the exact score. Workflow: `.github/workflows/classroom.yml`
(in your repo, not this one).

This score is this session's grade within the **Weekly practice sessions**
category — 1 point per practice, your best 10 count (see `SYLLABUS.md`).

## Connection to Lab 02

Lab 02 is Red Hat Academy **RH294**, due **Wed, Nov 4, 23:59**. Its
chapters on Ansible Vault, managing inventories and handling task failure
(blocks, rescue) are exactly today's material.
