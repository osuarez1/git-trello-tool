#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_SCRIPT="${REPO_ROOT}/bin/git-trello"

TMP_DIR="$(mktemp -d)"
TRACE_DIR="${TMP_DIR}/trace"
FIXTURE_DIR="${TMP_DIR}/fixture"
TEST_HOME="${TMP_DIR}/home"
STUB_BIN="${TMP_DIR}/stubs"
CURL_QUEUE_FILE="${TMP_DIR}/curl-queue.txt"
MOCK_GIT_STATE_FILE="${TMP_DIR}/git-branch.txt"

mkdir -p "${TRACE_DIR}" "${FIXTURE_DIR}" "${TEST_HOME}" "${STUB_BIN}"

CURRENT_DATE="$(date +%Y-%m-%d)"
CURRENT_VERSION="$(sed -n 's/^CURRENT_VERSION="\([^"]*\)"/\1/p' "${TARGET_SCRIPT}")"
[ -n "${CURRENT_VERSION}" ] || {
    echo "FAIL: could not parse CURRENT_VERSION from ${TARGET_SCRIPT}" >&2
    exit 1
}

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

cleanup() {
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

write_secrets() {
    cat > "${TEST_HOME}/.trello_secrets" <<'EOF'
export API_KEY="key"
export TOKEN="token"
export TARGET_BOARD_ID="board123"
export TARGET_LIST_ID="todo123"
export TARGET_DOING_LIST_ID="doing123"
EOF
}

set_curl_queue() {
    : > "${CURL_QUEUE_FILE}"
    for entry in "$@"; do
        printf '%s\n' "${entry}" >> "${CURL_QUEUE_FILE}"
    done
}

assert_status() {
    local expected="$1"
    local actual="$2"
    local context="$3"
    if [ "${actual}" -ne "${expected}" ]; then
        fail "${context}: expected exit ${expected}, got ${actual}"
    fi
}

assert_contains() {
    local file="$1"
    local expected="$2"
    local context="$3"
    local content
    content="$(<"${file}")"
    if [[ "${content}" != *"${expected}"* ]]; then
        echo "---- ${file} ----" >&2
        cat "${file}" >&2
        fail "${context}: expected '${expected}'"
    fi
}

run_traced() {
    local name="$1"
    local cwd="$2"
    shift 2

    LAST_STDOUT="${TMP_DIR}/${name}.stdout"
    LAST_TRACE="${TRACE_DIR}/${name}.trace"

    set +e
    (
        cd "${cwd}"
        export PS4='+${BASH_SOURCE}:${LINENO}:'
        export HOME="${TEST_HOME}"
        export PATH="${STUB_BIN}:${PATH}"
        export MOCK_CURL_QUEUE_FILE="${CURL_QUEUE_FILE}"
        export MOCK_GIT_STATE_FILE
        bash -x "${TARGET_SCRIPT}" "$@"
    ) >"${LAST_STDOUT}" 2>"${LAST_TRACE}"
    LAST_STATUS=$?
    set -e
}

run_traced_with_input() {
    local name="$1"
    local cwd="$2"
    local input_data="$3"
    shift 3

    LAST_STDOUT="${TMP_DIR}/${name}.stdout"
    LAST_TRACE="${TRACE_DIR}/${name}.trace"

    set +e
    printf "%b" "${input_data}" | (
        cd "${cwd}"
        export PS4='+${BASH_SOURCE}:${LINENO}:'
        export HOME="${TEST_HOME}"
        export PATH="${STUB_BIN}:${PATH}"
        export MOCK_CURL_QUEUE_FILE="${CURL_QUEUE_FILE}"
        export MOCK_GIT_STATE_FILE
        bash -x "${TARGET_SCRIPT}" "$@"
    ) >"${LAST_STDOUT}" 2>"${LAST_TRACE}"
    LAST_STATUS=$?
    set -e
}

run_traced_snippet() {
    local name="$1"
    local cwd="$2"
    local snippet="$3"

    LAST_STDOUT="${TMP_DIR}/${name}.stdout"
    LAST_TRACE="${TRACE_DIR}/${name}.trace"

    set +e
    (
        cd "${cwd}"
        export PS4='+${BASH_SOURCE}:${LINENO}:'
        export HOME="${TEST_HOME}"
        export PATH="${STUB_BIN}:${PATH}"
        export MOCK_CURL_QUEUE_FILE="${CURL_QUEUE_FILE}"
        export MOCK_GIT_STATE_FILE
        export TEST_SNIPPET="${snippet}"
        bash -x -c 'set -- help; source "'"${TARGET_SCRIPT}"'"; eval "$TEST_SNIPPET"'
    ) >"${LAST_STDOUT}" 2>"${LAST_TRACE}"
    LAST_STATUS=$?
    set -e
}

cat > "${STUB_BIN}/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

want_http_code=0
for arg in "$@"; do
    if [[ "${arg}" == *raw.githubusercontent.com/osuarez1/git-trello-tool/main/version.txt* ]]; then
        printf '%s\n' "${MOCK_REMOTE_VERSION:-1.1.3}"
        exit 0
    fi
    if [[ "${arg}" == *'%{http_code}'* ]]; then
        want_http_code=1
    fi
done

status="${MOCK_CURL_STATUS:-200}"
body="${MOCK_CURL_BODY:-{}}"
queue_file="${MOCK_CURL_QUEUE_FILE:-}"

if [ -n "${queue_file}" ] && [ -s "${queue_file}" ]; then
    IFS='|' read -r status body < "${queue_file}"
    awk 'NR > 1' "${queue_file}" > "${queue_file}.tmp"
    mv "${queue_file}.tmp" "${queue_file}"
fi

body="${body//\\n/$'\n'}"
if [ "${want_http_code}" -eq 1 ]; then
    printf '%s\n%s\n' "${body}" "${status}"
else
    printf '%s\n' "${body}"
fi
EOF

cat > "${STUB_BIN}/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

state_file="${MOCK_GIT_STATE_FILE:-}"
branch_default="${MOCK_GIT_BRANCH:-feature/aaaaaaaaaaaaaaaaaaaaaaaa-default}"

case "${1:-}" in
    branch)
        if [ "${2:-}" = "--show-current" ]; then
            if [ -n "${state_file}" ] && [ -f "${state_file}" ]; then
                cat "${state_file}"
            else
                printf '%s\n' "${branch_default}"
            fi
            exit 0
        fi
        ;;
    checkout)
        if [ "${2:-}" = "-b" ]; then
            new_branch="${3:-}"
            [ -n "${new_branch}" ] || exit 1
            if [ -n "${state_file}" ]; then
                printf '%s\n' "${new_branch}" > "${state_file}"
            fi
            printf "Switched to a new branch '%s'\n" "${new_branch}"
            exit 0
        fi
        ;;
    config)
        if [ "${2:-}" = "--get" ] && [ "${3:-}" = "remote.origin.url" ]; then
            printf '%s\n' "${MOCK_GIT_REMOTE_URL-git@bitbucket.org:team/repo.git}"
            exit 0
        fi
        if [ "${2:-}" = "user.name" ]; then
            printf '%s\n' "${MOCK_GIT_USER_NAME:-Test User}"
            exit 0
        fi
        if [ "${2:-}" = "--unset" ]; then
            exit 0
        fi
        exit 0
        ;;
