#!/usr/bin/env bash
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/clean-vscode-extensions.sh"
FIXTURES="$(cd "$(dirname "$0")/fixtures" && pwd)"
TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

PASS=0
FAIL=0

ok() {
    echo "PASS: $1"
    PASS=$(( PASS + 1 ))
}

fail() {
    echo "FAIL: $1"
    echo "      $2"
    FAIL=$(( FAIL + 1 ))
}

assert_contains() {
    local test_name="$1" pattern="$2" output="$3"
    if echo "$output" | grep -qF -- "$pattern"; then
        ok "$test_name"
    else
        fail "$test_name" "expected output to contain: $pattern"
        echo "      actual output:"
        echo "$output" | sed 's/^/        /'
    fi
}

assert_not_contains() {
    local test_name="$1" pattern="$2" output="$3"
    if ! echo "$output" | grep -qF -- "$pattern"; then
        ok "$test_name"
    else
        fail "$test_name" "expected output NOT to contain: $pattern"
    fi
}

assert_exit_code() {
    local test_name="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        ok "$test_name"
    else
        fail "$test_name" "expected exit $expected, got $actual"
    fi
}

copy_fixture() {
    local name="$1"
    local dest="${TMPDIR_BASE}/${name}"
    cp -r "$FIXTURES/$name" "$dest"
    echo "$dest"
}

echo "Running vscode-extension-cleaner tests..."
echo

# ── Test: dry-run lists old versions, keeps newest ─────────────────────────
output=$(bash "$SCRIPT" "$FIXTURES/basic" 2>&1)
assert_contains "basic: lists old azurefunctions 1.14.0" \
    "ms-azuretools.vscode-azurefunctions-1.14.0" "$output"
assert_contains "basic: lists old azurefunctions 1.15.0" \
    "ms-azuretools.vscode-azurefunctions-1.15.0" "$output"
assert_not_contains "basic: does not list newest azurefunctions 2.0.0" \
    "ms-azuretools.vscode-azurefunctions-2.0.0" "$output"
assert_contains "basic: lists old python 2023" \
    "ms-python.python-2023.0.0" "$output"
assert_not_contains "basic: does not list newest python 2024" \
    "ms-python.python-2024.0.0" "$output"
assert_not_contains "basic: dry-run does not delete" \
    "Deleted:" "$output"
assert_contains "basic: shows total space line" \
    "Total space to reclaim:" "$output"
assert_contains "basic: shows dry-run hint" \
    "--delete" "$output"

# ── Test: --delete actually removes old versions ────────────────────────────
work=$(copy_fixture "basic")
output=$(bash "$SCRIPT" --delete "$work" 2>&1)
assert_contains "delete: reports deletion" "Deleted:" "$output"
assert_contains "delete: removes azurefunctions 1.14.0" \
    "ms-azuretools.vscode-azurefunctions-1.14.0" "$output"
if [[ ! -d "$work/ms-azuretools.vscode-azurefunctions-1.14.0" ]]; then
    ok "delete: azurefunctions 1.14.0 dir is gone"
else
    fail "delete: azurefunctions 1.14.0 dir is gone" "dir still exists"
fi
if [[ -d "$work/ms-azuretools.vscode-azurefunctions-2.0.0" ]]; then
    ok "delete: newest azurefunctions 2.0.0 dir survives"
else
    fail "delete: newest azurefunctions 2.0.0 dir survives" "dir was deleted"
fi

# ── Test: single version per extension → nothing to clean ──────────────────
output=$(bash "$SCRIPT" "$FIXTURES/single" 2>&1)
assert_contains "single: reports nothing to clean" "Nothing to clean" "$output"

# ── Test: platform-suffixed directory names ─────────────────────────────────
output=$(bash "$SCRIPT" "$FIXTURES/platform" 2>&1)
assert_contains "platform: lists old claude-code 2.1.0" \
    "anthropic.claude-code-2.1.0-darwin-arm64" "$output"
assert_not_contains "platform: does not list newest claude-code 2.2.0" \
    "anthropic.claude-code-2.2.0-darwin-arm64" "$output"
