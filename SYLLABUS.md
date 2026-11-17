# Course Syllabus

*Formatted to match SDU's official syllabus template. Fields marked
`[TBD]` need confirmation from the program director / registrar before
this is filed officially — everything else reflects the course design
decided so far.*

**Course Code:** INF 345
**Department:** School of Information Technology and Applied Mathematics
**Course Title:** Fundamentals of DevOps
**Semester:** Fall 2026
**Credits/ECTS:** 3 cr / 5 ECTS (weekly contact hours: 2 lecture + 1 seminar + 2 lab)
**Degree Cycle (Level):** Bachelor
**Course Type:** Elective
**Language of Instruction:** English

## Requisites

*Auto-filled by the Education Program system when the course is registered
there — not reproducible in this draft.*

| Type | Program Code | Educational Program | Course Title | Consent status |
|---|---|---|---|---|
| PR (Prerequisite) | `[TBD]` | `[TBD]` | `[TBD]` | |

Suggested prerequisite in the meantime: comfortable with a Linux/Unix
command line and basic Git — no formal course prerequisite identified yet.

## Programmes for which the course is available

*Auto-filled by the Education Program system.* `[TBD]`

## Mode of Delivery

- [ ] Face to Face
- [x] Online
- [ ] Hybrid

## Course Description

An introduction to DevOps practice through its two most foundational
disciplines: containers and configuration-management automation. Students
containerize real applications, automate infrastructure with Ansible, and
build a CI/CD pipeline — the core skills used in production software
engineering today. The course runs partly on Red Hat Academy cloud labs
(provided free to SDU students through the university's Red Hat Academy
partnership) and partly on open-source tooling students can keep using
without any subscription. Containers and Automation are graded directly
from Red Hat Academy lab completion; the CI/CD lab and weekly practices
are graded automatically within minutes of a push to your own practice
repository, created for you in Maru (maru.o0o7.com).

## Instructor(s)

| Name Surname | Degree | Contact information |
|---|---|---|
| Adil Akhmetov (Senior Lecturer) | Master | adil.akhmetov@sdu.edu.kz (online course — no physical room) |

## Skills and competences

| Academic Skills | Subject-Specific Skills |
|---|---|
| Critical thinking | Containerizing applications with Podman/Docker |
| Problem decomposition | Writing idempotent automation with Ansible |
| Reading and adapting existing code/config | Building CI/CD pipelines with GitHub Actions |
| Working effectively under time constraints | Debugging infrastructure-as-code |

## Weekly course plan

| № | Topics | Activity |
|---|---|---|
| 1 | Welcome & the DevOps landscape | Lecture & discussion |
| 2 | Git/GitHub workflow & Linux CLI refresher | Lecture & hands-on exercise |
| 3 | Containers 101: why & how | Lecture & hands-on lab |
| 4 | Images, layers, multi-stage builds | Lecture & hands-on lab |
| 5 | Container networking & volumes | Lecture & hands-on lab |
| 6 | Container security & module wrap-up | Lab work — **Lab 01 due** |
| 7 | Configuration management & Ansible basics | Lecture & hands-on lab |
| 8 | Playbooks, roles, variables | Lecture & hands-on lab |
| 9 | Idempotence & testing with Molecule | Lecture & hands-on lab |
| 10 | Ansible in production patterns | Lab work — **Lab 02 due** |
| 11 | CI/CD concepts & GitHub Actions basics | Lecture & hands-on lab |
| 12 | Building & testing pipelines | Lecture & hands-on lab |
| 13 | Security scanning & module wrap-up | Lab work — **Lab 03 due** |
| 14 | Capstone integration work session | Project work |
| 15 | Capstone demos & course wrap-up | Project presentations — **Capstone due** |

Only Weeks 1-3 have built lectures so far (`lectures/01-intro/`,
`lectures/02-git-github/`, `lectures/03-containers-101/`); the rest of the
plan is a placeholder to be filled in incrementally. Each lesson also gets
a 1-hour practice session (~2h lecture + 1h practice per week) — see
`practices/` (only Lesson 2's is built so far; see
`practices/02-git-github/`).

## Course Learning Outcomes

| Active verb | What will be done/produced | How this learning outcome will be achieved |
|---|---|---|
| Explain | The difference between containers and VMs, and why it matters | Lecture 1-2 discussion + RHA DO188 guided labs |
| Write | A secure, non-root Containerfile/Dockerfile | Weekly practices, autograded via CI (build, run, non-root check); Lab 01 via RHA DO188 |
| Write | An idempotent Ansible playbook | Lab 02 via RHA RH294 guided labs |
| Build | A working CI/CD pipeline in GitHub Actions | Lab 03, autograded via CI |
| Adapt | Existing DevOps tooling/configuration to a new problem | Capstone project + demo |

## Planned Learning Activities and Teaching Method

- [x] Lecture
- [x] Question & Answer
- [x] Discussion
- [x] Problem Solving (hands-on labs)
- [x] Other — autograded practice exercises on GitHub, via Maru

## Reading List

**Required:**
- Red Hat Academy courseware — DO188 (OpenShift Development I: Containers
  with Podman) and RH294 (RHEL Automation with Ansible), accessed via the
  RHA portal.

