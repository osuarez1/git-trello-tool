# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]


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