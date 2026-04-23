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

`<type>(optional-scope): short imperative summary`

Examples:

- `ci(version): split validation from sync/release workflow`
- `docs(conventions): add commit and PR conventions`

## Pull Request Convention

PR title should follow the same Conventional Commit style as the primary commit.

PR description should include:

1. **Summary**: what changed and why
2. **Testing**: how it was validated
3. **Risk/Impact**: behavior changes or rollout notes
4. **Checklist**:
   - [ ] CI passes
   - [ ] Backward compatibility considered
   - [ ] Docs updated (if needed)
