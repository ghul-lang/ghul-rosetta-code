#!/bin/bash

# Report solution sources the formatter would change. Every source is laid out
# as the compiler's formatter lays it out at 64 columns, and a source that
# differs from what the formatter writes fails the check. See AGENTS.md.
#
#   scripts/check-format.sh          list the sources that differ, with a diff
#   scripts/check-format.sh --fix    rewrite them in place instead
#
# A task whose source is also its own data - a quine, a program that reads its
# own text - carries a format-exempt file naming the sources to leave as they
# are, one path per line relative to the task directory, with the reason on a #
# line above them.
#
# Uses the compiler the tool manifest pins. Exits non-zero if any source
# differs, or if the formatter could not read one.

set -eo pipefail

ROOT=${CHECK_FORMAT_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
WIDTH=64

cd "$ROOT"

# Every source, less the ones a format-exempt file in the same task names.
sources() {
    local exempt
    exempt=$(mktemp)

    while IFS= read -r marker ; do
        local task
        task=$(dirname "$marker")

        grep -v '^[[:space:]]*\(#.*\)\?$' "$marker" | while IFS= read -r path ; do
            echo "$task/$path"
        done
    done < <(find tasks -name format-exempt) >"$exempt"

    find tasks -name '*.ghul' | sort | grep -vxF -f "$exempt"

    rm -f "$exempt"
}

if [ "$1" = "--fix" ] ; then
    sources | xargs -d '\n' -n 20 -P 4 dotnet ghul-compiler --format-in-place --format-width "$WIDTH"
    exit
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# The formatter rewrites a copy of each source in place, so the comparison is
# file by file whatever the compiler prints.
sources | while IFS= read -r source ; do
    mkdir -p "$work/$(dirname "$source")"
    cp "$source" "$work/$source"
done

# Run from the repository, so the tool manifest's compiler is the one used.
find "$work/tasks" -name '*.ghul' | xargs -d '\n' -n 20 -P 4 dotnet ghul-compiler --format-in-place --format-width "$WIDTH"

status=0

while IFS= read -r source ; do
    if ! cmp -s "$source" "$work/$source" ; then
        diff -u "$source" "$work/$source" --label "$source" --label "$source (formatted)" || true
        status=1
    fi
done < <(sources)

if [ $status -ne 0 ] ; then
    echo
    echo "the sources above are not as the formatter writes them; scripts/check-format.sh --fix rewrites them"
fi

exit $status
