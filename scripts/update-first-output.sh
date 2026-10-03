#!/bin/bash

# Rewrite each task's first_output_ms and run_ms from a ghul-test run that
# recorded timings (ghul-test 6.1.0+): the milliseconds a task's program runs
# on the dev box before it prints anything and in total, a multi-part task
# taking the slowest of its parts. The playground shows a task carrying a
# large first_output_ms as one that computes for a while before it says
# anything, so the number has to say exactly that and nothing else - not how
# long the task takes to run, which most long runners spend printing steadily
# after an early first line. That is what run_ms carries, for the page to
# tell a long-running program from a stuck one.
#
#   scripts/update-first-output.sh <timings.events>
#
# where the input is a ghul-test events file whose finish lines carry
# timings. The field is written only where the wait reaches half a second,
# and removed everywhere else, so regenerating after a task is made quicker
# clears its entry rather than leaving a stale warning behind. A program that
# printed nothing counts as the timeout it ran to.
#
# The measurements are one machine's; the browser scales them by its own
# speed, so a rough number from a quiet box is close enough, and the script
# is the way to refresh them all at once after a batch of solutions change.
# Files are edited in place rather than through jq, which would reformat a
# task.json it had nothing to say about.

set -euo pipefail

HERE=$(dirname "$0")
ROOT=$(cd "$HERE/.." && pwd)

EVENTS=${1:?usage: update-first-output.sh <ghul-test events file>}

THRESHOLD_MS=500

# The slowest of a task's programs is what a reader of the task page meets,
# so one line a task: its slug, its longest wait for a first line of output,
# and its longest run, both in milliseconds, first output -1 where a program
# printed nothing.
grep -oE 'tasks/[^ ]+ \[run [0-9]+ ms, first output ([0-9]+ ms|none)\]' "$EVENTS" \
    | sed -E 's/ \[run ([0-9]+) ms, first output ([0-9]+) ms\]/@@\1@@\2/;
              s/ \[run ([0-9]+) ms, first output none\]/@@\1@@-1/' \
    | awk -F@@ '{ split($1, p, "/");
                  slug = p[2];
                  if ($3 + 0 > first[slug]) first[slug] = $3 + 0;
                  if ($2 + 0 > run[slug]) run[slug] = $2 + 0 }
        END { for (slug in first) print slug "\t" first[slug] "\t" run[slug] }' \
    | sort \
    | while IFS=$'\t' read -r slug first run; do
        json="$ROOT/tasks/$slug/task.json"
        [ -f "$json" ] || continue

        set_field() {
            local name=$1 value=$2

            if grep -q "\"$name\"" "$json"; then
                perl -pi -e "s/\"$name\": -?[0-9]+/\"$name\": $value/" "$json"
            else
                perl -0pi -e "s/\\n\\}\\n\\z/,\\n    \\\"$name\\\": $value\\n\\}\\n/" "$json"
            fi
        }

        clear_field() {
            local name=$1

            perl -0pi -e "s/,\\n    \\\"$name\\\": -?[0-9]+(?=\\n\\})//g;
                          s/    \\\"$name\\\": -?[0-9]+,\\n//g" "$json"
        }

        if [ "$first" -ge "$THRESHOLD_MS" ]; then
            set_field first_output_ms "$first"
        else
            clear_field first_output_ms
        fi

        if [ "$run" -ge "$THRESHOLD_MS" ]; then
            set_field run_ms "$run"
        else
            clear_field run_ms
        fi
    done

echo "updated: $(grep -rl 'first_output_ms' "$ROOT/tasks" | wc -l) tasks carry a first_output_ms"
