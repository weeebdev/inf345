---
theme: seriph
title: "INF345 — Lecture 10: Ansible in Production Patterns"
info: |
  INF345 — Fundamentals of DevOps
  Lecture 10 of 15
background: /cover-bg.svg
transition: fade
mdc: true
download: true
---

# INF 345 — Fundamentals of DevOps

## Lecture 10: Ansible in Production Patterns

<div class="pt-8 opacity-70">
Adil Akhmetov · Lesson 10
</div>

---
layout: default
---

# Recap — Lesson 9 (Idempotence & Molecule)

<v-clicks>

- The second run of your playbook says `changed=2`. What does that tell you? <span v-click class="opacity-60">(two tasks aren't idempotent — a re-run should report `changed=0`)</span>
- `command: cat app.conf` only reads. What does it need? <span v-click class="opacity-60">(`changed_when: false` — and `check_mode: false` so it also runs in `--check`)</span>
- Which flag previews a run without changing anything — and shows the lines? <span v-click class="opacity-60">(`--check --diff`)</span>
- Which `molecule test` step catches `echo "x" >> file`? <span v-click class="opacity-60">(`idempotence` — the second converge reports `changed`)</span>

</v-clicks>

---
---

# Today's agenda

<v-clicks>

- [ ] One playbook, many environments: inventories for staging and production
- [ ] Variable precedence, again — now per environment
- [ ] Secrets with Ansible Vault, and `no_log`
- [ ] Tags: run only part of a playbook
- [ ] Safe changes: `block` / `rescue` / `always` and rollback
- [ ] Rolling updates: `serial`, `max_fail_percentage`, `--limit`
- [ ] Dependencies (`requirements.yml`) and `ansible-lint` in CI
- [ ] Module wrap-up: automation, weeks 7–10 — and **Lab 02 (due today)**
- [ ] Straight into today's practice

</v-clicks>

---
layout: center
class: text-center
---

# The scenario

<div class="text-lg text-left mt-4 max-w-2xl mx-auto">

Your `webapp` role is idempotent and tested. Now the team wants it on
**staging** and **production** — different ports, a database password that
must not leak, and a config change on a Friday that must not take the site
down if it's wrong.

</div>

<div v-click class="mt-8 text-xl font-bold">
Today: the same role, shipped to two environments — with secrets kept
secret, and a way back when a change goes wrong.
</div>

---
layout: section
transition: slide-left
---

# Block 1
## One playbook, many environments

---
---

# Inventories per environment

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```text
.
├── ansible.cfg
├── site.yml                  ← one playbook
├── roles/webapp/             ← one role
└── inventories/
    ├── staging/
    │   ├── hosts
    │   └── group_vars/
    │       └── web.yml       ← staging values
    └── production/
        ├── hosts
        └── group_vars/
            └── web.yml       ← production values
```

</div>
<div>

<v-clicks>

- **Same code, different data.** The playbook and role never say "staging"
  or "production" — the inventory does.
- Each environment is its own directory: its hosts **and** its variables.
- `group_vars/` next to an inventory file is loaded automatically for that
  inventory.
- You choose the environment with `-i`:

```bash
ansible-playbook -i inventories/staging    site.yml
ansible-playbook -i inventories/production site.yml
```

</v-clicks>

</div>
</div>

---
---

# Same role, different values

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

`inventories/staging/group_vars/web.yml`

```yaml
app_env: staging
app_port: 8081
app_workers: 1
```

`inventories/production/group_vars/web.yml`

```yaml
app_env: production
app_port: 80
app_workers: 4
```

</div>
<div>

<v-clicks>

- Both inventories have a `web` group, so the play `hosts: web` works with
  either one.
- Only the **differences** go here. Everything both share stays in the role's
  `defaults/main.yml` — e.g. `app_root: /tmp/inf345-p10/{{ app_env }}`.
- A typo in production values is a production incident — that's why
  staging exists: **same playbook, run there first**.
- Never point one inventory at the other's hosts. Keep them apart, so
  `-i inventories/staging` can't reach production.

</v-clicks>

</div>
</div>

---
---

# Precedence, applied to environments

<div class="grid grid-cols-2 gap-6 text-sm">
<div class="text-xs">
<div>

From weakest to strongest (the parts you use):

| # | Where | Use it for |
|---|---|---|
| 1 | role `defaults/` | safe defaults |
| 2 | inv. `group_vars/all` | the whole environment |
| 3 | inv. `group_vars/web` | this env's `web` servers |
| 4 | inv. `host_vars/<host>` | one special machine |
| 5 | play `vars:` | the play itself |
| 6 | role `vars/` | constants |
| 7 | `-e` extra vars | one-off — always win |

</div>
</div>
<div>

<v-clicks>

- Environment values belong in **inventory `group_vars`** (2–3): they beat
  role defaults, so each environment can override them.
- Putting `app_port` in role `vars/` (6) **silently ignores** both
  environments — the same bug as in lecture 8.
- `-e app_port=9090` for a quick test is fine; for a permanent difference,
  write it into the inventory.
- `ansible-inventory -i inventories/staging --host localhost` shows the
  variables a host ends up with.

</v-clicks>

</div>
</div>

---
layout: center
class: text-center
---

# Quick check

<div class="text-xl mt-4 max-w-2xl mx-auto text-left">

The role default is `app_port: 8000`. `inventories/staging/group_vars/web.yml`
says `8081`. You run `ansible-playbook -i inventories/staging site.yml -e app_port=9090`.
Which port does staging get?

</div>

<div v-click class="mt-8 text-lg opacity-70">

**9090** — extra vars beat everything. Without `-e`, it's **8081**: inventory
`group_vars` beat role defaults.

</div>

---
layout: section
transition: slide-left
---

# Block 2
## Secrets: Ansible Vault

---
---

# A password in git is a leaked password

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```yaml
# inventories/production/group_vars/web.yml
app_env: production
db_password: S3cr3t-prod-2026      # ← committed, pushed, forever
```

</div>
<div>

<v-clicks>

- Git keeps **every version**. Deleting the line later doesn't remove it
  from history — anyone with the repo has it.
- Same lesson as lecture 6 with images: **secrets don't go into the
  artifact**, and a repo is an artifact.
- But Ansible *needs* the password to write the app's config.
- **Ansible Vault**: encrypt the secret in the repo; decrypt it only at run
  time, with a password that lives somewhere else.

</v-clicks>

</div>
</div>

---
---

# `ansible-vault`: the commands

```bash {none|1|2|3|4|5|6|all}
ansible-vault create   inventories/production/group_vars/web/vault.yml   # new encrypted file
ansible-vault encrypt  secrets.yml        # encrypt an existing plain file in place
ansible-vault view     secrets.yml        # print it decrypted
ansible-vault edit     secrets.yml        # decrypt → $EDITOR → re-encrypt
ansible-vault decrypt  secrets.yml        # back to plain text (careful!)
ansible-vault rekey    secrets.yml        # change the vault password
```

<div class="grid grid-cols-2 gap-6 text-sm mt-4">
<div v-click>

An encrypted file is plain text — safe to commit, useless to read:

```text
$ANSIBLE_VAULT;1.1;AES256
6338363536643634633537353864363966...
3465303862373231623562363565653638...
```

</div>
<div v-click>

- AES-256; the header says it's a vault file.
- `git diff` shows only noise — a reason to keep secrets in **their own**
  small file.
- Ansible decrypts it in memory when it runs; the file on disk stays
  encrypted.

</div>
</div>

---
---

# Giving Ansible the vault password

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```bash
# ask for it
ansible-playbook -i inventories/production site.yml --ask-vault-pass

# read it from a file
ansible-playbook -i inventories/production site.yml \
  --vault-password-file ~/.vault_pass_prod
```

```ini
# ansible.cfg — so you don't type it each time
[defaults]
vault_password_file = ~/.vault_pass_prod
```

</div>
<div>

<v-clicks>

- No password → `Attempting to decrypt but no vault secrets found`.
- Wrong password → `Decryption failed`. Nothing runs.
- The password file lives **outside the repo** (or in `.gitignore`), with
  mode `0600`. In CI it comes from the CI system's secrets store.
- **Vault IDs** label passwords, one per environment:
  `--vault-id staging@.vault_pass_staging --vault-id prod@prompt` — then
  staging people can't decrypt production.

</v-clicks>

</div>
</div>

---
---

# The `vault_` indirection pattern

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```text
inventories/production/group_vars/web/
├── vars.yml      ← plain, readable
└── vault.yml     ← encrypted
```

```yaml
# vault.yml (shown decrypted)
vault_db_password: S3cr3t-prod-2026
```

```yaml
# vars.yml
app_env: production
db_password: "{{ vault_db_password }}"
```

</div>
<div>

<v-clicks>

- `group_vars/web/` can be a **directory**: every file in it is loaded.
- The secret lives in `vault.yml` under a `vault_` name.
- `vars.yml` maps the real name to it — so `grep db_password` still finds
  where it's defined, without decrypting anything.
- The role just uses `{{ db_password }}`; it doesn't know or care that it
  was encrypted.

</v-clicks>

</div>
</div>

---
---

# One secret, inline: `encrypt_string`

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```bash
ansible-vault encrypt_string 'S3cr3t-prod-2026' --name 'db_password'
```

```yaml
db_password: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  62313365396662343061393464336163383764316462...
  3166303163643730...
```

</div>
<div>

<v-clicks>

- Encrypts **one value**, to paste into an otherwise plain YAML file.
- Handy for a single secret; for several, a `vault.yml` file is easier to
  manage (`ansible-vault edit` works on whole files only).
- Either way: the decrypted value exists **only in memory** during the run.

</v-clicks>

</div>
</div>

---
---

# `no_log`: don't print the secret either

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```yaml
- name: App secrets file
  ansible.builtin.template:
    src: env.j2
    dest: "{{ app_root }}/.env"
    mode: "0600"
  no_log: true
```

```text
TASK [webapp : App secrets file] ******
changed: [localhost] => {"censored": "the output has been
hidden due to the fact that 'no_log: true' was specified
for this result"}
```

</div>
<div>

<v-clicks>

- Vault protects the secret **in git**. But `-v` output, `debug:` and error
  messages can print it into CI logs.
- `no_log: true` hides a task's result — use it on tasks that handle
  secrets.
- The file it writes still contains the secret — so `mode: "0600"`, readable
  only by its owner.
- Never `debug: var=db_password` "just to check".

</v-clicks>

</div>
</div>

---
layout: center
class: text-center
---

# Quick check

<div class="text-xl mt-4 max-w-2xl mx-auto text-left">

A teammate ran `ansible-vault decrypt vault.yml` to fix a typo, then
committed and pushed. What happened — and what now?

</div>

<div v-click class="mt-8 text-lg opacity-70">

The secret is now **in git history in plain text** — treat it as leaked.
**Change the password** itself (re-encrypting doesn't help: history keeps the
plain copy), then use `ansible-vault edit` next time.

</div>

---
layout: section
transition: slide-left
---

# Block 3
## Tags: run only part of a playbook

---
---

# Tags

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```yaml
- name: Site config
  ansible.builtin.template:
    src: app.conf.j2
    dest: "{{ app_root }}/app.conf"
  tags: [config]

- name: Deploy the release
  ansible.builtin.copy:
    src: release/
    dest: "{{ app_root }}/current/"
  tags: [deploy]
```

</div>
<div>

```bash {none|1|2|3|4|all}
ansible-playbook site.yml --list-tags        # what tags exist?
ansible-playbook site.yml --tags config      # only config tasks
ansible-playbook site.yml --skip-tags deploy # everything but deploy
ansible-playbook site.yml --tags config,deploy
```

<v-clicks>

- A config tweak doesn't need a full deploy — `--tags config` runs only
  those tasks.
- Tags on a role in `roles:` apply to **every task** in it:
  `- { role: webapp, tags: [webapp] }`.
- Untagged tasks don't run when you ask for `--tags`.

</v-clicks>

</div>
</div>

---
---

# Special tags: `always` and `never`

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```yaml
- name: Check the inventory is sane
  ansible.builtin.assert:
    that: app_env in ['staging', 'production']
  tags: [always]

- name: Wipe the app's data
  ansible.builtin.file:
    path: "{{ app_root }}/data"
    state: absent
  tags: [never, reset]
```

</div>
<div>

<v-clicks>

- `always` — runs even with `--tags config` (unless you
  `--skip-tags always`). Good for safety checks and facts.
- `never` — skipped **unless** you ask for one of its other tags:
  `--tags reset`. Good for dangerous, rarely-needed tasks.
- Tags are a convenience, not a security boundary: anyone can run the
  playbook without `--tags`.

</v-clicks>

</div>
</div>

---
layout: section
transition: slide-left
---

# Block 4
## Safe changes: block, rescue, rollback

---
---

# `block` / `rescue` / `always`

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```yaml {all|1-6|7-10|11-14|all}
- name: Change the config safely
  block:
    - name: New config
      ansible.builtin.template: …
    - name: Health check
      ansible.builtin.uri: …
  rescue:
    - name: Put the old config back
      ansible.builtin.copy: …
    - ansible.builtin.fail: …
  always:
    - name: Record the attempt
      ansible.builtin.lineinfile: …
```

</div>
<div>

<v-clicks>

- `block` — a group of tasks (and a place for shared `when:`, `tags:`,
  `become:`).
- `rescue` — runs **only if a task in the block failed**. Like `try` /
  `catch`.
- `always` — runs either way. Like `finally`.
- After a rescue, the recap counts the host as `rescued=1`, not failed.
  If the change **didn't** happen, end the rescue with `fail:` so the run
  is honestly red.
- Inside `rescue`: `ansible_failed_task.name` and `ansible_failed_result`.

</v-clicks>

</div>
</div>

---
---

# A deploy with a way back

<div class="grid grid-cols-[3fr_2fr] gap-6 text-sm">
<div class="text-xs">

```yaml {all|2-5|6-11|12-13|14-18|all}
- name: Deploy config with rollback
  vars: { conf: "{{ app_root }}/app.conf" }
  block:
    - name: New config
      ansible.builtin.template: { src: app.conf.j2, dest: "{{ conf }}" }
    - name: Health check — the app answers
      ansible.builtin.uri:
        url: "http://localhost:{{ app_port }}/health"
      register: health
      until: health.status == 200
      retries: 5
    - name: Keep it as the last good config
      ansible.builtin.copy: { src: "{{ conf }}", dest: "{{ conf }}.good", remote_src: true }
  rescue:
    - name: Restore the last good config
      ansible.builtin.copy: { src: "{{ conf }}.good", dest: "{{ conf }}", remote_src: true }
    - ansible.builtin.fail:
        msg: "{{ ansible_failed_task.name }} failed — rolled back."
```

</div>
<div>

<v-clicks>

- Write the config, then **check** it.
- Only a config that **passed** is saved as `.good`.
- Check fails → `rescue` puts `.good` back; `fail:` turns the run red.
- Re-run with no change: every task `ok` — still `changed=0`.

</v-clicks>

</div>
</div>

---
---

# Health checks without a web server

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```yaml
- name: Health check — the config is valid
  ansible.builtin.command: >-
    grep -Eq '^port = [0-9]+$' {{ app_root }}/app.conf
  changed_when: false
```

```yaml
- name: Health check — custom rule
  ansible.builtin.command: /opt/app/bin/app --check-config
  register: chk
  changed_when: false
  failed_when: "'OK' not in chk.stdout"
```

</div>
<div>

<v-clicks>

- A health check is **any task that fails when the result is bad**: `uri`,
  a command with a non-zero exit code, or `failed_when:` on its output.
- It's read-only → `changed_when: false` (lecture 9).
- Even better: **don't write a bad file at all**. `template` and `copy`
  have `validate:` — the new file is checked *before* it replaces the old:

```yaml
validate: "nginx -t -c %s"
```

</v-clicks>

</div>
</div>

---
layout: center
class: text-center
---

# Quick check

<div class="text-xl mt-4 max-w-2xl mx-auto text-left">

The health check fails, `rescue` restores `app.conf.good`, and the recap
says `failed=0 rescued=1`. Your CI shows green. What's missing?

</div>

<div v-click class="mt-8 text-lg opacity-70">

A **`fail:`** at the end of `rescue`. The rollback worked, but the
deploy didn't — the run should say so, so someone looks.

</div>

---
layout: section
transition: slide-left
---

# Block 5
## Running at scale

---
---

# Rolling updates: `serial`

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```yaml
- name: Update the web tier
  hosts: web
  serial: 2                    # 2 hosts at a time
  max_fail_percentage: 25      # stop if >25% of a batch fails
  roles:
    - webapp
```

```yaml
serial: "25%"                  # a quarter of the hosts at a time
serial: [1, 5, "100%"]         # one canary, then 5, then the rest
```

</div>
<div>

<v-clicks>

- By default Ansible runs each task on **all hosts at once** — a bad change
  hits every server together.
- `serial:` runs the **whole play** on a batch, then the next batch. The
  rest keep serving users.
- `[1, 5, "100%"]` — a **canary**: if the first host breaks, the others
  are never touched.
- `max_fail_percentage` — stop the rollout when **more than** that share of
  a batch fails. (`any_errors_fatal: true` stops at the first failure.)
- In today's practice there's one host — `serial` has nothing to split,
  but the pattern is the same.

</v-clicks>

</div>
</div>

---
---

# Before production: look first

```bash {none|1|2|3|4|all}
ansible-playbook -i inventories/production site.yml --list-hosts       # who would it touch?
ansible-playbook -i inventories/production site.yml --check --diff     # what would change?
ansible-playbook -i inventories/production site.yml --limit web1       # one host first
ansible-playbook -i inventories/production site.yml                    # then everyone
```

<v-clicks>

- `--list-hosts` — no surprises about **where** it runs.
- `--check --diff` — no surprises about **what** changes (lecture 9 —
  works because your tasks are idempotent and check-mode friendly).
- `--limit` — narrow the run to a host or group: a manual canary.
- Staging first, always. Production gets the **same playbook** that
  already worked on staging.

</v-clicks>

---
---

# Dependencies: `requirements.yml`

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```yaml
# requirements.yml
collections:
  - name: community.general
    version: ">=9.0.0,<10.0.0"
  - name: ansible.posix
roles:
  - name: geerlingguy.nginx
    version: "3.2.0"
```

```bash
ansible-galaxy install -r requirements.yml
```

</div>
<div>

<v-clicks>

- **Collections** bundle modules, plugins and roles:
  `community.general.ufw`, `ansible.posix.sysctl`… That's what the
  `ansible.builtin.` prefix is about — FQCNs name the collection.
- Pin versions, like base images in lecture 4: a new upstream release
  shouldn't change your production run.
- The file lives in git; CI and teammates install exactly the same versions.

</v-clicks>

</div>
</div>

---
---

# `ansible-lint` in CI — coming next

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```yaml
# .github/workflows/ansible.yml (preview)
on: [push, pull_request]
jobs:
  lint-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: pip install ansible-core ansible-lint molecule
      - run: ansible-lint
      - run: molecule test
```

</div>
<div>

<v-clicks>

- Everything from weeks 7–10 can run **on every push**: lint, syntax check,
  Molecule's idempotence and verify.
- The vault password comes from the CI's **secrets**, never from the repo.
- That's the next module: **CI/CD with GitHub Actions** (weeks 11–13) —
  you've been using it all along through the autograder.

</v-clicks>

</div>
</div>

---
layout: center
class: text-center
---

# Worked example

<div class="text-lg mt-4 max-w-2xl mx-auto text-left">

The **`webapp`** role from lectures 8–9 — now shipped to **staging** and
**production**, with an encrypted database password and a config change that
rolls itself back.

</div>

---
---

# The layout

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```text
inventories/
├── staging/
│   ├── hosts
│   └── group_vars/web/
│       ├── vars.yml
│       └── vault.yml        ← encrypted
└── production/
    ├── hosts
    └── group_vars/web/
        ├── vars.yml
        └── vault.yml        ← encrypted
roles/webapp/
site.yml
ansible.cfg
```

</div>
<div>

```ini
# inventories/staging/hosts
[web]
localhost ansible_connection=local
```

```yaml
# inventories/staging/group_vars/web/vars.yml
app_env: staging
app_port: 8081
db_password: "{{ vault_db_password }}"
```

```bash
ansible-vault create \
  inventories/staging/group_vars/web/vault.yml
# vault_db_password: staging-only-pass
```

</div>
</div>

---
---

# The role's tasks

<div class="text-xs">

```yaml {all|1-7|9-24|all}
- name: Secrets in .env
  ansible.builtin.template:
    src: env.j2                       # DB_PASSWORD={{ db_password }}
    dest: "{{ app_root }}/.env"
    mode: "0600"
  no_log: true
  tags: [config]

- name: Config, rolled back if the health check fails
  tags: [config]
  vars: { conf: "{{ app_root }}/app.conf" }
  block:
    - ansible.builtin.template: { src: app.conf.j2, dest: "{{ conf }}", mode: "0644" }
    - name: Health check
      ansible.builtin.command: grep -Eq '^port = [0-9]+$' {{ conf }}
      changed_when: false
    - name: Keep it as the last good config
      ansible.builtin.copy: { src: "{{ conf }}", dest: "{{ conf }}.good", remote_src: true }
  rescue:
    - name: Restore the last good config
      ansible.builtin.copy: { src: "{{ conf }}.good", dest: "{{ conf }}", remote_src: true }
    - ansible.builtin.fail: { msg: "Bad config — rolled back to the last good one." }
```

</div>

---
---

# Run it

```bash {none|1|2|3|4|5|all}
ansible-playbook -i inventories/staging site.yml            # staging first
ansible-playbook -i inventories/staging site.yml            # changed=0 — still idempotent?
ansible-playbook -i inventories/production site.yml --check --diff
ansible-playbook -i inventories/production site.yml         # then production
ansible-playbook -i inventories/production site.yml --tags config -e app_port=abc
```

<v-clicks>

- Two directories, two configs: `/tmp/inf345-p10/staging/app.conf` says
  `port = 8081`, `/tmp/inf345-p10/production/app.conf` says `port = 80`.
- `.env` has the right password for each, mode `0600` — and the password
  appears nowhere in the output or in git.
- The last run writes `port = abc`, the health check fails, `rescue` puts
  `port = 80` back — and the run ends **failed**, as it should.
- `app.conf.good` is only written after a check **passed** — so a bad
  config can never become the "good" one.

</v-clicks>

---
layout: section
transition: slide-left
---

# Block 6
## Common mistakes

---
---

# When it doesn't work — environments & vault

| Symptom | Likely cause |
|---|---|
| Staging and production get the same values | Environment values in role `vars/` (or in a shared `group_vars/` next to `site.yml`) instead of each inventory's `group_vars/` |
| `'db_password' is undefined` | `vault.yml` not in `group_vars/web/` — or the group name doesn't match the inventory |
| `Attempting to decrypt but no vault secrets found` | No `--vault-password-file` / `--ask-vault-pass`, and none in `ansible.cfg` |
| `Decryption failed` | Wrong vault password — or a file encrypted with another one |
| The password shows up in CI logs | A `debug:` on the variable, or `-v` without `no_log: true` |
| The plain secret is in git history | Someone committed it before encrypting — **rotate it** |

---
---

# When it doesn't work — tags & rollback

| Symptom | Likely cause |
|---|---|
| `--tags config` does nothing | The tasks have no tags — or a different spelling (`--list-tags`) |
| A setup task is skipped under `--tags` | Untagged — tag it, or `always` |
| `rescue` never runs | The check can't fail (`failed_when: false`, `ignore_errors`) |
| `app.conf.good` not found | The very first config was bad — nothing good to go back to |
| Green run, but it was rolled back | No `fail:` at the end of `rescue` |
| A re-run reports `changed` | Backup copied before the check — save it after a passed one |

---
---

# Self-check

<v-clicks>

- How do you run the same playbook against production instead of staging? <span v-click class="opacity-60">(`-i inventories/production` — same playbook, other inventory)</span>
- Which command creates a new encrypted variables file? <span v-click class="opacity-60">(`ansible-vault create <file>`)</span>
- Why `vault_db_password` in `vault.yml` and `db_password: "{{ vault_db_password }}"` in `vars.yml`? <span v-click class="opacity-60">(you can find where a variable comes from without decrypting anything)</span>
- A task is tagged `[never, reset]`. When does it run? <span v-click class="opacity-60">(only with `--tags reset` — or `--tags never`)</span>
- What does `serial: [1, 5, "100%"]` do? <span v-click class="opacity-60">(one canary host, then 5, then all the rest)</span>

</v-clicks>

---
layout: section
transition: slide-left
---

# Block 7
## Module wrap-up: automation

---
---

# Weeks 7–10 in one slide

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

| Week | You learned to… |
|---|---|
| 7 | describe machines in an inventory; ad-hoc commands; your first playbook |
| 8 | structure it: roles, variables, templates, handlers |
| 9 | make it idempotent — and prove it with Molecule |
| 10 | ship it: environments, secrets, tags, safe rollouts |

</div>
<div v-click>

The whole module, as one sentence:

<div class="mt-4 text-base italic">
"Describe the desired state of your servers in a tested, idempotent role;
keep each environment's values and encrypted secrets in its own inventory;
and roll changes out a few hosts at a time, with a way back."
</div>

</div>
</div>

---
---

# Lab 02 — Red Hat Academy RH294 — due today

<v-clicks>

- **Due today, Wednesday, Nov 4, 23:59 (Almaty).** Graded from your RH294
  completion on Red Hat Academy: completion × 15 points, frozen at the
  deadline.
- Maru syncs your RHA progress every hour — check the **Red Hat labs**
  section on your dashboard: your progress, the deadline, and **How to get
  in** if you still can't log in.
- Registered with your **SDU email** and your **student ID** as the
  username? Otherwise your progress can't reach your grade.
- RH294's chapters on inventories, variables and secrets, task control and
  roles are exactly weeks 7–10.
- Next module (week 11+): **CI/CD with GitHub Actions** — Lab 03 is graded
  on GitHub, no RHA.

</v-clicks>

---
layout: section
transition: slide-left
---

# Block 8
## Today's practice

---
---

# Practice 10 — Ship it to two environments

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

The `webapp` role, ready for **staging** and **production**. You:

1. fill in `inventories/staging` and `inventories/production` — same
   playbook, different values; files under `/tmp/inf345-p10/<env>/`
2. put the database password in a **vault-encrypted** file and use it,
   with `no_log`
3. tag the tasks `config` and `deploy`
4. wrap the config change in `block` / `rescue`: a failed health check
   rolls back to the previous config

</div>
<div>

```bash
ansible-playbook -i inventories/staging site.yml
ansible-playbook -i inventories/production site.yml
ansible-playbook -i inventories/production site.yml   # changed=0
ansible-playbook -i inventories/staging site.yml --tags config
head -1 inventories/*/group_vars/web/vault.yml        # $ANSIBLE_VAULT;1.1;AES256
```

<div v-click class="mt-4 opacity-70">
Same flow as always: accept "Practice 10" on Maru, work in your repo,
push to <code>main</code>. Graded automatically on every push.
</div>

</div>
</div>

---
---

# About that `.vault_pass` in your repo

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

The template ships a **practice-only** `.vault_pass` with a fixed password,
so the autograder can decrypt your vault on GitHub. Encrypt your secret file
with it:

```bash
ansible-vault encrypt --vault-password-file .vault_pass \
  inventories/staging/group_vars/web/vault.yml
```

</div>
<div v-click>

<div class="text-base font-bold">This is for this practice only.</div>

In real life the vault password **never** goes into git:

- it lives outside the repo (`~/.vault_pass`, mode `0600`), or you type it
  (`--ask-vault-pass`);
- in CI it comes from the CI system's **secrets** (next module);
- one password per environment (vault IDs).

A committed vault password makes the encryption pointless.

</div>
</div>

---
---

# By the end of this lesson, you should be able to

<v-clicks>

- [ ] Run one playbook against separate staging and production inventories
- [ ] Put each environment's values where precedence lets them win
- [ ] Encrypt secrets with `ansible-vault` and keep them out of logs with `no_log`
- [ ] Run parts of a playbook with `--tags`, `--skip-tags`, `always` and `never`
- [ ] Write a `block` / `rescue` that rolls back a failed change — and still fails the run
- [ ] Explain `serial`, `max_fail_percentage` and `--limit` for safe rollouts

</v-clicks>

---
layout: default
---

# Before next lecture

- [ ] **Lab 02 (RHA RH294) is due tonight, Wed, Nov 4, 23:59** — check
      "Red Hat labs" in Maru
- [ ] Finish today's practice if you didn't wrap it up in session — same
      Maru flow as always
- [ ] Look at the **Actions** tab of any practice repo you've pushed: that
      workflow is next week's topic

<div class="mt-8 text-sm opacity-60">
That closes the automation module. Next: pipelines that build, test and
ship on every push.
</div>

---
layout: end
---

# Next lecture

CI/CD concepts & GitHub Actions basics — workflows, jobs, steps, and your
first pipeline.
