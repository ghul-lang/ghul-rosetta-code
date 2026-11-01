#!/bin/bash

# Which tasks a change needs tested: the changed paths, one a line on standard
# input, in; on standard output either `full`, when something outside the
# tasks could affect any of them, or the task directories to run, space
# separated and possibly none.
#
#   git diff --name-only BASE HEAD | scripts/tasks-to-test.sh
#
# ci.yml asks here for every pull request.
# A path ledger-only.sh accepts - a ledger entry, or a task.json - records a
# task's state and runs nothing, so it names no task to run; asking that
# script rather than repeating its pattern keeps the two answers the same.

set -euo pipefail

HERE=$(dirname "$0")
CHANGED=$(cat)

# A change outside tasks/ and ledger/ - the tool, the scripts, the build
# props, the tool manifest, the workflows - can reach every task.
OUTSIDE=$(echo "$CHANGED" | grep -v -e '^tasks/' -e '^ledger/' -e '^$' || true)

if [ -n "$OUTSIDE" ] ; then
    echo full
    exit 0
fi

# A task project reaching outside its own task directory would make a task's
# result depend on a directory the diff does not name. A reference between
# the parts of one task stays inside it, and the task is run whole, so only
# one that leaves the task counts.
for PROJECT in $(grep -rl ProjectReference tasks \
    --include='*.ghulproj' --include='*.csproj' || true) ; do
    TASK=$(echo "$PROJECT" | cut -d/ -f1,2)

    for REFERENCE in $(grep -o 'ProjectReference Include="[^"]*"' "$PROJECT" \
        | sed 's/.*Include="\(.*\)"/\1/') ; do
        TARGET=$(realpath -m --relative-to=. "$(dirname "$PROJECT")/$REFERENCE")

        case "$TARGET" in
            "$TASK"/*) ;;
            *) echo full; exit 0 ;;
        esac
    done
done

TASKS=
for PATH_ in $(echo "$CHANGED" | grep '^tasks/' || true) ; do
    if echo "$PATH_" | bash "$HERE/ledger-only.sh" ; then
        continue
    fi

    TASK=$(echo "$PATH_" | cut -d/ -f1,2)

    # A task the change deletes has nothing left to run.
    if [ -d "$TASK" ] ; then
        TASKS="$TASKS $TASK"
    fi
done

echo $(echo $TASKS | tr ' ' '\n' | sort -u)
