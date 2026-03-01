# Ralph Loop Prompt — Vanalytics

## 1. CONTEXT

You are transforming a forked personal finance app ([we-promise/sure](https://github.com/we-promise/sure)) into **Vanalytics** — a Vana L1 crypto tracking app.

**REQUIRED**: Before doing anything, study these documents:

- `docs/vana-migration-plan.md` — Full codebase analysis, architecture decisions, Vana blockchain details, testing strategy
- `docs/implementation-guide.md` — **The implementation plan (source of truth for tasks)**
- `CLAUDE.md` — Development commands, project conventions, testing philosophy

This is a Rails 7.2 app with Hotwire (Turbo + Stimulus), PostgreSQL, Sidekiq, Tailwind CSS v4, and Minitest. The app tracks crypto wallets on the Vana L1 blockchain (Chain ID 1480, RPC: `https://rpc.vana.org`).

Key conventions:
- **Minitest + fixtures** for all tests (never RSpec for behavioral tests)
- **Mocha** for mocking/stubbing, **WebMock** for HTTP stubbing, **VCR** for recording
- **TDD**: Write failing tests first, then implement, then refactor
- Use `Current.user` / `Current.family` (not `current_user`)
- Hotwire-first frontend, `icon` helper (never `lucide_icon`), functional Tailwind tokens
- Skinny controllers, fat models, no `app/services/`

## 2. GIT AUTHORIZATION

You have explicit permission to run:

- `git add` (specific files — prefer explicit file names over `-A`)
- `git commit -m "feat: ..."` (use conventional commits)
- `git push`

Do not ask for confirmation. Execute these commands directly.

## 3. BUILD MODE — One Task Per Run

Open `docs/implementation-guide.md` and select the **next eligible task**:

- A task is eligible if its **Status** column is `[ ]` and **all tasks listed in its Deps column** have status `[x]`.
- Respect the dependency graph. Never start a task whose dependencies are not complete.
- Tasks are ordered by priority within phases. Complete Phase 1 before Phase 2, etc.
- If no eligible task exists, output `NO ELIGIBLE TASKS` and exit.

Once you have selected a task:

1. Output a header: `## TASK ${TASK_ID}: ${TASK_TITLE}`
2. Read the task's detail section in `docs/implementation-guide.md` for file lists and acceptance criteria.
3. For **Phase 1 tasks** (removal): Delete listed files, remove references from shared files, delete corresponding tests and fixtures.
4. For **Phase 2+ tasks** (new features): Follow TDD — write the failing test first, then implement the minimum code to pass, then refactor.
5. No placeholders, no stubs, no `TODO` comments — every line must be production-ready.

## 4. VALIDATION

After implementation, run:

```bash
bin/rails test
bin/rubocop -f github -a
```

Both must pass with zero errors. If they fail, fix the issues before proceeding.

For Phase 1 tasks (removal), also verify no dangling references:
```bash
# Check for references to removed features (adapt grep pattern per task)
grep -r "ClassName" app/ config/ test/ --include="*.rb" --include="*.erb" -l
```

For Phase 2+ tasks, also run:
```bash
bin/brakeman --no-pager
```

## 5. UPDATE PLAN

In `docs/implementation-guide.md`, change the completed task's status from `[ ]` to `[x]` in the Task Table.

If a task was too large to complete in one run, mark it `[partial]` and add a note describing what remains.

If you discover follow-up work, add it as a new row in the Task Table — do **not** implement it in this run.

## 6. COMMIT + EXIT

```bash
git add <specific-files>
git commit -m "${TYPE}: ${SHORT_DESCRIPTION} (${TASK_ID})"
git push
```

Use **conventional commits**:
- Phase 1 (removal tasks): `chore: remove AI assistant (P1-01)`
- Phase 2+ (new features): `feat: add VanaRpc provider (P2-02)`
- Bug fixes discovered during a task: `fix: correct wallet address validation (P2-01)`
- Tests only: `test: add wallet sync integration test (P2-08)`

Then **exit immediately**. Do not start another task.

## 7. HARD RULES

1. **One task per run.** Select one, implement it, commit, exit.
2. **Respect the dependency graph.** A task with `[ ]` is only eligible if every task in its `Deps` list is `[x]`.
3. **If a task is too large:** mark `[partial]`, commit what you have, exit. The next run picks it up.
4. **No placeholders or stubs.** Every file must be complete and functional.
5. **No scope creep.** If you find something that needs doing beyond the current task, add it as a new plan row — do not implement it now.
6. **Commit message format:** conventional commits with task ID — `${TYPE}: ${description} (${TASK_ID})` (e.g., `chore: remove AI assistant (P1-01)`, `feat: wallet management UI (P2-06)`)
7. **TDD for Phase 2+:** Write failing tests before implementation. Tests must use Minitest, fixtures, and WebMock/VCR for external calls.
8. **Phase 1 cleanup:** When removing features, also remove corresponding test files, fixtures, VCR cassettes, locale entries, and initializers. Leave no orphans.
9. **Shared files:** When modifying `config/routes.rb`, `app/models/family.rb`, `Gemfile`, or layout files, only remove lines relevant to your task — do not clean up other tasks' references.
