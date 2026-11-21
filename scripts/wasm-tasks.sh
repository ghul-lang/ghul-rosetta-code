#!/bin/bash

# The programs to build and run for WebAssembly, one test directory a line:
# every program under the given task directories (all of tasks/ when none
# is given) that the playground can run and wasm-exempt.txt does not list.
#
#   dotnet ghul-test --config wasm $(scripts/wasm-tasks.sh)
#   scripts/wasm-tasks.sh --check    # every exemption names a program
#
# A program is a directory holding a source named after it. Its id is its
# path under tasks/, as the index writes it. A program with a
# playground-unsupported file is not run in the playground at all, so it
# needs no exemption.

set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
EXEMPT="$ROOT/wasm-exempt.txt"

exempt_ids() {
    [ -f "$EXEMPT" ] || return 0
    sed -e 's/#.*//' "$EXEMPT" | awk 'NF { print $1 }'
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

if [ "${1:-}" = --check ] ; then
    STATUS=0
    for id in $(exempt_ids) ; do
        if [ ! -f "$ROOT/tasks/$id/$(basename "$id").ghul" ] ; then
            echo "wasm-exempt.txt: $id is not a program under tasks/" >&2
            STATUS=1
        elif [ -f "$ROOT/tasks/$id/playground-unsupported" ] ; then
            echo "wasm-exempt.txt: $id is playground-unsupported, so needs no exemption" >&2
            STATUS=1
        fi
    done
    for id in $(exempt_ids | sort | uniq -d) ; do
        echo "wasm-exempt.txt: $id is listed more than once" >&2
        STATUS=1
    done
    exit $STATUS
fi

[ $# -gt 0 ] || set -- tasks

declare -A SKIP
for id in $(exempt_ids) ; do
    SKIP[tasks/$id]=1
done

for program in $(programs "$@") ; do
    if [ -n "${SKIP[$program]:-}" ] || [ -f "$ROOT/$program/playground-unsupported" ] ; then
        continue
    fi
    echo "$program"
done
