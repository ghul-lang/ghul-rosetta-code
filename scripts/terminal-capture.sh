#!/usr/bin/env bash
# Pictures of the terminal a task draws in, for the tasks that ask for one
# with a terminal-capture file: each frame of the output its test asserts is
# written as a page by `rosetta terminal-frames`, headless Chrome takes a
# picture of each, one at a time, and `rosetta terminal-image` puts them
# together as the task's terminal.png - a still, or an animated PNG that the
# publish uploads as a GIF.
#
# Run at publish time; the images are not committed, and nothing in CI
# compares them.
#
#   scripts/terminal-capture.sh <slug>...
#
# CHROME names the browser (default: google-chrome, else chromium).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
chrome="${CHROME:-$(command -v google-chrome || command -v chromium || true)}"

if [ -z "$chrome" ]; then
    echo "terminal-capture: no Chrome or Chromium found; set CHROME" >&2
    exit 1
fi

rosetta() {
    dotnet run --project "$root/tools/rosetta" -- "$@"
}

for slug in "$@"; do
    task="$root/tasks/$slug"

    [ -f "$task/terminal-capture" ] || continue

    work="$(mktemp -d)"
    profile="$(mktemp -d)"

    rosetta terminal-frames "$slug" "$work"
    read -r count width height < "$work/frames.txt"

    for ((i = 0; i < count; i++)); do
        name=$(printf 'frame-%03d' "$i")

        "$chrome" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
            --user-data-dir="$profile" --window-size="$width,$height" \
            --screenshot="$work/$name.png" "file://$work/$name.html" > /dev/null 2>&1

        [ -s "$work/$name.png" ] || { echo "terminal-capture: $slug: no picture of frame $i" >&2; exit 1; }
    done

    rosetta terminal-image "$slug" "$work"
    echo "$slug: $count frame(s), ${width}x${height}"

    rm -rf "$work" "$profile"
done
