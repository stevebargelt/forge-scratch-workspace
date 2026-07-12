#!/usr/bin/env bash
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/clean-vscode-extensions.sh"
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

# Make a minimal extension dir with a payload file (so du returns non-zero)
make_ext() {
    local base="$1" name="$2"
    mkdir -p "$base/$name"
    echo '{"name":"test"}' > "$base/$name/package.json"
}

echo "Running vscode-extension-cleaner INTEGRATION tests..."
echo

# ══════════════════════════════════════════════════════════════════════════
# TEST GROUP 1: Realistic scale (62-entry fixture)
#
# Models a real ~/.vscode/extensions dir: mixed platform-suffixed and plain
# names, IDs with dashes/dots, multiple versions, singles, and metadata files.
# ══════════════════════════════════════════════════════════════════════════
echo "--- Group 1: Realistic scale (62-entry fixture) ---"

REALISTIC_DIR="$TMPDIR_BASE/realistic"
mkdir -p "$REALISTIC_DIR"

# The reference case: 4 versions of an ID with dashes in both segments
make_ext "$REALISTIC_DIR" "ms-azuretools.vscode-azurefunctions-1.14.0"
make_ext "$REALISTIC_DIR" "ms-azuretools.vscode-azurefunctions-1.15.0"
make_ext "$REALISTIC_DIR" "ms-azuretools.vscode-azurefunctions-1.16.0"
make_ext "$REALISTIC_DIR" "ms-azuretools.vscode-azurefunctions-2.0.0"

# Platform-suffixed — dashes in extension name
make_ext "$REALISTIC_DIR" "ms-vscode.cpptools-1.18.0-linux-x64"
make_ext "$REALISTIC_DIR" "ms-vscode.cpptools-1.19.0-linux-x64"
make_ext "$REALISTIC_DIR" "ms-vscode.cpptools-1.20.0-linux-x64"

# Platform-suffixed with dots in version
make_ext "$REALISTIC_DIR" "anthropic.claude-code-2.0.0-darwin-arm64"
make_ext "$REALISTIC_DIR" "anthropic.claude-code-2.1.0-darwin-arm64"
make_ext "$REALISTIC_DIR" "anthropic.claude-code-2.2.0-darwin-arm64"

# Calendar-versioned Python
make_ext "$REALISTIC_DIR" "ms-python.python-2022.0.0"
make_ext "$REALISTIC_DIR" "ms-python.python-2023.0.0"
make_ext "$REALISTIC_DIR" "ms-python.python-2024.0.0"

# Pylance — two versions
make_ext "$REALISTIC_DIR" "ms-python.vscode-pylance-2024.1.1"
make_ext "$REALISTIC_DIR" "ms-python.vscode-pylance-2024.2.0"

# Golang — two versions
make_ext "$REALISTIC_DIR" "golang.go-0.41.0"
make_ext "$REALISTIC_DIR" "golang.go-0.42.0"

# Rust-analyzer — platform-suffixed
make_ext "$REALISTIC_DIR" "rust-lang.rust-analyzer-0.3.1800-linux-x64"
make_ext "$REALISTIC_DIR" "rust-lang.rust-analyzer-0.3.1900-linux-x64"

# Docker (another ms-azuretools extension)
make_ext "$REALISTIC_DIR" "ms-azuretools.vscode-docker-1.28.0"
make_ext "$REALISTIC_DIR" "ms-azuretools.vscode-docker-1.29.0"

# ESLint — two versions
make_ext "$REALISTIC_DIR" "dbaeumer.vscode-eslint-2.4.0"
make_ext "$REALISTIC_DIR" "dbaeumer.vscode-eslint-2.4.4"

# Prettier — two versions
make_ext "$REALISTIC_DIR" "esbenp.prettier-vscode-10.1.0"
make_ext "$REALISTIC_DIR" "esbenp.prettier-vscode-11.0.0"

# GitLens — single version (must not appear as candidate)
make_ext "$REALISTIC_DIR" "eamodio.gitlens-14.9.0"

# Remote-SSH — three versions
make_ext "$REALISTIC_DIR" "ms-vscode-remote.remote-ssh-0.111.0"
make_ext "$REALISTIC_DIR" "ms-vscode-remote.remote-ssh-0.113.0"
make_ext "$REALISTIC_DIR" "ms-vscode-remote.remote-ssh-0.114.0"

# Java (Red Hat) — three platform-suffixed versions
make_ext "$REALISTIC_DIR" "redhat.java-1.28.0-linux-x64"
make_ext "$REALISTIC_DIR" "redhat.java-1.29.0-linux-x64"
make_ext "$REALISTIC_DIR" "redhat.java-1.30.0-linux-x64"

# Dracula theme — single version (must not appear as candidate)
make_ext "$REALISTIC_DIR" "dracula-theme.theme-dracula-2.25.1"

# XML + YAML (Red Hat)
make_ext "$REALISTIC_DIR" "redhat.vscode-xml-0.26.0"
make_ext "$REALISTIC_DIR" "redhat.vscode-xml-0.27.0"
make_ext "$REALISTIC_DIR" "redhat.vscode-yaml-1.15.0"
make_ext "$REALISTIC_DIR" "redhat.vscode-yaml-1.16.0"

# LLDB-DAP — platform-suffixed
make_ext "$REALISTIC_DIR" "llvm-vs-code-extensions.lldb-dap-0.4.0-linux-x64"
make_ext "$REALISTIC_DIR" "llvm-vs-code-extensions.lldb-dap-0.4.148-linux-x64"

# EditorConfig — single version
make_ext "$REALISTIC_DIR" "editorconfig.editorconfig-0.16.4"

# Git History — two versions
make_ext "$REALISTIC_DIR" "donjayamanne.githistory-0.6.19"
make_ext "$REALISTIC_DIR" "donjayamanne.githistory-0.6.20"

# TypeScript Nightly — two versions
make_ext "$REALISTIC_DIR" "ms-vscode.vscode-typescript-next-5.4.0"
make_ext "$REALISTIC_DIR" "ms-vscode.vscode-typescript-next-5.5.0"

# Code Runner — two versions
make_ext "$REALISTIC_DIR" "formulahendry.code-runner-0.12.0"
make_ext "$REALISTIC_DIR" "formulahendry.code-runner-0.12.2"

# Better Comments — two versions
make_ext "$REALISTIC_DIR" "aaron-bond.better-comments-3.0.0"
make_ext "$REALISTIC_DIR" "aaron-bond.better-comments-3.0.2"

# Markdown All in One — two versions
make_ext "$REALISTIC_DIR" "yzhang.markdown-all-in-one-3.5.0"
make_ext "$REALISTIC_DIR" "yzhang.markdown-all-in-one-3.6.0"

# Code Spell Checker — two versions
make_ext "$REALISTIC_DIR" "streetsidesoftware.code-spell-checker-3.0.1"
make_ext "$REALISTIC_DIR" "streetsidesoftware.code-spell-checker-3.1.0"

