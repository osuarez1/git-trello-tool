# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.4] - 2026-04-23

### Added
- **Git-Trello Coverage Harness:** Added `tests/git-trello-coverage.sh` with deterministic stubs and trace-based assertions to exercise command routing, API error handling, dry-run behavior, interactive flows, update checks, and uninstall paths for `bin/git-trello`.

### Changed
- **CI Coverage Gate:** Updated `.github/workflows/auto-version.yml` to enforce 100% line coverage for both `scripts/sync-version.sh` and `bin/git-trello` on pull requests, including workflow trigger paths for the new coverage test.
- **Version Bump:** Updated `CURRENT_VERSION` in `bin/git-trello` and synchronized `version.txt` to `1.1.4`.

### Documentation
- **Testing Docs:** Updated README with local coverage commands for both coverage harnesses and clarified that CI enforces both checks to prevent regressions.

## [1.1.3] - 2026-04-23

### Fixed
- **Release Trigger Branch:** Updated `.github/workflows/auto-version.yml` to trigger release automation on `main` so version sync and release creation run on the repository default branch.
- **Path Robustness:** Updated `scripts/sync-version.sh` to resolve `bin/git-trello` and `version.txt` from repo-root paths derived from script location, allowing reliable execution from any working directory.

### Changed
- **Workflow Job Split:** Split release automation into `validate-version` (PR checks) and `sync-and-release` (main branch sync/release) to preserve fail-fast validation in PRs while keeping main branch self-healing behavior.

### Test
- **Non-root Invocation Guardrail:** Added CI validation that executes version checks from non-root directories (`scripts/` and `/tmp`) to prevent regressions in path handling.

## [1.1.2] - 2026-04-15

### Added
- **Version Sync Script:** Added `scripts/sync-version.sh` as the single helper for printing, checking, and syncing project version metadata from `bin/git-trello`.

### Changed
- **Release Automation:** Updated `.github/workflows/auto-version.yml` to use `scripts/sync-version.sh` for version extraction and `version.txt` synchronization, making release version flow explicit and consistent.
- **Version Bump:** Updated `CURRENT_VERSION` in `bin/git-trello` and synchronized `version.txt` to `1.1.2`.

### Documentation
- **Versioning Guide:** Added README documentation for the new script-based versioning workflow and canonical version source.

### Chore
- **Git Ignore Rules:** Added markdown convention artifact to ignore rules for cleaner repository status.

## [1.1.1] - 2026-03-19

### Fixed
- **Command Routing:** Added a master Git alias (`alias.trello`) so that running explicit commands like `git trello help` or `git trello start` routes correctly to the script instead of throwing an unknown Git command error.
- **Uninstaller Cleanup:** Updated both the standalone `uninstall.sh` and the internal `trello_uninstall` function to properly clean up the new master alias.


## [1.1.0] - 2026-03-19

### Added
- **`git tb` (Trello Branch):** New command to create a standardized Git branch from an *existing* Trello card ID. Automatically fetches the card title to format the branch name.
- **`git td` (Trello Doing):** New command to instantly move the active Trello card to the "Doing" list. Automatically posts an audit comment noting who moved it.
- **`git tt` (Trello To Do):** New command to instantly move the active Trello card back to the "To Do" list, including an audit comment.
- **`git tl` (Trello List):** New command to list all cards and their exact IDs from your configured "To Do" list. Color-coded output makes it trivial to copy an ID and pass it directly into the `git tb` command.
- **Multi-line Descriptions:** The `git ts` command now supports multi-line task descriptions. Users can type freely and press `Ctrl+D` to save.
- **Terminal Setup Commands:** Added one-liner `curl` commands to the README so users can easily find their Trello Board and List IDs directly from the terminal.

### Fixed
- **Description Payload Bug:** Fixed a variable mismatch (`TASK_DESC` vs `CARD_DESC`) where the user's typed description was being dropped before hitting the Trello API. Cards now successfully generate with the full user-provided description and detected language metadata.

## [1.0.2] - Initial Release Tracked
### Added
- Core functionality for `git ts` (Start), `git tc` (Comment), and `git tm` (Members).
- Automated Git hooks (`pre-push`, `post-commit`, `prepare-commit-msg`).
- Repository-scoped installation and uninstallation scripts.