esac

exit 0
EOF

cat > "${STUB_BIN}/find" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat > "${STUB_BIN}/sleep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

chmod +x "${STUB_BIN}/curl" "${STUB_BIN}/git" "${STUB_BIN}/find" "${STUB_BIN}/sleep"

write_secrets
echo "feature/aaaaaaaaaaaaaaaaaaaaaaaa-default" > "${MOCK_GIT_STATE_FILE}"
export MOCK_GIT_BRANCH="feature/aaaaaaaaaaaaaaaaaaaaaaaa-default"
export MOCK_GIT_REMOTE_URL="git@bitbucket.org:team/repo.git"
export MOCK_GIT_USER_NAME="Test User"
export MOCK_REMOTE_VERSION="${CURRENT_VERSION}"
set_curl_queue

create_language_markers() {
    local dir="$1"
    touch "${dir}/package.json"
    touch "${dir}/requirements.txt"
    touch "${dir}/pyproject.toml"
    touch "${dir}/Pipfile"
    touch "${dir}/go.mod"
    touch "${dir}/Gemfile"
    touch "${dir}/Rakefile"
    touch "${dir}/tooling.gemspec"
    touch "${dir}/composer.json"
    touch "${dir}/pom.xml"
    touch "${dir}/build.gradle"
    touch "${dir}/build.gradle.kts"
    touch "${dir}/Cargo.toml"
    touch "${dir}/workspace.sln"
    touch "${dir}/project.csproj"
}

