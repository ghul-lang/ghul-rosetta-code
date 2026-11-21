#!/usr/bin/env bash
#
# Fetches a few solutions as `ghul rosetta` does, from an index generated
# from this checkout rather than the published one, and runs `ghul test` on
# each, so the index, the files it lists and what ghul-cli makes of them
# cannot drift apart unnoticed. The sample covers each kind of test file a
# fetched project carries: plain output, standard input, arguments, files
# read beside the program, an exit status and a fixture.
#
# Usage: scripts/fetch-check.sh [--target <wasm|llvm>] [<task>...]
#
# Needs `ghul` (ghul.cli) on PATH, with what it needs to run the target.

set -euo pipefail

target=wasm

if [ "${1:-}" = --target ] ; then
    target=$2
    shift 2
fi

if [ $# -gt 0 ] ; then
    tasks=("$@")
else
    tasks=(
        100-doors
        24-game-solve
        command-line-arguments
        abc-words
        halt-and-catch-fire
        rename-a-file
    )
fi

root=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

echo "fetch-check: generating the index from $root" >&2
(cd "$root" && dotnet run --project tools/rosetta -- index --commit "$(git rev-parse HEAD)" > /dev/null)
mv "$root/index.json" "$scratch/index.json"

export GHUL_ROSETTA_INDEX="file://$scratch/index.json"
export GHUL_ROSETTA_REPOSITORY="file://$root"

failed=()

for task in "${tasks[@]}" ; do
    echo "fetch-check: $task on $target" >&2

    directory="$scratch/projects/$task"

    if ! ghul rosetta "$task" "$directory" ; then
        failed+=("$task (fetch)")
        continue
    fi

    if ! (cd "$directory" && ghul test --target "$target") ; then
        failed+=("$task")
    fi
done

if [ ${#failed[@]} -gt 0 ] ; then
    echo "fetch-check: failed on $target: ${failed[*]}" >&2
    exit 1
fi

echo "fetch-check: ${#tasks[@]} tasks fetched and passed on $target" >&2
