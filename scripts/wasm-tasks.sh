#!/bin/bash

# The programs to build and run for WebAssembly, one test directory a line:
# every program under the given task directories (all of tasks/ when none
# is given) that the playground can run and neither wasm-exempt.txt nor
# wasm-never.txt lists.
#
#   dotnet ghul-test --config wasm $(scripts/wasm-tasks.sh)
#   scripts/wasm-tasks.sh --check    # every exemption names a program
#   scripts/wasm-tasks.sh --others   # the programs left out instead
#   scripts/wasm-tasks.sh --fast     # the programs to run, less wasm-slow.txt's
#   scripts/wasm-tasks.sh --slow     # wasm-slow.txt's programs alone
#
# A program is a directory holding a source named after it. Its id is its
# path under tasks/, as the index writes it. A program with a
# playground-unsupported file is not run in the playground at all, so it
# needs no exemption.

set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
LISTS="wasm-exempt.txt wasm-never.txt"

# Each exempt program as `<list> <id>`.
exemptions() {
    local list
    for list in $LISTS ; do
        [ -f "$ROOT/$list" ] || continue
        sed -e 's/#.*//' "$ROOT/$list" | awk -v list="$list" 'NF { print list, $1 }'
    done
}

exempt_ids() {
    exemptions | awk '{ print $2 }'
}

programs() {
    local dir
    for dir in "$@" ; do
        find "$ROOT/$dir" -name '.*' -prune -o -type d -print
    done | while read -r candidate ; do
        if [ -f "$candidate/$(basename "$candidate").ghul" ] ; then
            echo "${candidate#"$ROOT"/}"
        fi
    done | sort -u
}

# Each program wasm-slow.txt lists, as its id.
slow_ids() {
    [ -f "$ROOT/wasm-slow.txt" ] || return 0
    sed -e 's/#.*//' "$ROOT/wasm-slow.txt" | awk 'NF { print $1 }'
}

if [ "${1:-}" = --check ] ; then
    STATUS=0
    for id in $(slow_ids) ; do
        if [ ! -f "$ROOT/tasks/$id/$(basename "$id").ghul" ] ; then
            echo "wasm-slow.txt: $id is not a program under tasks/" >&2
            STATUS=1
        elif [ -f "$ROOT/tasks/$id/playground-unsupported" ] || exempt_ids | grep -qx -- "$id" ; then
            echo "wasm-slow.txt: $id does not run on wasm, so cannot be slow there" >&2
            STATUS=1
        fi
    done
    for id in $(slow_ids | sort | uniq -d) ; do
        echo "$id is listed more than once in wasm-slow.txt" >&2
        STATUS=1
    done
    while read -r list id ; do
        if [ ! -f "$ROOT/tasks/$id/$(basename "$id").ghul" ] ; then
            echo "$list: $id is not a program under tasks/" >&2
            STATUS=1
        elif [ -f "$ROOT/tasks/$id/playground-unsupported" ] ; then
            echo "$list: $id is playground-unsupported, so needs no exemption" >&2
            STATUS=1
        fi
    done < <(exemptions)
    for id in $(exempt_ids | sort | uniq -d) ; do
        echo "$id is listed more than once in $LISTS" >&2
        STATUS=1
    done
    exit $STATUS
fi

OTHERS=
SLOW=
case "${1:-}" in
    --others) OTHERS=1 ; shift ;;
    --fast) SLOW=skip ; shift ;;
    --slow) SLOW=only ; shift ;;
esac

[ $# -gt 0 ] || set -- tasks

declare -A SKIP
for id in $(exempt_ids) ; do
    SKIP[tasks/$id]=1
done

declare -A SLOW_IDS
for id in $(slow_ids) ; do
    SLOW_IDS[tasks/$id]=1
done

for program in $(programs "$@") ; do
    if [ "$SLOW" = only ] ; then
        [ -n "${SLOW_IDS[$program]:-}" ] && echo "$program"
        continue
    fi
    if [ "$SLOW" = skip ] && [ -n "${SLOW_IDS[$program]:-}" ] ; then
        continue
    fi
    if [ -n "${SKIP[$program]:-}" ] || [ -f "$ROOT/$program/playground-unsupported" ] ; then
        [ -n "$OTHERS" ] && echo "$program"
        continue
    fi
    [ -n "$OTHERS" ] || echo "$program"
done