SCENARIO_DIR="${FIXTURE_DIR}/repo"
mkdir -p "${SCENARIO_DIR}"
touch "${SCENARIO_DIR}/.gitignore"
mkdir -p "${SCENARIO_DIR}/.git-trello"
create_language_markers "${SCENARIO_DIR}"

# 1) Missing secrets branch.
rm -f "${TEST_HOME}/.trello_secrets"
run_traced "missing_secrets" "${SCENARIO_DIR}" help
assert_status 1 "${LAST_STATUS}" "missing secrets should fail"
assert_contains "${LAST_STDOUT}" "Error: ~/.trello_secrets not found. Please run install.sh." "missing secrets message"
write_secrets

# 2) Update available message + help.
rm -f "${TEST_HOME}/.git-trello.lastcheck"
export MOCK_REMOTE_VERSION="9.9.9"
set_curl_queue
run_traced "help_update_available" "${SCENARIO_DIR}" help
assert_status 0 "${LAST_STATUS}" "help should succeed"
assert_contains "${LAST_STDOUT}" "Update Available for Git-Trello Tool!" "update banner"
assert_contains "${LAST_STDOUT}" "Usage: git trello <command> [options]" "help output"

# 3) Skip update check when already checked today.
printf '%s\n' "${CURRENT_DATE}" > "${TEST_HOME}/.git-trello.lastcheck"
export MOCK_REMOTE_VERSION="${CURRENT_VERSION}"
set_curl_queue
run_traced "help_skip_update" "${SCENARIO_DIR}" help
assert_status 0 "${LAST_STATUS}" "help with cached check should succeed"

# 4) Unknown command fallback.
set_curl_queue
run_traced "unknown_command" "${SCENARIO_DIR}" nonsense
assert_status 1 "${LAST_STATUS}" "unknown command should fail"
assert_contains "${LAST_STDOUT}" "Error: Unknown command 'nonsense'" "unknown command message"

# 4b) Debug flag parsing branch.
set_curl_queue '200|[]'
run_traced "list_with_debug_flag" "${SCENARIO_DIR}" list --debug
assert_status 0 "${LAST_STATUS}" "list with --debug should succeed"
assert_contains "${LAST_STDOUT}" "[DEBUG] Fetching cards from To Do list..." "debug logging should be enabled"

# 5) start --dry-run with invalid then valid task type.
rm -f "${TEST_HOME}/.git-trello.lastcheck"
export MOCK_REMOTE_VERSION="${CURRENT_VERSION}"
set_curl_queue '200|{"id":"member123"}'
printf '%s\n' "feature/aaaaaaaaaaaaaaaaaaaaaaaa-default" > "${MOCK_GIT_STATE_FILE}"
run_traced_with_input "start_dry_run" "${SCENARIO_DIR}" "invalid\nfeature\nDry Run Card\nDry description line\n" start --dry-run
assert_status 0 "${LAST_STATUS}" "start dry-run should succeed"
assert_contains "${LAST_STDOUT}" "Invalid task type" "start invalid task type feedback"
assert_contains "${LAST_STDOUT}" "--- DRY RUN: Simulated Execution ---" "start dry-run heading"
assert_contains "${LAST_STDOUT}" "Command: git checkout -b feature/5f1b2c3d4e5f6g7h8i9j0k1l-dry-run-card" "start dry-run branch command"

