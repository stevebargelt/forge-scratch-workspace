#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

usage() {
    cat <<'EOF'
Usage: clean-vscode-extensions.sh [OPTIONS] [EXTENSIONS_DIR]

Remove old versions of VS Code extensions from an extensions directory.

ARGUMENTS
  EXTENSIONS_DIR    Directory to scan (default: ~/.vscode/extensions)

OPTIONS
  --delete    Actually delete old versions (default: dry run / print only)
  --help      Show this help message and exit

DESCRIPTION
  Groups extension directories by extension ID and keeps the newest version
  of each. Older versions are deletion candidates and are printed with their
  on-disk size. By default nothing is deleted; pass --delete to perform
  removal.

  If extensions.json exists in the target directory, the versions it records
  are treated as protected and will never be deleted, even when a newer
  directory exists alongside them.

  If .obsolete exists, its entries are treated as explicitly safe to delete
  regardless of version ordering.

  Non-extension entries (extensions.json, .obsolete, hidden files) and
  symlinks are skipped.

WORKFLOW
  # Step 1: preview what would be removed
  clean-vscode-extensions.sh

  # Step 2: delete after reviewing
  clean-vscode-extensions.sh --delete
EOF
}

DO_DELETE=false
EXTENSIONS_DIR="${HOME}/.vscode/extensions"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --delete)
            DO_DELETE=true
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        -*)
            echo "Error: unknown option: $1" >&2
            echo "Run with --help for usage." >&2
            exit 1
            ;;
        *)
            EXTENSIONS_DIR="$1"
            shift
            ;;
    esac
done

if [[ ! -d "$EXTENSIONS_DIR" ]]; then
    echo "Error: directory does not exist: $EXTENSIONS_DIR" >&2
    exit 1
fi

# Resolve to physical path to prevent symlink escapes
EXTENSIONS_DIR="$(cd -- "$EXTENSIONS_DIR" && pwd -P)"

# Read protected id-version pairs from extensions.json.
# Format: JSON array with objects containing identifier.id and version fields.
# We store keys of the form "<id>-<version>" (lowercase) as a newline-separated
# string for prefix matching — no associative array needed.
_PROTECTED_KEYS=""

EXTENSIONS_JSON="${EXTENSIONS_DIR}/extensions.json"
if [[ -f "$EXTENSIONS_JSON" ]] && command -v python3 &>/dev/null; then
    _PROTECTED_KEYS="$(python3 /dev/stdin "$EXTENSIONS_JSON" <<'PYEOF'
import sys, json
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
    if isinstance(data, list):
        for e in data:
            try:
                eid = e['identifier']['id'].lower()
                ver = e['version']
                print(f'{eid}-{ver}')
            except (KeyError, TypeError):
                pass
except Exception:
    pass
PYEOF
    )"
fi

# Read .obsolete entries (explicitly safe to delete).
# Format: JSON object whose keys are extension directory names.
# Stored as a newline-separated string of directory names.
_OBSOLETE_KEYS=""

OBSOLETE_FILE="${EXTENSIONS_DIR}/.obsolete"
if [[ -f "$OBSOLETE_FILE" ]] && command -v python3 &>/dev/null; then
    _OBSOLETE_KEYS="$(python3 /dev/stdin "$OBSOLETE_FILE" <<'PYEOF'
import sys, json
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
    if isinstance(data, dict):
        for key in data:
            print(key)
    elif isinstance(data, list):
        for item in data:
            if isinstance(item, str):
                print(item)
except Exception:
    pass
PYEOF
    )"
fi

# Extract the extension ID from a directory name.
# Format: <publisher>.<name>-<version>[-<platform>]
# Version always starts with a digit; platforms start with a letter.
ext_id_of() {
    echo "$1" | sed -E 's/-[0-9][0-9.]*(-[a-zA-Z][^/]*)?$//'
}

ext_version_of() {
    echo "$1" | sed -E 's/^.*-([0-9][0-9.]*)(-[a-zA-Z][^/]*)?$/\1/'
}