# Tailwind CSS — two versions
make_ext "$REALISTIC_DIR" "bradlc.vscode-tailwindcss-0.11.0"
make_ext "$REALISTIC_DIR" "bradlc.vscode-tailwindcss-0.12.0"

# Kubernetes tools — two versions
make_ext "$REALISTIC_DIR" "ms-kubernetes-tools.vscode-kubernetes-tools-1.3.16"
make_ext "$REALISTIC_DIR" "ms-kubernetes-tools.vscode-kubernetes-tools-1.3.17"

# Makefile tools — two versions
make_ext "$REALISTIC_DIR" "ms-vscode.makefile-tools-0.8.0"
make_ext "$REALISTIC_DIR" "ms-vscode.makefile-tools-0.9.0"

# Indent rainbow — single version
make_ext "$REALISTIC_DIR" "oderwat.indent-rainbow-8.3.1"

# Metadata files (must be skipped)
echo '[]' > "$REALISTIC_DIR/extensions.json"
printf '{}' > "$REALISTIC_DIR/.obsolete"

entry_count=$(find "$REALISTIC_DIR" -maxdepth 1 -mindepth 1 | wc -l)
if [[ "$entry_count" -ge 60 ]]; then
    ok "realistic: fixture has sufficient scale ($entry_count entries)"
else
    fail "realistic: fixture has sufficient scale ($entry_count entries)" "expected >= 60, got $entry_count"
fi

output=$(bash "$SCRIPT" "$REALISTIC_DIR" 2>&1)

# Oldest versions of the key multi-version reference extension should be candidates
assert_contains "realistic: azurefunctions 1.14.0 is candidate" \
    "ms-azuretools.vscode-azurefunctions-1.14.0" "$output"
assert_contains "realistic: azurefunctions 1.15.0 is candidate" \
    "ms-azuretools.vscode-azurefunctions-1.15.0" "$output"
assert_contains "realistic: azurefunctions 1.16.0 is candidate" \
    "ms-azuretools.vscode-azurefunctions-1.16.0" "$output"
assert_not_contains "realistic: azurefunctions 2.0.0 is NOT a candidate" \
    "ms-azuretools.vscode-azurefunctions-2.0.0" "$output"

# Calendar-versioned Python
assert_contains "realistic: python 2022.0.0 is candidate" \
    "ms-python.python-2022.0.0" "$output"
assert_contains "realistic: python 2023.0.0 is candidate" \
    "ms-python.python-2023.0.0" "$output"
assert_not_contains "realistic: python 2024.0.0 is NOT a candidate" \
    "ms-python.python-2024.0.0" "$output"

# Single-version extensions must not appear
assert_not_contains "realistic: gitlens single-version not candidate" \
    "eamodio.gitlens-14.9.0" "$output"
assert_not_contains "realistic: dracula single-version not candidate" \
    "dracula-theme.theme-dracula-2.25.1" "$output"
assert_not_contains "realistic: editorconfig single-version not candidate" \
    "editorconfig.editorconfig-0.16.4" "$output"

# Metadata files must never appear
assert_not_contains "realistic: extensions.json not listed" \
    "extensions.json" "$output"

assert_contains "realistic: shows total space line" \
    "Total space to reclaim:" "$output"
assert_contains "realistic: shows dry-run hint" \
    "--delete" "$output"
assert_not_contains "realistic: dry-run does not show Deleted:" \
    "Deleted:" "$output"

# ══════════════════════════════════════════════════════════════════════════
# TEST GROUP 2: Dry-run is truly side-effect-free
#
# Inventory the tree (listing + file checksums) before and after a dry-run;
# they must be identical.
# ══════════════════════════════════════════════════════════════════════════
echo
echo "--- Group 2: Dry-run is side-effect-free ---"

SIDEEFFECT_DIR="$TMPDIR_BASE/sideeffect"
cp -r "$REALISTIC_DIR" "$SIDEEFFECT_DIR"

# Snapshot: directory listing (names + types)
before_listing=$(find "$SIDEEFFECT_DIR" -maxdepth 1 -mindepth 1 | sort)

# Snapshot: all file contents
before_content=$(find "$SIDEEFFECT_DIR" -type f | sort | xargs cat 2>/dev/null || true)

# Run dry-run (must not mutate anything)
bash "$SCRIPT" "$SIDEEFFECT_DIR" > /dev/null 2>&1

after_listing=$(find "$SIDEEFFECT_DIR" -maxdepth 1 -mindepth 1 | sort)
after_content=$(find "$SIDEEFFECT_DIR" -type f | sort | xargs cat 2>/dev/null || true)

if [[ "$before_listing" == "$after_listing" ]]; then
    ok "dry-run: directory tree identical before/after (no entries added or removed)"
else
    before_count=$(echo "$before_listing" | wc -l)
    after_count=$(echo "$after_listing" | wc -l)
    fail "dry-run: directory tree identical before/after" \
        "before=$before_count entries, after=$after_count entries"
fi

if [[ "$before_content" == "$after_content" ]]; then
    ok "dry-run: file content identical before/after (no files modified)"
else
    fail "dry-run: file content identical before/after" "file content changed"
fi

# Running dry-run twice gives the same output (idempotent reporting)
out1=$(bash "$SCRIPT" "$SIDEEFFECT_DIR" 2>&1)
out2=$(bash "$SCRIPT" "$SIDEEFFECT_DIR" 2>&1)
if [[ "$out1" == "$out2" ]]; then
    ok "dry-run: idempotent — two consecutive runs produce identical output"
else
    fail "dry-run: idempotent — two consecutive runs produce identical output" "output differed"
fi

# ══════════════════════════════════════════════════════════════════════════
# TEST GROUP 3: --delete removes exactly the predicted set and nothing else
#
# 1. Dry-run against a fresh copy — parse the predicted candidate names.
# 2. Run --delete against the same copy.
# 3. Verify every predicted candidate is gone and every non-candidate survives.
# ══════════════════════════════════════════════════════════════════════════
echo
echo "--- Group 3: --delete removes exactly the predicted set ---"

DELETE_DIR="$TMPDIR_BASE/delete_exact"
cp -r "$REALISTIC_DIR" "$DELETE_DIR"

# Capture the dry-run candidate list.
# Output format:
#   EXTENSION DIRECTORY                                                     SIZE
#   -----...
#   <dirname>                                                               <sz>
#   ...
#   -----...
#   Total space to reclaim: ...
#
# Extension dir names always start with a lowercase letter (publisher).
dry_output=$(bash "$SCRIPT" "$DELETE_DIR" 2>&1)
predicted_candidates=()
while IFS= read -r _line; do
    [[ -n "$_line" ]] && predicted_candidates+=("$_line")