# 6) start success path (non dry-run).
rm -f "${TEST_HOME}/.git-trello.lastcheck"
set_curl_queue \
    '200|{"id":"member123"}' \
    '200|{"id":"bbbbbbbbbbbbbbbbbbbbbbbb"}'
printf '%s\n' "feature/aaaaaaaaaaaaaaaaaaaaaaaa-default" > "${MOCK_GIT_STATE_FILE}"
run_traced_with_input "start_real" "${SCENARIO_DIR}" "feature\nReal Card\nReal description\n" start
assert_status 0 "${LAST_STATUS}" "start should succeed"
assert_contains "${LAST_STDOUT}" "✅ Card #bbbbbbbbbbbbbbbbbbbbbbbb created and branch feature/bbbbbbbbbbbbbbbbbbbbbbbb-real-card checked out." "start success output"

# 7-9) Explicit API error handlers.
set_curl_queue
run_traced_snippet "api_401" "${SCENARIO_DIR}" 'handle_api_response 401 "unauthorized" "UnitTest401"'
assert_status 1 "${LAST_STATUS}" "401 handler should fail"
assert_contains "${LAST_STDOUT}" "[ERROR] 401 Unauthorized: Invalid Trello Token/Key. (Context: UnitTest401)" "401 log message"

set_curl_queue
run_traced_snippet "api_410" "${SCENARIO_DIR}" 'handle_api_response 410 "gone" "UnitTest410"'
assert_status 1 "${LAST_STATUS}" "410 handler should fail"
assert_contains "${LAST_STDOUT}" "[ERROR] 410 Gone: Resource deleted. (Context: UnitTest410)" "410 log message"

set_curl_queue
run_traced_snippet "api_500" "${SCENARIO_DIR}" 'handle_api_response 500 "boom" "UnitTest500"'
assert_status 1 "${LAST_STATUS}" "500 handler should fail"
assert_contains "${LAST_STDOUT}" "[ERROR] API Error (500): boom (Context: UnitTest500)" "500 log message"

# 10) Trello ID extraction failure.
set_curl_queue
run_traced_snippet "trello_id_missing" "${SCENARIO_DIR}" 'printf "%s\n" "feature/no-id" > "${MOCK_GIT_STATE_FILE}"; get_trello_id'
assert_status 1 "${LAST_STATUS}" "get_trello_id should fail when ID is absent"
assert_contains "${LAST_STDOUT}" "Could not find a 24-character Trello ID in branch name (feature/no-id)." "missing trello id message"

# 11) doing command with missing list ID.
set_curl_queue
printf '%s\n' "feature/aaaaaaaaaaaaaaaaaaaaaaaa-default" > "${MOCK_GIT_STATE_FILE}"
run_traced_snippet "doing_missing_list" "${SCENARIO_DIR}" 'TARGET_DOING_LIST_ID=""; trello_doing'
assert_status 1 "${LAST_STATUS}" "doing with missing list id should fail"
assert_contains "${LAST_STDOUT}" "List ID for 'Doing' is not configured in ${TEST_HOME}/.trello_secrets." "doing missing list output"

# 12) doing command success path.
set_curl_queue \
    '200|{"ok":true}' \
    '200|{"ok":true}'
printf '%s\n' "feature/aaaaaaaaaaaaaaaaaaaaaaaa-default" > "${MOCK_GIT_STATE_FILE}"
run_traced "doing_success" "${SCENARIO_DIR}" doing
assert_status 0 "${LAST_STATUS}" "doing should succeed"
assert_contains "${LAST_STDOUT}" "✅ Card successfully moved to Doing!" "doing success message"

