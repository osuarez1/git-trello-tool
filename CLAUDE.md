# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Is

A per-repository CLI tool that bridges Git (Bitbucket) workflows with Trello. It installs silently into a hidden `.git-trello/` directory inside a user's project. The tool is distributed via a `curl | bash` installer that downloads files from the GitHub `main` branch; there is no build step or package manager.

## Commands

### Test Coverage (CI-enforced, 100% line coverage required)

```bash
# Run coverage harness for bin/git-trello
bash tests/git-trello-coverage.sh

# Run coverage harness for scripts/sync-version.sh
bash tests/sync-version-coverage.sh
```

### Version Management

```bash
# Check that version.txt matches CURRENT_VERSION in bin/git-trello
bash scripts/sync-version.sh --check

# Print the version from bin/git-trello
bash scripts/sync-version.sh --print

# Write version.txt from CURRENT_VERSION in bin/git-trello
bash scripts/sync-version.sh --write
```

### Running a Single Test Scenario

The coverage harnesses run all scenarios in sequence; there is no mechanism to run one test case in isolation. Add temporary `exit 0` lines or comment out scenarios when debugging a specific path.

## Architecture

### Source of Truth: `bin/git-trello`

All user-facing logic lives in a single Bash script. The `CURRENT_VERSION` variable at the top of this file is the canonical version. `version.txt` and GitHub release tags must always reflect this value.

### Version Synchronization Pipeline

1. Developer bumps `CURRENT_VERSION` in `bin/git-trello`.
2. `scripts/sync-version.sh --write` updates `version.txt` to match.
3. On PR: CI (`validate-version` job) runs `--check` plus both coverage harnesses.
4. On merge to `main`: CI (`sync-and-release` job) syncs `version.txt`, commits it, and creates a GitHub release tag.

### Coverage Harnesses (`tests/`)

Both harnesses use `bash -x` (xtrace) with a `PS4` prefix that embeds `${BASH_SOURCE}` and `${LINENO}` so each executed line is written to a per-scenario trace file. The child shell’s stderr is redirected to that file (so this works on Bash 3.2, which does not implement `BASH_XTRACEFD`). Coverage is measured by diffing the set of executable lines in the source against line numbers parsed from the trace. The approach requires no external coverage tool.

- **`git-trello-coverage.sh`**: Stubs `curl`, `git`, `find`, and `sleep` in a temp `$STUB_BIN` directory prepended to `$PATH`. A queue file (`curl-queue.txt`) feeds sequenced `status|body` responses to the curl stub. Tests use `run_traced`, `run_traced_with_input`, and `run_traced_snippet` (which sources the script and evals a function directly).
- **`sync-version-coverage.sh`**: Runs `scripts/sync-version.sh` directly, mutating `bin/git-trello` and `version.txt` as fixtures. A `restore_fixtures` function and `trap cleanup EXIT` ensure originals are restored even on failure.

### Installed Hooks (`hooks/`)

These are copied into the end-user's `.git-trello/hooks/` by the installer:

- **`prepare-commit-msg`**: Optionally appends `Trello-Card: <24-char-id>` when `git config git-trello.injectCommitCard true` (off by default). Extracts ID from branch name; skips merge/squash commits and if the tag is already present.
- **`pre-push`**: Rejects pushes on non-protected branches that lack a 24-character hex Trello ID.
- **`post-commit`**: After a successful commit, loads `~/.trello_secrets` (if present), moves the card to the configured Doing list, and posts commit metadata to Trello via `curl`. Lives in `hooks/post-commit` and is not exercised by the line-coverage harness (network and secrets).

### CI Workflow (`.github/workflows/auto-version.yml`)

Two mutually exclusive jobs triggered by path filters on `bin/git-trello`, `version.txt`, `scripts/sync-version.sh`, `tests/git-trello-coverage.sh`, `tests/sync-version-coverage.sh`, `tests/cli-tests.sh`, `CLAUDE.md`, `CONVENTION.md`, `README.md`, and the workflow file itself:

| Trigger | Job | What it does |
|---|---|---|
| `pull_request` → `main` | `validate-version` | `--check` + both coverage harnesses + `tests/cli-tests.sh` + CWD portability test |
| `push` → `main` | `sync-and-release` | `--write`, commit `version.txt`, create GitHub release |

## Conventions

See `CONVENTION.md` for the full commit and PR conventions. Summary:

- Commit messages follow Conventional Commits: `<type>(scope): short imperative summary`
- Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`
- PR title mirrors the primary commit style
- PRs must include: Overview, Summary of Changes, Testing Instructions, Risk/Impact, Related Tickets, and a checklist confirming CI passes, backward compatibility, version bump, CHANGELOG update

## Versioning Rules

- Never edit `version.txt` by hand; always run `bash scripts/sync-version.sh --write` after bumping `CURRENT_VERSION` in `bin/git-trello`.
- CI will fail the PR if `version.txt` does not match `CURRENT_VERSION`.
- When adding or removing executable lines in `bin/git-trello` or `scripts/sync-version.sh`, the corresponding coverage harness must be updated to maintain 100% coverage or CI will block the PR.
