#!/bin/bash

CASE=$1

if [ ! -d $CASE ] ; then
    echo "no such test case directory: $CASE"
    exit 1;
fi

if [ ! -f $CASE/ghulflags ] ; then
    echo "not a test case directory (no ghulflags): $CASE"
    exit 1;
fi

# The runner compares text output ignoring whitespace, so a task whose output
# changed only in spacing passes and leaves no failed marker. A produced file
# that differs from its expectation byte for byte is still worth promoting.
differs() {
    local produced=$1 expectation=$2

    if [ ! -f "$produced" ] ; then
        return 1
    fi

    if [ ! -f "$expectation" ] ; then
        [ -s "$produced" ]
        return
    fi

    ! cmp -s "$produced" "$expectation"
}

if
    [ ! -f $CASE/failed ] &&
    ! differs $CASE/run.out $CASE/run.expected &&
    ! differs $CASE/err.sort $CASE/err.expected &&
    ! differs $CASE/warn.sort $CASE/warn.expected
then
    echo "nothing to capture in $CASE: no failed marker, and no produced output that differs from its expectations"
    echo "a passing run deletes its output; run the test with GHUL_TEST_KEEP_ARTIFACTS=1 to keep it for capture"
    exit 1
fi

# A solution that does not compile has no output worth capturing, and its
# errors are not an expectation: promoted, they become the thing the test
# asserts, and it passes from then on by continuing to fail to build.
if [ -s $CASE/err.sort ] ; then
    echo "$CASE did not compile:"
    echo
    sed 's/^/    /' $CASE/err.sort
    echo
    echo "compiler errors are not an expectation to capture. Fix the solution, or"
    echo "record the task as blocked against the issue that stops it:"
    echo
    echo "    dotnet run --project tools/rosetta -- set \"<task title>\" blocked <issue>"
    exit 1
fi

if [ -f $CASE/err.sort ] ; then
    mv $CASE/err.sort $CASE/err.expected
fi

if [ -f $CASE/warn.sort ] ; then
    mv $CASE/warn.sort $CASE/warn.expected
fi

# Deliberately no il.expected: these tasks assert what the program prints, not what the
# compiler emits. A test folder with no il.expected has its IL output ignored.

# An image the task wrote becomes the expectation for it. ghul-test compares
# the bytes first and the decoded pixels only if those differ, so an
# expectation stays good across a change to what the encoder compresses to.
for image in $CASE/*.png ; do
    if [ -f "$image" ] ; then
        cp "$image" "$image.expected"
    fi
done

if [ -f $CASE/run.out ] ; then
    mv $CASE/run.out $CASE/run.expected
    rm -f $CASE/fail.expected
else
    echo >$CASE/fail.expected
fi

# What the program wrote to standard error, and the status it ended with, are
# expectations only where a task is about them: carrying neither file says
# nothing about either, which is what nearly every task wants. So each is
# promoted when the run produced something worth asserting - anything on
# standard error, or an abnormal exit - or when the task already carries it.
if [ -f $CASE/run.err ] ; then
    if [ -s $CASE/run.err ] || [ -f $CASE/run.err.expected ] ; then
        # A stack frame names the source by the path the run happened to use,
        # and the runner compares frames with that path taken out, so the
        # snapshot is written the same way rather than holding local paths.
        sed -E 's| in [^ ]*/([^/]+):line | in \1:line |' $CASE/run.err > $CASE/run.err.expected
    fi

    rm -f $CASE/run.err
fi

if [ -f $CASE/run.exit ] ; then
    if [ "$(cat $CASE/run.exit)" != 0 ] || [ -f $CASE/run.exit.expected ] ; then
        mv $CASE/run.exit $CASE/run.exit.expected
    else
        rm -f $CASE/run.exit
    fi
fi

exit 0