# 13) todo command success path (201 response branch).
set_curl_queue \
    '201|{"ok":true}' \
    '201|{"ok":true}'
printf '%s\n' "feature/aaaaaaaaaaaaaaaaaaaaaaaa-default" > "${MOCK_GIT_STATE_FILE}"
run_traced "todo_success" "${SCENARIO_DIR}" todo
assert_status 0 "${LAST_STATUS}" "todo should succeed"
assert_contains "${LAST_STDOUT}" "✅ Card successfully moved to To Do!" "todo success message"

# 14) list with missing TARGET_LIST_ID.
set_curl_queue
run_traced_snippet "list_missing_target" "${SCENARIO_DIR}" 'TARGET_LIST_ID=""; trello_list'
assert_status 1 "${LAST_STATUS}" "list with missing list id should fail"
assert_contains "${LAST_STDOUT}" "TARGET_LIST_ID is not configured in ${TEST_HOME}/.trello_secrets." "missing list id message"

# 15) list empty state.
set_curl_queue '200|[]'
run_traced "list_empty" "${SCENARIO_DIR}" list
assert_status 0 "${LAST_STATUS}" "list empty should succeed"
assert_contains "${LAST_STDOUT}" "No cards in the To Do list! Time for a coffee." "list empty output"

# 16) list non-empty state.
set_curl_queue '200|[{"id":"111111111111111111111111","name":"Card One"}]'
run_traced "list_nonempty" "${SCENARIO_DIR}" list
assert_status 0 "${LAST_STATUS}" "list with cards should succeed"
assert_contains "${LAST_STDOUT}" "111111111111111111111111" "list includes card id"
assert_contains "${LAST_STDOUT}" "Card One" "list includes card title"

# 17) branch command without target id.
set_curl_queue
run_traced_with_input "branch_missing_id" "${SCENARIO_DIR}" "\n" branch
assert_status 1 "${LAST_STATUS}" "branch without id should fail"
assert_contains "${LAST_STDOUT}" "Card ID is required to create a branch." "branch missing id output"

# 18) branch command interactive success with invalid task type retry.
set_curl_queue '200|{"name":"Interactive Branch Card"}'
run_traced_with_input "branch_interactive" "${SCENARIO_DIR}" "cccccccccccccccccccccccc\ninvalid\nbugfix\n" branch
assert_status 0 "${LAST_STATUS}" "branch interactive should succeed"
assert_contains "${LAST_STDOUT}" "Invalid task type" "branch invalid task type feedback"
assert_contains "${LAST_STDOUT}" "✅ Branch bugfix/cccccccccccccccccccccccc-interactive-branch-card checked out from card #cccccccccccccccccccccccc." "branch interactive output"

# 19) branch command with card id argument.
set_curl_queue '200|{"name":"Argument Branch Card"}'
run_traced_with_input "branch_arg" "${SCENARIO_DIR}" "feature\n" branch dddddddddddddddddddddddd
assert_status 0 "${LAST_STATUS}" "branch with argument should succeed"
assert_contains "${LAST_STDOUT}" "✅ Branch feature/dddddddddddddddddddddddd-argument-branch-card checked out from card #dddddddddddddddddddddddd." "branch argument output"

# 20) comment dry-run with explicit message.
set_curl_queue
printf '%s\n' "feature/aaaaaaaaaaaaaaaaaaaaaaaa-default" > "${MOCK_GIT_STATE_FILE}"
export MOCK_GIT_REMOTE_URL="git@bitbucket.org:team/repo.git"
run_traced "comment_dry_run" "${SCENARIO_DIR}" comment --dry-run "Dry run comment"
assert_status 0 "${LAST_STATUS}" "comment dry-run should succeed"
assert_contains "${LAST_STDOUT}" "--- DRY RUN: Simulated Execution ---" "comment dry-run header"
assert_contains "${LAST_STDOUT}" "Post Comment" "comment dry-run command"