done < <(
    echo "$dry_output" \
    | grep -E '^[a-z][a-zA-Z0-9]' \
    | grep -v '^Total' \
    | awk '{print $1}'
)

predicted_count="${#predicted_candidates[@]}"
if [[ "$predicted_count" -gt 0 ]]; then
    ok "delete-exact: dry-run produced $predicted_count candidate(s) to verify"
else
    fail "delete-exact: dry-run produced candidates to verify" "zero candidates parsed — check fixture"
fi

# Run --delete
bash "$SCRIPT" --delete "$DELETE_DIR" > /dev/null 2>&1

# Every predicted candidate must now be absent
missing_from_disk=0
for candidate in "${predicted_candidates[@]}"; do
    [[ -z "$candidate" ]] && continue
    if [[ -d "$DELETE_DIR/$candidate" ]]; then
        fail "delete-exact: '$candidate' was predicted but NOT deleted" "dir still exists"
        missing_from_disk=$(( missing_from_disk + 1 ))
    fi
done
if [[ "$missing_from_disk" -eq 0 && "$predicted_count" -gt 0 ]]; then
    ok "delete-exact: all $predicted_count predicted candidates were removed"
fi

# Newest versions of multi-version extensions must still be present
for survivor in \
    "ms-azuretools.vscode-azurefunctions-2.0.0" \
    "ms-python.python-2024.0.0" \
    "anthropic.claude-code-2.2.0-darwin-arm64" \
    "ms-vscode.cpptools-1.20.0-linux-x64" \
    "ms-vscode-remote.remote-ssh-0.114.0" \
    "redhat.java-1.30.0-linux-x64"
do
    if [[ -d "$DELETE_DIR/$survivor" ]]; then
        ok "delete-exact: newest '$survivor' preserved"
    else
        fail "delete-exact: newest '$survivor' preserved" "dir was deleted"
    fi
done

# Single-version extensions must also survive
for solo in "eamodio.gitlens-14.9.0" "dracula-theme.theme-dracula-2.25.1"; do
    if [[ -d "$DELETE_DIR/$solo" ]]; then
        ok "delete-exact: single-version '$solo' preserved"
    else
        fail "delete-exact: single-version '$solo' preserved" "dir was deleted"
    fi
done

# After deleting all candidates, another dry-run must say "Nothing to clean"
post_delete_output=$(bash "$SCRIPT" "$DELETE_DIR" 2>&1)
assert_contains "delete-exact: second dry-run says nothing to clean" \
    "Nothing to clean" "$post_delete_output"

# ══════════════════════════════════════════════════════════════════════════
# TEST GROUP 4: Edge cases
# ══════════════════════════════════════════════════════════════════════════
echo
echo "--- Group 4: Edge cases ---"

# ── 4a: Cross-platform version difference ─────────────────────────────────
# ext-1.0.0-darwin and ext-2.0.0-linux share ext_id; older one is a candidate.
PLATFORM_CROSS_DIR="$TMPDIR_BASE/platform_cross"
mkdir -p "$PLATFORM_CROSS_DIR"
make_ext "$PLATFORM_CROSS_DIR" "pub.myext-1.0.0-darwin-arm64"
make_ext "$PLATFORM_CROSS_DIR" "pub.myext-2.0.0-linux-x64"

output=$(bash "$SCRIPT" "$PLATFORM_CROSS_DIR" 2>&1)
assert_contains "platform-cross: older 1.0.0-darwin is a candidate" \
    "pub.myext-1.0.0-darwin-arm64" "$output"
assert_not_contains "platform-cross: newer 2.0.0-linux is NOT a candidate" \
    "pub.myext-2.0.0-linux-x64" "$output"

# ── 4b: Same version, different platform → both kept ──────────────────────
# When two platform variants share the same (newest) version, neither is a
# candidate because version == newest_version for both.
PLATFORM_SAME_VER_DIR="$TMPDIR_BASE/platform_same_ver"
mkdir -p "$PLATFORM_SAME_VER_DIR"
make_ext "$PLATFORM_SAME_VER_DIR" "pub.myext-1.0.0-darwin-arm64"
make_ext "$PLATFORM_SAME_VER_DIR" "pub.myext-1.0.0-linux-x64"
make_ext "$PLATFORM_SAME_VER_DIR" "pub.myext-0.9.0-linux-x64"  # older — must be candidate

output=$(bash "$SCRIPT" "$PLATFORM_SAME_VER_DIR" 2>&1)
assert_not_contains "platform-same-ver: 1.0.0-darwin-arm64 kept (same as newest)" \
    "pub.myext-1.0.0-darwin-arm64" "$output"
assert_not_contains "platform-same-ver: 1.0.0-linux-x64 kept (same as newest)" \
    "pub.myext-1.0.0-linux-x64" "$output"
assert_contains "platform-same-ver: 0.9.0 older version is candidate" \
    "pub.myext-0.9.0-linux-x64" "$output"

# ── 4c: Dirs with no parseable version segment ────────────────────────────
# The script must skip unparseable entries and still function on the valid ones.
NOVERSION_DIR="$TMPDIR_BASE/noversion"
mkdir -p "$NOVERSION_DIR"
make_ext "$NOVERSION_DIR" "publisher.valid-1.0.0"
make_ext "$NOVERSION_DIR" "publisher.valid-2.0.0"
mkdir -p "$NOVERSION_DIR/publisher.noversion"          # missing version segment
mkdir -p "$NOVERSION_DIR/notanextension"               # no dot separator
mkdir -p "$NOVERSION_DIR/publisher.ext-notaversion"    # version starts with letter

set +e
output=$(bash "$SCRIPT" "$NOVERSION_DIR" 2>&1)
noversion_exit=$?
set -e
assert_exit_code "noversion: script exits 0 despite unparseable entries" "0" "$noversion_exit"
assert_contains "noversion: valid 1.0.0 is candidate" \
    "publisher.valid-1.0.0" "$output"
assert_not_contains "noversion: publisher.noversion not listed" \
    "publisher.noversion" "$output"
assert_not_contains "noversion: notanextension not listed" \
    "notanextension" "$output"
assert_not_contains "noversion: publisher.ext-notaversion not listed" \
    "publisher.ext-notaversion" "$output"

# ── 4d: Symlinked entry inside the target dir ─────────────────────────────
# Symlinks are explicitly skipped; the symlinked dir must never appear as a
# candidate (even if its name looks like a valid extension dir).
SYMLINK_DIR="$TMPDIR_BASE/symlink"
mkdir -p "$SYMLINK_DIR"
make_ext "$SYMLINK_DIR" "publisher.real-1.0.0"
make_ext "$SYMLINK_DIR" "publisher.real-2.0.0"
SYMLINK_REAL_TARGET="$TMPDIR_BASE/symlink_real_target"
make_ext "$TMPDIR_BASE" "symlink_real_target"   # place target outside the dir
ln -s "$SYMLINK_REAL_TARGET" "$SYMLINK_DIR/publisher.linked-1.0.0"

