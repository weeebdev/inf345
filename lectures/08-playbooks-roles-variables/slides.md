---
theme: seriph
title: "INF345 — Lecture 8: Playbooks, Roles & Variables"
info: |
  INF345 — Fundamentals of DevOps
  Lecture 8 of 15
background: /cover-bg.svg
transition: fade
mdc: true
download: true
---

# INF 345 — Fundamentals of DevOps

## Lecture 8: Playbooks, Roles & Variables

<div class="pt-8 opacity-70">
Adil Akhmetov · Lesson 8
</div>

---
layout: default
---

# Recap — Lesson 7 (Ansible Basics)

<v-clicks>

- `ansible all -m ping` fails with an SSH error for `localhost`. Why? <span v-click class="opacity-60">(no `ansible_connection=local` — Ansible uses SSH for every host unless told otherwise)</span>
- The second run of a playbook still says `changed=1` on the same task. Why? <span v-click class="opacity-60">(a `shell`/`command` task — Ansible can't check its state, so it always reports "changed")</span>
- When does a handler run? <span v-click class="opacity-60">(once, at the end of the play, and only if a task that notifies it reported `changed`)</span>

</v-clicks>

---
---

# Today's agenda

<v-clicks>

- [ ] Playbooks in depth: several plays, `become`, tags
- [ ] Variables: every place they can live — and which one wins
- [ ] Facts, registered results, `when:` and loops
- [ ] Jinja2 templates and filters; handlers, revisited
- [ ] Roles: the standard way to package automation
- [ ] Worked example: last week's `site.yml` → a `webapp` role
- [ ] Straight into today's practice: refactor into a role

</v-clicks>

---
layout: center
class: text-center
---

# The scenario

<div class="text-lg text-left mt-4 max-w-2xl mx-auto">

Last week's `site.yml` worked. Now staging needs port 8081, production
port 80, and one server is on Rocky Linux instead of Ubuntu. A teammate
wants the same nginx setup for another project, so they copy your
playbook and start editing it. Three months later there are four
slightly different copies, and nobody knows which one is right.

</div>

<div v-click class="mt-8 text-xl font-bold">
Today: one piece of automation, reused everywhere, with the differences
kept in variables instead of in copies.
</div>

---
layout: section
transition: slide-left
---

# Block 1
## Playbooks in depth

---
---

# A playbook is a list of plays

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```yaml {all|1-8|10-17|19-24|all}
- name: Databases
  hosts: db
  become: true
  tasks:
    - name: PostgreSQL installed
      ansible.builtin.package:
        name: postgresql
        state: present

- name: Web servers
  hosts: web
  become: true
  tasks:
    - name: nginx installed
      ansible.builtin.package:
        name: nginx
        state: present

- name: Smoke test
  hosts: localhost
  tasks:
    - name: Site answers
      ansible.builtin.uri:
        url: http://web1.example.com/
```

</div>
<div>

<v-clicks>

- A **play** = which hosts + how (`become`, vars) + what (tasks, roles,
  handlers).
- Plays run **top to bottom**. Database first, then web, then a check.
- Inside a play, each task runs on **all** its hosts before the next task
  starts.
- One file, several groups of machines, one command:
  `ansible-playbook site.yml`.

</v-clicks>

</div>
</div>

---
---

# `become`: who runs the task

```yaml {all|3|6-9|11-14|16-19|all}
- name: Web servers
  hosts: web
  become: true                  # every task in this play runs with sudo

  tasks:
    - name: nginx installed     # needs root: inherits become: true
      ansible.builtin.package:
        name: nginx
        state: present

    - name: Check the app as a normal user
      ansible.builtin.command: whoami
      become: false             # task-level override wins over play-level
      changed_when: false

    - name: Create the app database
      community.postgresql.postgresql_db:
        name: inf345
      become_user: postgres     # sudo to another user, not root
```

<div v-click class="mt-2 text-sm">

`become` can be set on a play, a block, a task, or a role. If sudo asks for a
password, run with `-K` (`--ask-become-pass`).

</div>

---
---

# Tags: run only part of a playbook

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```yaml
- name: nginx installed
  ansible.builtin.package:
    name: nginx
    state: present
  tags: packages

- name: Site config
  ansible.builtin.template:
    src: app.conf.j2
    dest: /etc/nginx/conf.d/app.conf
  tags: config
```

</div>
<div>

```bash {none|1|2|3|all}
ansible-playbook site.yml --list-tags
ansible-playbook site.yml --tags config
ansible-playbook site.yml --skip-tags packages
```

<v-clicks>

- "I only changed the config — don't reinstall everything."
- Tasks without the tag are skipped. The special tag `always` runs even
  with `--tags`.
- Use them sparingly: a playbook must still work when run **in full**.

</v-clicks>

</div>
</div>

---
layout: section
transition: slide-left
---

# Block 2
## Variables: where they live, who wins

---
---

# Where a variable can live

| Where | Scope | Use it for |
|---|---|---|
| `roles/x/defaults/main.yml` | the role | defaults anyone can override |
| inventory `[web:vars]` | a group | quick tests — prefer `group_vars/` |
| `group_vars/web.yml` | hosts in `web` | per-group settings |
| `host_vars/web1.yml` | one host | the one machine that's different |
| play `vars:` / `vars_files:` | one play | values tied to this playbook |
| `roles/x/vars/main.yml` | the role | internal constants |
| `-e` / `--extra-vars` | everything | one-off overrides |


---
---

# `group_vars/` and `host_vars/`

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```text
project/
├── ansible.cfg
├── inventory.ini
├── site.yml
├── group_vars/
│   ├── all.yml          # every host
│   └── web.yml          # hosts in [web]
└── host_vars/
    └── web2.example.com.yml
```

```yaml
# group_vars/web.yml
app_port: 80
app_env: production
```

</div>
<div>

<v-clicks>

- Ansible loads these **automatically**: no `include`, no `vars_files`.
- They must sit **next to the inventory or next to the playbook**.
- File name = **group name** or **host name** exactly
  (`web.yml`, a directory `web/` works too).
- Plain YAML, no `---` needed. Keep the inventory file a list of hosts,
  and keep the values here.
- `all.yml` is the weakest group; a specific group (`web`) beats `all`.

</v-clicks>

</div>
</div>

---
---

# Precedence: who wins

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

From **weakest** (1) to **strongest** (8), simplified:

1. **Role defaults** — `defaults/main.yml`
2. Inventory group vars: `[web:vars]`, then `group_vars/all`, then `group_vars/web`
3. Inventory host vars, then `host_vars/<host>`
4. Facts gathered from the host
5. Play `vars:`, then `vars_files:`
6. **Role vars** — `vars/main.yml`
7. Task vars, `set_fact`, `register`
8. **Extra vars** — `-e` on the command line

</div>
<div>

<v-clicks>

- **Extra vars always win.** Nothing in a file can override `-e`.
- **Role defaults are the weakest.** Anything, anywhere, overrides them.
  That's exactly what you want for a tunable value.
- More specific beats more general: host beats group, `web` beats `all`.
- Role **vars** beat inventory — so `group_vars/` can't override them.
- The full list has 22 levels (in the Ansible docs). In practice: put
  each variable in **one** place.

</v-clicks>

</div>
</div>

---
---

# Precedence in action

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```yaml
# roles/webapp/defaults/main.yml
app_port: 8080
```

```yaml
# group_vars/web.yml        (web1 and web2 are in [web])
app_port: 80
```

```yaml
# host_vars/web2.example.com.yml
app_port: 8081
```

</div>
<div>

<v-clicks>

- `ansible-playbook site.yml` → web1 listens on **80**, web2 on **8081**.
  The default 8080 is used by nobody — both hosts override it.
- A new host `web3` with no host_vars → **80** (from the group).
- A host outside `web` that uses the role → **8080** (the default).
- `ansible-playbook site.yml -e app_port=9090` → **every host: 9090**.

</v-clicks>

</div>
</div>

---
layout: center
class: text-center
---

# Quick check

<div class="text-xl mt-4 max-w-2xl mx-auto text-left">

You put `app_port: 8080` in `roles/webapp/vars/main.yml` and
`app_port: 80` in `group_vars/web.yml`. Which port do the web servers get?

</div>

<div v-click class="mt-8 text-lg opacity-70">

**8080.** Role `vars/` beat inventory variables. Move it to
`defaults/main.yml` and the `group_vars` value (80) wins.

</div>

---
layout: section
transition: slide-left
---

# Block 3
## Facts, conditionals, loops

---
---

# Facts: what Ansible learns about each host

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```yaml
- name: Show what Ansible found
  ansible.builtin.debug:
    msg: >-
      {{ inventory_hostname }} runs
      {{ ansible_facts['distribution'] }}
      {{ ansible_facts['distribution_version'] }}
      ({{ ansible_facts['os_family'] }} family)
```

```text
ok: [web1] => {
    "msg": "web1 runs Ubuntu 24.04 (Debian family)"
}
```

```bash
ansible web1 -m ansible.builtin.setup     # all facts
```

</div>
<div>

<v-clicks>

- The **Gathering Facts** step at the start of every play runs the
  `setup` module and stores the results in `ansible_facts`.
- Useful ones: `os_family` (`Debian`, `RedHat`), `distribution`,
  `distribution_major_version`, `hostname`, `default_ipv4.address`,
  `memtotal_mb`, `processor_vcpus`.
- `inventory_hostname` is not a fact — it's the name from your inventory.
- Not using facts? `gather_facts: false` makes the play start faster.

</v-clicks>

</div>
</div>

---
---

# `when:` — run a task only if…

```yaml {all|1-5|7-11|5,11|all}
- name: nginx on Debian / Ubuntu
  ansible.builtin.apt:
    name: nginx
    state: present
  when: ansible_facts['os_family'] == 'Debian'

- name: nginx on RHEL / Rocky
  ansible.builtin.dnf:
    name: nginx
    state: present
  when: ansible_facts['os_family'] == 'RedHat'
```

<v-clicks>

- On an Ubuntu host the second task says `skipping: [web1]`.
- `when:` is **already** a Jinja2 expression — write the condition with no
  braces: `when: app_env == 'production'`, not `when: "{{ ... }}"`.
- A list under `when:` means **and**: every line must be true.

</v-clicks>

---
---

# `register:` — keep a task's result

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```yaml {all|1-4|6-8|10-15|all}
- name: Is there a maintenance flag?
  ansible.builtin.stat:
    path: /etc/maintenance
  register: maint

- name: Look at the result
  ansible.builtin.debug:
    var: maint.stat.exists

- name: Deploy the page
  ansible.builtin.copy:
    src: index.html
    dest: /var/www/inf345/index.html
    mode: "0644"
  when: not maint.stat.exists
```

</div>
<div>

<v-clicks>

- `register: maint` saves the module's JSON result in a variable for this
  host — the same JSON you see with `-v`.
- Every module returns different fields: `stat` gives `maint.stat.exists`,
  `command` gives `.stdout`, `.rc`; every result has `.changed`.
- Not sure what's inside? `debug: var: maint` and read it.
- A read-only `command` you only register? Add `changed_when: false` so it
  doesn't report "changed" every run.

</v-clicks>

</div>
</div>

---
---

# Loops: one task, many items

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```yaml {all|1-9|11-21|all}
- name: App directories
  ansible.builtin.file:
    path: "{{ app_root }}/{{ item }}"
    state: directory
    mode: "0755"
  loop:
    - static
    - logs
    - uploads

- name: App users
  ansible.builtin.user:
    name: "{{ item.name }}"
    groups: "{{ item.groups }}"
    append: true
  loop: "{{ app_users }}"

# group_vars/web.yml
# app_users:
#   - { name: deploy, groups: www-data }
#   - { name: ci,     groups: www-data }
```

</div>
<div>

<v-clicks>

- `loop:` takes a list; each element is `item` inside the task.
- Items can be dictionaries: `item.name`, `item.groups`.
- The list can come from a variable — so `group_vars` decides *how many*.
- Output shows each item: `changed: [web1] => (item=static)`.
- `when:` on a looped task is checked **per item**.
- Packages: pass the list to `name:` instead of looping — one install,
  much faster.

</v-clicks>

</div>
</div>

---
layout: center
class: text-center
---

# Quick check

<div class="text-xl mt-4 max-w-2xl mx-auto text-left">

A play has one task with `when: ansible_facts['os_family'] == 'RedHat'`,
and the play has `gather_facts: false`. What happens?

</div>

<div v-click class="mt-8 text-lg opacity-70">

It **fails**: `ansible_facts` was never collected, so `os_family` is
undefined. Conditions on facts need fact gathering on.

</div>

---
layout: section
transition: slide-left
---

# Block 4
## Templates, filters, handlers

---
---

# Jinja2 templates: more than `{{ var }}`

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

`templates/app.conf.j2`

```jinja
# {{ app_name | upper }} ({{ app_env }}) — managed by Ansible
server {
    listen {{ app_port }};
    server_name {{ server_names | join(' ') }};
    root {{ app_root }};
{% if app_env == 'production' %}
    server_tokens off;
{% endif %}
{% for path in blocked_paths %}
    location {{ path }} { deny all; }
{% endfor %}
}
```

</div>
<div>

<v-clicks>

- `{{ ... }}` prints a value. `{% ... %}` is logic: `if`, `for`.
- `{# ... #}` is a comment that never reaches the server.
- The same variables as everywhere else: role defaults, group_vars,
  facts, `-e`.
- Rendered **on the control node**, then copied — the server never needs
  Jinja2.
- A header like "managed by Ansible" warns people not to edit it by hand.

</v-clicks>

</div>
</div>

---
---

# Filters: transform a value with `|`

```jinja {all|1|2|3|4|5|all}
{{ app_env | default('development') }}        {# app_env not set   → development   #}
{{ app_name | upper }}                        {# app_name: inf345  → INF345        #}
{{ server_names | join(', ') }}               {# [a.kz, b.kz]      → a.kz, b.kz    #}
{{ server_names | length }}                   {# [a.kz, b.kz]      → 2             #}
{{ app_port | int + 1 }}                      {# app_port: "8080"  → 8081          #}
```

<v-clicks>

- Filters chain left to right: `{{ ['a', 'b'] | join('-') | upper }}` → `A-B`.
- Without `default`, an undefined variable **fails the task**:
  `'app_workers' is undefined`.
- In a role, prefer a real default in `defaults/main.yml` over
  `| default(...)` scattered through templates — one place to look.

</v-clicks>

---
---

# Handlers, revisited

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```yaml
tasks:
  - name: Site config
    ansible.builtin.template:
      src: app.conf.j2
      dest: /etc/nginx/conf.d/app.conf
    notify: Reload nginx

  - name: TLS certificate
    ansible.builtin.copy:
      src: app.crt
      dest: /etc/nginx/app.crt
    notify: Reload nginx

handlers:
  - name: Reload nginx
    ansible.builtin.service:
      name: nginx
      state: reloaded
```

</div>
<div>

<v-clicks>

- Both tasks changed → the handler runs **once**, not twice.
- Neither changed (`ok`) → the handler **doesn't run at all**.
- It runs after the play's tasks finish, and `notify:` matches the
  handler's `name` exactly.
- If a later task fails on that host, its pending handlers are skipped.
  Need it right now? `ansible.builtin.meta: flush_handlers`.

</v-clicks>

```text
RUNNING HANDLER [Reload nginx] ****
changed: [web2]       ← only web2's config changed
```

</div>
</div>

---
layout: section
transition: slide-left
---

# Block 5
## Roles

---
---

# Why roles

<v-clicks>

- A 200-line `site.yml` mixes **what** (a web app) with **where**
  (these hosts, these ports). You can't reuse half of it.
- A **role** packages one job — "set up the web app" — as a directory with
  a fixed layout: tasks, handlers, templates, files, defaults.
- The playbook shrinks to *which hosts get which roles*.
- Every host or environment changes the role's behaviour through
  **variables**, never by editing the role.
- Same idea as a function: a role is the body, its defaults are the
  parameters with default values.
- Shared roles and collections live on **Ansible Galaxy** — RH294 shows
  you how to install them.

</v-clicks>

---
---

# The role layout

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```text
$ ansible-galaxy role init --init-path roles webapp
- Role webapp was created successfully

roles/webapp/
├── defaults/main.yml   # default values — weakest
├── files/              # static files for copy
├── handlers/main.yml   # handlers
├── meta/main.yml       # author, platforms, dependencies
├── tasks/main.yml      # the entry point: task list
├── templates/          # .j2 files for template
├── tests/              # sample inventory + playbook
├── vars/main.yml       # internal constants — strong
└── README.md
```

</div>
<div>

<v-clicks>

- `ansible-galaxy init webapp` (short form) creates the same thing in the
  current directory.
- Ansible looks for `main.yml` in each folder — that's the role's
  entry point.
- Delete the folders you don't use. Only `tasks/` is really needed.
- Inside the role, `src:` paths are **relative to the role**:
  `copy` looks in `files/`, `template` looks in `templates/`.
- Ansible finds roles in a `roles/` directory **next to the playbook**.

</v-clicks>

</div>
</div>

---
---

# `defaults/` vs `vars/`

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

**`defaults/main.yml`** — the role's settings

```yaml
app_name: inf345
app_port: 8080
app_env: production
```

Weakest of all: group_vars, host_vars, play vars and `-e` override them.
This is the role's public interface.

</div>
<div>

**`vars/main.yml`** — the role's internals

```yaml
nginx_conf_dir: /etc/nginx/conf.d
```

Stronger than inventory: group_vars **can't** override them. Use it for
values the role relies on and users shouldn't touch.

</div>
</div>

<div v-click class="mt-6 p-4 rounded bg-blue-500/10 text-sm">
Rule of thumb: if someone might want to change it, it goes in
<code>defaults/</code>. When in doubt — <code>defaults/</code>.
</div>

---
---

# Using a role in a play

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

```yaml {all|4-5|7-14|all}
- name: Web servers
  hosts: web
  become: true
  roles:
    - webapp

- name: A second site, same role
  hosts: web
  become: true
  roles:
    - role: webapp
      vars:
        app_name: docs
        app_port: 8090
```

</div>
<div>

<v-clicks>

- `roles:` runs the role's `tasks/main.yml`, with its handlers, defaults
  and vars loaded.
- Pass values per use with `vars:` under the role (they beat
  `group_vars`).
- Order inside a play: `roles:` run **before** `tasks:`. You can have
  both.
- Need a role in the middle of a task list? `ansible.builtin.import_role`
  or `include_role` as a task.

</v-clicks>

</div>
</div>

---
layout: center
class: text-center
---

# Worked example

<div class="text-lg mt-4 max-w-2xl mx-auto text-left">

Take last week's `site.yml` — nginx serving one page, a templated
config, a handler — and turn it into a role called **`webapp`**.
Same result on the servers, but reusable and configurable.

</div>

---
---

# Before: everything in one file

```yaml {all|4-7|9-19|20-22|all}
- name: Web servers
  hosts: web
  become: true
  vars:
    app_name: inf345
    app_port: 8080
    app_root: /var/www/inf345
  tasks:
    - { name: nginx installed, ansible.builtin.package: { name: nginx, state: present } }
    - name: App directory
      ansible.builtin.file: { path: "{{ app_root }}", state: directory, mode: "0755" }
    - name: Home page
      ansible.builtin.copy: { src: files/index.html, dest: "{{ app_root }}/index.html", mode: "0644" }
    - name: Site config
      ansible.builtin.template:
        src: templates/app.conf.j2
        dest: /etc/nginx/conf.d/app.conf
        mode: "0644"
      notify: Reload nginx
  handlers:
    - name: Reload nginx
      ansible.builtin.service: { name: nginx, state: reloaded }
```

<div v-click class="text-sm mt-2">
Values, steps and handlers are all tangled together. Four parts → four role folders.
</div>

---
---

# After (1/3): defaults and tasks

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

`roles/webapp/defaults/main.yml`

```yaml
---
app_name: inf345
app_port: 8080
app_env: production
app_root: /var/www/inf345
server_names:
  - localhost
```

The `vars:` block moved here — now they're **defaults**, not fixed values.

</div>
<div>

`roles/webapp/tasks/main.yml`

```yaml
---
- name: nginx installed
  ansible.builtin.package:
    name: nginx
    state: present

- name: App directory
  ansible.builtin.file:
    path: "{{ app_root }}"
    state: directory
    mode: "0755"

- name: Home page
  ansible.builtin.copy:
    src: index.html        # → files/index.html
    dest: "{{ app_root }}/index.html"
    mode: "0644"
```

</div>
</div>

---
---

# After (2/3): template, config task, handler

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

`roles/webapp/templates/app.conf.j2`

```jinja
# {{ app_name | upper }} — managed by Ansible
server {
    listen {{ app_port }};
    server_name {{ server_names | join(' ') }};
    root {{ app_root }};
}
```

`roles/webapp/handlers/main.yml`

```yaml
---
- name: Reload nginx
  ansible.builtin.service:
    name: nginx
    state: reloaded
```

</div>
<div>

`roles/webapp/tasks/main.yml` (continued)

```yaml
- name: Site config
  ansible.builtin.template:
    src: app.conf.j2       # → templates/app.conf.j2
    dest: "/etc/nginx/conf.d/{{ app_name }}.conf"
    mode: "0644"
  notify: Reload nginx

- name: nginx running
  ansible.builtin.service:
    name: nginx
    state: started
    enabled: true
```

No `files/` or `templates/` prefix in `src:` — the role knows where to
look.

</div>
</div>

---
---

# After (3/3): the playbook and the override

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

`site.yml` — now 5 lines

```yaml
- name: Web servers
  hosts: web
  become: true
  roles:
    - webapp
```

`group_vars/web.yml` — this group's differences

```yaml
app_port: 80
server_names:
  - inf345.example.kz
  - www.inf345.example.kz
```

</div>
<div>

```bash {none|1|2|3|all}
ansible-playbook site.yml           # listen 80; both names
ansible-playbook site.yml           # changed=0, no reload
ansible-playbook site.yml -e app_port=9090   # one change → one reload
```

<v-clicks>

- The role wasn't edited — `group_vars` overrode two **defaults**.
- Second run: nothing changed, so the handler didn't run.
- Task names in the output now carry the role:
  `TASK [webapp : Site config]`.

</v-clicks>

</div>
</div>

---
layout: center
class: text-center
---

# Quick check

<div class="text-xl mt-4 max-w-2xl mx-auto text-left">

You ran the playbook, then edited only `files/index.html` in the role and
ran it again. Does nginx reload?

</div>

<div v-click class="mt-8 text-lg opacity-70">

**No.** The "Home page" task changed, but it doesn't notify the handler —
only "Site config" does, and the config didn't change. (nginx serves the
new page anyway: no reload needed for static files.)

