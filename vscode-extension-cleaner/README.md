# vscode-extension-cleaner

Removes old versions of VS Code extensions from an extensions directory,
keeping only the newest version of each extension.

## Usage

```
clean-vscode-extensions.sh [OPTIONS] [EXTENSIONS_DIR]
```

**Arguments**

| Argument | Default | Description |
|---|---|---|
| `EXTENSIONS_DIR` | `~/.vscode/extensions` | Directory to scan |

**Options**

| Option | Description |
|---|---|
| `--delete` | Actually delete old versions (default: dry run) |
| `--help` | Show help and exit |

## Workflow

Always preview before deleting:

```bash
# Step 1: see what would be removed and how much space to reclaim
./clean-vscode-extensions.sh

# Step 2: delete after reviewing
./clean-vscode-extensions.sh --delete
```

## Behaviour

- **Dry-run by default.** Prints each deletion candidate with its size and a
  total space-to-reclaim figure. Nothing is deleted unless `--delete` is passed.
- **Newest version is kept.** For each extension ID, the directory with the
  highest version number (compared segment-by-segment) is retained; all older
  siblings are candidates for removal.
- **Platform suffixes handled.** Directory names like
  `anthropic.claude-code-2.1.202-darwin-arm64` are parsed correctly — the
  platform suffix does not affect version comparison or extension ID grouping.
- **extensions.json protection.** If `extensions.json` exists in the target
  directory, any version it records as currently installed is never deleted,
  even when a newer directory exists alongside it.
- **`.obsolete` entries are candidates, but never the last copy.** Directories
  listed in `.obsolete` are treated as deletion candidates even when they would
  otherwise be retained by version ordering. However, for each extension ID one
  directory is always guaranteed to survive `--delete`: (i) the
  `extensions.json`-recorded directory if it exists on disk, otherwise (ii) the
  newest non-obsolete directory, otherwise (iii) the newest directory overall
  when every copy is marked obsolete. This guards against VS Code's own
  bookkeeping being stale mid-update — `.obsolete` can list the only on-disk
  copy of an extension while `extensions.json` points at a directory that has
  not yet arrived on disk.
- **Skips non-extension entries.** `extensions.json`, `.obsolete`, hidden
  files, and symlinks are ignored.
- **Refuses nonexistent directories.** Exits with a nonzero status if the
  target directory does not exist.
- **Never follows symlinks** out of the target directory.

## Examples

```bash
# Scan default location
./clean-vscode-extensions.sh

# Scan a custom location
./clean-vscode-extensions.sh /path/to/my/extensions

# Delete old versions from default location
./clean-vscode-extensions.sh --delete

# Delete old versions from a custom location
./clean-vscode-extensions.sh --delete /path/to/my/extensions
```

## Tests

```bash
bash test/run-tests.sh
```

Tests live in `test/` alongside fixture directories that cover multi-version
grouping, platform-suffixed names, `extensions.json` protection, `.obsolete`
handling, the guaranteed-survivor invariant (sole-copy-in-obsolete and
all-copies-in-obsolete scenarios), single-version extensions, and error cases.

## Requirements

- bash 4.0+
- `sort -V` (GNU coreutils or compatible)
- `python3` (for JSON parsing; optional — protection and obsolete features
  degrade gracefully if unavailable)
- `du`, `awk` (standard POSIX utilities)