output=$(bash "$SCRIPT" "$SYMLINK_DIR" 2>&1)
assert_not_contains "symlink: symlinked entry not listed as candidate" \
    "publisher.linked-1.0.0" "$output"
assert_contains "symlink: real old version is still a candidate" \
    "publisher.real-1.0.0" "$output"

# Verify symlink is not deleted when --delete runs
SYMLINK_DELETE_DIR="$TMPDIR_BASE/symlink_delete"
mkdir -p "$SYMLINK_DELETE_DIR"
make_ext "$SYMLINK_DELETE_DIR" "publisher.real-1.0.0"
make_ext "$SYMLINK_DELETE_DIR" "publisher.real-2.0.0"
ln -s "$SYMLINK_REAL_TARGET" "$SYMLINK_DELETE_DIR/publisher.linked-1.0.0"

bash "$SCRIPT" --delete "$SYMLINK_DELETE_DIR" > /dev/null 2>&1
if [[ -L "$SYMLINK_DELETE_DIR/publisher.linked-1.0.0" ]]; then
    ok "symlink: symlinked entry untouched by --delete"
else
    fail "symlink: symlinked entry untouched by --delete" "symlink was removed"
fi

# ── 4e: Empty target dir ──────────────────────────────────────────────────
EMPTY_DIR="$TMPDIR_BASE/empty"
mkdir -p "$EMPTY_DIR"

set +e
output=$(bash "$SCRIPT" "$EMPTY_DIR" 2>&1)
empty_exit=$?
set -e
assert_exit_code "empty-dir: exits 0" "0" "$empty_exit"
assert_contains "empty-dir: reports nothing to clean" "Nothing to clean" "$output"

# ── 4f: Dir containing only extensions.json, no extension dirs ────────────
ONLY_JSON_DIR="$TMPDIR_BASE/only_json"
mkdir -p "$ONLY_JSON_DIR"
cat > "$ONLY_JSON_DIR/extensions.json" <<'EOF'
[
  {
    "identifier": {"id": "publisher.ext"},
    "version": "1.0.0",
    "location": {},
    "relativeLocation": "publisher.ext-1.0.0",
    "metadata": {}
  }
]
EOF

set +e
output=$(bash "$SCRIPT" "$ONLY_JSON_DIR" 2>&1)
only_json_exit=$?
set -e
assert_exit_code "only-json: exits 0" "0" "$only_json_exit"
assert_contains "only-json: reports nothing to clean" "Nothing to clean" "$output"

# ══════════════════════════════════════════════════════════════════════════
# TEST GROUP 5: Exit codes
# ══════════════════════════════════════════════════════════════════════════
echo
echo "--- Group 5: Exit codes ---"

# 5a: 0 when single version per extension (nothing to clean)
SINGLE_DIR="$TMPDIR_BASE/exit_single"
mkdir -p "$SINGLE_DIR"
make_ext "$SINGLE_DIR" "publisher.solo-1.0.0"

set +e
bash "$SCRIPT" "$SINGLE_DIR" > /dev/null 2>&1
single_exit=$?
set -e
assert_exit_code "exit-codes: 0 when nothing to clean (single version)" "0" "$single_exit"

# 5b: 0 on dry-run when candidates exist (dry-run is not an error)
MULTI_DIR="$TMPDIR_BASE/exit_multi"
mkdir -p "$MULTI_DIR"
make_ext "$MULTI_DIR" "publisher.ext-1.0.0"
make_ext "$MULTI_DIR" "publisher.ext-2.0.0"

set +e
bash "$SCRIPT" "$MULTI_DIR" > /dev/null 2>&1
dryrun_exit=$?
set -e
assert_exit_code "exit-codes: 0 on dry-run with candidates (not an error)" "0" "$dryrun_exit"

# 5c: 0 on successful --delete
set +e
bash "$SCRIPT" --delete "$MULTI_DIR" > /dev/null 2>&1
delete_exit=$?
set -e
assert_exit_code "exit-codes: 0 on successful --delete" "0" "$delete_exit"

# 5d: nonzero on nonexistent directory
set +e
bash "$SCRIPT" "/tmp/does-not-exist-vscode-cleaner-$$" > /dev/null 2>&1
nonexist_exit=$?
set -e
if [[ "$nonexist_exit" -ne 0 ]]; then
    ok "exit-codes: nonzero ($nonexist_exit) on nonexistent dir"
else
    fail "exit-codes: nonzero on nonexistent dir" "got 0"
fi

# 5e: error message goes to stderr (not stdout) for nonexistent dir
set +e
stdout_output=$(bash "$SCRIPT" "/tmp/does-not-exist-vscode-cleaner-xxx" 2>/dev/null)
set -e
if [[ -z "$stdout_output" ]]; then
    ok "exit-codes: error for nonexistent dir is on stderr (stdout empty)"
else
    fail "exit-codes: error for nonexistent dir is on stderr (stdout empty)" \
        "got stdout: $stdout_output"
fi

# 5f: dry-run with candidates must NOT print "Deleted:" on stdout
DRYRUN_NODELETED_DIR="$TMPDIR_BASE/exit_dryrun_check"
mkdir -p "$DRYRUN_NODELETED_DIR"
make_ext "$DRYRUN_NODELETED_DIR" "publisher.ext-1.0.0"
make_ext "$DRYRUN_NODELETED_DIR" "publisher.ext-2.0.0"

output=$(bash "$SCRIPT" "$DRYRUN_NODELETED_DIR" 2>&1)
assert_not_contains "exit-codes: dry-run output has no 'Deleted:' line" "Deleted:" "$output"
assert_contains "exit-codes: dry-run output has --delete hint" "--delete" "$output"

# ══════════════════════════════════════════════════════════════════════════
# TEST GROUP 6: Guaranteed-survivor invariant (wrong-deletion safety)
#
# VS Code's .obsolete bookkeeping cannot be trusted blindly. After --delete,
# every extension ID that had at least one on-disk directory still has at
# least one on-disk directory.
# ══════════════════════════════════════════════════════════════════════════
echo
echo "--- Group 6: Guaranteed-survivor invariant ---"

# ── 6a: Sole copy in .obsolete is kept (claude-code scenario) ─────────────
# extensions.json records a version that does not exist on disk; the only
# on-disk dir is in .obsolete — it must NOT be treated as a deletion candidate.
SOLE_OBSOLETE_DIR="$TMPDIR_BASE/sole_obsolete"
mkdir -p "$SOLE_OBSOLETE_DIR"
make_ext "$SOLE_OBSOLETE_DIR" "anthropic.claude-code-2.1.202-darwin-arm64"
printf '{"anthropic.claude-code-2.1.202-darwin-arm64": true}\n' \
    > "$SOLE_OBSOLETE_DIR/.obsolete"
