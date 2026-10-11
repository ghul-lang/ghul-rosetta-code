#!/bin/bash

# Add a part to a task, for the tasks worth showing more than one way. Each part is a whole
# program with its own project and test, and becomes one `===heading===` section of the
# entry, in the order the leading number gives.
#
#   scripts/new-part.sh <slug> <NN-name>
#
# The heading comes from the directory name: 01-using-map becomes "Using map". A task with parts
# has no source of its own - move the existing one into a part first, and delete the task's
# .ghulproj and ghul.json, or the two will collide over the entry point.

set -e

SLUG=$1
PART=$2

if [ -z "$SLUG" ] || [ -z "$PART" ] ; then
    echo "usage: scripts/new-part.sh <slug> <NN-name>"
    exit 1
fi

if [[ ! $PART =~ ^[0-9][0-9]-[a-z0-9-]+$ ]] ; then
    echo "part name must be NN-lower-case-name, for example 01-using-map"
    exit 1
fi

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TASK=$ROOT/tasks/$SLUG
DIR=$TASK/$PART

if [ ! -d "$TASK" ] ; then
    echo "no such task: tasks/$SLUG"
    exit 1
fi

if [ -e "$DIR" ] ; then
    echo "part already exists: tasks/$SLUG/$PART"
    exit 1
fi

mkdir -p "$DIR"

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
} >"$DIR/$PART.ghulproj"

cat >"$DIR/ghul.json" <<'EOJ'
{
    "restore_tools": true
}
EOJ

cat >"$DIR/$PART.ghul" <<'EOJ'
use IO.Std.write_line

write_line("not written yet")
EOJ

for f in ghulflags err.expected warn.expected run.expected ; do
    : >"$DIR/$f"
done

echo "created tasks/$SLUG/$PART"
echo
echo "write the part, then:"
echo "    dotnet run --project tasks/$SLUG/$PART"
echo "    dotnet ghul-test tasks/$SLUG/$PART"
echo "    scripts/capture.sh tasks/$SLUG/$PART"
