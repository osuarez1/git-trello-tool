#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PASS_COUNT=0
FAIL_COUNT=0

pass() {
    local name="$1"
    PASS_COUNT=$((PASS_COUNT + 1))
    printf 'PASS: %s\n' "$name"
}

fail() {
    local name="$1"
    local reason="$2"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf 'FAIL: %s\n' "$name"
    printf '  %s\n' "$reason"
}

run_test() {
    local name="$1"
    local fn="$2"
    if "$fn"; then
        pass "$name"
    else
        fail "$name" "Assertion failed"
    fi
}

test_sync_version_consistency() {
    local script_version
    local file_version

    script_version="$(bash "$ROOT_DIR/scripts/sync-version.sh" --print)"
    file_version="$(tr -d '[:space:]' < "$ROOT_DIR/version.txt")"

    [[ -n "$script_version" ]] || return 1
    [[ "$script_version" == "$file_version" ]] || return 1

    bash "$ROOT_DIR/scripts/sync-version.sh" --check >/dev/null
}

test_pre_push_branch_validation() {
    local status

    # Valid feature branch with 24-char Trello ID should pass.
    set +e
    printf 'refs/heads/feature/abcdef123456abcdef123456-my-task a refs/heads/feature/abcdef123456abcdef123456-my-task b\n' \
        | bash "$ROOT_DIR/hooks/pre-push" >/dev/null 2>&1
    status=$?
    set -e
    [[ "$status" -eq 0 ]] || return 1

    # Protected branch without Trello ID should pass.
    set +e
    printf 'refs/heads/main a refs/heads/main b\n' | bash "$ROOT_DIR/hooks/pre-push" >/dev/null 2>&1
    status=$?
    set -e
    [[ "$status" -eq 0 ]] || return 1

    # Non-protected branch without Trello ID should fail.
    set +e
    printf 'refs/heads/feature/no-id a refs/heads/feature/no-id b\n' | bash "$ROOT_DIR/hooks/pre-push" >/dev/null 2>&1
    status=$?
    set -e
    [[ "$status" -ne 0 ]]
}

test_prepare_commit_msg_injection() {
    local tmp_dir
    local msg_file
    local original_path
    local status

    tmp_dir="$(mktemp -d)"
    msg_file="$tmp_dir/COMMIT_EDITMSG"
    original_path="$PATH"

    cat > "$tmp_dir/git" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "branch" && "$2" == "--show-current" ]]; then
    echo "feature/abcdef123456abcdef123456-new-thing"
    exit 0
fi
exit 1
EOF
    chmod +x "$tmp_dir/git"

    printf 'feat: add behavior\n' > "$msg_file"
    PATH="$tmp_dir:$PATH"

    set +e
    bash "$ROOT_DIR/hooks/prepare-commit-msg" "$msg_file" ""
    status=$?
    set -e
    PATH="$original_path"
    [[ "$status" -eq 0 ]] || return 1

    grep -q 'Trello-Card: abcdef123456abcdef123456' "$msg_file" || return 1

    # Running the hook again should not duplicate the metadata line.
    PATH="$tmp_dir:$PATH"
    set +e
    bash "$ROOT_DIR/hooks/prepare-commit-msg" "$msg_file" ""
    status=$?
    set -e
    PATH="$original_path"
    [[ "$status" -eq 0 ]] || return 1

    local count
    count="$(grep -c 'Trello-Card: abcdef123456abcdef123456' "$msg_file")"
    [[ "$count" == "1" ]]
}

main() {
    run_test "version sync remains consistent" test_sync_version_consistency
    run_test "pre-push validates branch naming rules" test_pre_push_branch_validation
    run_test "prepare-commit-msg injects card ID once" test_prepare_commit_msg_injection

    printf '\nResult: %d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"

    if [[ "$FAIL_COUNT" -ne 0 ]]; then
        exit 1
    fi
}

main "$@"