cat > "$SOLE_OBSOLETE_DIR/extensions.json" <<'EOF'
[
  {
    "identifier": {"id": "anthropic.claude-code"},
    "version": "2.1.207",
    "relativeLocation": "anthropic.claude-code-2.1.207-darwin-arm64",
    "metadata": {}
  }
]
EOF

output=$(bash "$SCRIPT" "$SOLE_OBSOLETE_DIR" 2>&1)
assert_contains "sole-obsolete: sole copy kept (nothing to clean)" \
    "Nothing to clean" "$output"
assert_not_contains "sole-obsolete: sole copy not listed as candidate" \
    "anthropic.claude-code-2.1.202-darwin-arm64" "$output"

SOLE_OBSOLETE_DELETE_DIR="$TMPDIR_BASE/sole_obsolete_delete"
mkdir -p "$SOLE_OBSOLETE_DELETE_DIR"
make_ext "$SOLE_OBSOLETE_DELETE_DIR" "anthropic.claude-code-2.1.202-darwin-arm64"
printf '{"anthropic.claude-code-2.1.202-darwin-arm64": true}\n' \
    > "$SOLE_OBSOLETE_DELETE_DIR/.obsolete"
cp "$SOLE_OBSOLETE_DIR/extensions.json" "$SOLE_OBSOLETE_DELETE_DIR/"
bash "$SCRIPT" --delete "$SOLE_OBSOLETE_DELETE_DIR" > /dev/null 2>&1
if [[ -d "$SOLE_OBSOLETE_DELETE_DIR/anthropic.claude-code-2.1.202-darwin-arm64" ]]; then
    ok "sole-obsolete: --delete preserved the sole copy"
else
    fail "sole-obsolete: --delete preserved the sole copy" "dir was deleted"
fi

# ── 6b: All copies in .obsolete keeps newest (nrwl scenario) ──────────────
# Both on-disk dirs are in .obsolete — the newer one must survive as the
# guaranteed survivor; the older one is a candidate.
ALL_OBSOLETE_DIR="$TMPDIR_BASE/all_obsolete"
mkdir -p "$ALL_OBSOLETE_DIR"
make_ext "$ALL_OBSOLETE_DIR" "nrwl.angular-console-18.100.5"
make_ext "$ALL_OBSOLETE_DIR" "nrwl.angular-console-18.101.0"
printf '{"nrwl.angular-console-18.100.5": true, "nrwl.angular-console-18.101.0": true}\n' \
    > "$ALL_OBSOLETE_DIR/.obsolete"

output=$(bash "$SCRIPT" "$ALL_OBSOLETE_DIR" 2>&1)
assert_contains "all-obsolete: older 18.100.5 is a candidate" \
    "nrwl.angular-console-18.100.5" "$output"
assert_not_contains "all-obsolete: newest 18.101.0 is NOT a candidate (survivor)" \
    "nrwl.angular-console-18.101.0" "$output"

ALL_OBSOLETE_DELETE_DIR="$TMPDIR_BASE/all_obsolete_delete"
mkdir -p "$ALL_OBSOLETE_DELETE_DIR"
make_ext "$ALL_OBSOLETE_DELETE_DIR" "nrwl.angular-console-18.100.5"
make_ext "$ALL_OBSOLETE_DELETE_DIR" "nrwl.angular-console-18.101.0"
printf '{"nrwl.angular-console-18.100.5": true, "nrwl.angular-console-18.101.0": true}\n' \
    > "$ALL_OBSOLETE_DELETE_DIR/.obsolete"
bash "$SCRIPT" --delete "$ALL_OBSOLETE_DELETE_DIR" > /dev/null 2>&1
if [[ ! -d "$ALL_OBSOLETE_DELETE_DIR/nrwl.angular-console-18.100.5" ]]; then
    ok "all-obsolete: --delete removed older 18.100.5"
else
    fail "all-obsolete: --delete removed older 18.100.5" "dir still exists"
fi
if [[ -d "$ALL_OBSOLETE_DELETE_DIR/nrwl.angular-console-18.101.0" ]]; then
    ok "all-obsolete: --delete preserved newest 18.101.0 (survivor)"
else
    fail "all-obsolete: --delete preserved newest 18.101.0 (survivor)" "dir was deleted"
fi

# ── 6c: .obsolete entries still deleted when non-obsolete survivor exists ──
# Preserves the original correct behavior: an obsolete dir is still a
# candidate when a non-obsolete dir exists to serve as the survivor.
OBSOLETE_WITH_SURVIVOR_DIR="$TMPDIR_BASE/obsolete_with_survivor"
mkdir -p "$OBSOLETE_WITH_SURVIVOR_DIR"
make_ext "$OBSOLETE_WITH_SURVIVOR_DIR" "publisher.tool-1.0.0"
make_ext "$OBSOLETE_WITH_SURVIVOR_DIR" "publisher.tool-2.0.0"
printf '{"publisher.tool-1.0.0": true}\n' \
    > "$OBSOLETE_WITH_SURVIVOR_DIR/.obsolete"

output=$(bash "$SCRIPT" "$OBSOLETE_WITH_SURVIVOR_DIR" 2>&1)
assert_contains "obsolete-with-survivor: obsolete 1.0.0 is candidate" \
    "publisher.tool-1.0.0" "$output"
assert_not_contains "obsolete-with-survivor: non-obsolete 2.0.0 is NOT candidate" \
    "publisher.tool-2.0.0" "$output"

bash "$SCRIPT" --delete "$OBSOLETE_WITH_SURVIVOR_DIR" > /dev/null 2>&1
if [[ ! -d "$OBSOLETE_WITH_SURVIVOR_DIR/publisher.tool-1.0.0" ]]; then
    ok "obsolete-with-survivor: --delete removed obsolete 1.0.0"
else
    fail "obsolete-with-survivor: --delete removed obsolete 1.0.0" "dir still exists"
fi
if [[ -d "$OBSOLETE_WITH_SURVIVOR_DIR/publisher.tool-2.0.0" ]]; then
    ok "obsolete-with-survivor: --delete preserved non-obsolete 2.0.0"
else
    fail "obsolete-with-survivor: --delete preserved non-obsolete 2.0.0" "dir was deleted"
fi

# ══════════════════════════════════════════════════════════════════════════
# TEST GROUP 7: Adversarial per-ID survivor rule — new deletion semantics
#
# Six scenarios that adversarially verify the updated deletion rule:
#   (i)  extensions.json-recorded dir wins unconditionally as survivor
#   (ii) newest non-obsolete dir is survivor when no extensions.json match
#   (iii) newest dir overall when all dirs are in .obsolete
#   Invariant: after --delete, every extension ID still has at least one dir.
# ══════════════════════════════════════════════════════════════════════════
echo
echo "--- Group 7: Adversarial per-ID survivor rule ---"