</div>

---
layout: section
transition: slide-left
---

# Block 6
## Common mistakes

---
---

# When it doesn't work — variables

| Symptom | Likely cause |
|---|---|
| `group_vars` value ignored | It's set in the role's `vars/` (or with `-e`) — move it to `defaults/` |
| `group_vars/web.yml` never loaded | Not next to the inventory or playbook, or the file name isn't the group name |
| YAML error on a line starting with `{{` | Quote it: `path: "{{ app_root }}"` |
| Warning about templating in `when:` | `when:` takes a bare expression — drop the `{{ }}` |

---
---

# When it doesn't work — roles and handlers

| Symptom | Likely cause |
|---|---|
| `the role 'webapp' was not found` | No `roles/webapp/` next to `site.yml` |
| Template or file "not found" in a role | `src:` is relative to the role: `app.conf.j2`, not `templates/app.conf.j2` |
| `'app_port' is undefined` | Missing from `defaults/main.yml` |
| Handler never runs | Nothing changed, the `notify:` name doesn't match, or a later task failed |

---
---

# Self-check

<v-clicks>

- `defaults/` says `app_env: production`, `group_vars/web.yml` says `staging`, you run with `-e app_env=test`. Result? <span v-click class="opacity-60">(`test` — extra vars always win)</span>
- Your play notifies `Reload nginx` from three tasks; all three changed. How many reloads? <span v-click class="opacity-60">(one, after the tasks finish)</span>
- What does `{{ ['web1', 'web2'] | join(', ') | upper }}` print? <span v-click class="opacity-60">(`WEB1, WEB2`)</span>
- Where in a role do you put a value users of the role should be able to change? <span v-click class="opacity-60">(`defaults/main.yml`)</span>

