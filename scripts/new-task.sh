#!/bin/bash

# Scaffold a task: a runnable, testable project under tasks/. The test files
# (ghulflags, expected outputs) live in the same directory - the project is the
# test case.
#
#   scripts/new-task.sh <slug> "<Rosetta task title>"
#
# The slug is the task title lowercased, with anything that is not a letter or a digit collapsed
# to a single hyphen, so "Hello world/Text" is hello-world-text.

set -e

SLUG=$1
TITLE=$2

if [ -z "$SLUG" ] || [ -z "$TITLE" ] ; then
    echo "usage: scripts/new-task.sh <slug> \"<Rosetta task title>\""
    exit 1
fi

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TASK=$ROOT/tasks/$SLUG

if [ -e "$TASK" ] ; then
    echo "task already exists: tasks/$SLUG"
    exit 1
fi

# The wiki URL is the title with spaces underscored. Everything else, including the slash in a
# subtask like Hello world/Text, is left as it stands.
URL_TITLE=${TITLE// /_}

# A title can contain a quotation mark, which task.json holds as JSON.
JSON_TITLE=${TITLE//\"/\\\"}
JSON_URL_TITLE=${URL_TITLE//\"/\\\"}

mkdir -p "$TASK"

PROJECT='  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net10.0</TargetFramework>

    <AssemblyName>binary</AssemblyName>
    <GhulCompiler>dotnet ghul-compiler --test-run</GhulCompiler>
  </PropertyGroup>

  <ItemGroup>
    <GhulSources Include="**/*.ghul" />
  </ItemGroup>'

{
    echo '<Project Sdk="Microsoft.NET.Sdk">'
    echo "$PROJECT"
    echo '</Project>'
} >"$TASK/$SLUG.ghulproj"

cat >"$TASK/ghul.json" <<'EOJ'
{
    "restore_tools": true
}
EOJ

cat >"$TASK/task.json" <<EOJ
{
    "task": "$JSON_TITLE",
    "url": "https://rosettacode.org/wiki/$JSON_URL_TITLE",
    "status": "queued",
    "tags": [],
    "interest": 0
}
EOJ

cat >"$TASK/$SLUG.ghul" <<'EOJ'
use IO.Std.write_line

write_line("not written yet")
EOJ

for f in ghulflags err.expected warn.expected run.expected ; do
    : >"$TASK/$f"
done

echo "created tasks/$SLUG"
echo
echo "write the solution, then:"
echo "    dotnet run --project tasks/$SLUG"
echo "    dotnet ghul-test tasks/$SLUG"
echo "    scripts/capture.sh tasks/$SLUG"