# ── 7a: Sole copy in .obsolete is KEPT when extensions.json references
#        a nonexistent dir — adversarial: co-exists with a normal multi-
#        version ID so both IDs must honour their respective rules at once ───
SOLE_OBS_MIXED_DIR="$TMPDIR_BASE/sole_obs_mixed"
mkdir -p "$SOLE_OBS_MIXED_DIR"
make_ext "$SOLE_OBS_MIXED_DIR" "anthropic.claude-code-2.1.202-darwin-arm64"
make_ext "$SOLE_OBS_MIXED_DIR" "publisher.other-1.0.0"
make_ext "$SOLE_OBS_MIXED_DIR" "publisher.other-2.0.0"
printf '{"anthropic.claude-code-2.1.202-darwin-arm64": true}\n' \
    > "$SOLE_OBS_MIXED_DIR/.obsolete"
cat > "$SOLE_OBS_MIXED_DIR/extensions.json" <<'EOF'
[
  {
    "identifier": {"id": "anthropic.claude-code"},
    "version": "2.1.207",
    "relativeLocation": "anthropic.claude-code-2.1.207-darwin-arm64",
    "metadata": {}
  }
]
EOF

output=$(bash "$SCRIPT" "$SOLE_OBS_MIXED_DIR" 2>&1)
assert_not_contains "7a: sole-obsolete claude-code is NOT a candidate (sole copy, extensions.json points to nonexistent)" \
    "anthropic.claude-code-2.1.202-darwin-arm64" "$output"
assert_contains "7a: co-located older normal version IS a candidate" \
    "publisher.other-1.0.0" "$output"
assert_not_contains "7a: co-located newest normal version is NOT a candidate" \
    "publisher.other-2.0.0" "$output"

bash "$SCRIPT" --delete "$SOLE_OBS_MIXED_DIR" > /dev/null 2>&1
if [[ -d "$SOLE_OBS_MIXED_DIR/anthropic.claude-code-2.1.202-darwin-arm64" ]]; then
    ok "7a: --delete preserved sole-obsolete copy (extensions.json pointed to nonexistent version)"
else
    fail "7a: --delete preserved sole-obsolete copy (extensions.json pointed to nonexistent version)" "dir was deleted"
fi
if [[ ! -d "$SOLE_OBS_MIXED_DIR/publisher.other-1.0.0" ]]; then
    ok "7a: --delete removed co-located older normal version"
else
    fail "7a: --delete removed co-located older normal version" "dir still exists"
fi

# ── 7b: ALL copies in .obsolete — three versions, only the newest survives ──
# Adversarial variant: three copies all in .obsolete; both older ones deleted.
ALL_OBS_THREE_DIR="$TMPDIR_BASE/all_obs_three"
mkdir -p "$ALL_OBS_THREE_DIR"
make_ext "$ALL_OBS_THREE_DIR" "nrwl.angular-console-18.99.0"
make_ext "$ALL_OBS_THREE_DIR" "nrwl.angular-console-18.100.5"
make_ext "$ALL_OBS_THREE_DIR" "nrwl.angular-console-18.101.0"
printf '{"nrwl.angular-console-18.99.0":true,"nrwl.angular-console-18.100.5":true,"nrwl.angular-console-18.101.0":true}\n' \
    > "$ALL_OBS_THREE_DIR/.obsolete"

output=$(bash "$SCRIPT" "$ALL_OBS_THREE_DIR" 2>&1)
assert_contains "7b: all-obsolete-3 oldest 18.99.0 is candidate" \
    "nrwl.angular-console-18.99.0" "$output"
assert_contains "7b: all-obsolete-3 middle 18.100.5 is candidate" \
    "nrwl.angular-console-18.100.5" "$output"
assert_not_contains "7b: all-obsolete-3 newest 18.101.0 is NOT candidate (survivor rule iii)" \
    "nrwl.angular-console-18.101.0" "$output"

bash "$SCRIPT" --delete "$ALL_OBS_THREE_DIR" > /dev/null 2>&1
if [[ ! -d "$ALL_OBS_THREE_DIR/nrwl.angular-console-18.99.0" ]]; then
    ok "7b: --delete removed all-obsolete-3 oldest 18.99.0"
else
    fail "7b: --delete removed all-obsolete-3 oldest 18.99.0" "dir still exists"
fi
if [[ ! -d "$ALL_OBS_THREE_DIR/nrwl.angular-console-18.100.5" ]]; then
    ok "7b: --delete removed all-obsolete-3 middle 18.100.5"
else
    fail "7b: --delete removed all-obsolete-3 middle 18.100.5" "dir still exists"
fi
if [[ -d "$ALL_OBS_THREE_DIR/nrwl.angular-console-18.101.0" ]]; then
    ok "7b: --delete preserved all-obsolete-3 newest 18.101.0 (survivor)"
else
    fail "7b: --delete preserved all-obsolete-3 newest 18.101.0 (survivor)" "dir was deleted"
fi

# ── 7c: Obsolete entry is a DELETION CANDIDATE even when it is version-NEWER
#        than the non-obsolete survivor — is_obsolete flag takes precedence ──
OBS_NEWER_DIR="$TMPDIR_BASE/obs_newer_than_survivor"
mkdir -p "$OBS_NEWER_DIR"
make_ext "$OBS_NEWER_DIR" "publisher.tool-2.0.0"   # non-obsolete → survivor (rule ii)
make_ext "$OBS_NEWER_DIR" "publisher.tool-3.0.0"   # in .obsolete, version-NEWER than survivor
printf '{"publisher.tool-3.0.0": true}\n' > "$OBS_NEWER_DIR/.obsolete"

output=$(bash "$SCRIPT" "$OBS_NEWER_DIR" 2>&1)
assert_contains "7c: obsolete 3.0.0 is candidate even though version-newer than non-obsolete survivor" \
    "publisher.tool-3.0.0" "$output"
assert_not_contains "7c: non-obsolete 2.0.0 is NOT candidate (it is the survivor)" \
    "publisher.tool-2.0.0" "$output"

bash "$SCRIPT" --delete "$OBS_NEWER_DIR" > /dev/null 2>&1
if [[ ! -d "$OBS_NEWER_DIR/publisher.tool-3.0.0" ]]; then
    ok "7c: --delete removed obsolete 3.0.0 (is_obsolete flag beats version-newer-than-survivor)"
else
    fail "7c: --delete removed obsolete 3.0.0 (is_obsolete flag beats version-newer-than-survivor)" "dir still exists"
fi
if [[ -d "$OBS_NEWER_DIR/publisher.tool-2.0.0" ]]; then
    ok "7c: --delete preserved non-obsolete 2.0.0 (the survivor)"
else
    fail "7c: --delete preserved non-obsolete 2.0.0 (the survivor)" "dir was deleted"
fi