# 21) comment empty prompt and URL fallback.
set_curl_queue
printf '%s\n' "feature/aaaaaaaaaaaaaaaaaaaaaaaa-default" > "${MOCK_GIT_STATE_FILE}"
export MOCK_GIT_REMOTE_URL=""
run_traced_with_input "comment_empty" "${SCENARIO_DIR}" "\n" comment
assert_status 1 "${LAST_STATUS}" "empty comment should fail"
assert_contains "${LAST_STDOUT}" "Aborted: Comment cannot be empty." "empty comment output"

# 22) comment success via prompted message.
set_curl_queue '200|{"ok":true}'
printf '%s\n' "feature/aaaaaaaaaaaaaaaaaaaaaaaa-default" > "${MOCK_GIT_STATE_FILE}"
export MOCK_GIT_REMOTE_URL="git@bitbucket.org:team/repo.git"
run_traced_with_input "comment_success" "${SCENARIO_DIR}" "Looks good\n" comment
assert_status 0 "${LAST_STATUS}" "comment should succeed"
assert_contains "${LAST_STDOUT}" "✅ Success! Your comment is posted." "comment success output"

# 23) members dry-run.
set_curl_queue
printf '%s\n' "feature/aaaaaaaaaaaaaaaaaaaaaaaa-default" > "${MOCK_GIT_STATE_FILE}"
run_traced "members_dry_run" "${SCENARIO_DIR}" members --dry-run
assert_status 0 "${LAST_STATUS}" "members dry-run should succeed"
assert_contains "${LAST_STDOUT}" "Fetch Members" "members dry-run output"

# 24) members non-dry with no members.
set_curl_queue '200|{"members":[]}'
printf '%s\n' "feature/aaaaaaaaaaaaaaaaaaaaaaaa-default" > "${MOCK_GIT_STATE_FILE}"
run_traced "members_empty" "${SCENARIO_DIR}" members
assert_status 0 "${LAST_STATUS}" "members empty should succeed"
assert_contains "${LAST_STDOUT}" "No members are currently assigned to this card." "members empty output"

# 25) members non-dry with assigned members.
set_curl_queue '200|{"members":[{"username":"alice","fullName":"Alice Doe"}]}'
printf '%s\n' "feature/aaaaaaaaaaaaaaaaaaaaaaaa-default" > "${MOCK_GIT_STATE_FILE}"
run_traced "members_present" "${SCENARIO_DIR}" members
assert_status 0 "${LAST_STATUS}" "members present should succeed"
assert_contains "${LAST_STDOUT}" "@alice (Alice Doe)" "members present output"

# 26) uninstall cancel path.
set_curl_queue
mkdir -p "${SCENARIO_DIR}/.git-trello"
printf '.git-trello/\nkeep-me\n' > "${SCENARIO_DIR}/.gitignore"
run_traced_with_input "uninstall_cancel" "${SCENARIO_DIR}" "n\n" uninstall
assert_status 0 "${LAST_STATUS}" "uninstall cancel should succeed"
assert_contains "${LAST_STDOUT}" "Uninstall cancelled." "uninstall cancel output"

# 27) uninstall confirm path (linux branch).
set_curl_queue
mkdir -p "${SCENARIO_DIR}/.git-trello"
printf '.git-trello/\nkeep-me\n' > "${SCENARIO_DIR}/.gitignore"
export OSTYPE="linux-gnu"
run_traced_with_input "uninstall_yes_linux" "${SCENARIO_DIR}" "y\n" uninstall
assert_status 0 "${LAST_STATUS}" "uninstall confirm should succeed on linux"
assert_contains "${LAST_STDOUT}" "✅ Successfully uninstalled. Git aliases and hooks have been reset." "uninstall linux success"