**Additional:**
- Docker/Podman official documentation
- Ansible official documentation
- GitHub Actions official documentation

## Assessment Methods and Criteria

*The University's normative rules regarding assessment apply. See the Code
of Practice on Assessments.*

| Assessment | Description | Quantity | % |
|---|---|---|---|
| Lab 01 — Containers | Graded entirely from RHA **DO188** lab completion (instructor-assigned via the RHA portal) — no GitHub submission | 1 | 15 |
| Lab 02 — Automation | Graded entirely from RHA **RH294** lab completion (instructor-assigned via the RHA portal) — no GitHub submission | 1 | 15 |
| Lab 03 — CI/CD | Autograded GitHub Actions pipeline (no RHA equivalent exists for this topic) | 1 | 15 |
| Weekly practice sessions | 1-hour in-class exercise each lesson, autograded on push to your practice repo. 1 point each; your best 10 count | ~15 | 10 |
| Attendance | Present in lecture + practice (lecture: pass the lecture quiz; practice: complete the week's practice). 5 points × your attendance rate | ~15 | 5 |
| Final Exam — Capstone Project | Mandatory final assessment, delivered in project format (per policy, a project may substitute for a written exam): integration project + demo | 1 | 40 |
| **Total** | | | **100** |

**How you submit GitHub work:** in **Maru** (maru.o0o7.com), sign
in with your SDU Google account, link your GitHub once, and press
**Accept** on the week's practice. Maru creates your own private
repository from the practice template; do the work there and push.
GitHub Actions grades every push, and your score, attendance and grades
appear in Maru within minutes. Practice 02 (week 2) used a pull request
to this repository instead; that score still counts. Labs 01
and 02 are the exception: they are graded from Red Hat Academy, not
GitHub.

A university-wide Final Exam is a mandatory assessment component. This
course exercises the policy allowance to deliver it as a project rather
than a written exam — the Capstone Project *is* the Final Exam for grading
and compliance purposes.

**Rubrics:** to be published per-lab alongside each lab's README (the
"Definition of done" checklist in each lab functions as its rubric) and
alongside the capstone brief once written.

**Exam format description:** the Final Exam is delivered as a capstone
project + live demo rather than a written exam, per the project-substitution
policy. Students integrate containers (Podman/Docker), automation (Ansible),
and a CI/CD pipeline into one working project and must be able to explain
and defend their own work during the demo.

## Student Workload

| Activity | Quantity | Duration | Total Hours |
|---|---|---|---|
| Lecture | 15 | 1 | 15 |
| Lab session | 15 | 2 | 30 |
| Homework | 15 | 2 | 30 |
| Office Hours | 15 | 2 | 30 |
| Student's independent work | 30-40 | | |
| Student's independent work with the teacher | 15-20 | | |
| **Total Workload** | | | **150-165** |

## Academic Integrity

Students must ensure that all work completed for this course is their own
work. Any evidence of plagiarism, data falsification, fabrication,
collusion, self-plagiarism and/or other forms of academic misconduct will
be penalised. Further information can be found in the Code of Practice on
Academic Integrity. Autograder scores come from the Actions run on your
practice repository — editing the grading workflow voids that attempt.
Discussing concepts and approaches with classmates is
encouraged; submitting code you didn't write or understand is not, and
capstone demos include being able to explain your own work.

## Late/Non Submission and Attendance Policy

Academic excellence and high achievement are only possible in an
environment where the highest standards of academic honesty and integrity
are maintained: students at SDU must ensure they adhere to this
requirement. Active participation is an integral part of teaching and
learning at SDU. Therefore, all students are required to attend classes
regularly, and any absences are recorded for each subject. The percentage
of attendance should be at least 70%.

## Bell Curve Policy

The aim of using Bell Curve is to analyze the distribution of grades and
build a normal distribution diagram. Bell Curve can be applied when the
number of students is at least 30 to fit a normal distribution and when it
will significantly improve the level of quality in Education and
Assessment. In all cases, the median value must be within the 70-80 points
range and the standard deviation range should be between 7 to 15. Bell
Curve should not be used in courses that are prerequisites to many other
courses. Before performing BCA, too-low grades should be removed (less than
10%). For more information see the regulation:
https://oldpms.sdu.edu.kz/common/download/assessment_policy.pdf

## Course Specific Policy

Syllabus can be changed due to COVID-19 or other health conditions in the
country; students will be informed in advance.

## Email Etiquette

All communication between the instructor and students must be conducted
through official university email accounts. Students should regularly
check their email for important announcements, feedback, and instructions.
Communication via personal messaging apps (WhatsApp, Telegram, or similar)
is not permitted for official course business. All course-related
inquiries must be handled through email to ensure professionalism and
proper record-keeping.

If you have a private matter to discuss, use the following guidelines for a
timely response:
- Use your official `@stu.sdu.edu.kz` email account.
- Use a descriptive subject line that includes **"INF 345"** and your group
  name.
- Begin with a proper greeting.
- Briefly explain your question, concern, or request, including the course
  name (instructors teach several courses).
- End with a proper closing that includes your full name and student ID.

## Approved by Educational Program (EP) Director

_____________________________________________________________________________