# ── 7d: extensions.json-matched dir survives even when an on-disk sibling is
#        version-NEWER (the newer sibling is NOT a candidate because it is not
#        obsolete and not version-older than the extensions.json survivor) ────
EJ_OLDER_WINS_DIR="$TMPDIR_BASE/ej_older_wins"
mkdir -p "$EJ_OLDER_WINS_DIR"
make_ext "$EJ_OLDER_WINS_DIR" "publisher.ext-1.0.0"   # version-older than survivor → candidate
make_ext "$EJ_OLDER_WINS_DIR" "publisher.ext-2.0.0"   # in extensions.json → survivor (rule i)
make_ext "$EJ_OLDER_WINS_DIR" "publisher.ext-3.0.0"   # on-disk newer, not obsolete → NOT candidate
printf '{}' > "$EJ_OLDER_WINS_DIR/.obsolete"
cat > "$EJ_OLDER_WINS_DIR/extensions.json" <<'EOF'
[
  {
    "identifier": {"id": "publisher.ext"},
    "version": "2.0.0",
    "relativeLocation": "publisher.ext-2.0.0",
    "metadata": {}
  }
]
EOF

output=$(bash "$SCRIPT" "$EJ_OLDER_WINS_DIR" 2>&1)
assert_contains "7d: version-older 1.0.0 is candidate (older than extensions.json survivor)" \
    "publisher.ext-1.0.0" "$output"
assert_not_contains "7d: extensions.json-matched 2.0.0 is NOT candidate (it is the survivor)" \
    "publisher.ext-2.0.0" "$output"
assert_not_contains "7d: on-disk newer 3.0.0 is NOT candidate (not obsolete, not older than survivor)" \
    "publisher.ext-3.0.0" "$output"

bash "$SCRIPT" --delete "$EJ_OLDER_WINS_DIR" > /dev/null 2>&1
if [[ -d "$EJ_OLDER_WINS_DIR/publisher.ext-2.0.0" ]]; then
    ok "7d: --delete preserved extensions.json-matched 2.0.0 (survivor, rule i)"
else
    fail "7d: --delete preserved extensions.json-matched 2.0.0 (survivor, rule i)" "dir was deleted"
fi
if [[ -d "$EJ_OLDER_WINS_DIR/publisher.ext-3.0.0" ]]; then
    ok "7d: --delete preserved on-disk newer 3.0.0 (not a candidate)"
else
    fail "7d: --delete preserved on-disk newer 3.0.0 (not a candidate)" "dir was deleted"
fi
if [[ ! -d "$EJ_OLDER_WINS_DIR/publisher.ext-1.0.0" ]]; then
    ok "7d: --delete removed version-older 1.0.0"
else
    fail "7d: --delete removed version-older 1.0.0" "dir still exists"
fi

# ── 7e: Whole-tree post-delete invariant: the set of extension IDs present
#        before --delete must equal the set present after --delete ───────────
# Uses a mixed fixture that exercises all three survivor paths simultaneously.
INVARIANT_MIXED_DIR="$TMPDIR_BASE/invariant_mixed"
mkdir -p "$INVARIANT_MIXED_DIR"

# Rule (ii): normal multi-version, older gets deleted
make_ext "$INVARIANT_MIXED_DIR" "pub.normal-1.0.0"
make_ext "$INVARIANT_MIXED_DIR" "pub.normal-2.0.0"

# Rule (iii) sole: sole copy in .obsolete, extensions.json has nonexistent version
make_ext "$INVARIANT_MIXED_DIR" "anthropic.claude-code-2.1.202-darwin-arm64"

# Rule (iii) multiple: all copies in .obsolete, newest survives, older deleted
make_ext "$INVARIANT_MIXED_DIR" "nrwl.angular-console-18.100.5"
make_ext "$INVARIANT_MIXED_DIR" "nrwl.angular-console-18.101.0"

# Rule (i): extensions.json-matched dir wins over on-disk newer sibling
make_ext "$INVARIANT_MIXED_DIR" "pub.controlled-2.0.0"
make_ext "$INVARIANT_MIXED_DIR" "pub.controlled-3.0.0"

# Single version — no candidate generated
make_ext "$INVARIANT_MIXED_DIR" "eamodio.gitlens-14.9.0"

printf '{"anthropic.claude-code-2.1.202-darwin-arm64":true,"nrwl.angular-console-18.100.5":true,"nrwl.angular-console-18.101.0":true}\n' \
    > "$INVARIANT_MIXED_DIR/.obsolete"
cat > "$INVARIANT_MIXED_DIR/extensions.json" <<'EOF'
[
  {
    "identifier": {"id": "anthropic.claude-code"},
    "version": "2.1.207",
    "relativeLocation": "anthropic.claude-code-2.1.207-darwin-arm64",
    "metadata": {}
  },
  {
    "identifier": {"id": "pub.controlled"},
    "version": "2.0.0",
    "relativeLocation": "pub.controlled-2.0.0",
    "metadata": {}
  }
]
EOF

# Collect sorted unique extension IDs before deletion (bash 3.2: no assoc arrays)
_ids_before="$TMPDIR_BASE/invariant_ids_before"
_ids_after="$TMPDIR_BASE/invariant_ids_after"

{
    while IFS= read -r -d '' _fp; do
        _dn="$(basename -- "$_fp")"
        case "$_dn" in extensions.json|.obsolete|.*) continue ;; esac
        [[ -L "$_fp" ]] && continue
        [[ -d "$_fp" ]] || continue
        if echo "$_dn" | grep -qE '^[^.]+\.[^-].*-[0-9]'; then
            echo "$_dn" | sed -E 's/-[0-9][0-9.]*(-[a-zA-Z][^/]*)?$//'
        fi
    done < <(find "$INVARIANT_MIXED_DIR" -maxdepth 1 -mindepth 1 -print0 2>/dev/null)
} | sort -u > "$_ids_before"

INVARIANT_DELETE_DIR="$TMPDIR_BASE/invariant_mixed_delete"
cp -r "$INVARIANT_MIXED_DIR" "$INVARIANT_DELETE_DIR"
bash "$SCRIPT" --delete "$INVARIANT_DELETE_DIR" > /dev/null 2>&1

{
    while IFS= read -r -d '' _fp; do
        _dn="$(basename -- "$_fp")"
        case "$_dn" in extensions.json|.obsolete|.*) continue ;; esac
        [[ -L "$_fp" ]] && continue
        [[ -d "$_fp" ]] || continue
        if echo "$_dn" | grep -qE '^[^.]+\.[^-].*-[0-9]'; then
            echo "$_dn" | sed -E 's/-[0-9][0-9.]*(-[a-zA-Z][^/]*)?$//'
        fi
    done < <(find "$INVARIANT_DELETE_DIR" -maxdepth 1 -mindepth 1 -print0 2>/dev/null)
} | sort -u > "$_ids_after"

_before_count=$(wc -l < "$_ids_before" | tr -d ' ')
_after_count=$(wc -l < "$_ids_after" | tr -d ' ')

