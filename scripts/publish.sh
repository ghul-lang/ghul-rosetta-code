#!/bin/bash

# Publish solutions to the wiki and land the record of it in one invocation.
#
#   scripts/publish.sh <slug>...      publish those tasks
#   scripts/publish.sh --solved       publish every task not yet on the wiki
#
# Any other argument is passed through to `rosetta publish`, so --dry-run,
# --replace, --minor and --note <text> work as they do there, in any position.
#
# The record is the point of this script. `rosetta publish` writes each page's
# new digest into ledger/ as it goes, and that digest is the only thing a
# later run can use to tell an edit made on the wiki from one made here. A run
# whose record never reaches main leaves every one of those pages unpublishable
# until somebody works out by hand what happened to them, which is what this
# repository spent a fortnight doing. So the branch, the commit, the push and
# the pull request happen here, in the same invocation, rather than being left
# to whoever remembers.
#
# The pull request merges itself: .github/workflows/ledger.yml approves a
# change that touches only the ledger. Nothing else this script does is
# reviewed, because nothing else this script does changes a solution.

set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)

cd "$ROOT"

if [ $# -eq 0 ] ; then
    echo "usage: scripts/publish.sh <slug>... | --solved" >&2
    exit 1
fi

if [ -n "$(git status --porcelain)" ] ; then
    echo "the working tree has changes; commit or discard them first" >&2
    echo "the record this writes has to be the only thing in its commit" >&2
    exit 1
fi

BRANCH=ghul-coder/publish-record-$(date +%Y-%m-%d-%H%M%S)

# Where to go back to if nothing publishes. `main` is checked out in the primary
# clone, so a worktree cannot return to it by name.
WAS=$(git symbolic-ref --quiet --short HEAD || git rev-parse HEAD)

git fetch --quiet origin main
git checkout --quiet -b "$BRANCH" origin/main

# Publishing reads the markup from wiki-out/, and markup generated from some
# earlier state of the tree would put that state on the wiki. Regenerate the
# tasks about to be published, and nothing else: --solved and an explicit list
# generate exactly what the publish run will read.
# The flags can come in any order, so which tasks to generate is decided by
# reading all of them rather than by looking at the first. A flag left in the
# slug list generates nothing and then publishes nothing.
#
# --target, --api, --rehearse and --note each take the next argument as their
# value rather than a slug - skip it along with the flag, or it lands in SLUGS
# and a generate/publish run goes looking for a task by that name.
SLUGS=()
SOLVED=
SKIP_NEXT=

for argument in "$@" ; do
    if [ -n "$SKIP_NEXT" ] ; then
        SKIP_NEXT=
        continue
    fi

    case "$argument" in
        --solved)                          SOLVED=yes ;;
        --target|--api|--rehearse|--note)  SKIP_NEXT=yes ;;
        --*)                               ;;
        *)                                 SLUGS+=("$argument") ;;
    esac
done

if [ -n "$SOLVED" ] ; then
    scripts/generate-wiki.sh --solved
elif [ ${#SLUGS[@]} -gt 0 ] ; then
    scripts/generate-wiki.sh --out "${SLUGS[@]}"
fi

# A task carrying notes.md put explanatory prose on the page as well as tested code, and that
# prose has not been through the tests the code has. This is only a reminder about what is about
# to go out - the run this script is part of is already a deliberate, explicit act - but it is
# worth saying before the edit is sent, not after.
if [ -n "$SOLVED" ] ; then
    PUBLISHING=$(jq -r 'select(.state == "solved" and .slug != null) | .slug' ledger/*.json)
else
    PUBLISHING="${SLUGS[*]}"
fi

NOTED=
for SLUG in $PUBLISHING ; do
    if [ -f "tasks/$SLUG/notes.md" ] || compgen -G "tasks/$SLUG/[0-9][0-9]-*/notes.md" >/dev/null ; then
        NOTED="$NOTED $SLUG"
    fi
done

if [ -n "$NOTED" ] ; then
    echo "these carry notes.md - confirm the rendered prose was reviewed before publishing:${NOTED}" >&2
fi

# A refusal is per page and the rest of the batch carries on, so a non-zero
# exit still leaves records worth keeping. Take the status and continue.
STATUS=0
dotnet run --project tools/rosetta -- publish "$@" || STATUS=$?

if [ -z "$(git status --porcelain ledger)" ] ; then
    echo "nothing was published, so there is no record to land"
    git checkout --quiet "$WAS"
    git branch --quiet -D "$BRANCH"
    exit "$STATUS"
fi

PUBLISHED=$(git diff --unified=0 ledger | grep -c '^+.*published_hash' || true)

git add ledger tasks/*/task.json
git commit --quiet -m "Record $PUBLISHED published sections' digests

Written by scripts/publish.sh from the run that made the edits."

git push --quiet -u origin "$BRANCH"

gh pr create \
    --head "$BRANCH" \
    --title "Record $PUBLISHED published sections' digests" \
    --technical "Record the digest of each section the publish run put on the wiki"

# Armed here, by the raiser: the ledger workflow only approves, and the pull
# request lands once its shards pass.
gh pr merge "$BRANCH" --auto --squash

echo
echo "recorded $PUBLISHED sections; the pull request merges itself once the shards pass"

exit "$STATUS"
