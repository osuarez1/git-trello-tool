# Commit and Pull Request Conventions

## Commit Message Convention

Use Conventional Commits:

- `feat:` for new functionality
- `fix:` for bug fixes
- `chore:` for maintenance work
- `docs:` for documentation-only changes
- `refactor:` for code changes without behavior changes
- `test:` for test updates
- `ci:` for CI/CD workflow changes

Format:

```text
<type>(scope): short imperative summary

[optional body]

[optional footer(s)]
```

Simple commit examples:

- `ci(version): split validation from sync/release workflow`
- `docs(conventions): add commit and PR conventions`

**Example of a complex commit:**

```text
feat(hooks): add pre-push validation for branch names

- Created a regex pattern to scan for 24-character Trello IDs.
- Added logic to skip validation on protected branches (main, dev).
- Set script to exit 1 if validation fails to block the push.

Resolves #42
```

## Pull Request Convention

### PR title

Use the same Conventional Commit style as the primary commit.

**Example:** `feat(cli): introduce task branching and list management commands`

### PR description

It should answer three main questions:

- What changed?
- Why did it change?
- How do I test it?

A standard PR template includes:
1. **Overview/Context:** A brief paragraph explaining the purpose of the PR.
2. **Summary of Changes:** A bulleted list of the major additions, removals, or fixes.
3. **Testing Instructions:** Step-by-step instructions so the reviewer can pull down the branch and verify the code works as intended.
4. **Risk/Impact**: behavior changes or rollout notes
5. **Related Tickets:** Links to Trello cards for context if they are known.
6. **Checklist:** A markdown checklist (`- [x]`) confirming the developer ran tests, updated documentation, and bumped the version number:
   - [ ] CI passes
   - [ ] Backward compatibility considered
   - [ ] Bumped version number
   - [ ] Updated CHANGELOG.md
   - [ ] Docs updated (if needed)