# Return 0 if the directory name matches a protected id-version prefix.
is_protected() {
    local dirname="$1"
    local key
    [[ -z "$_PROTECTED_KEYS" ]] && return 1
    while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        if [[ "$dirname" == "$key" || "$dirname" == "${key}"-* ]]; then
            return 0
        fi
    done <<< "$_PROTECTED_KEYS"
    return 1
}

# Return 0 if the directory name appears in the .obsolete list.
is_obsolete() {
    local dirname="$1"
    [[ -z "$_OBSOLETE_KEYS" ]] && return 1
    echo "$_OBSOLETE_KEYS" | grep -qxF -- "$dirname"
}

# Collect extension directories as "ext_id<TAB>dirname" pairs into a temp file,
# then sort and process consecutive groups — no associative array required.
_pairs_file="$(mktemp)"
trap 'rm -f "$_pairs_file"' EXIT

while IFS= read -r -d '' fullpath; do
    dirname="$(basename -- "$fullpath")"

    # Skip well-known non-extension entries and hidden files
    case "$dirname" in
        extensions.json|.obsolete) continue ;;
        .*) continue ;;
    esac

    # Newline in dirname poisons the line-oriented grouping temp file;
    # tab corrupts the two-field record format.  Reject all [:cntrl:].
    case "$dirname" in
        *$'\n'*)
            printf 'warning: skipping entry with control character in name\n' >&2
            continue ;;
    esac
    if printf '%s' "$dirname" | LC_ALL=C grep -q '[[:cntrl:]]'; then
        printf 'warning: skipping entry with control character in name\n' >&2
        continue
    fi

    # Skip symlinks (never follow out of target dir)
    [[ -L "$fullpath" ]] && continue

    [[ -d "$fullpath" ]] || continue

    # Must look like <publisher>.<name>-<digit>...
    if ! [[ "$dirname" =~ ^[^.]+\.[^-].*-[0-9] ]]; then
        continue
    fi

    ext_id="$(ext_id_of "$dirname")"

    # If ext_id equals dirname the version pattern didn't match — skip
    [[ "$ext_id" == "$dirname" ]] && continue

    # Must contain a dot (publisher separator)
    [[ "$ext_id" == *"."* ]] || continue

    printf '%s\t%s\n' "$ext_id" "$dirname" >> "$_pairs_file"
done < <(find "$EXTENSIONS_DIR" -maxdepth 1 -mindepth 1 -print0 2>/dev/null)

# Returns 0 if version string $1 is strictly less than version string $2.
_ver_lt() {
    local _a="$1" _b="$2"
    [[ "$_a" == "$_b" ]] && return 1
    [[ "$(printf '%s\n%s\n' "$_a" "$_b" | sort -V | head -n1)" == "$_a" ]]
}

# Determine deletion candidates by iterating over sorted id-grouped pairs.
CANDIDATES=()