if [[ "$_before_count" -eq "$_after_count" ]] && diff -q "$_ids_before" "$_ids_after" > /dev/null 2>&1; then
    ok "7e: whole-tree invariant holds — same $_before_count extension IDs before and after --delete"
else
    _before_list="$(tr '\n' ' ' < "$_ids_before")"
    _after_list="$(tr '\n' ' ' < "$_ids_after")"
    fail "7e: whole-tree invariant holds — same extension IDs before and after --delete" \
        "before ($( echo "$_before_count")): $_before_list | after ($_after_count): $_after_list"
fi

# ── 7f: Survivor rule composes with dry-run: the set of dirs predicted by
#        dry-run equals exactly the set that --delete removes — no more, no less.
#        Covers all three survivor paths in a single fixture. ─────────────────
DRYRUN_EXACT2_DIR="$TMPDIR_BASE/dryrun_exact2"
mkdir -p "$DRYRUN_EXACT2_DIR"

# Rule (ii): normal multi-version
make_ext "$DRYRUN_EXACT2_DIR" "pub.normal-1.0.0"
make_ext "$DRYRUN_EXACT2_DIR" "pub.normal-2.0.0"

# Rule (iii) multiple: all in .obsolete
make_ext "$DRYRUN_EXACT2_DIR" "nrwl.angular-console-18.100.5"
make_ext "$DRYRUN_EXACT2_DIR" "nrwl.angular-console-18.101.0"

# Rule (iii) sole: sole copy in .obsolete, extensions.json points to nonexistent
make_ext "$DRYRUN_EXACT2_DIR" "anthropic.claude-code-2.1.202-darwin-arm64"

# Rule (i): extensions.json-matched 2.0.0 wins, version-older 1.0.0 is candidate
make_ext "$DRYRUN_EXACT2_DIR" "pub.ejprotected-1.0.0"
make_ext "$DRYRUN_EXACT2_DIR" "pub.ejprotected-2.0.0"

printf '{"anthropic.claude-code-2.1.202-darwin-arm64":true,"nrwl.angular-console-18.100.5":true,"nrwl.angular-console-18.101.0":true}\n' \
    > "$DRYRUN_EXACT2_DIR/.obsolete"
cat > "$DRYRUN_EXACT2_DIR/extensions.json" <<'EOF'
[
  {
    "identifier": {"id": "anthropic.claude-code"},
    "version": "2.1.207",
    "relativeLocation": "anthropic.claude-code-2.1.207-darwin-arm64",
    "metadata": {}
  },
  {
    "identifier": {"id": "pub.ejprotected"},
    "version": "2.0.0",
    "relativeLocation": "pub.ejprotected-2.0.0",
    "metadata": {}
  }
]
EOF

# Parse dry-run output to get predicted deletion candidates
dry2_output=$(bash "$SCRIPT" "$DRYRUN_EXACT2_DIR" 2>&1)
_predicted2=()
while IFS= read -r _line; do
    [[ -n "$_line" ]] && _predicted2+=("$_line")
done < <(
    echo "$dry2_output" \
    | grep -E '^[a-z][a-zA-Z0-9]' \
    | grep -v '^Total' \
    | awk '{print $1}'
)
_pred2_count="${#_predicted2[@]}"

if [[ "$_pred2_count" -gt 0 ]]; then
    ok "7f: dry-run identified $_pred2_count candidates (fixture sanity)"
else
    fail "7f: dry-run identified candidates" "zero candidates parsed — check fixture or parse logic"
fi

# Run --delete on a copy and verify exact match
DRYRUN_EXACT2_DELETE_DIR="$TMPDIR_BASE/dryrun_exact2_delete"
cp -r "$DRYRUN_EXACT2_DIR" "$DRYRUN_EXACT2_DELETE_DIR"
bash "$SCRIPT" --delete "$DRYRUN_EXACT2_DELETE_DIR" > /dev/null 2>&1

# Every predicted candidate must have been deleted
_miss2=0
for _c in "${_predicted2[@]}"; do
    [[ -z "$_c" ]] && continue
    if [[ -d "$DRYRUN_EXACT2_DELETE_DIR/$_c" ]]; then
        fail "7f: dry-run predicted '$_c' but --delete did NOT remove it" "dir still exists"
        _miss2=$(( _miss2 + 1 ))
    fi
done
if [[ "$_miss2" -eq 0 ]]; then
    ok "7f: --delete removed every dir predicted by dry-run (no prediction misses)"
else
    fail "7f: --delete removed every dir predicted by dry-run" "$_miss2 predicted dirs were not deleted"
fi

# No dir that was NOT predicted must have been deleted
_extra2=0
while IFS= read -r -d '' _fp; do
    _dn="$(basename -- "$_fp")"
    case "$_dn" in extensions.json|.obsolete|.*) continue ;; esac
    [[ -L "$_fp" ]] && continue
    [[ -d "$_fp" ]] || continue
    _in_pred=0
    for _c in "${_predicted2[@]}"; do
        if [[ "$_c" == "$_dn" ]]; then
            _in_pred=1
            break
        fi
    done
    if [[ "$_in_pred" -eq 0 ]] && [[ ! -d "$DRYRUN_EXACT2_DELETE_DIR/$_dn" ]]; then
        fail "7f: --delete removed '$_dn' which dry-run did NOT predict" "unexpected deletion"
        _extra2=$(( _extra2 + 1 ))
    fi
done < <(find "$DRYRUN_EXACT2_DIR" -maxdepth 1 -mindepth 1 -print0 2>/dev/null)
if [[ "$_extra2" -eq 0 ]]; then
    ok "7f: --delete made no deletions beyond dry-run predictions (no surprise deletions)"
fi

# Explicit spot-checks for the survivor scenarios
assert_not_contains "7f: sole-obsolete claude-code is NOT in dry-run candidates" \
    "anthropic.claude-code-2.1.202-darwin-arm64" "$dry2_output"
if [[ -d "$DRYRUN_EXACT2_DELETE_DIR/anthropic.claude-code-2.1.202-darwin-arm64" ]]; then
    ok "7f: sole-obsolete claude-code survived --delete (dry-run and delete agree)"
else
    fail "7f: sole-obsolete claude-code survived --delete (dry-run and delete agree)" "dir was deleted"
fi
assert_not_contains "7f: extensions.json-matched pub.ejprotected-2.0.0 is NOT in dry-run candidates" \
    "pub.ejprotected-2.0.0" "$dry2_output"
if [[ -d "$DRYRUN_EXACT2_DELETE_DIR/pub.ejprotected-2.0.0" ]]; then
    ok "7f: extensions.json-matched pub.ejprotected-2.0.0 survived --delete"
else
    fail "7f: extensions.json-matched pub.ejprotected-2.0.0 survived --delete" "dir was deleted"
fi

# ── Summary ─────────────────────────────────────────────────────────────────
echo
echo "Integration test results: ${PASS} passed, ${FAIL} failed"

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