# 28) uninstall confirm path (darwin sed branch).
set_curl_queue
mkdir -p "${SCENARIO_DIR}/.git-trello"
printf '.git-trello/\nkeep-me\n' > "${SCENARIO_DIR}/.gitignore"
export OSTYPE="darwin22"
run_traced_with_input "uninstall_yes_darwin" "${SCENARIO_DIR}" "y\n" uninstall
assert_status 0 "${LAST_STATUS}" "uninstall confirm should succeed on darwin path"
assert_contains "${LAST_STDOUT}" "✅ Successfully uninstalled. Git aliases and hooks have been reset." "uninstall darwin success"
export OSTYPE="linux-gnu"

# 29) Direct function execution for run_cmd non-dry and clean log branches.
set_curl_queue
run_traced_snippet "direct_functions" "${SCENARIO_DIR}" 'DRY_RUN=false; run_cmd "direct" "echo direct-command-ran"; OSTYPE="linux-gnu"; trello_clean_logs 1; OSTYPE="darwin21"; trello_clean_logs 0'
assert_status 0 "${LAST_STATUS}" "direct function calls should succeed"
assert_contains "${LAST_STDOUT}" "direct-command-ran" "run_cmd non-dry output"
assert_contains "${LAST_STDOUT}" "Cleaning logs older than 0 days..." "clean logs zero-day output"

COVERABLE_FILE="${TMP_DIR}/coverable-lines.txt"
awk '
    BEGIN { continuation = 0 }
    {
        raw = $0
        line = $0
        sub(/^[[:space:]]+/, "", line)
        trimmed = raw
        sub(/[[:space:]]+$/, "", trimmed)

        if (continuation == 0) {
            if (line == "" || line ~ /^#/) {
                # ignore
            } else if (line ~ /^[[:alnum:]_]+\(\)[[:space:]]*\{$/) {
                # function signature
            } else if (line ~ /^(\}|\{)$/) {
                # braces
            } else if (line ~ /^(then|do|done|fi|esac|else)$/) {
                # shell structural keywords
            } else if (line ~ /^elif[[:space:]]/) {
                # structural branch keyword
            } else if (line ~ /^;;$/) {
                # case separator
            } else if (line ~ /^[^[:space:]\(][^)]*\)[[:space:]]*$/) {
                # case label without inline command
            } else if (trimmed ~ /\\$/) {
                # multiline command starts are not emitted in xtrace
            } else {
                print NR
            }
        }

        if (trimmed ~ /\\$/) {
            continuation = 1
        } else {
            continuation = 0
        }
    }' "${TARGET_SCRIPT}" | sort -n >"${COVERABLE_FILE}"

COVERED_FILE="${TMP_DIR}/covered-lines.txt"
awk -F: '/git-trello:[0-9]+:/{print $2}' "${TRACE_DIR}"/*.trace | sort -n -u >"${COVERED_FILE}"

declare -a MISSING_LINES=()
while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "${line}" ]] && continue
    MISSING_LINES+=("${line}")
done < <(comm -23 "${COVERABLE_FILE}" "${COVERED_FILE}")

TOTAL_LINES="$(wc -l <"${COVERABLE_FILE}" | awk '{ print $1 }')"
COVERED_LINES_COUNT=$((TOTAL_LINES - ${#MISSING_LINES[@]}))
COVERAGE_PERCENT=$((COVERED_LINES_COUNT * 100 / TOTAL_LINES))

if [ "${#MISSING_LINES[@]}" -gt 0 ]; then
    fail "missing coverage for line(s): ${MISSING_LINES[*]}"
fi

if [ "${COVERAGE_PERCENT}" -ne 100 ]; then
    fail "expected 100% line coverage, got ${COVERAGE_PERCENT}%"
fi

echo "PASS: bin/git-trello coverage is ${COVERAGE_PERCENT}% (${COVERED_LINES_COUNT}/${TOTAL_LINES})"