</v-clicks>

---
layout: section
transition: slide-left
---

# Block 7
## Today's practice

---
---

# Practice 08 — Refactor into a role

<div class="grid grid-cols-2 gap-6 text-sm">
<div>

Last week's playbook, split into a role. The role skeleton, template
and page are given; you fill in:

1. `site.yml` — one play on `web`, just `roles: [webapp]`
2. `defaults/main.yml` — last week's values, as defaults
3. `tasks/main.yml` — last week's tasks, moved into the role
4. the template task **notifies** a handler
5. `handlers/main.yml` — the handler: runs only on change
6. `group_vars/web.yml` — override one default

</div>
<div>

```bash
ansible-playbook site.yml --syntax-check
ansible-playbook site.yml      # works, handler runs
ansible-playbook site.yml      # changed=0, no handler
ansible-playbook site.yml -e app_port=9090
```

<div v-click class="mt-4 opacity-70">
Same flow as last week: accept "Practice 08" on Maru, work in your repo,
push to <code>main</code>. Graded automatically on every push — the role
layout, the default and its override, the template, the handler, and
idempotence.
</div>

</div>
</div>

---
---

# By the end of this lesson, you should be able to

<v-clicks>

- [ ] Write a playbook with several plays, `become` and tags
- [ ] Put a variable in the right place — and predict which value wins
- [ ] Use facts, `register` and `when:` to make tasks conditional
- [ ] Loop over a list, and use filters in a Jinja2 template
- [ ] Explain when a handler runs — and when it doesn't
- [ ] Turn a playbook into a role with defaults, a template and a handler

</v-clicks>

---
layout: default
---

# Before next lecture

- [ ] Finish today's practice if you didn't wrap it up in session — same
      Maru flow as always
- [ ] **Lab 02 (RHA RH294)** is due **Wed, Nov 4, 23:59** — the chapters
      on variables and facts, task control, templates and roles are
      today's material; see "Red Hat labs" in Maru
- [ ] Two weeks left on Lab 02: don't leave the whole course for the
      last weekend

<div class="mt-8 text-sm opacity-60">
Keep today's role — next week we test it.
</div>

---
layout: end
---

# Next lecture

Idempotence & testing with Molecule — proving a role works (and keeps
working) before it ever touches a real server.
