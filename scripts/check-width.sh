#!/bin/bash

# Report solution lines that are too wide to read where a solution is read: a fixed-width block on
# Rosetta Code, and a prose column on ghul.dev. See AGENTS.md.
#
#   scripts/check-width.sh          every line over the soft limit, worst first
#   scripts/check-width.sh --hard   only lines over the hard limit
#   scripts/check-width.sh --self-test
#                                   check that a planted wide line is caught
#
# A task whose source cannot be narrowed without becoming a different program carries a
# width-exempt file naming the sources to skip, one path per line relative to the task
# directory, with the reason on a # line above them. A quine is the case this exists for.
#
# Exits non-zero if anything is over the hard limit, or if the widths could not
# be measured at all.

set -eo pipefail

# Under some UTF-8 locales awk rejects the byte range the measurement uses and
# reports nothing, which would read as every line being narrow enough. The
# count below does not depend on the locale, so the plain one is used always.
export LC_ALL=C

SOFT=76
HARD=76

ROOT=${CHECK_WIDTH_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}

LIMIT=$SOFT

# Plant a line that is too wide and one that is narrow but full of multi-byte
# characters, and run the check on them from a plain and a UTF-8 locale. Only
# the wide line may be reported, and the check must fail because of it.
self_test() {
    local dir script status
    dir=$(mktemp -d)
    script=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")

    mkdir -p "$dir/tasks/planted"

    {
        printf 'x%.0s' $(seq 90)
        echo
        printf 'let s = "%s"\n' "$(printf '\303\251%.0s' $(seq 60))"
    } > "$dir/tasks/planted/planted.ghul"

    status=0

    for locale in C C.UTF-8 ; do
        local out

        if out=$(LC_ALL=$locale CHECK_WIDTH_ROOT=$dir "$script" --hard 2>&1) ; then
            echo "self-test: a 90-column line passed under $locale"
            status=1
        elif ! grep -q "^  90 tasks/planted/planted.ghul:1$" <<< "$out" ; then
            echo "self-test: the 90-column line was not reported under $locale:"
            echo "$out"
            status=1
        elif grep -q "planted.ghul:2" <<< "$out" ; then
            echo "self-test: a 70-character line was measured as too wide under $locale"
            status=1
        fi
    done

    rm -rf "$dir"

    if [ $status -eq 0 ] ; then
        echo "self-test passed"
    fi

    return $status
}

if [ "$1" = "--self-test" ] ; then
    self_test
    exit
fi

if [ "$1" = "--hard" ] ; then
    LIMIT=$HARD
fi

cd "$ROOT"

# Every source, less the ones a width-exempt file in the same task names.
sources() {
    local exempt
    exempt=$(mktemp)

    while IFS= read -r marker ; do
        local task
        task=$(dirname "$marker")

        grep -v '^[[:space:]]*\(#.*\)\?$' "$marker" | while IFS= read -r path ; do
            echo "$task/$path"
        done
    done < <(find tasks -name width-exempt) >"$exempt"

    find tasks -name '*.ghul' | grep -vxF -f "$exempt"

    rm -f "$exempt"
}

# A line is measured in characters, because what the limit is about is how wide
# it looks where the solution is read. awk's own length counts characters under
# a UTF-8 locale and bytes otherwise, and the container CI runs in has no UTF-8
# locale at all, which measured an accented 61-character line as 91. So the
# characters are counted here instead of asked for: in UTF-8 every byte of a
# character after its first is a continuation byte, so the count is the bytes
# less those. Same answer under any locale, and under mawk as under gawk.
measure() {
    sources | tr '\n' '\0' | xargs -0 awk -v limit="$1" '
        {
            rest = $0
            width = length($0) - gsub(/[\200-\277]/, "", rest)

            if (width > limit) {
                printf "%4d %s:%d\n", width, FILENAME, FNR
            }
        }'
}

if ! OVER=$(measure "$LIMIT" | sort -rn) ; then
    echo "check-width: could not measure the line widths" >&2
    exit 2
fi

if [ -n "$OVER" ] ; then
    echo "$OVER"
    echo
fi

if ! TOO_WIDE=$(measure "$HARD" | wc -l) ; then
    echo "check-width: could not measure the line widths" >&2
    exit 2
fi

echo "$(echo -n "$OVER" | grep -c . || true) over $LIMIT, $TOO_WIDE over the hard limit of $HARD"

[ "$TOO_WIDE" -eq 0 ]
