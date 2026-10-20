#!/usr/bin/env bash
# Refreshes GHUL.md from the master copy in the ghul repository, or with
# --check says whether it is out of step.
#
# GHUL.md is not authored here. The master is ghul/GHUL.md on ghul's main
# branch. Its links to the topic files in ghul/docs/ are relative there, so
# they are written out as links to that repository here.
#
#   scripts/sync-ghul-md.sh           # refresh GHUL.md
#   scripts/sync-ghul-md.sh --check   # exit 1 if GHUL.md is out of step
#
# GHUL_MD_SOURCE names a different file to read, for a test.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source="${GHUL_MD_SOURCE:-https://raw.githubusercontent.com/ghul-lang/ghul/main/GHUL.md}"
docs="https://github.com/ghul-lang/ghul/blob/main/docs/"

scratch="$(mktemp)"
trap 'rm -f "$scratch"' EXIT

case "$source" in
    http://* | https://*) curl -fsSL "$source" -o "$scratch.raw" ;;
    *) cp "$source" "$scratch.raw" ;;
esac

sed -E "s#\]\(docs/#](${docs}#g" "$scratch.raw" > "$scratch"
rm -f "$scratch.raw"

if [ "${1:-}" = "--check" ]; then
    if ! diff -q "$scratch" "$repo_root/GHUL.md" > /dev/null; then
        echo "GHUL.md is out of step with ghul/main: run scripts/sync-ghul-md.sh" >&2
        exit 1
    fi

    echo "GHUL.md matches ghul/main."
    exit 0
fi

cp "$scratch" "$repo_root/GHUL.md"
echo "GHUL.md refreshed from ghul/main."