assert_contains "platform: lists old lldb-dap 0.4.0" \
    "llvm-vs-code-extensions.lldb-dap-0.4.0" "$output"
assert_not_contains "platform: does not list newest lldb-dap 0.4.148" \
    "llvm-vs-code-extensions.lldb-dap-0.4.148" "$output"

# ── Test: extensions.json protection ───────────────────────────────────────
output=$(bash "$SCRIPT" "$FIXTURES/protected" 2>&1)
assert_contains "protected: lists unprotected old 1.0.0" \
    "publisher.ext-1.0.0" "$output"
assert_not_contains "protected: does not list protected 2.0.0" \
    "publisher.ext-2.0.0" "$output"
assert_not_contains "protected: does not list newest 3.0.0" \
    "publisher.ext-3.0.0" "$output"

# ── Test: .obsolete entry deleted when non-obsolete survivor exists ─────────
output=$(bash "$SCRIPT" "$FIXTURES/obsolete" 2>&1)
assert_contains "obsolete: lists .obsolete entry 1.0.0" \
    "publisher.tool-1.0.0" "$output"
assert_not_contains "obsolete: does not list non-obsolete newest 2.0.0" \
    "publisher.tool-2.0.0" "$output"

# ── Test: sole copy in .obsolete is kept (claude-code scenario) ─────────────
# extensions.json records a version not on disk; the only on-disk dir is in
# .obsolete — guaranteed-survivor rule must protect it from deletion.
output=$(bash "$SCRIPT" "$FIXTURES/sole-obsolete" 2>&1)
assert_contains "sole-obsolete: sole copy is kept (nothing to clean)" \
    "Nothing to clean" "$output"
assert_not_contains "sole-obsolete: sole copy not listed as candidate" \
    "anthropic.claude-code-2.1.202-darwin-arm64" "$output"

# ── Test: all copies in .obsolete keeps newest (nrwl scenario) ──────────────
# Both on-disk dirs in .obsolete — newer is the survivor, older is a candidate.
output=$(bash "$SCRIPT" "$FIXTURES/all-obsolete" 2>&1)
assert_contains "all-obsolete: older 18.100.5 is a candidate" \
    "nrwl.angular-console-18.100.5" "$output"
assert_not_contains "all-obsolete: newest 18.101.0 is kept (not a candidate)" \
    "nrwl.angular-console-18.101.0" "$output"

# Verify --delete on all-obsolete removes only the older copy
work=$(copy_fixture "all-obsolete")
bash "$SCRIPT" --delete "$work" > /dev/null 2>&1
if [[ ! -d "$work/nrwl.angular-console-18.100.5" ]]; then
    ok "all-obsolete delete: older 18.100.5 was deleted"
else
    fail "all-obsolete delete: older 18.100.5 was deleted" "dir still exists"
fi
if [[ -d "$work/nrwl.angular-console-18.101.0" ]]; then
    ok "all-obsolete delete: newest 18.101.0 survived"
else
    fail "all-obsolete delete: newest 18.101.0 survived" "dir was deleted"
fi

# ── Test: nonexistent directory fails with nonzero exit ────────────────────
set +e
bash "$SCRIPT" "/nonexistent/path/does/not/exist" >/dev/null 2>&1
exit_code=$?
set -e
assert_exit_code "nonexistent-dir: exits nonzero" "1" "$exit_code"

# ── Test: --help exits zero ─────────────────────────────────────────────────
set +e
output=$(bash "$SCRIPT" --help 2>&1)
exit_code=$?
set -e
assert_exit_code "--help: exits zero" "0" "$exit_code"
assert_contains "--help: shows usage" "Usage:" "$output"
assert_contains "--help: mentions --delete" "--delete" "$output"

# ── Test: noext dir (no extension dirs) → nothing to clean ─────────────────
output=$(bash "$SCRIPT" "$FIXTURES/noext" 2>&1)
assert_contains "noext: reports nothing to clean" "Nothing to clean" "$output"

# ── Summary ─────────────────────────────────────────────────────────────────
echo
echo "Results: ${PASS} passed, ${FAIL} failed"

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