_process_group() {
    local _eid="$1"
    local _gdirs="$2"
    local _d _v _survivor _non_obsolete_dirs _newest_ver _survivor_ver

    # Guaranteed-survivor invariant: after --delete, every extension ID that
    # had at least one directory still has at least one directory.
    # Survivor selection priority:
    #   (i)   extensions.json-recorded id+version dir if it exists on disk
    #   (ii)  newest (sort -V) non-obsolete dir
    #   (iii) newest dir overall (all dirs are in .obsolete)
    _survivor=""

    # (i) extensions.json-protected dir wins unconditionally
    while IFS= read -r _d; do
        [[ -z "$_d" ]] && continue
        if is_protected "$_d"; then
            _survivor="$_d"
            break
        fi
    done <<< "$_gdirs"

    # (ii) Newest non-obsolete dir
    if [[ -z "$_survivor" ]]; then
        _non_obsolete_dirs=""
        while IFS= read -r _d; do
            [[ -z "$_d" ]] && continue
            if ! is_obsolete "$_d"; then
                if [[ -z "$_non_obsolete_dirs" ]]; then
                    _non_obsolete_dirs="$_d"
                else
                    _non_obsolete_dirs="${_non_obsolete_dirs}"$'\n'"$_d"
                fi
            fi
        done <<< "$_gdirs"

        if [[ -n "$_non_obsolete_dirs" ]]; then
            _newest_ver="$(
                while IFS= read -r _d; do
                    [[ -z "$_d" ]] && continue
                    ext_version_of "$_d"
                done <<< "$_non_obsolete_dirs" | sort -V | tail -n1
            )"
            while IFS= read -r _d; do
                [[ -z "$_d" ]] && continue
                if [[ "$(ext_version_of "$_d")" == "$_newest_ver" ]]; then
                    _survivor="$_d"
                    break
                fi
            done <<< "$_non_obsolete_dirs"
        fi
    fi

    # (iii) All dirs are in .obsolete — pick newest overall as survivor
    if [[ -z "$_survivor" ]]; then
        _newest_ver="$(
            while IFS= read -r _d; do
                [[ -z "$_d" ]] && continue
                ext_version_of "$_d"
            done <<< "$_gdirs" | sort -V | tail -n1
        )"
        while IFS= read -r _d; do
            [[ -z "$_d" ]] && continue
            if [[ "$(ext_version_of "$_d")" == "$_newest_ver" ]]; then
                _survivor="$_d"
                break
            fi
        done <<< "$_gdirs"
    fi

    _survivor_ver="$(ext_version_of "$_survivor")"

    # Every dir except the survivor is a candidate if it is in .obsolete or
    # version-older than the survivor. Protected dirs are never candidates.
    while IFS= read -r _d; do
        [[ -z "$_d" ]] && continue
        [[ "$_d" == "$_survivor" ]] && continue
        is_protected "$_d" && continue
        _v="$(ext_version_of "$_d")"
        if is_obsolete "$_d" || _ver_lt "$_v" "$_survivor_ver"; then
            CANDIDATES+=("$_d")
        fi
    done <<< "$_gdirs"
}

_prev_id=""
_group_dirs=""

while IFS=$'\t' read -r _ext_id _dirname; do
    if [[ "$_ext_id" != "$_prev_id" ]]; then
        if [[ -n "$_prev_id" ]]; then
            _process_group "$_prev_id" "$_group_dirs"
        fi
        _prev_id="$_ext_id"
        _group_dirs="$_dirname"
    else
        _group_dirs="${_group_dirs}"$'\n'"$_dirname"
    fi
done < <(sort "$_pairs_file")

# Process the last group
[[ -n "$_prev_id" ]] && _process_group "$_prev_id" "$_group_dirs"

if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
    echo "Nothing to clean in: $EXTENSIONS_DIR"
    exit 0
fi

# Sort candidates and filter any empty strings
sorted_candidates=()
while IFS= read -r _line; do
    [[ -n "$_line" ]] && sorted_candidates+=("$_line")
done < <(printf '%s\n' "${CANDIDATES[@]}" | sort | grep -v '^$')

# Print candidates with sizes and accumulate total
total_kb=0

printf '\n%-72s %s\n' "EXTENSION DIRECTORY" "SIZE"
printf '%s\n' "$(printf '%.0s-' {1..80})"

for d in "${sorted_candidates[@]}"; do
    fullpath="${EXTENSIONS_DIR}/${d}"
    [[ -d "$fullpath" ]] || continue
    size_kb=$(du -sk -- "$fullpath" 2>/dev/null | cut -f1)
    size_human=$(du -sh -- "$fullpath" 2>/dev/null | cut -f1)
    printf '%-72s %s\n' "$d" "$size_human"
    total_kb=$(( total_kb + size_kb ))
done

total_human=$(awk -v kb="$total_kb" 'BEGIN {
    if (kb >= 1048576) printf "%.1fG", kb/1048576
    else if (kb >= 1024)  printf "%.1fM", kb/1024
    else                  printf "%dK",   kb
}')

printf '%s\n' "$(printf '%.0s-' {1..80})"
printf 'Total space to reclaim: %s (%d candidate(s))\n\n' \
    "$total_human" "${#sorted_candidates[@]}"

if $DO_DELETE; then
    echo "Deleting..."
    for d in "${sorted_candidates[@]}"; do
        fullpath="${EXTENSIONS_DIR}/${d}"
        [[ -d "$fullpath" ]] || continue
        rm -rf -- "$fullpath"
        echo "  Deleted: $d"
    done
    echo "Done."
else
    echo "Dry run — pass --delete to remove the directories listed above."
fi
