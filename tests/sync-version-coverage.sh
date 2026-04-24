#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_SCRIPT="${REPO_ROOT}/scripts/sync-version.sh"
SOURCE_SCRIPT="${REPO_ROOT}/bin/git-trello"
VERSION_FILE="${REPO_ROOT}/version.txt"

TMP_DIR="$(mktemp -d)"
TRACE_DIR="$(mktemp -d)"
BACKUP_SOURCE="${TMP_DIR}/git-trello.backup"
BACKUP_VERSION="${TMP_DIR}/version.txt.backup"
HAS_VERSION_FILE=0

cp -p "${SOURCE_SCRIPT}" "${BACKUP_SOURCE}"
if [ -f "${VERSION_FILE}" ]; then
    cp -p "${VERSION_FILE}" "${BACKUP_VERSION}"
    HAS_VERSION_FILE=1
fi

restore_fixtures() {
    rm -f "${SOURCE_SCRIPT}"
    cp -p "${BACKUP_SOURCE}" "${SOURCE_SCRIPT}"
    if [ "${HAS_VERSION_FILE}" -eq 1 ]; then
        cp -p "${BACKUP_VERSION}" "${VERSION_FILE}"
    else
        rm -f "${VERSION_FILE}"
    fi
}

cleanup() {
    restore_fixtures
    rm -rf "${TMP_DIR}" "${TRACE_DIR}"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

assert_status() {
    local expected="$1"
    local actual="$2"
    local context="$3"
    if [ "${actual}" -ne "${expected}" ]; then
        fail "${context}: expected exit ${expected}, got ${actual}"
    fi
}

assert_file_contains() {
    local file="$1"
    local expected="$2"
    local context="$3"
    local content
    content="$(<"${file}")"
    if [[ "${content}" != *"${expected}"* ]]; then
        fail "${context}: expected '${expected}' in ${file}; got: ${content}"
    fi
}

assert_file_equals() {
    local file="$1"
    local expected="$2"
    local context="$3"
    local content
    content="$(<"${file}")"
    if [ "${content}" != "${expected}" ]; then
        fail "${context}: expected '${expected}', got '${content}'"
    fi
}

run_traced() {
    local name="$1"
    shift || true

    LAST_STDOUT="${TMP_DIR}/${name}.stdout"
    LAST_TRACE="${TRACE_DIR}/${name}.trace"

    set +e
    (
        export PS4='+${BASH_SOURCE}:${LINENO}:'
        bash -x "${TARGET_SCRIPT}" "$@"
    ) >"${LAST_STDOUT}" 2>"${LAST_TRACE}"
    LAST_STATUS=$?
    set -e
}

EXPECTED_VERSION="$(sed -n 's/^CURRENT_VERSION="\([^"]*\)"/\1/p' "${BACKUP_SOURCE}")"
[ -n "${EXPECTED_VERSION}" ] || fail "failed to detect expected CURRENT_VERSION from ${SOURCE_SCRIPT}"

# --check (default mode) with a synced version file.
printf "%s\n" "${EXPECTED_VERSION}" > "${VERSION_FILE}"
run_traced "default_check"
assert_status 0 "${LAST_STATUS}" "default --check should succeed"
assert_file_contains "${LAST_STDOUT}" "Version files are in sync (${EXPECTED_VERSION})" "default --check output"

# --print happy path.
run_traced "print_mode" --print
assert_status 0 "${LAST_STATUS}" "--print should succeed"
assert_file_equals "${LAST_STDOUT}" "${EXPECTED_VERSION}" "--print output"

# --check mismatch path.
printf "0.0.0\n" > "${VERSION_FILE}"
run_traced "mismatch_check" --check
assert_status 1 "${LAST_STATUS}" "--check mismatch should fail"
assert_file_contains "${LAST_STDOUT}" "Version mismatch detected:" "mismatch header"
assert_file_contains "${LAST_STDOUT}" "${VERSION_FILE}: 0.0.0" "mismatch expected version file value"
assert_file_contains "${LAST_STDOUT}" "Run: bash \"${REPO_ROOT}/scripts/sync-version.sh\" --write" "mismatch remediation hint"

# --write sync path.
run_traced "write_mode" --write
assert_status 0 "${LAST_STATUS}" "--write should succeed"
assert_file_contains "${LAST_STDOUT}" "Synced ${VERSION_FILE} to ${EXPECTED_VERSION}" "--write output"
assert_file_equals "${VERSION_FILE}" "${EXPECTED_VERSION}" "--write should update version file"

# Missing version file branch in read_version_file.
rm -f "${VERSION_FILE}"
run_traced "missing_version_file" --check
assert_status 1 "${LAST_STATUS}" "--check with missing version file should fail"
assert_file_contains "${LAST_STDOUT}" "${VERSION_FILE}: <missing>" "missing version file output"

# Invalid mode branch + usage output.
run_traced "invalid_mode" --invalid
assert_status 1 "${LAST_STATUS}" "invalid mode should fail"
assert_file_contains "${LAST_STDOUT}" "Usage: scripts/sync-version.sh [--print|--write|--check]" "usage output"

# Unreadable source script branch.
mv "${SOURCE_SCRIPT}" "${SOURCE_SCRIPT}.missing"
run_traced "unreadable_source" --print
assert_status 1 "${LAST_STATUS}" "unreadable source should fail"
assert_file_contains "${LAST_TRACE}" "Error: Version source file not found or unreadable: ${SOURCE_SCRIPT}" "unreadable source error"
mv "${SOURCE_SCRIPT}.missing" "${SOURCE_SCRIPT}"
restore_fixtures

# Missing CURRENT_VERSION extraction branch.
sed 's/^CURRENT_VERSION="[^"]*"/CURRENT_VER="broken"/' "${SOURCE_SCRIPT}" >"${TMP_DIR}/git-trello-sed-patch.$$" \
    && mv "${TMP_DIR}/git-trello-sed-patch.$$" "${SOURCE_SCRIPT}"
run_traced "missing_current_version" --print
assert_status 1 "${LAST_STATUS}" "missing CURRENT_VERSION should fail"
assert_file_contains "${LAST_TRACE}" "Error: Could not extract CURRENT_VERSION from ${SOURCE_SCRIPT}" "missing CURRENT_VERSION error"
restore_fixtures

declare -a COVERABLE_LINES=(
    2 4 5 7 8 11 12 13 14 18 19 20 21 23 24 25 26 28
    32 33 34 36 39 41 43 46 47 48 51 52 54 55 56 57
    58 59 61 64 65
)

COVERABLE_FILE="${TMP_DIR}/coverable-lines.txt"
printf '%s\n' "${COVERABLE_LINES[@]}" | sort -n >"${COVERABLE_FILE}"

COVERED_FILE="${TMP_DIR}/covered-lines.txt"
awk -F: '/sync-version\.sh:[0-9]+:/{print $2}' "${TRACE_DIR}"/*.trace | sort -n -u >"${COVERED_FILE}"

declare -a MISSING_LINES=()
while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "${line}" ]] && continue
    MISSING_LINES+=("${line}")
done < <(comm -23 "${COVERABLE_FILE}" "${COVERED_FILE}")

TOTAL_LINES="${#COVERABLE_LINES[@]}"
COVERED_LINES_COUNT=$((TOTAL_LINES - ${#MISSING_LINES[@]}))
COVERAGE_PERCENT=$((COVERED_LINES_COUNT * 100 / TOTAL_LINES))

if [ "${#MISSING_LINES[@]}" -gt 0 ]; then
    fail "missing coverage for line(s): ${MISSING_LINES[*]}"
fi

if [ "${COVERAGE_PERCENT}" -ne 100 ]; then
    fail "expected 100% line coverage, got ${COVERAGE_PERCENT}%"
fi

echo "PASS: scripts/sync-version.sh coverage is ${COVERAGE_PERCENT}% (${COVERED_LINES_COUNT}/${TOTAL_LINES})"
