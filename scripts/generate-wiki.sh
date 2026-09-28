#!/bin/bash

# Emit Rosetta Code wiki markup for a task: heading, playground link, any notes, the source, and
# the output its test captured. The markup is rendered by `rosetta section`, which is also what
# the index compares against the ledger's published_hash to tell a task changed since it was
# posted, so there is one renderer and the two cannot disagree.
#
# A task worth showing more than one way holds parts instead: tasks/<slug>/NN-name/, each a whole
# program with its own project and test. Each becomes a ===heading=== section with its own source
# and output, in the order the numbers give.
#
# The output shown is the test's run.expected (with run.err.expected where the test captures it),
# or wiki-output.txt where a task that talks to a service records a real run by hand. Nothing is
# built or run here: the task's own test holds run.expected equal to what the program prints, so
# run the test before generating markup for a task whose output has changed.
#
#   scripts/generate-wiki.sh <slug>          markup to stdout, ready to paste
#   scripts/generate-wiki.sh --all           writes wiki-out/<slug>.wiki for every working task
#   scripts/generate-wiki.sh --solved        the same, for the tasks not yet on the wiki
#   scripts/generate-wiki.sh --out <slug>... the same, for the tasks named
#
# Publishing reads wiki-out/, and a publish run posts either named slugs or every solved task, so
# --solved and --out generate exactly what such a run will read and nothing else.
#
# A task whose test carries a `disabled` marker is skipped, as is one with no source or no
# captured output: an entry that does not run should not be posted. A run that touches a task
# carrying notes.md prints "(notes)" beside it, since a batch that adds prose is not one to wave
# through unread.

set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)

rosetta() {
    dotnet run --project "$ROOT/tools/rosetta" -- "$@"
}

# The slugs of every task the ledger holds in the given state. A rejected task carries no slug,
# having no solution to name, so the state has to be matched on the same entry as the slug rather
# than on whichever line happens to come next.
slugs_in_state() {
    jq -r --arg state "$1" \
        'select(.state == $state and .slug != null) | .slug' \
        "$ROOT"/ledger/*.json
}

if [ "$1" = "--all" ] || [ "$1" = "--solved" ] || [ "$1" = "--out" ] ; then
    MODE=$1
    shift

    case $MODE in
        --all)
            SLUGS=$(for dir in "$ROOT"/tasks/*/ ; do basename "$dir" ; done)
            ;;
        --solved)
            SLUGS=$(slugs_in_state solved)

            if [ -z "$SLUGS" ] ; then
                echo "no solved tasks - everything with a solution is already on the wiki" >&2
                exit 0
            fi
            ;;
        --out)
            if [ $# -eq 0 ] ; then
                echo "--out needs at least one slug" >&2
                exit 1
            fi

            SLUGS=$*

            for SLUG in $SLUGS ; do
                if [ ! -d "$ROOT/tasks/$SLUG" ] ; then
                    echo "no such task: $SLUG" >&2
                    exit 1
                fi
            done
            ;;
    esac

    # A named task that produced nothing is the caller's problem: they asked for it by name and a
    # publish run would read a file that is missing or stale. A bulk run skipping a broken task is
    # the documented behaviour and stays a success.
    STATUS=0
    # shellcheck disable=SC2086
    rosetta wiki-out $SLUGS || STATUS=$?

    echo
    echo "written to wiki-out/ - paste each into the ghul section of the page above it"

    if [ "$MODE" = "--out" ] && [ "$STATUS" -ne 0 ] ; then
        exit 1
    fi
elif [ -n "$1" ] ; then
    # to stderr, so stdout stays exactly what gets pasted
    echo "paste into: $(jq -r '.url' "$ROOT/tasks/$1/task.json" 2>/dev/null)" >&2

    rosetta section "$1"
else
    echo "usage: scripts/generate-wiki.sh <slug>"
    echo "       scripts/generate-wiki.sh --all"
    echo "       scripts/generate-wiki.sh --solved"
    echo "       scripts/generate-wiki.sh --out <slug>..."
    exit 1
fi
